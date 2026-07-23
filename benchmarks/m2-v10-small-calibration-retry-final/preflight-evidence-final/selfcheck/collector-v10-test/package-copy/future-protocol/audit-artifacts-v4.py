#!/usr/bin/env python3
"""Relocation-safe artifact auditor using shared v4 path validation."""
import argparse
import hashlib
import os
import pathlib
import shutil
import sys

from path_validation_v4 import PathValidationError, validate_paths


ROOT_FILES = (
    "bin/Holmake", "bin/hol", "bin/hol.state0",
    "tools/configure.sml", "tools/smart-configure.sml",
    "tools-poly/configure.sml", "tools-poly/smart-configure.sml",
)
TOOLS = (
    "awk", "basename", "bash", "cat", "cmp", "cp", "date",
    "dirname", "env", "find", "git", "grep", "ln", "mkdir",
    "pgrep", "poly", "readlink", "realpath", "rm", "rmdir", "sed",
    "sha256sum", "sh", "sleep", "sort", "stat", "timeout", "uname",
    "wc",
)


def die(message):
    print("audit-artifacts-v4: %s" % message, file=sys.stderr)
    raise SystemExit(2)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def row(scope, label, path):
    if not path.is_file():
        die("missing regular artifact %s:%s" % (scope, label))
    metadata = path.stat()
    return (scope, label, sha256(path), metadata.st_size,
            metadata.st_mtime_ns)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--package-dir", required=True)
    parser.add_argument("--scratch-root", required=True)
    parser.add_argument("--work", required=True)
    parser.add_argument("--scratch-dir", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        paths = validate_paths(
            root=args.root, package_dir=args.package_dir,
            scratch_root=args.scratch_root, work=args.work,
            tmp=args.scratch_dir, output=args.output)
    except PathValidationError as error:
        die(str(error))

    root = paths["root"]
    package = paths["package_dir"]
    scratch = paths["tmp"]
    output = paths["output"]
    if not scratch.is_dir():
        die("scratch directory is not an existing directory")
    if output.exists():
        die("output already exists")
    if not output.parent.is_dir():
        die("output parent is not an existing directory")

    rows = []
    auto = root / "src/auto"
    if not auto.is_dir():
        die("ROOT lacks src/auto")
    for path in sorted((p for p in auto.rglob("*") if p.is_file()),
                       key=lambda p: p.relative_to(root).as_posix()):
        rows.append(row("root", path.relative_to(root).as_posix(), path))
    for label in ROOT_FILES:
        rows.append(row("root", label, root / label))
    for path in sorted((p for p in package.rglob("*") if p.is_file()),
                       key=lambda p: p.relative_to(package).as_posix()):
        rows.append(row("package", path.relative_to(package).as_posix(),
                        path))
    for name in TOOLS:
        spelling = shutil.which(name)
        if spelling is None:
            die("required tool not found: %s" % name)
        path = pathlib.Path(spelling).resolve(strict=True)
        rows.append(row("tool", "%s=%s" % (name, path), path))

    temporary = scratch / ("artifact-audit-v4.%d.tmp" % os.getpid())
    if temporary.exists():
        die("auditor temporary path already exists")
    try:
        with temporary.open("x", encoding="utf-8", newline="") as stream:
            stream.write("scope\tpath\tsha256\tsize\tmtime_ns\n")
            for values in rows:
                stream.write("%s\t%s\t%s\t%d\t%d\n" % values)
        os.replace(temporary, output)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    main()
