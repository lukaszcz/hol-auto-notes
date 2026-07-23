#!/usr/bin/env python3
"""Exact launcher check and exception-safe disposable v7 containment proof."""
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
EXPECTATIONS = HERE / "UNSHARE_V7.json"


class PreflightUnsupported(RuntimeError):
    def __init__(self, message, provenance):
        super().__init__(message)
        self.provenance = provenance


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


def identity(row):
    return {"pid": row["pid"], "starttime": row["starttime"]}


def pidfd_dead(descriptor):
    poller = select.poll()
    poller.register(descriptor, select.POLLIN)
    return bool(poller.poll(0))


def verify_launcher():
    expected = json.loads(EXPECTATIONS.read_text())
    if set(expected) != {"launcher_path", "launcher_sha256",
                         "launcher_version", "options"}:
        raise RuntimeError("launcher manifest schema mismatch")
    launcher = pathlib.Path(expected["launcher_path"]).resolve(strict=True)
    if str(launcher) != expected["launcher_path"]:
        raise RuntimeError("unshare path mismatch")
    if digest(launcher) != expected["launcher_sha256"]:
        raise RuntimeError("unshare hash mismatch")
    version = subprocess.run([str(launcher), "--version"], check=True,
                             text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT).stdout.strip()
    if version != expected["launcher_version"]:
        raise RuntimeError("unshare version mismatch")
    help_text = subprocess.run([str(launcher), "--help"], check=True,
                               text=True, stdout=subprocess.PIPE).stdout
    required = ("--user", "--map-root-user", "--pid", "--fork",
                "--kill-child", "--mount-proc")
    if expected["options"] != ["--user", "--map-root-user", "--pid",
                               "--fork", "--kill-child=KILL",
                               "--mount-proc"]:
        raise RuntimeError("unshare options mismatch")
    for spelling in required:
        if spelling not in help_text:
            raise RuntimeError("unshare option missing: %s" % spelling)
    return expected


def close_bound(role, descriptor, faults, closes, errors):
    """Close once. Never retry an ambiguous close on a reusable fd number."""
    if descriptor is None:
        closes.append({"role": role, "result": "not_open",
                       "os_exit_will_close": False})
        return
    injected = faults.inject_close("preflight_%s_pidfd_close" % role)
    try:
        os.close(descriptor)
        result = "injected_error_after_close" if injected else "closed"
    except OSError as error:
        result = "error:%s" % error
    if result != "closed":
        errors.append("%s close: %s" % (role, result))
    closes.append({"role": role, "result": result,
                   "os_exit_will_close": result.startswith("error:")})


def proof(directory, faults):
    expected = verify_launcher()
    base = pathlib.Path(directory)
    base.mkdir(parents=True, exist_ok=False)
    ready, go = base / "init.ready", base / "init.go"
    endpoints = base / "fixture.endpoints"
    marker = "v7pf%08x" % (os.getpid() & 0xffffffff)
    command = [expected["launcher_path"], *expected["options"],
               sys.executable, "-B", str(HERE / "namespace-init-v7.py"),
               "--ready", str(ready), "--go", str(go), "--",
               sys.executable, "-B", str(HERE / "process-tree-fixture-v7.py"),
               str(endpoints), marker]
    wrapper = None
    wrapper_fd = None
    init_fd = None
    owned = []
    closes, cleanup_errors, observed = [], [], []
    endpoint_roles = []
    cleanup_cleared = False
    primary = None
    try:
        wrapper = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL,
                                   start_new_session=True)
        wrapper_fd = os.pidfd_open(wrapper.pid, 0)
        wrapper_row = proc_row(wrapper.pid)
        if wrapper_row is None:
            raise RuntimeError("preflight wrapper identity unavailable")
        faults.hit("preflight_after_wrapper")
        deadline = time.monotonic() + 3
        while not ready.exists():
            if wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("namespace init did not publish readiness")
            time.sleep(.005)
        faults.hit("preflight_status")
        ready_row = json.loads(ready.read_text())
        if set(ready_row) != {"namespace_pid", "pid_namespace_inode",
                             "proc_pid_one_present", "protocol_version"}:
            raise RuntimeError("namespace readiness schema mismatch")
        if (ready_row["protocol_version"] != 7 or
                ready_row["namespace_pid"] != 1 or
                not ready_row["proc_pid_one_present"]):
            raise RuntimeError("namespace-local proc/PID-1 proof failed")
        rows = snapshot()
        init_rows = [row for row in rows.values()
                     if row["ppid"] == wrapper.pid]
        if len(init_rows) != 1:
            raise RuntimeError("namespace init host identity not unique")
        init_row = init_rows[0]
        init_fd = os.pidfd_open(init_row["pid"], 0)
        if proc_row(init_row["pid"])["starttime"] != init_row["starttime"]:
            raise RuntimeError("namespace init identity changed")
        faults.hit("preflight_after_init")
        go.write_text("go\n", encoding="ascii")
        while (not endpoints.exists() or
               {line.split(":", 1)[0]
                for line in endpoints.read_text().splitlines()} <
               {"leader", "escape"}):
            if wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("containment fixture did not start")
            time.sleep(.005)
        faults.hit("preflight_signal")
        signal.pidfd_send_signal(init_fd, signal.SIGTERM, None, 0)
        while "signal:" not in endpoints.read_text():
            if time.monotonic() >= deadline:
                raise RuntimeError("fork-on-signal endpoint missing")
            time.sleep(.005)
        faults.hit("preflight_discovery")
        rows = snapshot()
        for pid in descendants(rows, wrapper.pid):
            row = rows[pid]
            observed.append(identity(row))
            if pid not in (wrapper.pid, init_row["pid"]):
                owned.append(("owned", os.pidfd_open(pid, 0)))
        signal.pidfd_send_signal(wrapper_fd, signal.SIGKILL, None, 0)
        wrapper.wait(timeout=3)
        deadline = time.monotonic() + 3
        descriptors = [fd for _role, fd in owned] + [wrapper_fd, init_fd]
        while not all(pidfd_dead(fd) for fd in descriptors):
            if time.monotonic() >= deadline:
                raise RuntimeError("namespace teardown left an exact endpoint")
            time.sleep(.005)
        endpoint_roles = sorted(line.split(":", 1)[0]
                                for line in endpoints.read_text().splitlines())
        if endpoint_roles != ["escape", "leader", "signal"]:
            raise RuntimeError("fixture endpoint ledger mismatch")
        cleanup_cleared = True
    except BaseException as error:
        primary = error
    finally:
        # Identity-bound init and wrapper signals are attempted on every
        # exceptional edge. Numeric PID-only cleanup is never used.
        for role, descriptor in (("init", init_fd),
                                 ("wrapper", wrapper_fd)):
            if descriptor is not None and not pidfd_dead(descriptor):
                try:
                    signal.pidfd_send_signal(descriptor, signal.SIGKILL,
                                             None, 0)
                except ProcessLookupError:
                    pass
                except BaseException as error:
                    cleanup_errors.append("%s cleanup signal: %s" %
                                          (role, error))
        if wrapper is not None:
            try:
                wrapper.wait(timeout=3)
            except subprocess.TimeoutExpired:
                cleanup_errors.append("wrapper reap deadline")
        deadline = time.monotonic() + 3
        bound = [fd for _role, fd in owned]
        bound += [fd for fd in (wrapper_fd, init_fd) if fd is not None]
        while bound and not all(pidfd_dead(fd) for fd in bound):
            if time.monotonic() >= deadline:
                cleanup_errors.append("pidfd teardown proof deadline")
                break
            time.sleep(.005)
        else:
            if wrapper is not None and wrapper.poll() is not None:
                cleanup_cleared = True
        for role, descriptor in owned:
            close_bound(role, descriptor, faults, closes, cleanup_errors)
        close_bound("init", init_fd, faults, closes, cleanup_errors)
        close_bound("wrapper", wrapper_fd, faults, closes, cleanup_errors)

    provenance = {
        "classification": "preflight_supported",
        "cleanup_cleared": cleanup_cleared,
        "cleanup_errors": cleanup_errors,
        "disposable_teardown_proved": bool(
            primary is None and cleanup_cleared and not cleanup_errors),
        "fixture_endpoint_roles": endpoint_roles,
        "launcher_options": expected["options"],
        "launcher_path": expected["launcher_path"],
        "launcher_sha256": expected["launcher_sha256"],
        "launcher_version": expected["launcher_version"],
        "namespace_init_identity_bound": init_fd is not None,
        "observed_identities": observed,
        "pidfd_closes": closes,
        "protocol_version": 7,
    }
    if primary is not None or cleanup_errors or not cleanup_cleared:
        message = ("%s: %s" % (type(primary).__name__, primary)
                   if primary is not None else
                   "preflight cleanup/close proof failed")
        raise PreflightUnsupported(message, provenance)
    return provenance


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scratch", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    # The CLI is diagnostic only. Supervisor supplies its tested fault set.
    class NoFaults:
        def hit(self, _name):
            return None
        def inject_close(self, _name):
            return False
    try:
        row = proof(args.scratch, NoFaults())
        status = 0
    except PreflightUnsupported as error:
        row = {"classification": "preflight_unsupported",
               "diagnostic": str(error), "containment_preflight":
               error.provenance, "disposable_teardown_proved": False,
               "protocol_version": 7}
        status = 125
    except BaseException as error:
        row = {"classification": "preflight_unsupported",
               "diagnostic": "%s: %s" % (type(error).__name__, error),
               "containment_preflight": None,
               "disposable_teardown_proved": False,
               "protocol_version": 7}
        status = 125
    pathlib.Path(args.output).write_text(
        json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
