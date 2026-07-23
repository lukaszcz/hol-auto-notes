#!/usr/bin/env python3
"""Hash every package regular file except the seal itself."""
import argparse
import hashlib
import pathlib


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    package = pathlib.Path(args.package).resolve(strict=True)
    output = pathlib.Path(args.output)
    rows = []
    for path in sorted(package.rglob("*"),
                       key=lambda p: p.relative_to(package).as_posix()):
        relative = path.relative_to(package).as_posix()
        if relative == "GO-SEAL.txt":
            continue
        if path.is_symlink():
            raise SystemExit("make-go-seal: symlink: %s" % relative)
        if path.is_file():
            rows.append("%s  %s\n" % (digest(path), relative))
        elif not path.is_dir():
            raise SystemExit("make-go-seal: unsupported: %s" % relative)
    output.write_text("".join(rows), encoding="utf-8")


if __name__ == "__main__":
    main()
