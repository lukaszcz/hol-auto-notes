#!/usr/bin/env python3
"""CLI for the shared future-protocol-v4 path validator."""
import argparse
import json
import sys

from path_validation_v4 import PathValidationError, validate_paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--package-dir", required=True)
    parser.add_argument("--scratch-root", required=True)
    parser.add_argument("--work", required=True)
    parser.add_argument("--tmp", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        values = validate_paths(**vars(args))
    except PathValidationError as error:
        print("validate-paths-v4: %s" % error, file=sys.stderr)
        return 2
    print(json.dumps({name: str(path) for name, path in values.items()},
                     sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
