#!/usr/bin/env python3
"""PID-namespace init used only by the explicit future v6 launcher."""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


def atomic_json(path, value):
    target = pathlib.Path(path)
    temporary = target.with_name(target.name + ".tmp.%d" % os.getpid())
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ready", required=True)
    parser.add_argument("--go", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--" or len(args.command) == 1:
        parser.error("command must follow --")
    if os.getpid() != 1:
        raise SystemExit("namespace-init-v6: expected namespace PID 1")
    proc_inode = os.stat("/proc/self/ns/pid").st_ino
    atomic_json(args.ready, {
        "namespace_pid": 1,
        "pid_namespace_inode": proc_inode,
        "proc_pid_one_present": pathlib.Path("/proc/1/status").is_file(),
        "protocol_version": 6,
    })
    deadline = time.monotonic() + 10
    while not os.path.exists(args.go):
        if time.monotonic() >= deadline:
            return 125
        time.sleep(.005)

    child = subprocess.Popen(args.command[1:], stdin=subprocess.DEVNULL,
                             start_new_session=True)

    def forward(signum, _frame):
        try:
            os.killpg(child.pid, signum)
        except ProcessLookupError:
            pass

    for number in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(number, forward)
    while True:
        try:
            returncode = child.wait(timeout=.05)
            break
        except subprocess.TimeoutExpired:
            while True:
                try:
                    pid, _status = os.waitpid(-1, os.WNOHANG)
                except ChildProcessError:
                    break
                if pid <= 0:
                    break
    return returncode if returncode >= 0 else 128 + (-returncode)


if __name__ == "__main__":
    raise SystemExit(main())
