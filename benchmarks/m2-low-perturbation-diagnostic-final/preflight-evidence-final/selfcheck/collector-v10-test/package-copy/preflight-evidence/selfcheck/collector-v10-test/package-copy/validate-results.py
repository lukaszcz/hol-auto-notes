#!/usr/bin/env python3
"""Closed schema/order/count/cross-ledger validator for Task 7n."""
import argparse
import hashlib
import json
import pathlib
import re


HEADER = ("protocol\tsequence\trepetition\tmode\texact_count\t"
          "observed_count\tsink_class\texternal_elapsed\t"
          "supervisor_status\tclassification\tcontainment")
POS = re.compile(r"[1-9][0-9]*")
SEC = re.compile(r"(?:0|[1-9][0-9]*)\.[0-9]{9}")
COUNT = 61486260


class Invalid(ValueError):
    pass


def read_schedule(path):
    text = path.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        raise Invalid("schedule EOF")
    lines = text.splitlines()
    if not lines or lines[0] != "sequence\trepetition\tmode":
        raise Invalid("schedule header")
    rows = []
    expected_modes = "ZNNZZNNZZN"
    expected_repetitions = (1, 1, 2, 2, 3, 3, 4, 4, 5, 5)
    for index, line in enumerate(lines[1:], 1):
        fields = line.split("\t")
        if len(fields) != 3 or not POS.fullmatch(fields[0]) or \
                not POS.fullmatch(fields[1]):
            raise Invalid("schedule schema/lexical")
        row = (int(fields[0]), int(fields[1]), fields[2])
        if row != (index, expected_repetitions[index - 1],
                   expected_modes[index - 1]):
            raise Invalid("schedule literal/order")
        rows.append(row)
    if len(rows) != 10 or any(sum(row[2] == mode for row in rows) != 5
                              for mode in "ZN"):
        raise Invalid("schedule cardinality/balance")
    return rows


def parse_raw(path, schedule):
    text = path.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        raise Invalid("raw EOF")
    lines = text.splitlines()
    if len(lines) != 12 or lines[0] != HEADER or \
            lines[-1] != "EOF\tV10CLOCK":
        raise Invalid("raw header/cardinality/EOF/no-append")
    rows = []
    for line, expected in zip(lines[1:-1], schedule):
        fields = line.split("\t")
        if len(fields) != 11 or fields[0] != "V10CLOCK":
            raise Invalid("row schema/protocol")
        if not POS.fullmatch(fields[1]) or not POS.fullmatch(fields[2]):
            raise Invalid("scheduled lexical")
        if (int(fields[1]), int(fields[2]), fields[3]) != expected:
            raise Invalid("row schedule/order")
        if fields[4] != str(COUNT) or fields[5] != str(COUNT):
            raise Invalid("exact count parity")
        if fields[6] != "nonnegative":
            raise Invalid("sink class")
        if not SEC.fullmatch(fields[7]):
            raise Invalid("external elapsed grammar")
        if fields[8:] != ["0", "completed_exit_0", "cleared"]:
            raise Invalid("supervisor status/classification/containment")
        rows.append(fields)
    if any(sum(row[3] == mode for row in rows) != 5 for mode in "ZN"):
        raise Invalid("raw mode balance")
    if sum(int(row[5]) for row in rows if row[3] == "Z") != 5 * COUNT or \
            sum(int(row[5]) for row in rows if row[3] == "N") != 5 * COUNT:
        raise Invalid("global exact count parity")
    return rows


def check_seal(child):
    lines = (child / "raw.seal.sha256").read_text().splitlines()
    if not lines:
        raise Invalid("child raw seal empty")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = child / relative
        if digest == "ABSENT" or not path.is_file() or \
                hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise Invalid("child raw seal mismatch")


def cross_ledger(rows, collection, reference):
    for fields in rows:
        child = collection / ("child-%s" % fields[1])
        if not child.is_dir():
            raise Invalid("child directory missing")
        if (child / "raw/stdout").read_text() != \
                "\t".join(fields[:7]) + "\n":
            raise Invalid("harness/raw cross-ledger")
        if (child / "raw/stderr").read_bytes():
            raise Invalid("harness stderr")
        supervisor = json.loads((child / "raw/supervisor.json").read_text())
        if type(supervisor.get("supervisor_return_status")) is not int or \
                supervisor["supervisor_return_status"] != int(fields[8]) or \
                supervisor.get("classification") != fields[9] or \
                supervisor.get("containment_cleared") is not True or \
                format(supervisor.get("elapsed_seconds"), ".9f") != fields[7]:
            raise Invalid("supervisor/raw cross-ledger")
        required = {"actual_supervisor_status=0", "supervisor_schema_status=0",
                    "containment_status=cleared", "raw_durability_status=0",
                    "raw_seal_status=0", "artifact_audit_status=0",
                    "endpoint_audit_status=0", "cleanup_or_audit_failure=0",
                    "final_status=0"}
        status = set((child / "final-status.txt").read_text().splitlines())
        if not required <= status:
            raise Invalid("collector final-status ledger")
        if (child / "audits/final-endpoint.txt").read_text() != \
                "matches=none\n":
            raise Invalid("exact endpoint audit")
        if (child / "audits/final-artifacts.tsv").read_bytes() != \
                reference.read_bytes():
            raise Invalid("artifact endpoint identity")
        check_seal(child)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--raw", required=True)
    parser.add_argument("--collection")
    parser.add_argument("--artifact-reference")
    args = parser.parse_args()
    try:
        schedule = read_schedule(pathlib.Path(args.schedule))
        rows = parse_raw(pathlib.Path(args.raw), schedule)
        if bool(args.collection) != bool(args.artifact_reference):
            raise Invalid("cross-ledger arguments")
        if args.collection:
            cross_ledger(rows, pathlib.Path(args.collection),
                         pathlib.Path(args.artifact_reference))
    except BaseException as error:
        print("validate-results: %s" % error, file=__import__("sys").stderr)
        return 1
    print("validate-results: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

