#!/usr/bin/env python3
"""Typed, symlink-aware deterministic package inventory."""
import argparse
import hashlib
import os
import pathlib


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root")
    parser.add_argument("output")
    parser.add_argument("--exclude", action="append", default=[])
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve()
    output = pathlib.Path(args.output)
    excluded = set(args.exclude)
    rows = ["type\tpath\tsha256_or_target\tsize\n"]
    paths = sorted(root.rglob("*"), key=lambda p: p.relative_to(root).as_posix())
    for path in paths:
        relative = path.relative_to(root).as_posix()
        if relative in excluded:
            continue
        if path.is_symlink():
            rows.append("symlink\t%s\t%s\t%d\n" %
                        (relative, os.readlink(path), len(os.readlink(path))))
        elif path.is_file():
            rows.append("file\t%s\t%s\t%d\n" %
                        (relative, digest(path), path.stat().st_size))
        elif path.is_dir():
            rows.append("directory\t%s\t-\t0\n" % relative)
        else:
            raise SystemExit("inventory: unsupported type %s" % relative)
    output.write_text("".join(rows), encoding="utf-8")


if __name__ == "__main__":
    main()
