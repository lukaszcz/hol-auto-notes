#!/usr/bin/env python3
"""Validate the exact completed prefix and censored fourth child."""
import csv
import json
import pathlib
import re
import sys


def fail(message):
    print("verify-partial-calibration: " + message, file=sys.stderr)
    raise SystemExit(1)


root = pathlib.Path(sys.argv[1])
with (root / "calibration-raw.tsv").open(newline="") as stream:
    rows = list(csv.DictReader(stream, delimiter="\t"))
if [(r["repetition"], r["problem"], r["depth"], r["mode"]) for r in rows] != [
    ("1", "38", "4", "v2"), ("1", "38", "4", "v4"),
    ("1", "43", "5", "v2")]:
    fail("exact completed prefix")
elapsed = re.compile(r"^(0|[1-9][0-9]*)\.[0-9]{9}$")
if any(r["outcome"] != "none" or not elapsed.match(r["elapsed"]) for r in rows):
    fail("outcome/elapsed grammar")
if ((rows[0]["attempts"], rows[1]["attempts"], rows[2]["attempts"]) !=
        ("22", "22", "2")):
    fail("attempt schedule")
for row in rows:
    if len(row["search_counters"].split(",")) != 8:
        fail("search signature width")
    signatures = row["reconstruction_signatures"].split(";")
    if len(signatures) != int(row["attempts"]):
        fail("reconstruction signature count")
    if any(len(signature.split(",")) != 37 for signature in signatures):
        fail("reconstruction signature width")
work = lambda r: (r["outcome"], r["attempts"], r["search_counters"],
                  r["reconstruction_signatures"])
if work(rows[0]) != work(rows[1]):
    fail("P38 paired work/signature parity")
fourth = json.loads((root / "status" / "representative-4.json").read_text())
if not (fourth["timed_out"] and fourth["term_sent"] and
        fourth["wait_returncode"] == -15 and fourth["term_signal"] == 15 and
        fourth["reaped"] and fourth["exit_status"] is None):
    fail("fourth child observed censoring")
if (root / "logs" / "representative-4.stdout").stat().st_size != 0:
    fail("censored child unexpectedly emitted elapsed row")
print("completed-prefix schema/schedule/P38 parity and P43 censoring: PASS")
