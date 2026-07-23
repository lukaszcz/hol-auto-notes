#!/usr/bin/env python3
"""Closed validator for the P38@4 v10 A/B/C/D calibration."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys


HEADER = ("protocol\tsequence\trepetition\tproblem\tdepth\tmode\t"
          "outcome\tattempts\tsearch_counters\t"
          "reconstruction_signatures\tclock_reads\tsummary_reads\t"
          "trace_allocations\tsequence_reads\tdiagnostic_elapsed\t"
          "external_elapsed\tsupervisor_status\tclassification\t"
          "containment")
NAT = re.compile(r"0|[1-9][0-9]*")
POS = re.compile(r"[1-9][0-9]*")
SEC = re.compile(r"(?:0|[1-9][0-9]*)\.[0-9]{9}")


class Invalid(ValueError):
    pass


def canonical(token, positive=False):
    return bool((POS if positive else NAT).fullmatch(token))


def schedule(path):
    text = path.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        raise Invalid("schedule EOF")
    lines = text.splitlines()
    if not lines or lines[0] != "sequence\trepetition\tproblem\tdepth\tmode":
        raise Invalid("schedule header")
    rows = []
    for index, line in enumerate(lines[1:], 1):
        fields = line.split("\t")
        if len(fields) != 5:
            raise Invalid("schedule schema")
        if not all(canonical(item, True) for item in fields[:4]):
            raise Invalid("schedule lexical")
        seq, rep, problem, depth = map(int, fields[:4])
        mode = fields[4]
        if seq != index or problem != 38 or depth != 4 or mode not in "ABCD":
            raise Invalid("schedule literal/order/enum")
        rows.append((seq, rep, problem, depth, mode))
    if len(rows) != 20:
        raise Invalid("schedule cardinality")
    expected = [
        "ABDC", "BCAD", "CDBA", "DACB", "ACBD"]
    for rep, modes in enumerate(expected, 1):
        got = "".join(row[4] for row in rows if row[1] == rep)
        if got != modes:
            raise Invalid("schedule balance/order")
    if any(sum(row[4] == mode for row in rows) != 5 for mode in "ABCD"):
        raise Invalid("schedule mode counts")
    return rows


def int_vector(token, width, where):
    parts = token.split(",")
    if len(parts) != width or not all(canonical(item) for item in parts):
        raise Invalid(where)
    return tuple(map(int, parts))


def signatures(token):
    parts = token.split(";")
    if not parts or any(not item for item in parts):
        raise Invalid("signature grammar")
    return tuple(int_vector(item, 37, "signature width/lexical")
                 for item in parts)


def parse_raw(path, expected_schedule):
    text = path.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        raise Invalid("raw EOF")
    lines = text.splitlines()
    if len(lines) != 22 or lines[0] != HEADER or lines[-1] != "EOF\tV10CAL2":
        raise Invalid("raw header/cardinality/EOF/no-append")
    rows = []
    for position, (line, expected) in enumerate(
            zip(lines[1:-1], expected_schedule), 1):
        fields = line.split("\t")
        if len(fields) != 19:
            raise Invalid("row schema")
        if fields[0] != "V10CAL2":
            raise Invalid("protocol enum")
        if not all(canonical(item, True) for item in fields[1:5]):
            raise Invalid("scheduled lexical")
        fixed = tuple(map(int, fields[1:5])) + (fields[5],)
        if fixed != expected:
            raise Invalid("row schedule/order")
        if fields[6] != "none":
            raise Invalid("outcome enum")
        if not canonical(fields[7], True):
            raise Invalid("attempt lexical")
        attempts = int(fields[7])
        search = int_vector(fields[8], 8, "search counters")
        signature = signatures(fields[9])
        if len(signature) != attempts:
            raise Invalid("attempt/signature identity")
        mode = fields[5]
        v4 = mode in "CD"
        if v4:
            if not all(canonical(item) for item in fields[10:14]):
                raise Invalid("v4 counter lexical")
            clock, summary, trace, seq_reads = map(int, fields[10:14])
            if clock <= 0 or summary != attempts or trace != 0 or seq_reads != 0:
                raise Invalid("v4 bounded summary invariant")
        elif fields[10:14] != ["NA", "NA", "NA", "NA"]:
            raise Invalid("non-v4 NA invariant")
        if mode in "BD":
            if not SEC.fullmatch(fields[14]):
                raise Invalid("diagnostic elapsed grammar")
        elif fields[14] != "NA":
            raise Invalid("diagnostic elapsed semantics")
        if not SEC.fullmatch(fields[15]):
            raise Invalid("external elapsed grammar")
        if fields[16:] != ["0", "completed_exit_0", "cleared"]:
            raise Invalid("supervisor status/classification/containment")
        rows.append({"fields": fields, "attempts": attempts,
                     "search": search, "signature": signature,
                     "clock": int(fields[10]) if v4 else None})
    baseline = (rows[0]["attempts"], rows[0]["search"],
                rows[0]["signature"], rows[0]["fields"][6])
    for row in rows[1:]:
        if (row["attempts"], row["search"], row["signature"],
                row["fields"][6]) != baseline:
            raise Invalid("cross-mode exact work parity")
    c_clocks = [row["clock"] for row in rows if row["fields"][5] == "C"]
    d_clocks = [row["clock"] for row in rows if row["fields"][5] == "D"]
    if len(set(c_clocks + d_clocks)) != 1 or c_clocks[0] <= 0:
        raise Invalid("C/D equal positive clock reads")
    for rep in range(1, 6):
        selected = {row["fields"][5]: row["clock"] for row in rows
                    if int(row["fields"][2]) == rep and
                    row["fields"][5] in "CD"}
        if selected.get("C") != selected.get("D"):
            raise Invalid("per-repetition C/D clock reads")
    return rows


def sealed_raw(child):
    seal = child / "raw.seal.sha256"
    lines = seal.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise Invalid("child raw seal empty")
    for line in lines:
        digest, relative = line.split("  ", 1)
        path = child / relative
        if digest == "ABSENT" or not path.is_file():
            raise Invalid("child raw seal absence")
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise Invalid("child raw seal mismatch")


def cross_ledger(rows, collection, reference):
    for row in rows:
        fields = row["fields"]
        child = collection / ("child-%s" % fields[1])
        if not child.is_dir():
            raise Invalid("child directory missing")
        stdout = (child / "raw/stdout").read_text(encoding="utf-8")
        if stdout != "\t".join(fields[:15]) + "\n":
            raise Invalid("harness/raw cross-ledger")
        supervisor = json.loads((child / "raw/supervisor.json").read_text())
        if (type(supervisor.get("supervisor_return_status")) is not int or
                supervisor["supervisor_return_status"] != int(fields[16]) or
                supervisor.get("classification") != fields[17] or
                supervisor.get("containment_cleared") is not True or
                format(supervisor.get("elapsed_seconds"), ".9f") !=
                fields[15]):
            raise Invalid("supervisor/raw cross-ledger")
        status = (child / "final-status.txt").read_text(encoding="utf-8")
        required = {"actual_supervisor_status=0", "supervisor_schema_status=0",
                    "containment_status=cleared", "raw_durability_status=0",
                    "raw_seal_status=0", "artifact_audit_status=0",
                    "endpoint_audit_status=0", "cleanup_or_audit_failure=0",
                    "final_status=0"}
        if not required <= set(status.splitlines()):
            raise Invalid("collector final-status ledger")
        if (child / "audits/final-endpoint.txt").read_text() != "matches=none\n":
            raise Invalid("endpoint audit")
        if (child / "audits/final-artifacts.tsv").read_bytes() != \
                reference.read_bytes():
            raise Invalid("artifact endpoint identity")
        sealed_raw(child)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--schedule", required=True)
    parser.add_argument("--raw", required=True)
    parser.add_argument("--collection")
    parser.add_argument("--artifact-reference")
    args = parser.parse_args()
    try:
        expected = schedule(pathlib.Path(args.schedule))
        rows = parse_raw(pathlib.Path(args.raw), expected)
        if bool(args.collection) != bool(args.artifact_reference):
            raise Invalid("cross-ledger arguments")
        if args.collection:
            cross_ledger(rows, pathlib.Path(args.collection),
                         pathlib.Path(args.artifact_reference))
    except BaseException as error:
        print("validate-results: %s" % error, file=sys.stderr)
        return 1
    print("validate-results: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
