#!/usr/bin/env python3
"""Versioned, relocation-safe future artifact auditor."""
import argparse
import hashlib
import os
import pathlib
import shutil
import sys


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
    print("audit-artifacts-v3: %s" % message, file=sys.stderr)
    raise SystemExit(2)


def directory(spelling, label):
    try:
        path = pathlib.Path(spelling).resolve(strict=True)
    except OSError:
        die("%s is not an existing path" % label)
    if not path.is_dir():
        die("%s is not a directory" % label)
    return path


def is_strict_descendant(path, parent):
    try:
        relative = path.relative_to(parent)
    except ValueError:
        return False
    return bool(relative.parts)


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
    return (scope, label, sha256(path), metadata.st_size, metadata.st_mtime_ns)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--package-dir", required=True)
    parser.add_argument("--scratch-root", required=True)
    parser.add_argument("--scratch-dir", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    root = directory(args.root, "ROOT")
    package = directory(args.package_dir, "PACKAGE_DIR")
    scratch_root = directory(args.scratch_root, "scratch root")
    scratch = directory(args.scratch_dir, "scratch directory")
    if not is_strict_descendant(scratch, scratch_root):
        die("scratch directory must be a strict descendant of scratch root")
    output = pathlib.Path(args.output)
    if not output.is_absolute():
        output = pathlib.Path.cwd() / output
    try:
        output = output.resolve(strict=False)
    except OSError:
        die("cannot resolve output")
    if not is_strict_descendant(output, scratch_root):
        die("output must be below scratch root")
    if output.exists():
        die("output already exists")
    if not output.parent.is_dir():
        die("output parent is not an existing directory")
    if output.parent.is_symlink():
        die("output parent must not be a symlink")

    rows = []
    auto = root / "src/auto"
    if not auto.is_dir():
        die("ROOT lacks src/auto")
    for path in sorted((p for p in auto.rglob("*") if p.is_file()),
                       key=lambda p: p.relative_to(root).as_posix()):
        label = path.relative_to(root).as_posix()
        rows.append(row("root", label, path))
    for label in ROOT_FILES:
        rows.append(row("root", label, root / label))
    for path in sorted((p for p in package.rglob("*") if p.is_file()),
                       key=lambda p: p.relative_to(package).as_posix()):
        label = path.relative_to(package).as_posix()
        rows.append(row("package", label, path))
    for name in TOOLS:
        spelling = shutil.which(name)
        if spelling is None:
            die("required tool not found: %s" % name)
        path = pathlib.Path(spelling).resolve(strict=True)
        rows.append(row("tool", "%s=%s" % (name, path), path))

    temporary = scratch / ("artifact-audit.%d.tmp" % os.getpid())
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
