#!/usr/bin/env python3
"""Linux v3 supervisor for one dedicated, recursively owned process tree."""
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


PR_SET_CHILD_SUBREAPER = 36
STATUS_VERSION = 3


class PreflightError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError(message)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def status_argument(argv):
    for index, item in enumerate(argv):
        if item == "--status" and index + 1 < len(argv):
            return argv[index + 1]
        if item.startswith("--status="):
            return item.split("=", 1)[1]
    return None


def write_preflight(path, diagnostic, classification="preflight_invalid"):
    record = {
        "classification": classification,
        "diagnostic": diagnostic,
        "protocol_version": STATUS_VERSION,
    }
    if path:
        try:
            with open(path, "x", encoding="utf-8") as stream:
                json.dump(record, stream, sort_keys=True)
                stream.write("\n")
            return
        except OSError as error:
            diagnostic = "%s; status_write=%s" % (diagnostic, error)
    print("supervise-v3: %s" % diagnostic, file=sys.stderr)


def enable_subreaper():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


def require_pidfds():
    if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
        raise OSError(errno.ENOSYS, "Python pidfd API unavailable")
    descriptor = os.pidfd_open(os.getpid(), 0)
    os.close(descriptor)


def proc_row(pid):
    try:
        text = open("/proc/%d/stat" % pid, encoding="ascii").read()
    except (FileNotFoundError, ProcessLookupError):
        return None
    close = text.rfind(")")
    if close < 0:
        return None
    fields = text[close + 2:].split()
    if len(fields) < 20:
        return None
    return {
        "pid": pid,
        "state": fields[0],
        "ppid": int(fields[1]),
        "pgid": int(fields[2]),
        "sid": int(fields[3]),
        "starttime": int(fields[19]),
    }


def proc_snapshot():
    rows = {}
    with os.scandir("/proc") as entries:
        for entry in entries:
            if not entry.name.isdigit():
                continue
            row = proc_row(int(entry.name))
            if row is not None:
                rows[row["pid"]] = row
    return rows


def decode_wait(pid, status, leader):
    row = {"pid": pid, "role": "leader" if pid == leader else "descendant"}
    if os.WIFEXITED(status):
        row.update(exit_status=os.WEXITSTATUS(status), signal=None)
        row["wait_returncode"] = row["exit_status"]
    elif os.WIFSIGNALED(status):
        row.update(exit_status=None, signal=os.WTERMSIG(status))
        row["wait_returncode"] = -row["signal"]
    else:
        return None
    return row


class Session:
    def __init__(self, child, pgid, poll, quiet):
        self.child = child
        self.pgid = pgid
        self.poll = poll
        self.quiet = quiet
        self.supervisor_pid = os.getpid()
        self.owned = {}
        self.reaps = []
        self.reaped = set()
        self.leader_returncode = None
        self.group_probes = []
        self.scans = []
        self.signals = []
        self.quiet_results = []
        self.pidfd_failure = None
        self.pidfd_signals_sent = set()
        self.discover(child.pid, "leader", proc_row(child.pid))

    def discover(self, pid, origin, row):
        if pid in self.owned:
            return
        identity = {
            "pid": pid,
            "origin": origin,
            "pidfd_available": False,
            "pidfd_open_result": None,
            "starttime": row["starttime"] if row else None,
            "initial_ppid": row["ppid"] if row else None,
            "initial_pgid": row["pgid"] if row else None,
            "initial_sid": row["sid"] if row else None,
        }
        try:
            descriptor = os.pidfd_open(pid, 0)
            identity["pidfd"] = descriptor
            identity["pidfd_available"] = True
            identity["pidfd_open_result"] = "opened"
        except ProcessLookupError:
            identity["pidfd"] = None
            identity["pidfd_open_result"] = "ESRCH_already_gone"
        except OSError as error:
            identity["pidfd"] = None
            identity["pidfd_open_result"] = errno.errorcode.get(error.errno, str(error.errno))
            self.pidfd_failure = "pidfd_open failed for %d: %s" % (pid, error)
        self.owned[pid] = identity

    def scan(self, phase):
        snapshot = proc_snapshot()
        known = set(self.owned)
        added = []
        changed = True
        while changed:
            changed = False
            for pid, row in snapshot.items():
                if pid in known or pid == self.supervisor_pid:
                    continue
                if row["ppid"] in known or row["ppid"] == self.supervisor_pid:
                    origin = "adopted_by_supervisor" if row["ppid"] == self.supervisor_pid else "parent_lineage"
                    self.discover(pid, origin, row)
                    known.add(pid)
                    added.append(pid)
                    changed = True
        present = []
        for pid, identity in self.owned.items():
            row = snapshot.get(pid)
            if row is None:
                continue
            if identity["starttime"] is not None and row["starttime"] != identity["starttime"]:
                continue
            present.append(pid)
        self.scans.append({
            "phase": phase,
            "discovered": sorted(added),
            "owned_present": sorted(present),
        })
        return present

    def reap(self):
        while True:
            try:
                pid, status = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                return
            if pid == 0:
                return
            if pid not in self.owned:
                # A child can be adopted and exit between two /proc scans.
                # waitpid proves that it was our dedicated supervisor's child
                # and that it is already dead, so no live PID fallback occurs.
                self.discover(pid, "adopted_reap_race", None)
                identity = self.owned[pid]
                if identity.get("pidfd") is not None:
                    os.close(identity["pidfd"])
                identity["pidfd"] = None
                identity["pidfd_available"] = False
                identity["pidfd_open_result"] = "already_reaped_owned_child"
            row = decode_wait(pid, status, self.child.pid)
            if row is None or pid in self.reaped:
                continue
            self.reaped.add(pid)
            self.reaps.append(row)
            if pid == self.child.pid:
                self.leader_returncode = row["wait_returncode"]
                self.child.returncode = self.leader_returncode

    def observe(self, phase):
        present = self.scan(phase + ":pre-reap")
        self.reap()
        present = self.scan(phase + ":post-reap")
        return present

    def group_gone(self, phase):
        try:
            os.killpg(self.pgid, 0)
            gone, error = False, None
        except ProcessLookupError:
            gone, error = True, "ESRCH"
        except PermissionError:
            gone, error = False, "EPERM"
        self.group_probes.append({"phase": phase, "gone": gone, "error": error})
        return gone

    def pidfd_dead(self, identity):
        descriptor = identity.get("pidfd")
        if descriptor is None:
            return identity["pid"] in self.reaped
        poller = select.poll()
        poller.register(descriptor, select.POLLIN)
        return bool(poller.poll(0))

    def all_owned_reaped(self):
        return all(pid in self.reaped for pid in self.owned)

    def signal_new_owned(self, sig, phase):
        for pid in sorted(self.owned):
            identity = self.owned[pid]
            signal_key = (pid, sig)
            if signal_key in self.pidfd_signals_sent:
                continue
            if pid in self.reaped or self.pidfd_dead(identity):
                result = "already_dead"
            elif not identity["pidfd_available"]:
                result = "pidfd_unavailable"
                self.pidfd_failure = self.pidfd_failure or "live owned PID lacks pidfd"
            else:
                try:
                    signal.pidfd_send_signal(identity["pidfd"], sig, None, 0)
                    result = "sent"
                except ProcessLookupError:
                    result = "ESRCH"
                except OSError as error:
                    result = errno.errorcode.get(error.errno, str(error.errno))
            self.signals.append({
                "phase": phase, "scope": "owned_pidfd", "target": pid,
                "signal": sig, "result": result,
            })
            self.pidfd_signals_sent.add(signal_key)

    def signal_all(self, sig, phase):
        self.observe(phase + ":discover")
        try:
            os.killpg(self.pgid, sig)
            group_result = "sent"
        except ProcessLookupError:
            group_result = "ESRCH"
        except PermissionError:
            group_result = "EPERM"
        self.signals.append({
            "phase": phase, "scope": "original_pgid", "target": self.pgid,
            "signal": sig, "result": group_result,
        })
        self.observe(phase + ":after-group")
        self.signal_new_owned(sig, phase)

    def clear_proof(self, budget, phase, active_signal=None):
        deadline = time.monotonic() + budget
        quiet_since = None
        empty_scans = 0
        while True:
            present = self.observe(phase)
            if active_signal is not None:
                # A process discovered only after the first group/tree signal
                # receives the same phase signal through its pidfd.
                self.signal_new_owned(active_signal, phase + ":rescan")
            group_gone = self.group_gone(phase)
            clear = (not present and group_gone and self.all_owned_reaped()
                     and self.pidfd_failure is None)
            now = time.monotonic()
            if clear:
                empty_scans += 1
                if quiet_since is None:
                    quiet_since = now
                if empty_scans >= 2 and now - quiet_since >= self.quiet:
                    self.quiet_results.append({
                        "phase": phase, "result": "cleared",
                        "empty_scans": empty_scans,
                        "quiet_seconds": round(now - quiet_since, 9),
                    })
                    return True
            else:
                quiet_since = None
                empty_scans = 0
            if now >= deadline:
                self.quiet_results.append({
                    "phase": phase, "result": "deadline",
                    "empty_scans": empty_scans,
                    "quiet_seconds": 0 if quiet_since is None else round(now - quiet_since, 9),
                })
                return False
            time.sleep(min(self.poll, deadline - now))

    def wait_leader(self, seconds):
        deadline = time.monotonic() + seconds
        while self.leader_returncode is None:
            self.observe("leader-wait")
            if self.leader_returncode is not None:
                return True
            now = time.monotonic()
            if now >= deadline:
                return False
            time.sleep(min(self.poll, deadline - now))
        return True

    def close_pidfds(self):
        for identity in self.owned.values():
            descriptor = identity.get("pidfd")
            if descriptor is not None:
                os.close(descriptor)
                identity["pidfd"] = None


def parse_args(argv):
    parser = Parser(add_help=True)
    parser.add_argument("--timeout", required=True)
    parser.add_argument("--term-grace", required=True)
    parser.add_argument("--post-kill-grace", required=True)
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
    numeric = {}
    for name in ("timeout", "term_grace", "post_kill_grace", "quiet_interval", "poll"):
        spelling = getattr(args, name)
        try:
            value = float(spelling)
        except ValueError:
            raise PreflightError("%s must be a finite number" % name.replace("_", "-"))
        if not math.isfinite(value):
            raise PreflightError("%s must be finite" % name.replace("_", "-"))
        numeric[name] = value
    for name in ("timeout", "term_grace", "post_kill_grace"):
        if numeric[name] < 0:
            raise PreflightError("%s must be nonnegative" % name.replace("_", "-"))
    if numeric["poll"] <= 0:
        raise PreflightError("poll must be positive")
    if numeric["quiet_interval"] <= 0:
        raise PreflightError("quiet-interval must be positive")
    if numeric["quiet_interval"] < numeric["poll"]:
        raise PreflightError("quiet-interval must be at least poll")
    for name, value in numeric.items():
        setattr(args, name, value)
    return args


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    status_path = status_argument(argv)
    try:
        args = parse_args(argv)
        enable_subreaper()
        require_pidfds()
    except PreflightError as error:
        write_preflight(status_path, str(error))
        return 125
    except OSError as error:
        write_preflight(status_path, str(error), "preflight_unsupported")
        return 125

    command = args.command[1:]
    started_utc = utc_now()
    started = time.monotonic()
    session = None
    try:
        with open(args.stdout, "xb") as stdout, open(args.stderr, "xb") as stderr:
            child = subprocess.Popen(
                command, cwd=args.cwd, stdin=subprocess.DEVNULL,
                stdout=stdout, stderr=stderr, start_new_session=True)
            session = Session(child, os.getpgid(child.pid), args.poll,
                              args.quiet_interval)
            leader_finished = session.wait_leader(args.timeout)
            timed_out = not leader_finished
            anomaly = False
            term_sent = False
            kill_sent = False

            if timed_out:
                session.signal_all(signal.SIGTERM, "timeout-term")
                term_sent = True
                cleared = session.clear_proof(
                    args.term_grace, "timeout-term-quiet", signal.SIGTERM)
                if cleared:
                    classification = "timeout_term_owned_tree_cleared"
                else:
                    session.signal_all(signal.SIGKILL, "timeout-kill")
                    kill_sent = True
                    cleared = session.clear_proof(
                        args.post_kill_grace, "timeout-kill-quiet",
                        signal.SIGKILL)
                    classification = (
                        "timeout_kill_owned_tree_cleared" if cleared else
                        "failure_owned_tree_uncleared_after_timeout_kill")
            else:
                present = session.observe("ordinary-exit-assessment")
                anomaly = bool(present or not session.group_gone(
                    "ordinary-exit-assessment") or not session.all_owned_reaped())
                if not anomaly:
                    clean_budget = args.quiet_interval + 2 * args.poll
                    if not session.clear_proof(clean_budget, "ordinary-exit-quiet"):
                        anomaly = True
                if anomaly:
                    session.signal_all(signal.SIGTERM, "anomaly-term")
                    term_sent = True
                    cleared = session.clear_proof(
                        args.term_grace, "anomaly-term-quiet", signal.SIGTERM)
                    if cleared:
                        classification = "lifecycle_anomaly_term_owned_tree_cleared"
                    else:
                        session.signal_all(signal.SIGKILL, "anomaly-kill")
                        kill_sent = True
                        cleared = session.clear_proof(
                            args.post_kill_grace, "anomaly-kill-quiet",
                            signal.SIGKILL)
                        classification = (
                            "lifecycle_anomaly_kill_owned_tree_cleared" if cleared else
                            "lifecycle_anomaly_owned_tree_uncleared")
                elif session.leader_returncode == 0:
                    cleared = True
                    classification = "completed_exit_0"
                else:
                    cleared = True
                    classification = "completed_exit_nonzero"
            session.observe("terminal")
    except Exception as error:
        if session is None:
            write_preflight(args.status, "launch failed: %s" % error)
            return 125
        raise

    identities = []
    for pid in sorted(session.owned):
        row = dict(session.owned[pid])
        row["pidfd_number"] = row.pop("pidfd", None)
        row["reaped"] = pid in session.reaped
        identities.append(row)
    record = {
        "classification": classification,
        "command": command,
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "ended_utc": utc_now(),
        "group_gone": session.group_gone("status-final"),
        "group_probes": session.group_probes,
        "kill_sent": kill_sent,
        "leader_pid": child.pid,
        "leader_returncode": session.leader_returncode,
        "owned_identities": identities,
        "owned_pids_all_reaped": session.all_owned_reaped(),
        "pgid": session.pgid,
        "pidfd_guarantee": session.pidfd_failure is None,
        "pidfd_failure": session.pidfd_failure,
        "poll_seconds": args.poll,
        "post_kill_grace_seconds": args.post_kill_grace,
        "protocol_version": STATUS_VERSION,
        "quiet_interval_seconds": args.quiet_interval,
        "quiet_results": session.quiet_results,
        "reaps": session.reaps,
        "scans": session.scans,
        "signals": session.signals,
        "started_utc": started_utc,
        "subreaper": True,
        "term_grace_seconds": args.term_grace,
        "term_sent": term_sent,
        "timed_out": timed_out,
        "timeout_seconds": args.timeout,
    }
    with open(args.status, "x", encoding="utf-8") as status:
        json.dump(record, status, sort_keys=True)
        status.write("\n")
    session.close_pidfds()

    if classification.startswith("failure_") or classification.startswith("lifecycle_anomaly_"):
        return 125
    if timed_out:
        return 124
    rc = session.leader_returncode
    if rc is None:
        return 125
    return rc if rc >= 0 else 128 + (-rc)


if __name__ == "__main__":
    sys.exit(main())
