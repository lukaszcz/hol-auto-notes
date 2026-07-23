#!/usr/bin/env python3
"""Resistant setsid/double-fork/fork-on-signal v7 fixture."""
import ctypes
import os
import signal
import sys
import time


endpoint, marker = sys.argv[1:]
libc = ctypes.CDLL(None)


def mark(role):
    name = (marker + role)[:15].encode("ascii")
    libc.prctl(15, name, 0, 0, 0)
    with open(endpoint, "a", encoding="ascii") as stream:
        stream.write("%s:%d\n" % (role, os.getpid()))
        stream.flush()


forked = False


def on_term(_signum, _frame):
    global forked
    if not forked:
        forked = True
        if os.fork() == 0:
            mark("signal")
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            while True:
                time.sleep(1)


def resist():
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, on_term)


mark("leader")
resist()
middle = os.fork()
if middle == 0:
    if os.fork() == 0:
        os.setsid()
        mark("escape")
        resist()
        while True:
            time.sleep(1)
    os._exit(0)
while True:
    time.sleep(1)
