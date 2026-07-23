#!/usr/bin/env python3
"""Long-lived v4 signal/containment fixtures."""
import os
import signal
import sys
import time
import ctypes


mode, pid_file = sys.argv[1:3]
marker = sys.argv[3] if len(sys.argv) > 3 else "v4fixture"
ctypes.CDLL(None).prctl(15, marker.encode("ascii"), 0, 0, 0)


def append_pid():
    with open(pid_file, "a", encoding="ascii") as stream:
        stream.write("%d\n" % os.getpid())
        stream.flush()


def resist():
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)


append_pid()
resist()

if mode == "same-group-resistant":
    if os.fork() == 0:
        append_pid()
        resist()
        while True:
            time.sleep(1)
elif mode == "setsid-resistant":
    if os.fork() == 0:
        os.setsid()
        append_pid()
        resist()
        while True:
            time.sleep(1)
elif mode == "double-fork-resistant":
    if os.fork() == 0:
        if os.fork() == 0:
            os.setsid()
            append_pid()
            resist()
            while True:
                time.sleep(1)
        os._exit(0)
else:
    raise SystemExit("unknown mode")

while True:
    time.sleep(1)
