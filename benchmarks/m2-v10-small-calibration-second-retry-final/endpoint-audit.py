#!/usr/bin/env python3
"""Exact /proc audit for the task7m executable/module identities."""
import argparse
import pathlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    package = pathlib.Path(__file__).resolve().parent
    executable = str(package / "task7mcalibration.exe").encode()
    module = str(package / "task7mcalibration").encode()
    matches = []
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            argv = (entry / "cmdline").read_bytes().split(b"\0")
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        if executable in argv or module in argv:
            matches.append("%s\t%s" %
                           (entry.name,
                            " ".join(item.decode("utf-8", "replace")
                                     for item in argv if item)))
    text = "matches=none\n" if not matches else "\n".join(matches) + "\n"
    pathlib.Path(args.output).write_text(text, encoding="utf-8")
    return 0 if not matches else 1


if __name__ == "__main__":
    raise SystemExit(main())
