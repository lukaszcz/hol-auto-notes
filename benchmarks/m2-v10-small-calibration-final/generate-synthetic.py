#!/usr/bin/env python3
"""Generate a timing-free positive fixture for the closed validator."""
import argparse
import pathlib


HEADER = ("protocol\tsequence\trepetition\tproblem\tdepth\tmode\t"
          "outcome\tattempts\tsearch_counters\t"
          "reconstruction_signatures\tclock_reads\tsummary_reads\t"
          "trace_allocations\tsequence_reads\tdiagnostic_elapsed\t"
          "external_elapsed\tsupervisor_status\tclassification\t"
          "containment")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("schedule")
    parser.add_argument("output")
    args = parser.parse_args()
    schedule = pathlib.Path(args.schedule).read_text().splitlines()[1:]
    signature = ",".join(["0"] * 37)
    lines = [HEADER]
    for line in schedule:
        sequence, repetition, problem, depth, mode = line.split("\t")
        v4 = mode in "CD"
        fields = ["V10CAL1", sequence, repetition, problem, depth, mode,
                  "none", "1", ",".join(["0"] * 8), signature,
                  "101" if v4 else "NA", "1" if v4 else "NA",
                  "0" if v4 else "NA", "0" if v4 else "NA",
                  "1.000000000" if mode in "BD" else "NA",
                  "%d.000000000" % (10 + int(sequence)), "0",
                  "completed_exit_0", "cleared"]
        lines.append("\t".join(fields))
    lines.append("EOF\tV10CAL1")
    pathlib.Path(args.output).write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
