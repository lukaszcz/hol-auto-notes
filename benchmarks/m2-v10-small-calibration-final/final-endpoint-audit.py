#!/usr/bin/env python3
"""Non-self-matching final task7k process endpoint audit."""
import pathlib


needles = (b"/task7kcalibration.exe", b"task7kcalibration.uo",
           b"bin/hol task7kcalibration")
matches = []
for entry in pathlib.Path("/proc").iterdir():
    if not entry.name.isdigit():
        continue
    try:
        command = (entry / "cmdline").read_bytes().replace(b"\0", b" ")
    except (FileNotFoundError, PermissionError, ProcessLookupError):
        continue
    if any(needle in command for needle in needles):
        matches.append("%s %s" %
                       (entry.name, command.decode("utf-8", "replace")))
if matches:
    print("\n".join(matches))
    raise SystemExit(1)
print("matches=none")
