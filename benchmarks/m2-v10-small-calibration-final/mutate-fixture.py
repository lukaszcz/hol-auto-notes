#!/usr/bin/env python3
"""One-change adversaries for result-ledger validation."""
import pathlib
import sys


source, target, mutation = map(pathlib.Path, sys.argv[1:])
lines = source.read_text().splitlines()
if mutation.name == "append":
    lines.append("forged")
elif mutation.name == "header":
    lines[0] += "\tforged"
elif mutation.name == "reorder":
    lines[1], lines[2] = lines[2], lines[1]
elif mutation.name == "mode":
    row = lines[1].split("\t"); row[5] = "Z"; lines[1] = "\t".join(row)
elif mutation.name == "work":
    row = lines[2].split("\t"); row[8] = "1,0,0,0,0,0,0,0"; lines[2] = "\t".join(row)
elif mutation.name == "clock":
    row = lines[3].split("\t"); row[10] = "102"; lines[3] = "\t".join(row)
elif mutation.name == "summary":
    row = lines[3].split("\t"); row[11] = "0"; lines[3] = "\t".join(row)
elif mutation.name == "trace":
    row = lines[3].split("\t"); row[12] = "1"; lines[3] = "\t".join(row)
elif mutation.name == "sequence_reads":
    row = lines[3].split("\t"); row[13] = "1"; lines[3] = "\t".join(row)
elif mutation.name == "internal":
    row = lines[1].split("\t"); row[14] = "0.000000000"; lines[1] = "\t".join(row)
elif mutation.name == "external":
    row = lines[1].split("\t"); row[15] = "1.0"; lines[1] = "\t".join(row)
elif mutation.name == "status":
    row = lines[1].split("\t"); row[16] = "7"; lines[1] = "\t".join(row)
elif mutation.name == "eof":
    lines[-1] = "EOF\tforged"
else:
    raise SystemExit("unknown mutation")
target.write_text("\n".join(lines) + "\n")
