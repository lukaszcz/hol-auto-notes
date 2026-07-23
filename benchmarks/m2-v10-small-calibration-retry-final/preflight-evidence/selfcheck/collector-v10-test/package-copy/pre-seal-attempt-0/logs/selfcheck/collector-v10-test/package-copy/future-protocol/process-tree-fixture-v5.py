#!/usr/bin/env python3
"""Deterministic lifecycle shapes for future supervisor v5."""
import ctypes
import os
import signal
import sys
import time


mode, pid_file = sys.argv[1:3]
marker = sys.argv[3] if len(sys.argv) > 3 else "v5fixture"
ctypes.CDLL(None).prctl(15, marker.encode("ascii"), 0, 0, 0)


def append(label):
    with open(pid_file, "a", encoding="ascii") as stream:
        stream.write("%s:%d\n" % (label, os.getpid()))
        stream.flush()


def resist():
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGINT, signal.SIG_IGN)


if mode in ("same-group-resistant", "setsid-resistant",
            "double-fork-resistant"):
    append("leader")
    resist()
    if mode == "same-group-resistant":
        if os.fork() == 0:
            append("same-group")
            resist()
            while True:
                time.sleep(1)
    elif mode == "setsid-resistant":
        if os.fork() == 0:
            os.setsid()
            append("setsid")
            resist()
            while True:
                time.sleep(1)
    elif os.fork() == 0:
        if os.fork() == 0:
            os.setsid()
            append("double-fork")
            resist()
            while True:
                time.sleep(1)
        os._exit(0)
    while True:
        time.sleep(1)


if mode == "rapid-double-fork-setsid":
    middle = os.fork()
    if middle == 0:
        if os.fork() == 0:
            os.setsid()
            ctypes.CDLL(None).prctl(15, marker.encode("ascii"), 0, 0, 0)
            resist()
            append("escape")
            while True:
                time.sleep(1)
        os._exit(0)
    os._exit(0)

if mode == "parent-reaps-grandchild":
    append("leader")
    child = os.fork()
    if child == 0:
        append("grandchild")
        time.sleep(.12)
        os._exit(0)
    os.waitpid(child, 0)
    resist()
    while True:
        time.sleep(1)

if mode == "adopted-zombie":
    if os.fork() == 0:
        append("adopted")
        time.sleep(.08)
        os._exit(0)
    os._exit(0)

raise SystemExit("unknown fixture mode")
