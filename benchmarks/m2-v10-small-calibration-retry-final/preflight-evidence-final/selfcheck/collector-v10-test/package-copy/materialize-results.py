#!/usr/bin/env python3
"""Build the derived calibration ledger from v10 child transactions."""
import argparse
import json
import os
import pathlib


HEADER = ("protocol\tsequence\trepetition\tproblem\tdepth\tmode\t"
          "outcome\tattempts\tsearch_counters\t"
          "reconstruction_signatures\tclock_reads\tsummary_reads\t"
          "trace_allocations\tsequence_reads\tdiagnostic_elapsed\t"
          "external_elapsed\tsupervisor_status\tclassification\t"
          "containment\n")


def atomic(path, text):
    temporary = path.with_name(path.name + ".tmp.%d" % os.getpid())
    with temporary.open("x", encoding="utf-8", newline="") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
    descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--collection", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    collection = pathlib.Path(args.collection)
    lines = [HEADER]
    for sequence in range(1, 21):
        child = collection / ("child-%d" % sequence)
        harness = (child / "raw/stdout").read_text(encoding="utf-8")
        if not harness.endswith("\n") or harness.count("\n") != 1:
            raise SystemExit("materialize-results: harness schema")
        fields = harness.rstrip("\n").split("\t")
        if len(fields) != 15:
            raise SystemExit("materialize-results: harness width")
        row = json.loads((child / "raw/supervisor.json").read_text())
        fields.extend([
            format(row["elapsed_seconds"], ".9f"),
            str(row["supervisor_return_status"]), row["classification"],
            "cleared" if row["containment_cleared"] else "uncleared"])
        lines.append("\t".join(fields) + "\n")
    lines.append("EOF\tV10CAL2\n")
    atomic(pathlib.Path(args.output), "".join(lines))


if __name__ == "__main__":
    main()
