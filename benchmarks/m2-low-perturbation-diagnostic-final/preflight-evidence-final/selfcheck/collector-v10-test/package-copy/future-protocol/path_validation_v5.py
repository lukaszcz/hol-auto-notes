#!/usr/bin/env python3
"""Exact mutable/protected path policy for future protocol v5."""
from __future__ import annotations

import pathlib


class PathValidationError(ValueError):
    pass


def _existing_directory(spelling: str, label: str) -> pathlib.Path:
    try:
        path = pathlib.Path(spelling).resolve(strict=True)
    except OSError as error:
        raise PathValidationError(
            "%s is not an existing path: %s" % (label, error)) from error
    if not path.is_dir():
        raise PathValidationError("%s is not a directory" % label)
    return path


def _prospective(spelling: str, label: str) -> pathlib.Path:
    path = pathlib.Path(spelling)
    if not path.is_absolute():
        path = pathlib.Path.cwd() / path
    try:
        resolved = path.resolve(strict=False)
    except OSError as error:
        raise PathValidationError("cannot resolve %s: %s" %
                                  (label, error)) from error
    probe = path
    while not probe.exists() and not probe.is_symlink():
        if probe.parent == probe:
            raise PathValidationError("%s has no existing parent" % label)
        probe = probe.parent
    try:
        existing = probe.resolve(strict=True)
    except OSError as error:
        raise PathValidationError(
            "cannot resolve existing parent of %s: %s" %
            (label, error)) from error
    if not existing.is_dir() and probe != path:
        raise PathValidationError(
            "existing parent of %s is not a directory" % label)
    return resolved


def _strict_beneath(path: pathlib.Path, parent: pathlib.Path) -> bool:
    try:
        relative = path.relative_to(parent)
    except ValueError:
        return False
    return bool(relative.parts)


def _overlap(left: pathlib.Path, right: pathlib.Path) -> bool:
    return (left == right or _strict_beneath(left, right) or
            _strict_beneath(right, left))


def validate_paths(*, root: str, package_dir: str, scratch_root: str,
                   work: str, tmp: str, output: str) -> dict[str, pathlib.Path]:
    """Validate exactly the v5 protected and mutable path relationships.

    PACKAGE_DIR may be the canonical package beneath ROOT, or a copied package
    elsewhere. ROOT and PACKAGE_DIR are therefore intentionally allowed to
    overlap each other. Every mutable work/tmp/output path is resolved through
    symlinks and must be strictly below SCRATCH_ROOT while being disjoint from
    both protected trees: it may not equal, contain, or be contained by either.
    """
    values = {
        "root": _existing_directory(root, "ROOT"),
        "package_dir": _existing_directory(package_dir, "PACKAGE_DIR"),
        "scratch_root": _existing_directory(scratch_root, "SCRATCH_ROOT"),
        "work": _prospective(work, "work"),
        "tmp": _prospective(tmp, "tmp"),
        "output": _prospective(output, "output"),
    }
    scratch = values["scratch_root"]
    for label in ("work", "tmp", "output"):
        path = values[label]
        if not _strict_beneath(path, scratch):
            raise PathValidationError(
                "%s must be a strict descendant of SCRATCH_ROOT" % label)
        for protected in ("root", "package_dir"):
            if _overlap(path, values[protected]):
                raise PathValidationError(
                    "%s overlaps %s" % (label, protected.upper()))
    if not _strict_beneath(values["tmp"], values["work"]):
        raise PathValidationError("tmp must be below work")
    if not _strict_beneath(values["output"], values["work"]):
        raise PathValidationError("output must be below work")
    if _overlap(values["tmp"], values["output"]):
        raise PathValidationError("tmp and output must be disjoint")
    return values
