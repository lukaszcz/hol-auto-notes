#!/usr/bin/env python3
"""Drive outer collector signals without shell background-signal masking."""
import json
import os
import signal
import subprocess
import sys
import time


result, work, pidfile, signal_name, repeats, *command = sys.argv[1:]
started = time.monotonic()
process = subprocess.Popen(command, env=os.environ.copy())
deadline = started + 5
while (not os.path.exists(pidfile) or os.path.getsize(pidfile) == 0 or
       not os.path.exists(os.path.join(work, "finalization-order.txt"))):
    if process.poll() is not None:
        raise SystemExit("collector exited before signal fixture started")
    if time.monotonic() >= deadline:
        process.kill()
        raise SystemExit("collector signal fixture did not start")
    time.sleep(.01)
number = getattr(signal, "SIG" + signal_name)
os.kill(process.pid, number)
for _ in range(1, int(repeats)):
    time.sleep(.03)
    try:
        os.kill(process.pid, number)
    except ProcessLookupError:
        break
try:
    status = process.wait(timeout=5)
except subprocess.TimeoutExpired:
    process.kill()
    process.wait()
    raise SystemExit("collector did not finish bounded cleanup")
with open(result, "x", encoding="utf-8") as stream:
    json.dump({"status": status, "elapsed": time.monotonic() - started},
              stream, sort_keys=True)
    stream.write("\n")
