#!/usr/bin/env python3
"""Create the frozen pre-GO input closure without self-reference."""
import argparse
import hashlib
import pathlib


EXCLUDED = {
    "ARTIFACT-REFERENCE.tsv",
    "GO-SEAL.txt",
    "INPUT-MANIFEST.tsv",
}


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve(strict=True)
    package = pathlib.Path(args.package).resolve(strict=True)
    rows = ["scope\tpath\tsha256\tsize\n"]
    for path in sorted((p for p in (root / "src/auto").rglob("*")
                        if p.is_file()),
                       key=lambda p: p.relative_to(root).as_posix()):
        rows.append("root\t%s\t%s\t%d\n" %
                    (path.relative_to(root).as_posix(), digest(path),
                     path.stat().st_size))
    for relative in ("bin/Holmake", "bin/hol", "bin/hol.state0",
                     "tools/configure.sml", "tools/smart-configure.sml",
                     "tools-poly/configure.sml",
                     "tools-poly/smart-configure.sml"):
        path = root / relative
        rows.append("root\t%s\t%s\t%d\n" %
                    (relative, digest(path), path.stat().st_size))
    for path in sorted((p for p in package.rglob("*") if p.is_file() and
                        p.relative_to(package).as_posix() not in EXCLUDED),
                       key=lambda p: p.relative_to(package).as_posix()):
        rows.append("package\t%s\t%s\t%d\n" %
                    (path.relative_to(package).as_posix(), digest(path),
                     path.stat().st_size))
    pathlib.Path(args.output).write_text("".join(rows), encoding="utf-8")


if __name__ == "__main__":
    main()
