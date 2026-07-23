#!/usr/bin/env python3
"""Future v5 fail-closed Linux supervisor with bootstrap ownership."""
from __future__ import annotations

import argparse
import ctypes
import datetime
import errno
import json
import math
import os
import select
import signal
import subprocess
import sys
import time
import traceback


PR_SET_CHILD_SUBREAPER = 36
PR_GET_CHILD_SUBREAPER = 37
STATUS_VERSION = 5
HANDLED_SIGNALS = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)


class PreflightError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError(message)


class Faults:
    """One-shot deterministic failures used only by v5 controls."""
    def __init__(self):
        raw = os.environ.get("SUPERVISE_V5_INJECT", "")
        self.pending = {name for name in raw.split(",") if name}
        self.triggered = []

    def hit(self, name):
        if name in self.pending:
            self.pending.remove(name)
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


def atomic_status(path, record, faults):
    temporary = "%s.tmp.%d" % (path, os.getpid())
    last_error = None
    for attempt in range(2):
        try:
            faults.hit("status_write")
            with open(temporary, "x", encoding="utf-8") as stream:
                json.dump(record, stream, sort_keys=True)
                stream.write("\n")
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
            return None
        except BaseException as error:
            last_error = error
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            if attempt == 0:
                continue
    return "%s: %s" % (type(last_error).__name__, last_error)


def atomic_ready(path):
    temporary = "%s.tmp.%d" % (path, os.getpid())
    with open(temporary, "x", encoding="ascii") as stream:
        stream.write("ready\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def preflight_status(path, diagnostic, classification="preflight_invalid"):
    record = {"classification": classification, "diagnostic": diagnostic,
              "protocol_version": STATUS_VERSION}
    error = atomic_status(path, record, Faults()) if path else "no status path"
    if error:
        print("supervise-v5: %s; status_write=%s" % (diagnostic, error),
              file=sys.stderr)


def enable_and_verify_subreaper():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))
    state = ctypes.c_int(0)
    if libc.prctl(PR_GET_CHILD_SUBREAPER, ctypes.byref(state), 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))
    if state.value != 1:
        raise OSError(errno.ENOTSUP, "subreaper state did not persist")
    return True


def require_pidfds():
    if not hasattr(os, "pidfd_open") or not hasattr(signal,
                                                     "pidfd_send_signal"):
        raise OSError(errno.ENOSYS, "Python pidfd API unavailable")
    descriptor = os.pidfd_open(os.getpid(), 0)
    os.close(descriptor)


def proc_row(pid):
    try:
        with open("/proc/%d/stat" % pid, encoding="ascii") as stream:
            text = stream.read()
    except (FileNotFoundError, ProcessLookupError):
        return None
    close = text.rfind(")")
    if close < 0:
        return None
    fields = text[close + 2:].split()
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
                if row is not None:
                    rows[row["pid"]] = row
    return rows


def lineage_candidates(snapshot, active_identities, supervisor_pid,
                       baseline_direct=frozenset()):
    """Admit only current lineage and new direct subreaper adoptees."""
    current = {(pid, row["starttime"]): row
               for pid, row in snapshot.items()}
    known = {identity for identity in active_identities if identity in current}
    admitted = []
    changed = True
    while changed:
        changed = False
        current_by_pid = {identity[0]: identity for identity in known}
        for pid, row in sorted(snapshot.items()):
            identity = (pid, row["starttime"])
            if identity in known or pid == supervisor_pid:
                continue
            direct = (row["ppid"] == supervisor_pid and
                      identity not in baseline_direct)
            parent = current_by_pid.get(row["ppid"])
            if direct or parent is not None:
                admitted.append((identity, "adopted_by_supervisor" if direct
                                 else "parent_lineage"))
                known.add(identity)
                changed = True
    return admitted


def decode_wait(status):
    if os.WIFEXITED(status):
        value = os.WEXITSTATUS(status)
        return value, None, value
    if os.WIFSIGNALED(status):
        value = os.WTERMSIG(status)
        return None, value, -value
    return None


class CleanupController:
    """Exists before launch and owns both bootstrap and full-session cleanup."""
    def __init__(self, poll, quiet, faults, subreaper_verified):
        self.poll = poll
        self.quiet = quiet
        self.faults = faults
        self.supervisor_pid = os.getpid()
        self.subreaper_verified = subreaper_verified
        baseline = proc_snapshot()
        self.baseline_direct_identities = {
            (pid, row["starttime"]) for pid, row in baseline.items()
            if row["ppid"] == self.supervisor_pid}
        self.child = None
        self.leader_pid = None
        self.pgid = None
        self.bootstrap_pidfd = None
        self.bootstrap_pidfd_result = "not_attached"
        self.leader_identity = None
        self.leader_returncode = None
        self.active = {}
        self.retired = {}
        self.reaps = []
        self.scans = []
        self.signals = []
        self.group_probes = []
        self.quiet_results = []
        self.cleanup_errors = []
        self.last_snapshot = baseline
        self.full_session_constructed = False

    def attach_bootstrap(self, child):
        """The first post-Popen call: retain child, PID, PGID, and pidfd."""
        self.child = child
        self.leader_pid = child.pid
        # start_new_session makes this exact without a fallible getpgid call.
        self.pgid = child.pid
        try:
            self.bootstrap_pidfd = os.pidfd_open(child.pid, 0)
            self.bootstrap_pidfd_result = "opened"
        except ProcessLookupError:
            self.bootstrap_pidfd_result = "ESRCH"
        except OSError as error:
            self.bootstrap_pidfd_result = errno.errorcode.get(
                error.errno, str(error.errno))
            self.cleanup_errors.append("bootstrap pidfd_open: %s" % error)
        self.faults.hit("bootstrap_attached")

    def construct_session(self):
        row = proc_row(self.leader_pid)
        self.faults.hit("identity_capture")
        if row is None:
            raise RuntimeError("leader vanished before identity capture")
        descriptor = self.bootstrap_pidfd
        self.bootstrap_pidfd = None
        self.discover((self.leader_pid, row["starttime"]), "leader", row,
                      descriptor)
        self.faults.hit("identity_attached")
        self.full_session_constructed = True
        self.faults.hit("session_construct")

    def discover(self, identity, origin, row, descriptor=None):
        if identity in self.active or identity in self.retired:
            if descriptor is not None:
                os.close(descriptor)
            return
        pid, starttime = identity
        direct = row["ppid"] == self.supervisor_pid
        item = {
            "identity": identity_json(identity), "origin": origin,
            "initial_ppid": row["ppid"], "initial_pgid": row["pgid"],
            "initial_sid": row["sid"], "ever_direct_adoptee": direct,
            "pidfd_number": None, "pidfd_open_result": None,
            "pidfd_close_result": None, "closure_state": "active",
            "exit_observed_by_pidfd": False, "reaped": False,
        }
        try:
            if descriptor is None:
                descriptor = os.pidfd_open(pid, 0)
            verify = proc_row(pid)
            if verify is None or verify["starttime"] != starttime:
                os.close(descriptor)
                descriptor = None
                item["pidfd_open_result"] = "identity_changed_during_open"
                raise ProcessLookupError(pid)
            item["pidfd"] = descriptor
            item["pidfd_number"] = descriptor
            item["pidfd_open_result"] = "opened_identity_verified"
        except ProcessLookupError:
            item["pidfd"] = None
            item["pidfd_open_result"] = (item["pidfd_open_result"] or
                                          "ESRCH_before_open")
        except OSError as error:
            item["pidfd"] = None
            item["pidfd_open_result"] = errno.errorcode.get(
                error.errno, str(error.errno))
            self.cleanup_errors.append("pidfd_open %s: %s" %
                                       (identity, error))
        self.active[identity] = item
        if identity[0] == self.leader_pid and self.leader_identity is None:
            self.leader_identity = identity

    def pidfd_dead(self, item):
        descriptor = item.get("pidfd")
        if descriptor is None:
            return item["reaped"]
        poller = select.poll()
        poller.register(descriptor, select.POLLIN)
        dead = bool(poller.poll(0))
        item["exit_observed_by_pidfd"] = (
            item["exit_observed_by_pidfd"] or dead)
        return dead

    def _close_absent_identity(self, identity, item):
        dead = self.pidfd_dead(item)
        if item["reaped"]:
            item["closure_state"] = "supervisor_reaped"
        elif dead and not item["ever_direct_adoptee"]:
            item["closure_state"] = "parent_reaped/exit_observed"
        else:
            item["closure_state"] = "uncleared"
        self.retired[identity] = self.active.pop(identity)

    def refresh_retired(self):
        for item in self.retired.values():
            if item["closure_state"] != "uncleared":
                continue
            if self.pidfd_dead(item) and not item["ever_direct_adoptee"]:
                item["closure_state"] = "parent_reaped/exit_observed"

    def scan(self, phase):
        self.faults.hit("proc_scan")
        snapshot = proc_snapshot()
        self.last_snapshot = snapshot
        # Bootstrap discovery works even when full construction failed.
        if self.leader_pid is not None:
            row = snapshot.get(self.leader_pid)
            if row is not None:
                identity = (self.leader_pid, row["starttime"])
                if identity not in self.active and identity not in self.retired:
                    descriptor = self.bootstrap_pidfd
                    self.bootstrap_pidfd = None
                    self.discover(identity, "leader_bootstrap", row,
                                  descriptor)
        admitted = []
        for identity, origin in lineage_candidates(
                snapshot, set(self.active), self.supervisor_pid,
                self.baseline_direct_identities):
            if identity not in self.active and identity not in self.retired:
                self.discover(identity, origin, snapshot[identity[0]])
                admitted.append(identity_json(identity))
        # A construction failure may precede leader identity capture; the
        # original fresh PGID remains a bounded discovery seed.
        if self.pgid is not None:
            for pid, row in sorted(snapshot.items()):
                identity = (pid, row["starttime"])
                if (row["pgid"] == self.pgid and
                        identity not in self.active and
                        identity not in self.retired):
                    self.discover(identity, "original_pgid_bootstrap", row)
                    admitted.append(identity_json(identity))
        for identity in list(self.active):
            pid, starttime = identity
            row = snapshot.get(pid)
            if row is not None and row["starttime"] == starttime:
                if row["ppid"] == self.supervisor_pid:
                    self.active[identity]["ever_direct_adoptee"] = True
                continue
            self._close_absent_identity(identity, self.active[identity])
        self.refresh_retired()
        present = [identity for identity in self.active
                   if snapshot.get(identity[0], {}).get("starttime") ==
                   identity[1]]
        self.scans.append({
            "phase": phase, "discovered": admitted,
            "active_present": [identity_json(item)
                               for item in sorted(present)],
            "closure_counts": self.closure_counts(),
        })
        return present

    def closure_counts(self):
        counts = {"active": len(self.active), "supervisor_reaped": 0,
                  "parent_reaped/exit_observed": 0, "uncleared": 0}
        for item in self.retired.values():
            counts[item["closure_state"]] += 1
        return counts

    def reap(self):
        # WNOWAIT binds each consumed status to a still-current identity.
        candidates = list(self.active.items()) + list(self.retired.items())
        for identity, item in sorted(candidates):
            if item["reaped"]:
                continue
            pid, starttime = identity
            row = proc_row(pid)
            if row is None or row["starttime"] != starttime:
                continue
            if row["ppid"] != self.supervisor_pid:
                continue
            item["ever_direct_adoptee"] = True
            try:
                pending = os.waitid(
                    os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
            except ChildProcessError:
                continue
            if pending is None or pending.si_pid == 0:
                continue
            verify = proc_row(pid)
            if verify is None or verify["starttime"] != starttime:
                self.cleanup_errors.append(
                    "waitid identity changed before waitpid %s" %
                    (identity,))
                continue
            try:
                waited_pid, status = os.waitpid(pid, 0)
            except ChildProcessError:
                self.cleanup_errors.append("waitid/waitpid race %s" %
                                           (identity,))
                continue
            decoded = decode_wait(status)
            if waited_pid != pid or decoded is None:
                self.cleanup_errors.append("unbound reap %s" % (identity,))
                continue
            item["reaped"] = True
            item["closure_state"] = "supervisor_reaped"
            exit_status, term_signal, returncode = decoded
            self.reaps.append({
                "identity": identity_json(identity),
                "role": "leader" if identity == self.leader_identity else
                        "descendant", "exit_status": exit_status,
                "signal": term_signal, "wait_returncode": returncode,
                "closure_state": "supervisor_reaped",
            })
            if identity == self.leader_identity or pid == self.leader_pid:
                self.leader_returncode = returncode
                if self.child is not None:
                    self.child.returncode = returncode
            if identity in self.active:
                self.retired[identity] = self.active.pop(identity)

    def observe(self, phase):
        self.scan(phase + ":pre-reap")
        self.reap()
        return self.scan(phase + ":post-reap")

    def original_group_reason(self):
        if self.pgid is None:
            return False, "skip_no_bootstrap_pgid", [], []
        rows = [row for row in self.last_snapshot.values()
                if row["pgid"] == self.pgid]
        active = set(self.active)
        owned = [(row["pid"], row["starttime"]) for row in rows
                 if (row["pid"], row["starttime"]) in active]
        foreign = [(row["pid"], row["starttime"]) for row in rows
                   if (row["pid"], row["starttime"]) not in active]
        if foreign:
            return False, "skip_foreign_or_reused_group_identity", owned, foreign
        if not owned:
            return False, "skip_no_current_owned_group_identity", owned, foreign
        return True, "current_owned_group_identity_verified", owned, foreign

    def signal_pidfds(self, sig, phase):
        self.faults.hit("signal")
        for identity, item in sorted(self.active.items()):
            if self.pidfd_dead(item):
                result = "already_dead"
            elif item.get("pidfd") is None:
                result = "pidfd_unavailable"
                self.cleanup_errors.append("live identity lacks pidfd %s" %
                                           (identity,))
            else:
                try:
                    signal.pidfd_send_signal(item["pidfd"], sig, None, 0)
                    result = "sent"
                except ProcessLookupError:
                    result = "ESRCH"
                except OSError as error:
                    result = errno.errorcode.get(error.errno,
                                                 str(error.errno))
                    self.cleanup_errors.append("pidfd signal %s: %s" %
                                               (identity, error))
            self.signals.append({
                "phase": phase, "scope": "owned_identity_pidfd",
                "identity": identity_json(identity), "signal": sig,
                "result": result})

    def signal_all(self, sig, phase):
        self.observe(phase + ":discover")
        safe, reason, owned, foreign = self.original_group_reason()
        result = reason
        if safe:
            try:
                os.killpg(self.pgid, sig)
                result = "sent"
            except ProcessLookupError:
                result = "ESRCH"
            except PermissionError:
                result = "EPERM"
                self.cleanup_errors.append("original PGID EPERM")
        self.signals.append({
            "phase": phase, "scope": "original_pgid", "target": self.pgid,
            "signal": sig, "result": result, "identity_reason": reason,
            "owned_identities": [identity_json(item) for item in owned],
            "foreign_identities": [identity_json(item) for item in foreign]})
        self.signal_pidfds(sig, phase)

    def group_probe(self, phase):
        safe, reason, owned, foreign = self.original_group_reason()
        try:
            os.killpg(self.pgid, 0)
            numeric = "present"
        except (ProcessLookupError, TypeError):
            numeric = "ESRCH"
        except PermissionError:
            numeric = "EPERM"
        logically_gone = not owned
        self.group_probes.append({
            "phase": phase, "numeric_result": numeric,
            "identity_reason": reason, "logically_gone": logically_gone,
            "owned_identities": [identity_json(item) for item in owned],
            "foreign_identities": [identity_json(item) for item in foreign]})
        return logically_gone

    def all_closed(self):
        if self.active:
            return False
        return all(item["closure_state"] in
                   ("supervisor_reaped", "parent_reaped/exit_observed")
                   for item in self.retired.values())

    def sleep(self, seconds):
        self.faults.hit("poll")
        if seconds > 0:
            time.sleep(seconds)

    def close_pidfds(self):
        if self.bootstrap_pidfd is not None:
            try:
                os.close(self.bootstrap_pidfd)
                self.bootstrap_pidfd_result += "/closed"
            except OSError as error:
                self.cleanup_errors.append("bootstrap pidfd close: %s" % error)
            self.bootstrap_pidfd = None
        for item in list(self.active.values()) + list(self.retired.values()):
            descriptor = item.get("pidfd")
            if descriptor is None:
                if item["pidfd_close_result"] is None:
                    item["pidfd_close_result"] = "not_open"
                continue
            try:
                os.close(descriptor)
                item["pidfd_close_result"] = "closed"
            except OSError as error:
                item["pidfd_close_result"] = "error:%s" % error
                self.cleanup_errors.append("pidfd close: %s" % error)
            item["pidfd"] = None


def safe_call(controller, label, operation, default=None):
    try:
        return operation()
    except BaseException as error:
        controller.cleanup_errors.append("%s: %s: %s" %
                                         (label, type(error).__name__, error))
        return default


def cleanup(controller, args, cancellation):
    """The sole bounded post-launch cleanup machine, including bootstrap."""
    present = safe_call(controller, "discover", lambda: controller.observe(
        "cleanup-discover"), [])
    safe_call(controller, "TERM", lambda: controller.signal_all(
        signal.SIGTERM, "cleanup-term"))
    deadline = time.monotonic() + args.term_grace
    while time.monotonic() < deadline and len(cancellation) < 2:
        present = safe_call(controller, "term-rescan", lambda:
                            controller.observe("cleanup-term-rescan"), present)
        if not present:
            break
        safe_call(controller, "term-poll", lambda: controller.sleep(
            min(args.poll, deadline - time.monotonic())))
    safe_call(controller, "KILL", lambda: controller.signal_all(
        signal.SIGKILL, "cleanup-kill"))
    deadline = time.monotonic() + args.post_kill_grace
    quiet_since = None
    empty_scans = 0
    cleared = False
    while True:
        present = safe_call(controller, "kill-rescan", lambda:
                            controller.observe("cleanup-kill-rescan"), present)
        group_gone = safe_call(controller, "group-probe", lambda:
                               controller.group_probe("cleanup-quiet"), False)
        clear_now = not present and group_gone and controller.all_closed()
        now = time.monotonic()
        if clear_now:
            empty_scans += 1
            if quiet_since is None:
                quiet_since = now
            if empty_scans >= 2 and now - quiet_since >= args.quiet_interval:
                cleared = True
                break
        else:
            quiet_since = None
            empty_scans = 0
        if now >= deadline:
            break
        safe_call(controller, "quiet-poll", lambda: controller.sleep(
            min(args.poll, deadline - now)))
    safe_call(controller, "final-observe", lambda: controller.observe(
        "cleanup-final"), [])
    descendants = any(identity != controller.leader_identity for identity in
                      list(controller.active) + list(controller.retired))
    controller.quiet_results.append({
        "phase": "cleanup-quiet", "result": "cleared" if cleared else
                 "deadline", "empty_scans": empty_scans,
        "quiet_seconds": 0 if quiet_since is None else
                         round(time.monotonic() - quiet_since, 9)})
    controller.close_pidfds()
    return cleared, descendants


def parse_args(argv):
    parser = Parser()
    for name in ("timeout", "term-grace", "post-kill-grace"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--quiet-interval", default="0.05")
    parser.add_argument("--poll", default="0.01")
    parser.add_argument("--status", required=True)
    parser.add_argument("--stdout", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--cwd", required=True)
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
    if args.poll <= 0 or args.quiet_interval <= 0:
        raise PreflightError("poll and quiet-interval must be positive")
    if args.quiet_interval < args.poll:
        raise PreflightError("quiet-interval must be at least poll")
    return args


def identity_records(controller):
    output = []
    for identity, item in sorted({**controller.active,
                                  **controller.retired}.items()):
        row = {key: value for key, value in item.items() if key != "pidfd"}
        row["identity"] = identity_json(identity)
        output.append(row)
    return output


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    status_path = status_argument(argv)
    try:
        args = parse_args(argv)
        subreaper_verified = enable_and_verify_subreaper()
        require_pidfds()
        faults = Faults()
        controller = CleanupController(args.poll, args.quiet_interval,
                                       faults, subreaper_verified)
    except PreflightError as error:
        preflight_status(status_path, str(error))
        return 125
    except OSError as error:
        preflight_status(status_path, str(error), "preflight_unsupported")
        return 125
    except BaseException as error:
        preflight_status(status_path, "controller bootstrap failed: %s" % error,
                         "preflight_failed")
        return 125

    cancellation = []
    old_handlers = {}

    def requested(signum, _frame):
        cancellation.append({"signal": signum, "observed_utc": utc_now()})

    for sig in HANDLED_SIGNALS:
        old_handlers[sig] = signal.signal(sig, requested)

    if args.ready is not None:
        try:
            atomic_ready(args.ready)
        except BaseException as error:
            preflight_status(args.status, "ready publication failed: %s" % error,
                             "preflight_failed")
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
            return 125

    command = args.command[1:]
    started = time.monotonic()
    started_utc = utc_now()
    primary_exception = None
    timed_out = False
    leader_finished = False
    launched = False
    try:
        with open(args.stdout, "xb") as stdout, open(args.stderr, "xb") as stderr:
            child = subprocess.Popen(
                command, cwd=args.cwd, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, start_new_session=True)
            launched = True
            # No fallible full-session work occurs before this attachment.
            controller.attach_bootstrap(child)
            controller.construct_session()
            deadline = time.monotonic() + args.timeout
            while controller.leader_returncode is None and not cancellation:
                faults.hit("wait")
                controller.observe("leader-wait")
                if controller.leader_returncode is not None:
                    break
                now = time.monotonic()
                if now >= deadline:
                    timed_out = True
                    break
                controller.sleep(min(args.poll, deadline - now))
            leader_finished = controller.leader_returncode is not None
    except BaseException as error:
        primary_exception = {
            "type": type(error).__name__, "message": str(error),
            "traceback": "".join(traceback.format_exception_only(
                type(error), error)).strip()}
        if not launched:
            preflight_status(args.status, "launch failed: %s" % error,
                             "launch_failed")
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
            return 125

    cleared, descendants = cleanup(controller, args, cancellation)
    cleanup_failed = not cleared or bool(controller.cleanup_errors)
    if cleanup_failed:
        classification = "failure_cleanup_uncleared_or_degraded"
        return_status = 125
    elif cancellation:
        classification = "cancelled_%s_cleanup_cleared" % signal.Signals(
            cancellation[0]["signal"]).name
        return_status = 128 + cancellation[0]["signal"]
    elif primary_exception is not None:
        classification = "failure_exception_cleanup_cleared"
        return_status = 125
    elif timed_out:
        classification = "timeout_cleanup_cleared"
        return_status = 124
    elif descendants:
        classification = "lifecycle_anomaly_cleanup_cleared"
        return_status = 125
    elif controller.leader_returncode is None:
        classification = "failure_missing_leader_status"
        return_status = 125
    elif controller.leader_returncode == 0:
        classification = "completed_exit_0"
        return_status = 0
    else:
        classification = "completed_exit_nonzero"
        return_status = (controller.leader_returncode if
                         controller.leader_returncode >= 0 else
                         128 + (-controller.leader_returncode))

    record = {
        "protocol_version": STATUS_VERSION, "classification": classification,
        "command": command, "started_utc": started_utc,
        "ended_utc": utc_now(),
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "controller_existed_before_launch": True,
        "baseline_direct_identities": [identity_json(item) for item in
                                       sorted(controller.baseline_direct_identities)],
        "subreaper_verified_before_launch": controller.subreaper_verified,
        "bootstrap_pidfd_result": controller.bootstrap_pidfd_result,
        "full_session_constructed": controller.full_session_constructed,
        "leader_identity": identity_json(controller.leader_identity),
        "leader_returncode": controller.leader_returncode,
        "leader_finished_before_cleanup": leader_finished,
        "original_pgid": controller.pgid, "timed_out": timed_out,
        "requested_outer_signals": cancellation,
        "requested_outer_status": (None if not cancellation else
                                    128 + cancellation[0]["signal"]),
        "supervisor_return_status": return_status,
        "primary_exception": primary_exception,
        "cleanup_cleared": cleared,
        "cleanup_errors": controller.cleanup_errors,
        "faults_triggered": faults.triggered,
        "owned_identities": identity_records(controller),
        "identity_closure_counts": controller.closure_counts(),
        "reaps": controller.reaps, "scans": controller.scans,
        "signals": controller.signals,
        "group_probes": controller.group_probes,
        "quiet_results": controller.quiet_results,
        "timeout_seconds": args.timeout,
        "term_grace_seconds": args.term_grace,
        "post_kill_grace_seconds": args.post_kill_grace,
        "quiet_interval_seconds": args.quiet_interval,
        "poll_seconds": args.poll}
    status_error = atomic_status(args.status, record, faults)
    for sig, handler in old_handlers.items():
        signal.signal(sig, handler)
    if status_error:
        print("supervise-v5: status media unwritable after cleanup: %s" %
              status_error, file=sys.stderr)
        return 125
    return return_status


if __name__ == "__main__":
    raise SystemExit(main())
