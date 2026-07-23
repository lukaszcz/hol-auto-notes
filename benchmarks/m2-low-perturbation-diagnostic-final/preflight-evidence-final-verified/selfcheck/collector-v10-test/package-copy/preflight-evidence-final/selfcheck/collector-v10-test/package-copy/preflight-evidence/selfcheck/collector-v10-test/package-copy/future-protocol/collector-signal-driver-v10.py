#!/usr/bin/env python3
"""Send signals at an exact v10 collector setup/finalization boundary."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


result, work, phase, names, *command = sys.argv[1:]
environment = os.environ.copy()
environment["COLLECT_V10_PAUSE_PHASE"] = phase
process = subprocess.Popen(command, env=environment)
ready = pathlib.Path(work) / "hooks" / (phase + ".ready")
release = pathlib.Path(work) / "hooks" / (phase + ".release")
deadline = time.monotonic() + 20
while not ready.exists():
    if process.poll() is not None:
        raise SystemExit("collector exited before hook")
    if time.monotonic() >= deadline:
        process.kill()
        raise SystemExit("collector hook timeout")
    time.sleep(.005)
for name in names.split(","):
    os.kill(process.pid, getattr(signal, "SIG" + name))
    time.sleep(.02)
release.write_text("release\n")
status = process.wait(timeout=20)
pathlib.Path(result).write_text(json.dumps({"status": status},
                                           sort_keys=True) + "\n")
