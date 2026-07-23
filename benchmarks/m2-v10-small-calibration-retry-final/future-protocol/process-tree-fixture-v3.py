#!/usr/bin/env python3
"""Deterministic process-tree shapes for the v3 supervisor regressions."""
import os
import signal
import sys
import time


mode, pid_file = sys.argv[1:]


def record_pid():
    with open(pid_file, "w", encoding="ascii") as stream:
        stream.write("%d\n" % os.getpid())


if mode == "setsid":
    if os.fork() == 0:
        os.setsid()
        record_pid()
        while True:
            time.sleep(1)
    while True:
        time.sleep(1)

if mode == "double-fork":
    intermediate = os.fork()
    if intermediate == 0:
        if os.fork() == 0:
            os.setsid()
            record_pid()
            while True:
                time.sleep(1)
        os._exit(0)
    os.waitpid(intermediate, 0)
    raise SystemExit(0)

if mode == "linger-term":
    if os.fork() == 0:
        record_pid()
        while True:
            time.sleep(1)
    raise SystemExit(0)

if mode == "linger-kill":
    if os.fork() == 0:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        record_pid()
        while True:
            time.sleep(1)
    raise SystemExit(0)

if mode == "linger-uncleared":
    if os.fork() == 0:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        record_pid()
        os.kill(os.getpid(), signal.SIGSTOP)
        while True:
            time.sleep(1)
    while not os.path.exists(pid_file):
        time.sleep(0.001)
    raise SystemExit(0)

raise SystemExit("unknown fixture mode")
