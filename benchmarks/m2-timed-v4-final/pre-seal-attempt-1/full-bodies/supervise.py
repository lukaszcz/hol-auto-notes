#!/usr/bin/env python3
"""Run one child in a fresh process group and retain observed termination."""
import argparse
import datetime
import errno
import json
import os
import signal
import subprocess
import sys
import time


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def group_gone(pgid):
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return True
    except PermissionError:
        return False
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--grace", type=float, required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--stdout", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--":
        parser.error("command must follow --")
    command = args.command[1:]
    started_utc = utc_now()
    started = time.monotonic()
    timed_out = False
    term_sent = False
    kill_sent = False
    with open(args.stdout, "wb") as stdout, open(args.stderr, "wb") as stderr:
        child = subprocess.Popen(command, cwd=args.cwd, stdin=subprocess.DEVNULL,
                                 stdout=stdout, stderr=stderr,
                                 start_new_session=True)
        pgid = os.getpgid(child.pid)
        try:
            returncode = child.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(pgid, signal.SIGTERM)
            term_sent = True
            try:
                returncode = child.wait(timeout=args.grace)
            except subprocess.TimeoutExpired:
                os.killpg(pgid, signal.SIGKILL)
                kill_sent = True
                returncode = child.wait()
    gone = group_gone(pgid)
    record = {
        "command": command,
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "ended_utc": utc_now(),
        "exit_status": returncode if returncode >= 0 else None,
        "grace_seconds": args.grace,
        "group_gone": gone,
        "kill_sent": kill_sent,
        "pgid": pgid,
        "pid": child.pid,
        "reaped": True,
        "started_utc": started_utc,
        "term_sent": term_sent,
        "term_signal": -returncode if returncode < 0 else None,
        "timed_out": timed_out,
        "timeout_seconds": args.timeout,
        "wait_returncode": returncode,
    }
    with open(args.status, "x", encoding="utf-8") as status:
        json.dump(record, status, sort_keys=True)
        status.write("\n")
    if not gone:
        return 125
    if timed_out:
        return 124
    return returncode if returncode >= 0 else 128 - returncode


if __name__ == "__main__":
    sys.exit(main())
