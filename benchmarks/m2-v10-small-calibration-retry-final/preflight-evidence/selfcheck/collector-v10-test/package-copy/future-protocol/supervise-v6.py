#!/usr/bin/env python3
"""Future v6 supervisor: fail-closed PID-namespace kernel containment."""
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
STATUS_VERSION = 6
HANDLED_SIGNALS = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
PR_SET_CHILD_SUBREAPER = 36
PR_GET_CHILD_SUBREAPER = 37


class PreflightError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError(message)


class Faults:
    def __init__(self):
        self.names = {item for item in os.environ.get(
            "SUPERVISE_V6_INJECT", "").split(",") if item}
        self.triggered = []
        self.runtime_armed = False

    def arm(self):
        self.runtime_armed = True

    def hit(self, name):
        persistent = name == "proc_scan" and "persistent_proc_scan" in self.names
        if persistent and self.runtime_armed:
            if "persistent_proc_scan" not in self.triggered:
                self.triggered.append("persistent_proc_scan")
            raise RuntimeError("injected persistent proc_scan failure")
        if name in self.names:
            self.names.remove(name)
            self.triggered.append(name)
            raise RuntimeError("injected %s failure" % name)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def identity_json(identity):
    return None if identity is None else {
        "pid": identity[0], "starttime": identity[1]}


def status_argument(argv):
    for index, item in enumerate(argv):
        if item == "--status" and index + 1 < len(argv):
            return argv[index + 1]
        if item.startswith("--status="):
            return item.split("=", 1)[1]
    return None


def atomic_json(path, row):
    target = pathlib.Path(path)
    temporary = target.with_name(target.name + ".tmp.%d" % os.getpid())
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(row, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, target)


def preflight_status(path, diagnostic, classification, provenance=None):
    row = {"classification": classification, "diagnostic": diagnostic,
           "protocol_version": STATUS_VERSION,
           "benchmark_launched": False,
           "containment_preflight": provenance}
    try:
        if path:
            atomic_json(path, row)
            return
    except BaseException as error:
        diagnostic += "; status_write=%s" % error
    print("supervise-v6: %s" % diagnostic, file=sys.stderr)


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


def require_pidfds():
    if not hasattr(os, "pidfd_open") or not hasattr(signal,
                                                     "pidfd_send_signal"):
        raise OSError(errno.ENOSYS, "Python pidfd API unavailable")
    descriptor = os.pidfd_open(os.getpid(), 0)
    os.close(descriptor)


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


def load_preflight_module():
    path = HERE / "containment-preflight-v6.py"
    spec = importlib.util.spec_from_file_location("containment_preflight_v6",
                                                  path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Controller:
    """Binds the host wrapper and namespace init before benchmark launch."""
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
        self.quiet_results = []
        self.wrapper_returncode = None
        self.namespace_ready = None
        self.benchmark_launched = False

    def bind(self, child, ready, go):
        self.wrapper = child
        row = proc_row(child.pid)
        if row is None:
            raise RuntimeError("unshare wrapper vanished before identity bind")
        self.wrapper_identity = (child.pid, row["starttime"])
        self.wrapper_pidfd = os.pidfd_open(child.pid, 0)
        self.pgid = child.pid
        deadline = time.monotonic() + 3
        while not ready.exists():
            if child.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("namespace init readiness failed")
            time.sleep(.005)
        self.namespace_ready = json.loads(ready.read_text())
        if (self.namespace_ready.get("protocol_version") != 6 or
                self.namespace_ready.get("namespace_pid") != 1 or
                not self.namespace_ready.get("proc_pid_one_present")):
            raise RuntimeError("namespace init semantic proof failed")
        snapshot = proc_snapshot()
        candidates = [row for row in snapshot.values()
                      if row["ppid"] == child.pid]
        if len(candidates) != 1:
            raise RuntimeError("namespace init host identity is not unique")
        init = candidates[0]
        self.init_identity = (init["pid"], init["starttime"])
        self.init_pidfd = os.pidfd_open(init["pid"], 0)
        verify = proc_row(init["pid"])
        if verify is None or verify["starttime"] != init["starttime"]:
            raise RuntimeError("namespace init identity changed during bind")
        self.last_snapshot = snapshot
        go.write_text("go\n", encoding="ascii")
        self.benchmark_launched = True
        self.faults.arm()

    def scan(self, phase):
        self.faults.hit("proc_scan")
        self.last_snapshot = proc_snapshot()
        known = {item for item in (self.wrapper_identity, self.init_identity)
                 if item is not None}
        present = []
        for identity in known:
            row = self.last_snapshot.get(identity[0])
            if row and row["starttime"] == identity[1]:
                present.append(identity)
        self.scans.append({"phase": phase,
                           "known_present": [identity_json(item)
                                             for item in sorted(present)]})
        return present

    def observe_best_effort(self, phase):
        try:
            return self.scan(phase)
        except BaseException as error:
            message = "%s: %s: %s" % (phase, type(error).__name__, error)
            self.discovery_errors.append(message)
            self.cleanup_errors.append("discovery " + message)
            return None

    def verified_group(self):
        if self.wrapper_pidfd is None or pidfd_dead(self.wrapper_pidfd):
            return False, "wrapper_identity_not_live"
        row = self.last_snapshot.get(self.wrapper_identity[0])
        if (row and row["starttime"] == self.wrapper_identity[1] and
                row["pgid"] == self.pgid):
            return True, "wrapper_pidfd_and_snapshot_verified"
        # Persistent discovery failure does not erase the already-bound fresh
        # session while its exact wrapper pidfd is still live.
        return True, "wrapper_pidfd_and_launch_pgid_verified"

    def signal_pidfd(self, label, identity, descriptor, signum, phase):
        if descriptor is None or identity is None:
            result = "not_bound"
            self.cleanup_errors.append("%s identity not bound" % label)
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
                result = "%s:%s" % (type(error).__name__, error)
                self.cleanup_errors.append("%s pidfd signal: %s" %
                                           (label, error))
        self.signals.append({"phase": phase, "scope": label + "_pidfd",
                             "identity": identity_json(identity),
                             "signal": signum, "result": result})

    def signal_all(self, signum, phase):
        # Discovery is explicitly best effort. Its exception cannot bypass
        # either already-bound pidfd or the still-verified fresh PGID.
        self.observe_best_effort(phase + ":discover")
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
                result = "%s:%s" % (type(error).__name__, error)
                self.cleanup_errors.append("verified PGID signal: %s" % error)
        self.signals.append({"phase": phase, "scope": "verified_wrapper_pgid",
                             "target": self.pgid, "signal": signum,
                             "verification": reason, "result": result})
        self.signal_pidfd("containment_wrapper", self.wrapper_identity,
                          self.wrapper_pidfd, signum, phase)

    def reap(self):
        if self.wrapper is not None and self.wrapper_returncode is None:
            value = self.wrapper.poll()
            if value is not None:
                self.wrapper_returncode = value
                self.reaps.append({"role": "containment_wrapper",
                                   "identity": identity_json(
                                       self.wrapper_identity),
                                   "wait_returncode": value})
        if self.init_identity is not None:
            try:
                pid, status = os.waitpid(self.init_identity[0], os.WNOHANG)
            except ChildProcessError:
                pid = 0
            if pid:
                self.reaps.append({"role": "namespace_init",
                                   "identity": identity_json(
                                       self.init_identity),
                                   "wait_status": status})

    def containment_closed(self):
        self.reap()
        wrapper_dead = (self.wrapper_pidfd is not None and
                        pidfd_dead(self.wrapper_pidfd))
        init_dead = self.init_pidfd is not None and pidfd_dead(self.init_pidfd)
        return wrapper_dead and init_dead and self.wrapper_returncode is not None

    def close(self):
        for name in ("wrapper_pidfd", "init_pidfd"):
            descriptor = getattr(self, name)
            if descriptor is not None:
                try:
                    os.close(descriptor)
                except OSError as error:
                    self.cleanup_errors.append("%s close: %s" % (name, error))
                setattr(self, name, None)


def cleanup(controller, args):
    controller.signal_all(signal.SIGTERM, "cleanup-term")
    deadline = time.monotonic() + args.term_grace
    while time.monotonic() < deadline and not controller.containment_closed():
        controller.observe_best_effort("cleanup-term-rescan")
        time.sleep(min(args.poll, max(0, deadline - time.monotonic())))
    # Mandatory escalation. If TERM killed the wrapper this records identity-
    # bound already-dead results; otherwise it triggers kernel teardown.
    controller.signal_all(signal.SIGKILL, "cleanup-kill")
    deadline = time.monotonic() + args.post_kill_grace
    quiet_since = None
    empty = 0
    cleared = False
    while True:
        controller.observe_best_effort("cleanup-kill-rescan")
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
        "phase": "kernel-containment-quiet",
        "result": "cleared" if cleared else "deadline",
        "empty_proofs": empty,
        "quiet_seconds": 0 if quiet_since is None else
                         round(time.monotonic() - quiet_since, 9)})
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


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    status_path = status_argument(argv)
    try:
        args = parse_args(argv)
        enable_and_verify_subreaper()
        require_pidfds()
    except PreflightError as error:
        preflight_status(status_path, str(error), "preflight_invalid")
        return 125
    except BaseException as error:
        preflight_status(status_path, str(error), "preflight_unsupported")
        return 125
    try:
        provenance = load_preflight_module().proof(args.preflight_dir)
    except BaseException as error:
        preflight_status(args.status, "%s: %s" % (type(error).__name__, error),
                         "preflight_unsupported")
        return 125

    try:
        faults = Faults()
        controller = Controller(args.poll, args.quiet_interval, faults,
                                provenance)
    except BaseException as error:
        preflight_status(args.status, "controller bootstrap failed: %s" %
                         error, "preflight_failed", provenance)
        return 125
    cancellation = []
    old_handlers = {}

    def requested(signum, _frame):
        cancellation.append({"signal": signum, "observed_utc": utc_now()})

    for number in HANDLED_SIGNALS:
        old_handlers[number] = signal.signal(number, requested)
    if args.ready:
        try:
            pathlib.Path(args.ready).write_text("ready\n", encoding="ascii")
        except BaseException as error:
            preflight_status(args.status, "ready publication failed: %s" %
                             error, "preflight_failed", provenance)
            for number, handler in old_handlers.items():
                signal.signal(number, handler)
            return 125

    started, started_utc = time.monotonic(), utc_now()
    timed_out = False
    primary_exception = None
    launcher = provenance["launcher_path"]
    ready = pathlib.Path(args.preflight_dir).with_name(
        pathlib.Path(args.preflight_dir).name + ".session-ready")
    go = ready.with_name(ready.name + ".go")
    launch = [launcher, *provenance["launcher_options"], sys.executable, "-B",
              str(HERE / "namespace-init-v6.py"), "--ready", str(ready),
              "--go", str(go), "--", *args.command[1:]]
    try:
        with open(args.stdout, "xb") as stdout, open(args.stderr, "xb") as stderr:
            child = subprocess.Popen(
                launch, cwd=args.cwd, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, start_new_session=True)
            controller.bind(child, ready, go)
            deadline = time.monotonic() + args.timeout
            while child.poll() is None and not cancellation:
                controller.observe_best_effort("runtime-wait")
                if time.monotonic() >= deadline:
                    timed_out = True
                    break
                time.sleep(min(args.poll, deadline - time.monotonic()))
    except BaseException as error:
        primary_exception = {"type": type(error).__name__,
                             "message": str(error),
                             "traceback": "".join(
                                 traceback.format_exception_only(
                                     type(error), error)).strip()}
        if controller.wrapper is None:
            preflight_status(args.status, "launcher failed: %s" % error,
                             "launch_failed", provenance)
            return 125

    cleared = cleanup(controller, args)
    degraded = bool(controller.cleanup_errors)
    if not cleared:
        classification, return_status = "failure_containment_uncleared", 125
    elif degraded:
        classification, return_status = "failure_cleanup_degraded_contained", 125
    elif cancellation:
        classification = "cancelled_%s_contained" % signal.Signals(
            cancellation[0]["signal"]).name
        return_status = 128 + cancellation[0]["signal"]
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

    record = {
        "protocol_version": 6, "classification": classification,
        "command": args.command[1:], "benchmark_launched":
        controller.benchmark_launched, "started_utc": started_utc,
        "ended_utc": utc_now(),
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "containment_kind": "unprivileged_user_pid_namespace",
        "containment_required": True,
        "containment_cleared": cleared,
        "containment_guarantee": (
            "unshare --kill-child=KILL kills namespace PID 1 when the "
            "identity-bound wrapper dies; Linux then SIGKILLs every member "
            "of that PID namespace"),
        "containment_preflight": provenance,
        "wrapper_identity": identity_json(controller.wrapper_identity),
        "namespace_init_identity": identity_json(controller.init_identity),
        "namespace_init_ready": controller.namespace_ready,
        "original_pgid": controller.pgid,
        "wrapper_returncode": controller.wrapper_returncode,
        "timed_out": timed_out,
        "requested_outer_signals": cancellation,
        "requested_outer_status": None if not cancellation else
        128 + cancellation[0]["signal"],
        "supervisor_return_status": return_status,
        "primary_exception": primary_exception,
        "cleanup_degraded": degraded,
        "cleanup_errors": controller.cleanup_errors,
        "discovery_errors": controller.discovery_errors,
        "faults_triggered": faults.triggered,
        "signals": controller.signals, "scans": controller.scans,
        "reaps": controller.reaps, "quiet_results": controller.quiet_results,
        "kernel_containment_proof": {
            "wrapper_pidfd_exit_observed": cleared,
            "namespace_init_pidfd_exit_observed": cleared,
            "wrapper_wait_reaped": controller.wrapper_returncode is not None},
    }
    try:
        atomic_json(args.status, record)
    except BaseException as error:
        print("supervise-v6: status media unwritable after containment: %s" %
              error, file=sys.stderr)
        return_status = 125
    controller.close()
    for number, handler in old_handlers.items():
        signal.signal(number, handler)
    return return_status


if __name__ == "__main__":
    raise SystemExit(main())
