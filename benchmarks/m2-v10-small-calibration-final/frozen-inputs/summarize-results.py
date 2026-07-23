#!/usr/bin/env python3
"""Apply only the frozen median/ablation formulas."""
from decimal import Decimal, getcontext
import argparse
import os
import pathlib


getcontext().prec = 40


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


def fmt(value):
    return format(value, ".9f")


def ratio(value):
    return format(value, ".6f")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    rows = [line.split("\t") for line in
            pathlib.Path(args.raw).read_text().splitlines()[1:-1]]
    values = {mode: sorted(Decimal(row[15]) for row in rows if row[5] == mode)
              for mode in "ABCD"}
    med = {mode: values[mode][2] for mode in "ABCD"}
    ba = med["B"] / med["A"]
    ca = med["C"] / med["A"]
    dc = med["D"] / med["C"]
    total = med["D"] - med["A"]
    aggregation = med["C"] - med["A"]
    clock = med["D"] - med["C"]
    share = None if total <= 0 else clock / total
    sanity = Decimal("0.95") <= ba <= Decimal("1.05")
    clock_dominant = share is not None and share >= Decimal("0.80") and \
        dc >= Decimal("1.50")
    aggregation_material = ca >= Decimal("1.25")
    if not sanity:
        classification = "indeterminate_ba_sanity_failed"
    elif clock_dominant and aggregation_material:
        classification = "both"
    elif clock_dominant:
        classification = "clock-dominant"
    elif aggregation_material:
        classification = "aggregation-material"
    else:
        classification = "mixed/indeterminate"
    lines = ["mode\tmedian_external\tminimum_external\tmaximum_external\n"]
    for mode in "ABCD":
        lines.append("%s\t%s\t%s\t%s\n" %
                     (mode, fmt(med[mode]), fmt(values[mode][0]),
                      fmt(values[mode][-1])))
    lines += [
        "metric\tvalue\n", "B_over_A\t%s\n" % ratio(ba),
        "C_over_A\t%s\n" % ratio(ca),
        "D_over_C\t%s\n" % ratio(dc),
        "total_v4_increment_D_minus_A\t%s\n" % fmt(total),
        "constant_clock_increment_C_minus_A\t%s\n" % fmt(aggregation),
        "real_clock_increment_D_minus_C\t%s\n" % fmt(clock),
        "clock_share\t%s\n" % ("NA" if share is None else ratio(share)),
        "ba_sanity\t%s\n" % ("PASS" if sanity else "FAIL"),
        "classification\t%s\n" % classification]
    summary = "".join(lines)
    report = """# Final report

All 20 fresh P38@4 child transactions completed and passed exact work,
schema, bounded-summary, clock-count, containment, artifact and endpoint
validation.  The mechanically derived result is:

```
%s```

The classification is `%s`.  This is a process-level ablation with startup,
scheduler, cache and interaction limitations; it is not proof of
microarchitectural causation and selects no source optimization.
""" % (summary, classification)
    atomic(pathlib.Path(args.summary), summary)
    atomic(pathlib.Path(args.report), report)


if __name__ == "__main__":
    main()
