#!/usr/bin/env python3
"""Inject one or more signals at an exact collector v6 phase."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


result, work, phase, names, *command = sys.argv[1:]
environment = os.environ.copy()
environment["COLLECT_V6_PAUSE_PHASE"] = phase
started = time.monotonic()
process = subprocess.Popen(command, env=environment)
ready = pathlib.Path(work) / "hooks" / (phase + ".ready")
release = pathlib.Path(work) / "hooks" / (phase + ".release")
deadline = started + 8
while not ready.exists():
    if process.poll() is not None:
        raise SystemExit("collector exited before phase hook")
    if time.monotonic() >= deadline:
        process.kill()
        raise SystemExit("collector phase hook timeout")
    time.sleep(.005)
wait_file = os.environ.get("COLLECT_V6_WAIT_FILE")
if wait_file:
    target = pathlib.Path(wait_file)
    while not target.exists() or target.stat().st_size == 0:
        if process.poll() is not None or time.monotonic() >= deadline:
            process.kill()
            raise SystemExit("fixture readiness timeout")
        time.sleep(.005)
for name in names.split(","):
    os.kill(process.pid, getattr(signal, "SIG" + name))
    time.sleep(.02)
release.write_text("release\n")
status = process.wait(timeout=8)
pathlib.Path(result).write_text(json.dumps({
    "status": status, "elapsed": time.monotonic() - started},
    sort_keys=True) + "\n")
