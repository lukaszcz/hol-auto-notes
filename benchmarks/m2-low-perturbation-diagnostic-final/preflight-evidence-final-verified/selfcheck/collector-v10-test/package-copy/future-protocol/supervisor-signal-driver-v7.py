#!/usr/bin/env python3
"""Queue signals while the v7 supervisor is blocked at its GO commit."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time


result, hook, names, *command = sys.argv[1:]
process = subprocess.Popen(command)
ready = pathlib.Path(hook) / "commit.ready"
release = pathlib.Path(hook) / "commit.release"
deadline = time.monotonic() + 12
while not ready.exists():
    if process.poll() is not None:
        raise SystemExit("supervisor exited before commit hook")
    if time.monotonic() >= deadline:
        process.kill()
        raise SystemExit("supervisor commit hook timeout")
    time.sleep(.005)
for name in names.split(","):
    os.kill(process.pid, getattr(signal, "SIG" + name))
    time.sleep(.02)
release.write_text("release\n")
status = process.wait(timeout=12)
pathlib.Path(result).write_text(json.dumps({"status": status},
                                           sort_keys=True) + "\n")
