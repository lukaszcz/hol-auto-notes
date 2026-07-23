#!/usr/bin/env python3
"""Shared realpath/disjointness validation for future protocol v4."""
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
        raise PathValidationError(
            "cannot resolve %s: %s" % (label, error)) from error

    probe = path
    while not probe.exists() and not probe.is_symlink():
        if probe.parent == probe:
            raise PathValidationError("%s has no existing parent" % label)
        probe = probe.parent
    try:
        parent = probe.resolve(strict=True)
    except OSError as error:
        raise PathValidationError(
            "cannot resolve existing parent of %s: %s" %
            (label, error)) from error
    if not parent.is_dir() and probe != path:
        raise PathValidationError(
            "existing parent of %s is not a directory" % label)
    return resolved


def _beneath(path: pathlib.Path, parent: pathlib.Path) -> bool:
    try:
        relative = path.relative_to(parent)
    except ValueError:
        return False
    return bool(relative.parts)


def _overlap(left: pathlib.Path, right: pathlib.Path) -> bool:
    return left == right or _beneath(left, right) or _beneath(right, left)


def validate_paths(*, root: str, package_dir: str, scratch_root: str,
                   work: str, tmp: str, output: str) -> dict[str, pathlib.Path]:
    """Resolve and validate the complete v4 mutable path closure.

    The scratch root may also contain a copied package, provided that the
    copied package and the mutable work closure are disjoint siblings.
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
        if not _beneath(values[label], scratch):
            raise PathValidationError(
                "%s must be a strict descendant of SCRATCH_ROOT" % label)
        for protected in ("root", "package_dir"):
            if _overlap(values[label], values[protected]):
                raise PathValidationError(
                    "%s overlaps %s" % (label, protected.upper()))
    if not _beneath(values["tmp"], values["work"]):
        raise PathValidationError("tmp must be below work")
    if not _beneath(values["output"], values["work"]):
        raise PathValidationError("output must be below work")
    if _overlap(values["tmp"], values["output"]):
        raise PathValidationError("tmp and output must be disjoint")
    return values
