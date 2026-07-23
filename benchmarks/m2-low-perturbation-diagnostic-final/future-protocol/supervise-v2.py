#!/usr/bin/env python3
"""Future protocol: supervise one Linux process group to a terminal state."""
import argparse
import ctypes
import datetime
import errno
import json
import os
import signal
import subprocess
import sys
import time


PR_SET_CHILD_SUBREAPER = 36


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def enable_subreaper():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


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
    def __init__(self, child, pgid, poll):
        self.child = child
        self.pgid = pgid
        self.poll = poll
        self.reaps = []
        self.reaped_pids = set()
        self.leader_returncode = None
        self.probes = []

    def reap(self):
        while True:
            try:
                pid, status = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                return
            if pid == 0:
                return
            row = decode_wait(pid, status, self.child.pid)
            if row is None or pid in self.reaped_pids:
                continue
            self.reaped_pids.add(pid)
            self.reaps.append(row)
            if pid == self.child.pid:
                self.leader_returncode = row["wait_returncode"]
                self.child.returncode = self.leader_returncode

    def group_gone(self, phase):
        try:
            os.killpg(self.pgid, 0)
            result = False
            error = None
        except ProcessLookupError:
            result = True
            error = "ESRCH"
        except PermissionError:
            result = False
            error = "EPERM"
        self.probes.append({"phase": phase, "gone": result, "error": error})
        return result

    def send(self, sig):
        try:
            os.killpg(self.pgid, sig)
            return "sent"
        except ProcessLookupError:
            return "ESRCH"

    def poll_group(self, seconds, phase):
        deadline = time.monotonic() + seconds
        while True:
            self.reap()
            if self.group_gone(phase):
                return True
            now = time.monotonic()
            if now >= deadline:
                return False
            time.sleep(min(self.poll, deadline - now))

    def wait_leader(self, seconds):
        deadline = time.monotonic() + seconds
        while self.leader_returncode is None:
            self.reap()
            if self.leader_returncode is not None:
                return True
            now = time.monotonic()
            if now >= deadline:
                return False
            time.sleep(min(self.poll, deadline - now))
        return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--term-grace", type=float, required=True)
    parser.add_argument("--post-kill-grace", type=float, required=True)
    parser.add_argument("--poll", type=float, default=0.01)
    parser.add_argument("--status", required=True)
    parser.add_argument("--stdout", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--":
        parser.error("command must follow --")
    if min(args.timeout, args.term_grace, args.post_kill_grace) < 0:
        parser.error("timeouts must be nonnegative")
    if args.poll <= 0:
        parser.error("poll must be positive")

    enable_subreaper()
    command = args.command[1:]
    started_utc = utc_now()
    started = time.monotonic()
    with open(args.stdout, "xb") as stdout, open(args.stderr, "xb") as stderr:
        child = subprocess.Popen(
            command, cwd=args.cwd, stdin=subprocess.DEVNULL,
            stdout=stdout, stderr=stderr, start_new_session=True)
        session = Session(child, os.getpgid(child.pid), args.poll)
        timed_out = not session.wait_leader(args.timeout)
        term_result = None
        kill_result = None
        if timed_out:
            term_result = session.send(signal.SIGTERM)
            gone = session.poll_group(args.term_grace, "term-grace")
            if gone:
                classification = "timeout_term_group_cleared"
            else:
                kill_result = session.send(signal.SIGKILL)
                gone = session.poll_group(
                    args.post_kill_grace, "post-kill")
                classification = (
                    "timeout_kill_group_cleared" if gone
                    else "failure_group_uncleared_after_kill")
        else:
            session.reap()
            gone = session.group_gone("ordinary-exit")
            if not gone:
                term_result = session.send(signal.SIGTERM)
                gone = session.poll_group(args.term_grace, "ordinary-term")
            if not gone:
                kill_result = session.send(signal.SIGKILL)
                gone = session.poll_group(
                    args.post_kill_grace, "ordinary-post-kill")
            if not gone:
                classification = "failure_group_uncleared_after_exit"
            elif session.leader_returncode == 0:
                classification = "completed_exit_0"
            else:
                classification = "completed_exit_nonzero"
        session.reap()

    record = {
        "classification": classification,
        "command": command,
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "ended_utc": utc_now(),
        "group_gone": gone,
        "group_probes": session.probes,
        "kill_result": kill_result,
        "leader_pid": child.pid,
        "leader_returncode": session.leader_returncode,
        "pgid": session.pgid,
        "post_kill_grace_seconds": args.post_kill_grace,
        "reaps": session.reaps,
        "started_utc": started_utc,
        "subreaper": True,
        "term_grace_seconds": args.term_grace,
        "term_result": term_result,
        "timed_out": timed_out,
        "timeout_seconds": args.timeout,
    }
    with open(args.status, "x", encoding="utf-8") as status:
        json.dump(record, status, sort_keys=True)
        status.write("\n")

    if classification.startswith("failure_"):
        return 125
    if timed_out:
        return 124
    rc = session.leader_returncode
    if rc is None:
        return 125
    return rc if rc >= 0 else 128 - rc


if __name__ == "__main__":
    sys.exit(main())
