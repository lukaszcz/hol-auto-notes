#!/usr/bin/env python3
"""Recursively reject writable package paths and all symlinks."""
import argparse
import os
import pathlib
import stat


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    args = parser.parse_args()
    root = pathlib.Path(args.package).resolve(strict=True)
    failures = []
    paths = [root] + sorted(root.rglob("*"),
                            key=lambda p: p.relative_to(root).as_posix())
    counts = {"directory": 0, "file": 0}
    for path in paths:
        relative = "." if path == root else path.relative_to(root).as_posix()
        info = path.lstat()
        if stat.S_ISLNK(info.st_mode):
            failures.append("symlink\t%s" % relative)
            continue
        kind = "directory" if stat.S_ISDIR(info.st_mode) else "file"
        if kind == "file" and not stat.S_ISREG(info.st_mode):
            failures.append("unsupported\t%s" % relative)
            continue
        counts[kind] += 1
        if info.st_mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
            failures.append("writable\t%s\t%04o" %
                            (relative, stat.S_IMODE(info.st_mode)))
    if failures:
        print("\n".join(failures))
        return 1
    print("recursive_read_only=PASS")
    print("directories=%d" % counts["directory"])
    print("regular_files=%d" % counts["file"])
    print("symlinks=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
