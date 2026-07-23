#!/usr/bin/env python3
"""Retain an exact command/cwd/environment/stdout/stderr/status record."""
import argparse
import json
import os
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--" or len(args.command) == 1:
        parser.error("command must follow --")
    evidence = pathlib.Path(args.evidence)
    evidence.mkdir(parents=True, exist_ok=False)
    cwd = pathlib.Path(args.cwd).resolve(strict=True)
    environment = os.environ.copy()
    declared = {}
    for assignment in args.env:
        if "=" not in assignment:
            parser.error("--env requires KEY=VALUE")
        key, value = assignment.split("=", 1)
        environment[key] = value
        declared[key] = value
    command = args.command[1:]
    (evidence / "command.json").write_text(
        json.dumps(command, ensure_ascii=False) + "\n", encoding="utf-8")
    (evidence / "cwd.txt").write_text(str(cwd) + "\n", encoding="utf-8")
    (evidence / "environment.json").write_text(
        json.dumps(declared, sort_keys=True) + "\n", encoding="utf-8")
    with (evidence / "stdout").open("wb") as stdout, \
            (evidence / "stderr").open("wb") as stderr:
        result = subprocess.run(command, cwd=cwd, env=environment,
                                stdin=subprocess.DEVNULL,
                                stdout=stdout, stderr=stderr)
    (evidence / "status.txt").write_text(
        "%d\n" % result.returncode, encoding="utf-8")
    print("record-command: status=%d" % result.returncode)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
