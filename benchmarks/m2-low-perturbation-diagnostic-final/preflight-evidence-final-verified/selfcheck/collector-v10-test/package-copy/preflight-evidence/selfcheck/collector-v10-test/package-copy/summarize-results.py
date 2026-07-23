#!/usr/bin/env python3
"""Apply the frozen Task 7n median and consistency calculation."""
from decimal import Decimal, getcontext
import argparse
import os
import pathlib


getcontext().prec = 40
REFERENCE = Decimal("5.300872114")


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    rows = [line.split("\t") for line in
            pathlib.Path(args.raw).read_text().splitlines()[1:-1]]
    values = {mode: sorted(Decimal(row[7]) for row in rows if row[3] == mode)
              for mode in "ZN"}
    med = {mode: values[mode][2] for mode in "ZN"}
    net = med["N"] - med["Z"]
    ratio = net / REFERENCE
    consistent = net > 0 and Decimal("0.80") <= ratio <= Decimal("1.20")
    lines = ["mode\tmedian_external\tminimum_external\tmaximum_external\n"]
    for mode in "ZN":
        lines.append("%s\t%s\t%s\t%s\n" %
                     (mode, fmt(med[mode]), fmt(values[mode][0]),
                      fmt(values[mode][-1])))
    lines += [
        "metric\tvalue\n",
        "net_N_minus_Z\t%s\n" % fmt(net),
        "task7m_D_minus_C\t%s\n" % fmt(REFERENCE),
        "net_over_task7m\t%s\n" % format(ratio, ".6f"),
        "consistency_band\t[0.80,1.20]\n",
        "classification\t%s\n" %
        ("consistent" if consistent else "not-consistent")]
    summary = "".join(lines)
    report = """# Task 7n final report

Status: complete target-free standalone microcalibration.

```
%s```

The standalone net is `%s` with authoritative Task 7m `D-C`, under the
frozen inclusive `[0.80,1.20]` rule.

This descriptive comparison includes fresh-process startup, loop/closure and
counter overhead, Time-value consumption, runtime/GC and v10 wrapping.  Task
7m made the reads inside real reconstruction with different allocation,
cache, locality and control-flow context.  This package therefore identifies
no production source optimization, target profile, capability conclusion or
projected speedup.
""" % (summary, "consistent" if consistent else "not consistent")
    atomic(pathlib.Path(args.summary), summary)
    atomic(pathlib.Path(args.report), report)


if __name__ == "__main__":
    main()

