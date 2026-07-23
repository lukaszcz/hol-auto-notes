#!/usr/bin/env python3
"""No-benchmark exact-launcher and disposable namespace teardown proof."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import select
import signal
import subprocess
import sys
import time


HERE = pathlib.Path(__file__).resolve().parent
EXPECTATIONS = HERE / "UNSHARE_V6.json"


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def proc_row(pid):
    try:
        text = pathlib.Path("/proc/%d/stat" % pid).read_text(encoding="ascii")
    except (FileNotFoundError, ProcessLookupError):
        return None
    close = text.rfind(")")
    fields = text[close + 2:].split() if close >= 0 else []
    if len(fields) < 20:
        return None
    return {"pid": pid, "ppid": int(fields[1]), "pgid": int(fields[2]),
            "sid": int(fields[3]), "starttime": int(fields[19])}


def snapshot():
    rows = {}
    with os.scandir("/proc") as entries:
        for entry in entries:
            if entry.name.isdigit():
                row = proc_row(int(entry.name))
                if row:
                    rows[row["pid"]] = row
    return rows


def descendants(rows, root):
    found = {root}
    changed = True
    while changed:
        changed = False
        for pid, row in rows.items():
            if pid not in found and row["ppid"] in found:
                found.add(pid)
                changed = True
    return sorted(found)


def pidfd_dead(descriptor):
    poller = select.poll()
    poller.register(descriptor, select.POLLIN)
    return bool(poller.poll(0))


def verify_launcher():
    expected = json.loads(EXPECTATIONS.read_text())
    launcher = pathlib.Path(expected["launcher_path"]).resolve(strict=True)
    if str(launcher) != expected["launcher_path"]:
        raise RuntimeError("unshare path mismatch")
    actual_hash = digest(launcher)
    if actual_hash != expected["launcher_sha256"]:
        raise RuntimeError("unshare hash mismatch")
    version = subprocess.run([str(launcher), "--version"], check=True,
                             text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT).stdout.strip()
    if version != expected["launcher_version"]:
        raise RuntimeError("unshare version mismatch")
    help_text = subprocess.run([str(launcher), "--help"], check=True,
                               text=True, stdout=subprocess.PIPE).stdout
    for spelling in ("--user", "--map-root-user", "--pid", "--fork",
                     "--kill-child", "--mount-proc"):
        if spelling not in help_text:
            raise RuntimeError("unshare option missing: %s" % spelling)
    return expected


def proof(directory):
    expected = verify_launcher()
    base = pathlib.Path(directory)
    base.mkdir(parents=True, exist_ok=False)
    ready, go = base / "init.ready", base / "init.go"
    endpoints = base / "fixture.endpoints"
    marker = "v6pf%08x" % (os.getpid() & 0xffffffff)
    command = [expected["launcher_path"], *expected["options"],
               sys.executable, "-B", str(HERE / "namespace-init-v6.py"),
               "--ready", str(ready), "--go", str(go), "--",
               sys.executable, "-B", str(HERE / "process-tree-fixture-v6.py"),
               str(endpoints), marker]
    wrapper = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL,
                               start_new_session=True)
    descriptors = {}
    identities = []
    try:
        descriptors[wrapper.pid] = os.pidfd_open(wrapper.pid, 0)
        deadline = time.monotonic() + 3
        while not ready.exists():
            if wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("namespace init did not publish readiness")
            time.sleep(.005)
        ready_row = json.loads(ready.read_text())
        if ready_row.get("namespace_pid") != 1 or not ready_row.get(
                "proc_pid_one_present"):
            raise RuntimeError("namespace-local proc/PID-1 proof failed")
        go.write_text("go\n")
        while (not endpoints.exists() or
               {line.split(":", 1)[0] for line in endpoints.read_text().splitlines()}
               < {"leader", "escape"}):
            if wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("containment fixture did not start")
            time.sleep(.005)
        rows = snapshot()
        pids = descendants(rows, wrapper.pid)
        init_pids = [pid for pid in pids if rows[pid]["ppid"] == wrapper.pid]
        if len(init_pids) != 1:
            raise RuntimeError("namespace init host identity not unique")
        init_pid = init_pids[0]
        init_signal_fd = os.pidfd_open(init_pid, 0)
        try:
            signal.pidfd_send_signal(init_signal_fd, signal.SIGTERM, None, 0)
        finally:
            os.close(init_signal_fd)
        while "signal:" not in endpoints.read_text():
            if time.monotonic() >= deadline:
                raise RuntimeError("fork-on-signal endpoint missing")
            time.sleep(.005)
        rows = snapshot()
        pids = descendants(rows, wrapper.pid)
        for pid in pids:
            row = rows[pid]
            identities.append({"pid": pid, "starttime": row["starttime"]})
            if pid not in descriptors:
                descriptors[pid] = os.pidfd_open(pid, 0)
        signal.pidfd_send_signal(descriptors[wrapper.pid], signal.SIGKILL,
                                 None, 0)
        wrapper.wait(timeout=3)
        deadline = time.monotonic() + 3
        while not all(pidfd_dead(fd) for fd in descriptors.values()):
            if time.monotonic() >= deadline:
                raise RuntimeError("namespace teardown left an exact endpoint")
            time.sleep(.005)
        endpoint_roles = sorted(line.split(":", 1)[0]
                                for line in endpoints.read_text().splitlines())
        if endpoint_roles != ["escape", "leader", "signal"]:
            raise RuntimeError("fixture endpoint ledger mismatch")
        return {
            "classification": "preflight_supported",
            "disposable_teardown_proved": True,
            "fixture_endpoint_roles": endpoint_roles,
            "launcher_path": expected["launcher_path"],
            "launcher_sha256": expected["launcher_sha256"],
            "launcher_version": expected["launcher_version"],
            "launcher_options": expected["options"],
            "namespace_init_identity_bound": True,
            "observed_identities": identities,
            "protocol_version": 6,
        }
    finally:
        if wrapper.poll() is None:
            try:
                os.kill(wrapper.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                wrapper.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
        for descriptor in descriptors.values():
            try:
                os.close(descriptor)
            except OSError:
                pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scratch", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        row = proof(args.scratch)
        status = 0
    except BaseException as error:
        row = {"classification": "preflight_unsupported",
               "diagnostic": "%s: %s" % (type(error).__name__, error),
               "disposable_teardown_proved": False,
               "protocol_version": 6}
        status = 125
    pathlib.Path(args.output).write_text(
        json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
