#!/usr/bin/env python3
"""Queue signals at an exact v8 supervisor commit boundary."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


result, hook, phase, names, *command = sys.argv[1:]
process = subprocess.Popen(command)
ready = pathlib.Path(hook) / (phase + ".ready")
release = pathlib.Path(hook) / (phase + ".release")
deadline = time.monotonic() + 15
while not ready.exists():
    if process.poll() is not None:
        raise SystemExit("supervisor exited before hook")
    if time.monotonic() >= deadline:
        process.kill()
        raise SystemExit("supervisor hook timeout")
    time.sleep(.005)
for name in names.split(","):
    os.kill(process.pid, getattr(signal, "SIG" + name))
    time.sleep(.02)
release.write_text("release\n")
status = process.wait(timeout=15)
pathlib.Path(result).write_text(json.dumps({"status": status},
                                           sort_keys=True) + "\n")
