#!/usr/bin/env python3
"""Pinned launcher check plus atomically-owned v8 disposable proof."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import pathlib
import select
import signal
import subprocess
import sys
import time


HERE = pathlib.Path(__file__).resolve().parent
EXPECTATIONS = HERE / "UNSHARE_V8.json"


def load_bootstrap():
    path = HERE / "launch_bootstrap_v8.py"
    spec = importlib.util.spec_from_file_location("launch_bootstrap_v8", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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
                         "launcher_version", "options",
                         "protocol_version"}:
        raise RuntimeError("launcher manifest schema mismatch")
    if expected["protocol_version"] != 8:
        raise RuntimeError("launcher manifest version mismatch")
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
    if expected["options"] != ["--user", "--map-root-user", "--pid",
                               "--fork", "--kill-child=KILL",
                               "--mount-proc"]:
        raise RuntimeError("unshare options mismatch")
    help_text = subprocess.run([str(launcher), "--help"], check=True,
                               text=True,
                               stdout=subprocess.PIPE).stdout
    for spelling in ("--user", "--map-root-user", "--pid", "--fork",
                     "--kill-child", "--mount-proc"):
        if spelling not in help_text:
            raise RuntimeError("unshare option missing: %s" % spelling)
    return expected


def close_bound(role, descriptor, faults, closes, errors):
    if descriptor is None:
        closes.append({"os_exit_will_close": False, "result": "not_open",
                       "role": role})
        return
    injected = faults.inject_close("preflight_%s_pidfd_close" % role)
    try:
        os.close(descriptor)
        result = "injected_error_after_close" if injected else "closed"
    except OSError as error:
        result = "error:%s" % error
    will_close = result.startswith("error:")
    if result != "closed":
        errors.append("%s close: %s" % (role, result))
    closes.append({"os_exit_will_close": will_close, "result": result,
                   "role": role})


def proof(directory, faults):
    expected = verify_launcher()
    bootstrap = load_bootstrap()
    base = pathlib.Path(directory)
    base.mkdir(parents=True, exist_ok=False)
    ready, go = base / "init.ready", base / "init.go"
    endpoints = base / "fixture.endpoints"
    marker = "v8pf%08x" % (os.getpid() & 0xffffffff)
    exec_vector = [
        expected["launcher_path"], *expected["options"],
        sys.executable, "-B", str(HERE / "namespace-init-v8.py"),
        "--ready", str(ready), "--go", str(go), "--",
        sys.executable, "-B", str(HERE / "process-tree-fixture-v7.py"),
        str(endpoints), marker]
    wrapper = None
    wrapper_fd = init_fd = gate_write = None
    owned = []
    closes, errors, observed = [], [], []
    endpoint_roles = []
    cleanup_cleared = False
    primary = None
    gate = {
        "bootstrap_program": str(HERE / "launch-gate-v8.py"),
        "full_launch_vector": bootstrap.full_vector(exec_vector),
        "gate_child_had_no_descendants_before_go": False,
        "go_sent_only_after_pidfd_bound": False,
        "pidfd_bound_before_go": False,
        "same_pid_and_pidfd_after_exec": False,
        "unshare_exec_permitted_before_pidfd": False,
    }
    try:
        clean_environment = os.environ.copy()
        clean_environment.pop("LAUNCH_GATE_V8_INJECT", None)
        clean_environment.pop("LAUNCH_GATE_V8_MARKER", None)
        wrapper, wrapper_fd, gate_write, invocation = bootstrap.spawn_bound(
            exec_vector, cwd=str(base), stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, faults=faults,
            environment=clean_environment)
        gate["full_launch_vector"] = invocation
        gate["pidfd_bound_before_go"] = True
        rows = snapshot()
        gate["gate_child_had_no_descendants_before_go"] = (
            descendants(rows, wrapper.pid) == [wrapper.pid])
        if not gate["gate_child_had_no_descendants_before_go"]:
            raise RuntimeError("bootstrap created a pre-GO descendant")
        faults.hit("preflight_after_gate_bind")
        wrapper_row = proc_row(wrapper.pid)
        if wrapper_row is None:
            raise RuntimeError("gate identity unavailable")
        bootstrap.commit_go(gate_write)
        gate_write = None
        gate["go_sent_only_after_pidfd_bound"] = True
        deadline = time.monotonic() + 3
        while not ready.exists():
            if wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("namespace init did not publish readiness")
            time.sleep(.005)
        rows = snapshot()
        current = rows.get(wrapper.pid)
        gate["same_pid_and_pidfd_after_exec"] = bool(
            current and current["starttime"] == wrapper_row["starttime"])
        if not gate["same_pid_and_pidfd_after_exec"]:
            raise RuntimeError("gate/unshare identity changed")
        ready_row = json.loads(ready.read_text())
        if (set(ready_row) != {"namespace_pid", "pid_namespace_inode",
                               "proc_pid_one_present", "protocol_version"}
                or ready_row["protocol_version"] != 8
                or ready_row["namespace_pid"] != 1
                or ready_row["proc_pid_one_present"] is not True):
            raise RuntimeError("namespace readiness semantics")
        init_rows = [row for row in rows.values()
                     if row["ppid"] == wrapper.pid]
        if len(init_rows) != 1:
            raise RuntimeError("namespace init host identity not unique")
        init_row = init_rows[0]
        init_fd = os.pidfd_open(init_row["pid"], 0)
        faults.hit("preflight_after_init")
        go.write_text("go\n", encoding="ascii")
        while (not endpoints.exists() or
               {line.split(":", 1)[0]
                for line in endpoints.read_text().splitlines()} <
               {"leader", "escape"}):
            if wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("containment fixture did not start")
            time.sleep(.005)
        signal.pidfd_send_signal(init_fd, signal.SIGTERM, None, 0)
        while "signal:" not in endpoints.read_text():
            if time.monotonic() >= deadline:
                raise RuntimeError("fork-on-signal endpoint missing")
            time.sleep(.005)
        rows = snapshot()
        for pid in descendants(rows, wrapper.pid):
            row = rows[pid]
            observed.append(identity(row))
            if pid not in (wrapper.pid, init_row["pid"]):
                owned.append(("owned", os.pidfd_open(pid, 0)))
        signal.pidfd_send_signal(wrapper_fd, signal.SIGKILL, None, 0)
        wrapper.wait(timeout=3)
        deadline = time.monotonic() + 3
        bound = [fd for _role, fd in owned] + [wrapper_fd, init_fd]
        while not all(pidfd_dead(fd) for fd in bound):
            if time.monotonic() >= deadline:
                raise RuntimeError("namespace teardown left endpoint")
            time.sleep(.005)
        endpoint_roles = sorted(line.split(":", 1)[0]
                                for line in endpoints.read_text().splitlines())
        if endpoint_roles != ["escape", "leader", "signal"]:
            raise RuntimeError("fixture endpoint ledger mismatch")
        cleanup_cleared = True
    except BaseException as error:
        primary = error
        if hasattr(error, "proof"):
            gate.update(error.proof)
    finally:
        if gate_write is not None:
            os.close(gate_write)
        for descriptor in (init_fd, wrapper_fd):
            if descriptor is not None and not pidfd_dead(descriptor):
                try:
                    signal.pidfd_send_signal(descriptor, signal.SIGKILL,
                                             None, 0)
                except ProcessLookupError:
                    pass
                except BaseException as error:
                    errors.append("bound cleanup signal: %s" % error)
        if wrapper is not None:
            try:
                wrapper.wait(timeout=3)
            except subprocess.TimeoutExpired:
                errors.append("wrapper reap deadline")
        bound = [fd for _role, fd in owned]
        bound += [fd for fd in (wrapper_fd, init_fd) if fd is not None]
        deadline = time.monotonic() + 3
        while bound and not all(pidfd_dead(fd) for fd in bound):
            if time.monotonic() >= deadline:
                errors.append("pidfd teardown proof deadline")
                break
            time.sleep(.005)
        else:
            if wrapper is not None and wrapper.poll() is not None:
                cleanup_cleared = True
        for role, descriptor in owned:
            close_bound(role, descriptor, faults, closes, errors)
        close_bound("init", init_fd, faults, closes, errors)
        close_bound("wrapper", wrapper_fd, faults, closes, errors)

    provenance = {
        "bootstrap_ownership": gate,
        "classification": "preflight_supported",
        "cleanup_cleared": cleanup_cleared,
        "cleanup_errors": errors,
        "disposable_teardown_proved": bool(
            primary is None and cleanup_cleared and not errors),
        "fixture_endpoint_roles": endpoint_roles,
        "launcher_options": expected["options"],
        "launcher_path": expected["launcher_path"],
        "launcher_sha256": expected["launcher_sha256"],
        "launcher_version": expected["launcher_version"],
        "namespace_init_identity_bound": init_fd is not None,
        "observed_identities": observed,
        "pidfd_closes": closes,
        "protocol_version": 8,
    }
    if primary is not None or errors or not cleanup_cleared:
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
               "containment_preflight": error.provenance,
               "diagnostic": str(error),
               "disposable_teardown_proved": False,
               "protocol_version": 8}
        status = 125
    pathlib.Path(args.output).write_text(
        json.dumps(row, sort_keys=True) + "\n", encoding="utf-8")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
