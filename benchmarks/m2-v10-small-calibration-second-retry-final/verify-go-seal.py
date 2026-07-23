#!/usr/bin/env python3
"""Cwd-independent, package-scoped GO-seal verifier."""
import argparse
import hashlib
import pathlib
import re


ROW = re.compile(r"([0-9a-f]{64})  (.+)")


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--seal", required=True)
    args = parser.parse_args()
    package = pathlib.Path(args.package).resolve(strict=True)
    seal = pathlib.Path(args.seal).resolve(strict=True)
    if seal.parent != package or seal.name != "GO-SEAL.txt":
        raise SystemExit("verify-go-seal: seal location")
    text = seal.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        raise SystemExit("verify-go-seal: seal EOF")
    seen = set()
    for line in text.splitlines():
        match = ROW.fullmatch(line)
        if match is None:
            raise SystemExit("verify-go-seal: row schema")
        expected, spelling = match.groups()
        relative = pathlib.PurePosixPath(spelling)
        if (relative.is_absolute() or not relative.parts or
                any(part in ("", ".", "..") for part in relative.parts)):
            raise SystemExit("verify-go-seal: unsafe path")
        if spelling in seen:
            raise SystemExit("verify-go-seal: duplicate path")
        seen.add(spelling)
        path = (package / pathlib.Path(*relative.parts)).resolve(strict=True)
        try:
            path.relative_to(package)
        except ValueError:
            raise SystemExit("verify-go-seal: escaping path")
        if not path.is_file() or path.is_symlink():
            raise SystemExit("verify-go-seal: non-regular path")
        if digest(path) != expected:
            raise SystemExit("verify-go-seal: digest mismatch: %s" % spelling)
        print("%s: OK" % spelling)
    if not seen:
        raise SystemExit("verify-go-seal: empty seal")
    print("verify-go-seal: PASS")


if __name__ == "__main__":
    main()
