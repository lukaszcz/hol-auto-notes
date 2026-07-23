#!/usr/bin/env python3
"""V8 exec gate: read one GO byte before creating any descendant."""
from __future__ import annotations

import os
import pathlib
import sys
import time


PROTOCOL_VERSION = 8


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) < 2 or argv[0] != "--":
        print("launch-gate-v8: exec vector must follow --", file=sys.stderr)
        return 125
    if os.environ.get("LAUNCH_GATE_V8_MARKER"):
        # This marker means only that the tiny, descendant-free gate exists.
        pathlib.Path(os.environ["LAUNCH_GATE_V8_MARKER"]).write_text(
            "gate-ready\n", encoding="ascii")
    if os.environ.get("LAUNCH_GATE_V8_INJECT") == "slow":
        time.sleep(.2)
    if os.environ.get("LAUNCH_GATE_V8_INJECT") == "stuck":
        while True:
            time.sleep(1)
    while True:
        try:
            token = os.read(0, 1)
            break
        except InterruptedError:
            continue
    if token != b"G":
        return 125
    if os.environ.get("LAUNCH_GATE_V8_INJECT") == "exec_failure":
        argv[1] = "/v8/injected/exec/failure"
    os.execv(argv[1], argv[1:])
    return 125


if __name__ == "__main__":
    raise SystemExit(main())
