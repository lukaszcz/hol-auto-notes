#!/usr/bin/env python3
"""Fail-closed Linux supervisor keyed by immutable process identities."""
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
STATUS_VERSION = 4
HANDLED_SIGNALS = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)


class PreflightError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError(message)


class Faults:
    """One-shot deterministic failure injection used only by v4 tests."""
    def __init__(self):
        raw = os.environ.get("SUPERVISE_V4_INJECT", "")
        self.pending = {item for item in raw.split(",") if item}
        self.triggered = []

    def hit(self, name):
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            raise RuntimeError("injected %s failure" % name)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def identity_json(identity):
    if identity is None:
        return None
    return {"pid": identity[0], "starttime": identity[1]}


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
        except Exception as error:
            last_error = error
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            if attempt == 0:
                continue
    return "%s: %s" % (type(last_error).__name__, last_error)


def preflight_status(path, diagnostic, classification="preflight_invalid"):
    record = {"classification": classification, "diagnostic": diagnostic,
              "protocol_version": STATUS_VERSION}
    error = atomic_status(path, record, Faults()) if path else "no status path"
    if error:
        print("supervise-v4: %s; status_write=%s" % (diagnostic, error),
              file=sys.stderr)


def enable_subreaper():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))


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


def lineage_candidates(snapshot, active_identities, supervisor_pid):
    """Return new identities using only parents current in this snapshot."""
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
            direct = row["ppid"] == supervisor_pid
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


class Session:
    def __init__(self, child, pgid, poll, quiet, faults):
        self.child = child
        self.pgid = pgid
        self.poll = poll
        self.quiet = quiet
        self.faults = faults
        self.supervisor_pid = os.getpid()
        self.active = {}
        self.retired = {}
        self.reaps = []
        self.scans = []
        self.signals = []
        self.group_probes = []
        self.quiet_results = []
        self.cleanup_errors = []
        self.leader_identity = None
        self.leader_returncode = None
        self.last_snapshot = {}
        row = proc_row(child.pid)
        if row is None:
            raise RuntimeError("leader vanished before identity capture")
        self.leader_identity = (child.pid, row["starttime"])
        self.discover(self.leader_identity, "leader", row)

    def discover(self, identity, origin, row):
        if identity in self.active or identity in self.retired:
            return
        pid, starttime = identity
        item = {
            "identity": identity_json(identity), "origin": origin,
            "initial_ppid": row["ppid"], "initial_pgid": row["pgid"],
            "initial_sid": row["sid"], "pidfd_number": None,
            "pidfd_open_result": None, "pidfd_close_result": None,
            "reaped": False,
        }
        try:
            descriptor = os.pidfd_open(pid, 0)
            verify = proc_row(pid)
            if verify is None or verify["starttime"] != starttime:
                os.close(descriptor)
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

    def _retire_absent(self, snapshot):
        for identity in list(self.active):
            pid, starttime = identity
            row = snapshot.get(pid)
            if row is None or row["starttime"] != starttime:
                self.retired[identity] = self.active.pop(identity)

    def scan(self, phase):
        self.faults.hit("proc_scan")
        snapshot = proc_snapshot()
        self.last_snapshot = snapshot
        self._retire_absent(snapshot)
        admitted = []
        for identity, origin in lineage_candidates(
                snapshot, set(self.active), self.supervisor_pid):
            if identity not in self.active and identity not in self.retired:
                self.discover(identity, origin, snapshot[identity[0]])
                admitted.append(identity_json(identity))
        present = [identity for identity in self.active
                   if snapshot.get(identity[0], {}).get("starttime") ==
                   identity[1]]
        self.scans.append({
            "phase": phase, "discovered": admitted,
            "active_present": [identity_json(item)
                               for item in sorted(present)],
            "retired_count": len(self.retired),
        })
        return present

    def identity_for_reap(self, pid):
        candidates = [identity for identity in self.active
                      if identity[0] == pid]
        candidates += [identity for identity, item in self.retired.items()
                       if identity[0] == pid and not item["reaped"]]
        if len(candidates) == 1:
            return candidates[0]
        return None

    def reap(self):
        while True:
            try:
                pending = os.waitid(
                    os.P_ALL, 0, os.WEXITED | os.WNOHANG | os.WNOWAIT)
            except ChildProcessError:
                return
            if pending is None or pending.si_pid == 0:
                return
            pid = pending.si_pid
            identity = self.identity_for_reap(pid)
            if identity is None:
                # WNOWAIT keeps the adopted zombie in /proc long enough to
                # bind this reap to an immutable identity before consuming it.
                row = proc_row(pid)
                if row is not None and row["ppid"] == self.supervisor_pid:
                    identity = (pid, row["starttime"])
                    self.discover(identity, "adopted_reap_race", row)
            try:
                waited_pid, status = os.waitpid(pid, 0)
            except ChildProcessError:
                self.cleanup_errors.append("waitid/waitpid race pid=%d" % pid)
                continue
            if waited_pid != pid:
                self.cleanup_errors.append("waitpid identity mismatch pid=%d" %
                                           pid)
                continue
            decoded = decode_wait(status)
            if identity is None or decoded is None:
                self.cleanup_errors.append("unbound reap pid=%d" % pid)
                continue
            item = self.active.get(identity) or self.retired[identity]
            item["reaped"] = True
            exit_status, term_signal, returncode = decoded
            self.reaps.append({
                "identity": identity_json(identity),
                "role": "leader" if identity == self.leader_identity else
                        "descendant",
                "exit_status": exit_status, "signal": term_signal,
                "wait_returncode": returncode,
            })
            if identity == self.leader_identity:
                self.leader_returncode = returncode
                self.child.returncode = returncode

    def observe(self, phase):
        present = self.scan(phase + ":pre-reap")
        self.reap()
        present = self.scan(phase + ":post-reap")
        return present

    def pidfd_dead(self, item):
        descriptor = item.get("pidfd")
        if descriptor is None:
            return item["reaped"]
        poller = select.poll()
        poller.register(descriptor, select.POLLIN)
        return bool(poller.poll(0))

    def signal_pidfds(self, sig, phase):
        self.faults.hit("signal")
        for identity, item in sorted(self.active.items()):
            if self.pidfd_dead(item):
                result = "already_dead"
            elif item.get("pidfd") is None:
                result = "pidfd_unavailable"
                self.cleanup_errors.append(
                    "live identity lacks pidfd %s" % (identity,))
            else:
                try:
                    signal.pidfd_send_signal(item["pidfd"], sig, None, 0)
                    result = "sent"
                except ProcessLookupError:
                    result = "ESRCH"
                except OSError as error:
                    result = errno.errorcode.get(error.errno,
                                                 str(error.errno))
                    self.cleanup_errors.append(
                        "pidfd signal %s: %s" % (identity, error))
            self.signals.append({
                "phase": phase, "scope": "owned_identity_pidfd",
                "identity": identity_json(identity), "signal": sig,
                "result": result,
            })

    def original_group_reason(self):
        rows = [row for row in self.last_snapshot.values()
                if row["pgid"] == self.pgid]
        active = set(self.active)
        owned = [(row["pid"], row["starttime"]) for row in rows
                 if (row["pid"], row["starttime"]) in active]
        foreign = [(row["pid"], row["starttime"]) for row in rows
                   if (row["pid"], row["starttime"]) not in active]
        if foreign:
            return (False, "skip_foreign_or_reused_group_identity", owned,
                    foreign)
        if not owned:
            return (False, "skip_no_current_owned_group_identity", owned,
                    foreign)
        return True, "current_owned_group_identity_verified", owned, foreign

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
            "phase": phase, "scope": "original_pgid",
            "target": self.pgid, "signal": sig, "result": result,
            "identity_reason": reason,
            "owned_identities": [identity_json(item) for item in owned],
            "foreign_identities": [identity_json(item) for item in foreign],
        })
        self.signal_pidfds(sig, phase)

    def group_probe(self, phase):
        safe, reason, owned, foreign = self.original_group_reason()
        try:
            os.killpg(self.pgid, 0)
            numeric = "present"
        except ProcessLookupError:
            numeric = "ESRCH"
        except PermissionError:
            numeric = "EPERM"
        logically_gone = not owned
        self.group_probes.append({
            "phase": phase, "numeric_result": numeric,
            "identity_reason": reason, "logically_gone": logically_gone,
            "owned_identities": [identity_json(item) for item in owned],
            "foreign_identities": [identity_json(item) for item in foreign],
        })
        return logically_gone

    def all_reaped(self):
        return all(item["reaped"] for item in
                   list(self.active.values()) + list(self.retired.values()))

    def sleep(self, seconds):
        self.faults.hit("poll")
        if seconds > 0:
            time.sleep(seconds)

    def close_pidfds(self):
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


def safe_call(session, label, operation, default=None):
    try:
        return operation()
    except BaseException as error:
        session.cleanup_errors.append("%s: %s: %s" %
                                      (label, type(error).__name__, error))
        return default


def cleanup(session, args, cancellation):
    """One bounded cleanup machine for all post-launch terminal paths."""
    present = safe_call(session, "discover", lambda: session.observe(
        "cleanup-discover"), [])
    descendants_after_leader = any(
        identity != session.leader_identity for identity in present)
    safe_call(session, "TERM", lambda: session.signal_all(
        signal.SIGTERM, "cleanup-term"))
    term_deadline = time.monotonic() + args.term_grace
    while time.monotonic() < term_deadline and len(cancellation) < 2:
        present = safe_call(session, "term-rescan", lambda: session.observe(
            "cleanup-term-rescan"), present)
        if not present:
            break
        remaining = min(args.poll, term_deadline - time.monotonic())
        safe_call(session, "term-poll", lambda: session.sleep(remaining))

    # KILL is a mandatory state-machine phase even if TERM already cleared.
    safe_call(session, "KILL", lambda: session.signal_all(
        signal.SIGKILL, "cleanup-kill"))
    deadline = time.monotonic() + args.post_kill_grace
    quiet_since = None
    empty_scans = 0
    cleared = False
    while True:
        present = safe_call(session, "kill-rescan", lambda: session.observe(
            "cleanup-kill-rescan"), present)
        group_gone = safe_call(session, "group-probe", lambda:
                               session.group_probe("cleanup-quiet"), False)
        clear_now = not present and group_gone and session.all_reaped()
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
        remaining = min(args.poll, deadline - now)
        safe_call(session, "quiet-poll", lambda: session.sleep(remaining))
    safe_call(session, "final-reap", session.reap)
    session.quiet_results.append({
        "phase": "cleanup-quiet", "result": "cleared" if cleared else
                 "deadline", "empty_scans": empty_scans,
        "quiet_seconds": 0 if quiet_since is None else
                         round(time.monotonic() - quiet_since, 9),
    })
    session.close_pidfds()
    return cleared, descendants_after_leader


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
            raise PreflightError("%s must be finite" %
                                 name.replace("_", "-"))
        setattr(args, name, value)
    if min(args.timeout, args.term_grace, args.post_kill_grace) < 0:
        raise PreflightError("timeouts must be nonnegative")
    if args.poll <= 0 or args.quiet_interval <= 0:
        raise PreflightError("poll and quiet-interval must be positive")
    if args.quiet_interval < args.poll:
        raise PreflightError("quiet-interval must be at least poll")
    return args


def records(mapping, state):
    output = []
    for identity, item in sorted(mapping.items()):
        row = {key: value for key, value in item.items()
               if key != "pidfd"}
        row["state"] = state
        output.append(row)
    return output


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    status_path = status_argument(argv)
    try:
        args = parse_args(argv)
        enable_subreaper()
        require_pidfds()
    except PreflightError as error:
        preflight_status(status_path, str(error))
        return 125
    except OSError as error:
        preflight_status(status_path, str(error), "preflight_unsupported")
        return 125

    faults = Faults()
    cancellation = []
    old_handlers = {}

    def requested(signum, _frame):
        cancellation.append({"signal": signum, "observed_utc": utc_now()})

    for sig in HANDLED_SIGNALS:
        old_handlers[sig] = signal.signal(sig, requested)

    command = args.command[1:]
    started = time.monotonic()
    started_utc = utc_now()
    child = None
    session = None
    primary_exception = None
    timed_out = False
    leader_finished = False
    try:
        with open(args.stdout, "xb") as stdout, open(args.stderr, "xb") as stderr:
            child = subprocess.Popen(
                command, cwd=args.cwd, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, start_new_session=True)
            pgid = os.getpgid(child.pid)
            session = Session(child, pgid, args.poll, args.quiet_interval,
                              faults)
            deadline = time.monotonic() + args.timeout
            while session.leader_returncode is None and not cancellation:
                faults.hit("wait")
                session.observe("leader-wait")
                if session.leader_returncode is not None:
                    break
                now = time.monotonic()
                if now >= deadline:
                    timed_out = True
                    break
                session.sleep(min(args.poll, deadline - now))
            leader_finished = session.leader_returncode is not None
    except BaseException as error:
        primary_exception = {
            "type": type(error).__name__, "message": str(error),
            "traceback": "".join(traceback.format_exception_only(
                type(error), error)).strip(),
        }
        if child is None:
            preflight_status(args.status, "launch failed: %s" % error,
                             "launch_failed")
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
            return 125
        if session is None:
            try:
                session = Session(child, os.getpgid(child.pid), args.poll,
                                  args.quiet_interval, faults)
            except BaseException as nested:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except OSError:
                    pass
                try:
                    child.wait(timeout=args.post_kill_grace)
                except BaseException:
                    pass
                preflight_status(args.status,
                                 "post-launch session failure: %s; %s" %
                                 (error, nested), "failure_cleanup_unrecorded")
                for sig, handler in old_handlers.items():
                    signal.signal(sig, handler)
                return 125

    cleared, descendants = cleanup(session, args, cancellation)
    cleanup_failed = not cleared or bool(session.cleanup_errors)
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
    elif session.leader_returncode is None:
        classification = "failure_missing_leader_status"
        return_status = 125
    elif session.leader_returncode == 0:
        classification = "completed_exit_0"
        return_status = 0
    else:
        classification = "completed_exit_nonzero"
        return_status = (session.leader_returncode if
                         session.leader_returncode >= 0 else
                         128 + (-session.leader_returncode))

    record = {
        "protocol_version": STATUS_VERSION,
        "classification": classification, "command": command,
        "started_utc": started_utc, "ended_utc": utc_now(),
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "leader_identity": identity_json(session.leader_identity),
        "leader_returncode": session.leader_returncode,
        "leader_finished_before_cleanup": leader_finished,
        "original_pgid": session.pgid, "timed_out": timed_out,
        "requested_outer_signals": cancellation,
        "requested_outer_status": (None if not cancellation else
                                    128 + cancellation[0]["signal"]),
        "supervisor_return_status": return_status,
        "primary_exception": primary_exception,
        "cleanup_cleared": cleared,
        "cleanup_errors": session.cleanup_errors,
        "faults_triggered": faults.triggered,
        "active_identities": records(session.active, "active"),
        "retired_identities": records(session.retired, "retired"),
        "reaps": session.reaps, "scans": session.scans,
        "signals": session.signals, "group_probes": session.group_probes,
        "quiet_results": session.quiet_results,
        "subreaper": True, "pidfd_required": True,
        "timeout_seconds": args.timeout,
        "term_grace_seconds": args.term_grace,
        "post_kill_grace_seconds": args.post_kill_grace,
        "quiet_interval_seconds": args.quiet_interval,
        "poll_seconds": args.poll,
    }
    status_error = atomic_status(args.status, record, faults)
    for sig, handler in old_handlers.items():
        signal.signal(sig, handler)
    if status_error:
        print("supervise-v4: status media unwritable after cleanup: %s" %
              status_error, file=sys.stderr)
        return 125
    return return_status


if __name__ == "__main__":
    raise SystemExit(main())
