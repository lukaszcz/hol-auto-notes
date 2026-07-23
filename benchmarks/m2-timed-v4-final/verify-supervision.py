#!/usr/bin/env python3
"""Validate the exact observed calibration supervisor ledgers."""
import json
import pathlib
import sys


def fail(message):
    print("verify-supervision: " + message, file=sys.stderr)
    raise SystemExit(1)


root = pathlib.Path(sys.argv[1])
paths = sorted(root.glob("representative-*.json"),
               key=lambda p: int(p.stem.split("-")[1]))
if [p.name for p in paths] != [f"representative-{i}.json" for i in range(1, 5)]:
    fail("exact observed schedule")
for index, path in enumerate(paths, 1):
    try:
        row = json.loads(path.read_text())
    except Exception:
        fail("JSON schema")
    required = {"exit_status", "group_gone", "kill_sent", "pgid", "pid",
                "reaped", "term_sent", "term_signal", "timed_out",
                "wait_returncode", "timeout_seconds", "grace_seconds"}
    if not required.issubset(row):
        fail("JSON schema")
    if not row["reaped"]:
        fail("child not reaped")
    if not row["group_gone"]:
        fail("group not gone at supervisor endpoint")
    if index < 4 and (row["wait_returncode"] != 0 or row["timed_out"]):
        fail("completed child status")
    if index == 4 and not (row["timed_out"] and row["term_sent"] and
                           row["wait_returncode"] == -15 and
                           row["term_signal"] == 15):
        fail("censored child status/signal")
print("supervision schema/status/reap/group-gone: PASS")
