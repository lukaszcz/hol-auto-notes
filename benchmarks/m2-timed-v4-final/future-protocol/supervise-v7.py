#!/usr/bin/env python3
"""Future v7 supervisor with transactional GO and close-first status."""
from __future__ import annotations

import argparse
import ctypes
import datetime
import errno
import importlib.util
import json
import math
import os
import pathlib
import select
import signal
import subprocess
import sys
import time
import traceback


HERE = pathlib.Path(__file__).resolve().parent
STATUS_VERSION = 7
HANDLED = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
SIGNAL_STATUS = {signal.SIGHUP: 129, signal.SIGINT: 130,
                 signal.SIGTERM: 143}
PR_SET_CHILD_SUBREAPER = 36
PR_GET_CHILD_SUBREAPER = 37


class PreflightError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError(message)


class Faults:
    def __init__(self):
        self.pending = {item for item in os.environ.get(
            "SUPERVISE_V7_INJECT", "").split(",") if item}
        self.triggered = []
        self.runtime_armed = False

    def arm(self):
        self.runtime_armed = True

    def hit(self, name):
        if (name == "proc_scan" and
                "persistent_proc_scan" in self.pending and
                self.runtime_armed):
            if "persistent_proc_scan" not in self.triggered:
                self.triggered.append("persistent_proc_scan")
            raise RuntimeError("injected persistent proc_scan failure")
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            raise RuntimeError("injected %s failure" % name)

    def inject_close(self, name):
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            return True
        return False


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def identity_json(value):
    return None if value is None else {"pid": value[0],
                                       "starttime": value[1]}


def status_argument(argv):
    for index, item in enumerate(argv):
        if item == "--status" and index + 1 < len(argv):
            return argv[index + 1]
        if item.startswith("--status="):
            return item.split("=", 1)[1]
    return None


def atomic_json(path, row, faults=None):
    if faults is not None:
        faults.hit("status_write")
    target = pathlib.Path(path)
    temporary = target.with_name(target.name + ".tmp.%d" % os.getpid())
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(row, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise


def preflight_record(path, diagnostic, classification, provenance=None):
    row = {"benchmark_launched": False, "classification": classification,
           "containment_preflight": provenance, "diagnostic": diagnostic,
           "protocol_version": 7, "record_kind": "preflight",
           "supervisor_return_status": 125}
    try:
        if path:
            atomic_json(path, row)
            return
    except BaseException as error:
        diagnostic += "; status_write=%s" % error
    print("supervise-v7: %s" % diagnostic, file=sys.stderr)


def enable_and_verify_subreaper():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))
    state = ctypes.c_int()
    if libc.prctl(PR_GET_CHILD_SUBREAPER, ctypes.byref(state), 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))
    if state.value != 1:
        raise OSError(errno.ENOTSUP, "subreaper state did not persist")


def close_once(role, descriptor, injected, rows, errors):
    """Never retry close: after EINTR the numeric fd may already be reused."""
    if descriptor is None:
        rows.append({"os_exit_will_close": False, "result": "not_open",
                     "role": role})
        return
    try:
        os.close(descriptor)
        result = "injected_error_after_close" if injected else "closed"
    except OSError as error:
        result = "error:%s" % error
    if result != "closed":
        errors.append("%s close: %s" % (role, result))
    rows.append({"os_exit_will_close": result.startswith("error:"),
                 "result": result, "role": role})


def require_pidfds(faults, closes):
    if not hasattr(os, "pidfd_open") or not hasattr(signal,
                                                     "pidfd_send_signal"):
        raise OSError(errno.ENOSYS, "Python pidfd API unavailable")
    descriptor = os.pidfd_open(os.getpid(), 0)
    errors = []
    close_once("temp_preflight", descriptor, faults.inject_close(
        "temp_preflight_pidfd_close"), closes, errors)
    if errors:
        raise OSError(errno.EIO, errors[0])


def proc_row(pid):
    try:
        text = pathlib.Path("/proc/%d/stat" % pid).read_text(encoding="ascii")
    except (FileNotFoundError, ProcessLookupError):
        return None
    close = text.rfind(")")
    fields = text[close + 2:].split() if close >= 0 else []
    if len(fields) < 20:
        return None
    return {"pid": pid, "state": fields[0], "ppid": int(fields[1]),
            "pgid": int(fields[2]), "sid": int(fields[3]),
            "starttime": int(fields[19])}


def proc_snapshot():
    rows = {}
    with os.scandir("/proc") as entries:
        for entry in entries:
            if entry.name.isdigit():
                row = proc_row(int(entry.name))
                if row:
                    rows[row["pid"]] = row
    return rows


def pidfd_dead(descriptor):
    poller = select.poll()
    poller.register(descriptor, select.POLLIN)
    return bool(poller.poll(0))


def load_preflight():
    path = HERE / "containment-preflight-v7.py"
    spec = importlib.util.spec_from_file_location("containment_preflight_v7",
                                                  path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Controller:
    def __init__(self, poll, quiet, faults, preflight):
        self.poll, self.quiet, self.faults = poll, quiet, faults
        self.preflight = preflight
        self.wrapper = None
        self.wrapper_identity = None
        self.wrapper_pidfd = None
        self.init_identity = None
        self.init_pidfd = None
        self.pgid = None
        self.last_snapshot = proc_snapshot()
        self.signals, self.scans, self.reaps = [], [], []
        self.cleanup_errors, self.discovery_errors = [], []
        self.quiet_results, self.pidfd_closes = [], []
        self.wrapper_returncode = None
        self.namespace_ready = None
        self.benchmark_launched = False
        self.go_committed = False
        self.close_complete = False

    def attach_wrapper(self, child):
        self.wrapper = child
        self.pgid = child.pid
        # First post-Popen operation binds a non-reusable kernel handle.
        self.wrapper_pidfd = os.pidfd_open(child.pid, 0)
        row = proc_row(child.pid)
        if row is None:
            raise RuntimeError("unshare wrapper vanished before identity bind")
        self.wrapper_identity = (child.pid, row["starttime"])

    def bind_init(self, ready):
        deadline = time.monotonic() + 3
        while not ready.exists():
            if (self.wrapper.poll() is not None or
                    time.monotonic() >= deadline):
                raise RuntimeError("namespace init readiness failed")
            time.sleep(.005)
        self.namespace_ready = json.loads(ready.read_text())
        if (set(self.namespace_ready) != {
                "namespace_pid", "pid_namespace_inode",
                "proc_pid_one_present", "protocol_version"} or
                self.namespace_ready["protocol_version"] != 7 or
                self.namespace_ready["namespace_pid"] != 1 or
                not self.namespace_ready["proc_pid_one_present"]):
            raise RuntimeError("namespace init semantic proof failed")
        snapshot = proc_snapshot()
        candidates = [row for row in snapshot.values()
                      if row["ppid"] == self.wrapper.pid]
        if len(candidates) != 1:
            raise RuntimeError("namespace init host identity is not unique")
        init = candidates[0]
        self.init_identity = (init["pid"], init["starttime"])
        self.init_pidfd = os.pidfd_open(init["pid"], 0)
        verify = proc_row(init["pid"])
        if verify is None or verify["starttime"] != init["starttime"]:
            raise RuntimeError("namespace init identity changed during bind")
        self.last_snapshot = snapshot

    def scan(self, phase):
        self.faults.hit("proc_scan")
        self.last_snapshot = proc_snapshot()
        known = [item for item in (self.wrapper_identity, self.init_identity)
                 if item is not None]
        present = []
        for item in known:
            row = self.last_snapshot.get(item[0])
            if row and row["starttime"] == item[1]:
                present.append(item)
        self.scans.append({"known_present": [identity_json(item)
                                              for item in sorted(present)],
                           "phase": phase, "result": "observed"})
        return present

    def observe(self, phase):
        try:
            return self.scan(phase)
        except BaseException as error:
            message = "%s: %s: %s" % (phase, type(error).__name__, error)
            self.discovery_errors.append(message)
            self.cleanup_errors.append("discovery " + message)
            self.scans.append({"known_present": [], "phase": phase,
                               "result": "error"})
            return None

    def verified_group(self):
        if self.wrapper_pidfd is None or pidfd_dead(self.wrapper_pidfd):
            return False, "wrapper_identity_not_live"
        row = self.last_snapshot.get(self.wrapper_identity[0])
        if (row and row["starttime"] == self.wrapper_identity[1] and
                row["pgid"] == self.pgid):
            return True, "wrapper_pidfd_and_snapshot_verified"
        return True, "wrapper_pidfd_and_launch_pgid_verified"

    def signal_pidfd(self, role, identity, descriptor, signum, phase):
        result = "not_bound"
        if descriptor is None or identity is None:
            self.cleanup_errors.append("%s identity not bound" % role)
        elif pidfd_dead(descriptor):
            result = "already_dead"
        else:
            try:
                self.faults.hit("known_signal")
                signal.pidfd_send_signal(descriptor, signum, None, 0)
                result = "sent"
            except ProcessLookupError:
                result = "ESRCH"
            except BaseException as error:
                result = "error:%s:%s" % (type(error).__name__, error)
                self.cleanup_errors.append("%s signal: %s" % (role, error))
        self.signals.append({"phase": phase, "result": result,
                             "scope": role + "_pidfd", "signal": signum,
                             "target_identity": identity_json(identity),
                             "target_pgid": None, "verification": "pidfd"})

    def signal_all(self, signum, phase):
        self.observe(phase + ":discover")
        self.signal_pidfd("namespace_init", self.init_identity,
                          self.init_pidfd, signum, phase)
        safe, reason = self.verified_group()
        result = reason
        if safe:
            try:
                os.killpg(self.pgid, signum)
                result = "sent"
            except ProcessLookupError:
                result = "ESRCH"
            except BaseException as error:
                result = "error:%s:%s" % (type(error).__name__, error)
                self.cleanup_errors.append("verified PGID signal: %s" % error)
        self.signals.append({"phase": phase, "result": result,
                             "scope": "verified_wrapper_pgid",
                             "signal": signum, "target_identity": None,
                             "target_pgid": self.pgid,
                             "verification": reason})
        self.signal_pidfd("containment_wrapper", self.wrapper_identity,
                          self.wrapper_pidfd, signum, phase)

    def reap(self):
        if self.wrapper is not None and self.wrapper_returncode is None:
            value = self.wrapper.poll()
            if value is not None:
                self.wrapper_returncode = value
                self.reaps.append({"identity": identity_json(
                    self.wrapper_identity), "role": "containment_wrapper",
                    "wait_returncode": value})

    def containment_closed(self):
        self.reap()
        return bool(
            self.wrapper_pidfd is not None and
            self.init_pidfd is not None and
            pidfd_dead(self.wrapper_pidfd) and pidfd_dead(self.init_pidfd) and
            self.wrapper_returncode is not None)

    def close_pidfds(self):
        for role, attribute, injection in (
                ("namespace_init", "init_pidfd", "init_pidfd_close"),
                ("containment_wrapper", "wrapper_pidfd",
                 "wrapper_pidfd_close")):
            descriptor = getattr(self, attribute)
            close_once(role, descriptor, self.faults.inject_close(injection),
                       self.pidfd_closes, self.cleanup_errors)
            setattr(self, attribute, None)
        self.close_complete = True


def cleanup(controller, args):
    controller.signal_all(signal.SIGTERM, "cleanup-term")
    deadline = time.monotonic() + args.term_grace
    while time.monotonic() < deadline and not controller.containment_closed():
        controller.observe("cleanup-term-rescan")
        time.sleep(min(args.poll, max(0, deadline - time.monotonic())))
    controller.signal_all(signal.SIGKILL, "cleanup-kill")
    deadline = time.monotonic() + args.post_kill_grace
    quiet_since, empty, cleared = None, 0, False
    while True:
        controller.observe("cleanup-kill-rescan")
        now = time.monotonic()
        if controller.containment_closed():
            empty += 1
            quiet_since = now if quiet_since is None else quiet_since
            if empty >= 2 and now - quiet_since >= args.quiet_interval:
                cleared = True
                break
        else:
            empty, quiet_since = 0, None
        if now >= deadline:
            break
        time.sleep(min(args.poll, deadline - now))
    controller.quiet_results.append({
        "empty_proofs": empty, "phase": "kernel-containment-quiet",
        "quiet_seconds": 0 if quiet_since is None else
                         round(time.monotonic() - quiet_since, 9),
        "result": "cleared" if cleared else "deadline"})
    return cleared


def parse_args(argv):
    parser = Parser()
    for name in ("timeout", "term-grace", "post-kill-grace"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--quiet-interval", default=".05")
    parser.add_argument("--poll", default=".01")
    parser.add_argument("--status", required=True)
    parser.add_argument("--stdout", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--preflight-dir", required=True)
    parser.add_argument("--ready")
    parser.add_argument("--commit-hook-dir")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if not args.command or args.command[0] != "--" or len(args.command) == 1:
        raise PreflightError("command must follow --")
    for name in ("timeout", "term_grace", "post_kill_grace",
                 "quiet_interval", "poll"):
        try:
            value = float(getattr(args, name))
        except ValueError:
            raise PreflightError("%s must be a finite number" %
                                 name.replace("_", "-"))
        if not math.isfinite(value):
            raise PreflightError("%s must be finite" % name.replace("_", "-"))
        setattr(args, name, value)
    if min(args.timeout, args.term_grace, args.post_kill_grace) < 0:
        raise PreflightError("timeouts must be nonnegative")
    if args.poll <= 0 or args.quiet_interval < args.poll:
        raise PreflightError("poll/quiet-interval relationship invalid")
    return args


def signal_event(signum, sequence, phase):
    return {"observed_utc": utc_now(), "phase": phase,
            "requested_status": SIGNAL_STATUS[signum],
            "sequence": sequence, "signal": signal.Signals(signum).name,
            "signal_number": signum}


def drain_pending(events, phase):
    while True:
        info = signal.sigtimedwait(HANDLED, 0)
        if info is None:
            break
        events.append(signal_event(info.si_signo, len(events) + 1, phase))


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    status_path = status_argument(argv)
    temp_closes = []
    try:
        args = parse_args(argv)
        faults = Faults()
        enable_and_verify_subreaper()
        require_pidfds(faults, temp_closes)
    except PreflightError as error:
        preflight_record(status_path, str(error), "preflight_invalid")
        return 125
    except BaseException as error:
        preflight_record(status_path, str(error), "preflight_unsupported")
        return 125
    try:
        provenance = load_preflight().proof(args.preflight_dir, faults)
    except BaseException as error:
        provenance = getattr(error, "provenance", None)
        preflight_record(args.status, "%s: %s" %
                         (type(error).__name__, error),
                         "preflight_unsupported", provenance)
        return 125

    try:
        controller = Controller(args.poll, args.quiet_interval, faults,
                                provenance)
    except BaseException as error:
        preflight_record(args.status, "controller bootstrap failed: %s" %
                         error, "preflight_failed", provenance)
        return 125

    cancellation = []
    old_handlers = {}
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)

    def requested(signum, _frame):
        cancellation.append(signal_event(
            signum, len(cancellation) + 1,
            "post_go" if controller.go_committed else "pre_go"))

    for number in HANDLED:
        old_handlers[number] = signal.signal(number, requested)
    if args.ready:
        try:
            pathlib.Path(args.ready).write_text("ready\n", encoding="ascii")
        except BaseException as error:
            preflight_record(args.status, "ready publication failed: %s" %
                             error, "preflight_failed", provenance)
            return 125

    started, started_utc = time.monotonic(), utc_now()
    timed_out = False
    primary_exception = None
    pre_go_cancelled = False
    ready = pathlib.Path(args.preflight_dir).with_name(
        pathlib.Path(args.preflight_dir).name + ".session-ready")
    go = ready.with_name(ready.name + ".go")
    launch = [provenance["launcher_path"],
              *provenance["launcher_options"], sys.executable, "-B",
              str(HERE / "namespace-init-v7.py"), "--ready", str(ready),
              "--go", str(go), "--", *args.command[1:]]
    try:
        with open(args.stdout, "xb") as stdout, open(
                args.stderr, "xb") as stderr:
            child = subprocess.Popen(
                launch, cwd=args.cwd, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, start_new_session=True)
            controller.attach_wrapper(child)
            controller.bind_init(ready)
            if args.commit_hook_dir:
                hook = pathlib.Path(args.commit_hook_dir)
                hook.mkdir(parents=True, exist_ok=True)
                (hook / "commit.ready").write_text("ready\n")
                deadline = time.monotonic() + 8
                while not (hook / "commit.release").exists():
                    if time.monotonic() >= deadline:
                        raise RuntimeError("commit hook timeout")
                    time.sleep(.005)
            # Linearization is the final empty drain while HANDLED is blocked.
            # A request queued after that drain is defined as post-GO; this
            # avoids claiming an impossible atomic ordering with filesystem IO.
            drain_pending(cancellation, "pre_go")
            if cancellation:
                pre_go_cancelled = True
            else:
                temporary = go.with_name(go.name + ".tmp.%d" % os.getpid())
                temporary.write_text("go\n", encoding="ascii")
                os.replace(temporary, go)
                controller.go_committed = True
                controller.benchmark_launched = True
                faults.arm()
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            if not pre_go_cancelled:
                deadline = time.monotonic() + args.timeout
                while child.poll() is None and not cancellation:
                    controller.observe("runtime-wait")
                    if time.monotonic() >= deadline:
                        timed_out = True
                        break
                    time.sleep(min(args.poll,
                                   max(0, deadline - time.monotonic())))
    except BaseException as error:
        primary_exception = {"message": str(error),
                             "traceback": "".join(
                                 traceback.format_exception_only(
                                     type(error), error)).strip(),
                             "type": type(error).__name__}
        if controller.wrapper is None:
            preflight_record(args.status, "launcher failed: %s" % error,
                             "launch_failed", provenance)
            return 125
    finally:
        # If an exception occurred while blocked, allow collector cancellation
        # to be handled during the bounded cleanup machine.
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)

    cleared = cleanup(controller, args)
    # Freeze any final queued requests, then close every pidfd before deciding
    # classification or publishing status.
    signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)
    drain_pending(cancellation, "post_go" if controller.go_committed else
                  "pre_go")
    controller.close_pidfds()
    degraded = bool(controller.cleanup_errors)
    first_status = (None if not cancellation else
                    cancellation[0]["requested_status"])
    if not cleared:
        classification, return_status = "failure_containment_uncleared", 125
    elif degraded:
        classification, return_status = (
            "failure_cleanup_degraded_contained", 125)
    elif pre_go_cancelled or (not controller.go_committed and cancellation):
        classification = "cancelled_pre_go_%s_contained" % cancellation[0][
            "signal"]
        return_status = first_status
    elif cancellation:
        classification = "cancelled_post_go_%s_contained" % cancellation[0][
            "signal"]
        return_status = first_status
    elif primary_exception:
        classification, return_status = "failure_exception_contained", 125
    elif timed_out:
        classification, return_status = "timeout_contained", 124
    elif controller.wrapper_returncode is None:
        classification, return_status = "failure_missing_wrapper_status", 125
    elif controller.wrapper_returncode == 0:
        classification, return_status = "completed_exit_0", 0
    else:
        classification = "completed_exit_nonzero"
        value = controller.wrapper_returncode
        return_status = value if value >= 0 else 128 + (-value)

    proof = {
        "all_pidfds_closed": controller.close_complete and not any(
            item["result"] != "closed" for item in controller.pidfd_closes),
        "namespace_init_pidfd_exit_observed": cleared,
        "pidfd_close_failures": [item for item in controller.pidfd_closes
                                 if item["result"] != "closed"],
        "wrapper_pidfd_exit_observed": cleared,
        "wrapper_wait_reaped": controller.wrapper_returncode is not None,
    }
    record = {
        "benchmark_launched": controller.benchmark_launched,
        "classification": classification, "cleanup_degraded": degraded,
        "cleanup_errors": controller.cleanup_errors,
        "command": args.command[1:], "containment_cleared": cleared,
        "containment_guarantee": (
            "the pinned unshare wrapper kills namespace PID 1; Linux then "
            "kills every member of that PID namespace"),
        "containment_kind": "unprivileged_user_pid_namespace",
        "containment_preflight": provenance, "containment_required": True,
        "discovery_errors": controller.discovery_errors,
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "ended_utc": utc_now(), "faults_triggered": faults.triggered,
        "go_commit_linearization": "final_empty_blocked_signal_drain",
        "go_committed": controller.go_committed,
        "kernel_containment_proof": proof,
        "launcher_invocation": launch,
        "namespace_init_identity": identity_json(controller.init_identity),
        "namespace_init_ready": controller.namespace_ready,
        "original_pgid": controller.pgid,
        "pidfd_closes": controller.pidfd_closes,
        "primary_exception": primary_exception,
        "protocol_version": 7, "quiet_results": controller.quiet_results,
        "reaps": controller.reaps, "record_kind": "runtime",
        "requested_outer_signals": cancellation,
        "requested_outer_status": first_status, "scans": controller.scans,
        "signals": controller.signals, "started_utc": started_utc,
        "supervisor_return_status": return_status,
        "timed_out": timed_out,
        "wrapper_identity": identity_json(controller.wrapper_identity),
        "wrapper_returncode": controller.wrapper_returncode,
    }
    try:
        atomic_json(args.status, record, faults)
    except BaseException as error:
        print("supervise-v7: status medium unwritable after cleanup: %s" %
              error, file=sys.stderr)
        return_status = 125
    for number, handler in old_handlers.items():
        signal.signal(number, handler)
    return return_status


if __name__ == "__main__":
    raise SystemExit(main())
