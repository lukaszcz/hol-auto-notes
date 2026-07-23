#!/usr/bin/env python3
"""Inject collector signals at one exact v5 lifecycle phase."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


result, work, phase, signal_names, *command = sys.argv[1:]
environment = os.environ.copy()
environment["COLLECT_V5_PAUSE_PHASE"] = phase
started = time.monotonic()
process = subprocess.Popen(command, env=environment)
ready = pathlib.Path(work) / "hooks" / (phase + ".ready")
release = pathlib.Path(work) / "hooks" / (phase + ".release")
deadline = started + 5
while not ready.exists():
    if process.poll() is not None:
        raise SystemExit("collector exited before %s hook" % phase)
    if time.monotonic() >= deadline:
        process.kill()
        raise SystemExit("collector phase hook did not start: %s" % phase)
    time.sleep(.005)
wait_file = os.environ.get("COLLECT_V5_WAIT_FILE")
if wait_file:
    waited = pathlib.Path(wait_file)
    while not waited.exists() or waited.stat().st_size == 0:
        if process.poll() is not None:
            raise SystemExit("collector exited before child fixture started")
        if time.monotonic() >= deadline:
            process.kill()
            raise SystemExit("collector child fixture did not start")
        time.sleep(.005)
for name in signal_names.split(","):
    os.kill(process.pid, getattr(signal, "SIG" + name))
    time.sleep(.02)
release.write_text("release\n")
try:
    status = process.wait(timeout=6)
except subprocess.TimeoutExpired:
    process.kill()
    process.wait()
    raise SystemExit("collector did not finish bounded finalization")
with open(result, "x", encoding="utf-8") as stream:
    json.dump({"status": status, "elapsed": time.monotonic() - started},
              stream, sort_keys=True)
    stream.write("\n")
