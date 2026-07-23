#!/usr/bin/env python3
"""Future v6 collector with sealed containment provenance."""
from __future__ import annotations

import datetime
import hashlib
import json
import os
import pathlib
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from path_validation_v5 import PathValidationError, validate_paths


HANDLED = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
SIGNAL_STATUS = {signal.SIGHUP: 129, signal.SIGINT: 130,
                 signal.SIGTERM: 143}


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def atomic_text(path, text):
    temporary = path.with_name(path.name + ".tmp.%d" % os.getpid())
    with temporary.open("x", encoding="utf-8") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def shell_status(value):
    return value if value >= 0 else 128 + (-value)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) < 2 or argv[0] != "--":
        print("collect-v6: command must follow --", file=sys.stderr)
        return 2
    required = ("ROOT", "PACKAGE_DIR", "SCRATCH_ROOT", "SCRATCH_DIR",
                "ENDPOINT_PATTERN", "ARTIFACT_REFERENCE")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        print("collect-v6: missing %s" % ",".join(missing), file=sys.stderr)
        return 2
    try:
        reference = pathlib.Path(os.environ["ARTIFACT_REFERENCE"]).resolve(
            strict=True)
        work_input = pathlib.Path(os.environ["SCRATCH_DIR"])
        if not work_input.is_absolute():
            work_input = pathlib.Path.cwd() / work_input
        paths = validate_paths(
            root=os.environ["ROOT"], package_dir=os.environ["PACKAGE_DIR"],
            scratch_root=os.environ["SCRATCH_ROOT"], work=str(work_input),
            tmp=str(work_input / "tmp"),
            output=str(work_input / "audits/final-artifacts.tsv"))
    except (OSError, PathValidationError) as error:
        print("collect-v6: %s" % error, file=sys.stderr)
        return 2
    root, package = paths["root"], paths["package_dir"]
    scratch_root, work = paths["scratch_root"], paths["work"]
    tmp, artifact_output = paths["tmp"], paths["output"]
    if work.exists():
        print("collect-v6: scratch exists", file=sys.stderr)
        return 2
    for path in (work / "raw", work / "audits", tmp, work / "hooks"):
        path.mkdir(parents=True, exist_ok=True)

    phase = "before_supervisor_launch"
    events, first_requested = [], None
    supervisor, supervisor_ready = None, False
    order = work / "finalization-order.txt"
    pause_phase = os.environ.get("COLLECT_V6_PAUSE_PHASE", "")

    def append_order(name):
        with order.open("a", encoding="utf-8") as stream:
            stream.write(name + "\n")
            stream.flush()

    def requested(signum, _frame):
        nonlocal first_requested
        event = {"sequence": len(events) + 1,
                 "signal": signal.Signals(signum).name,
                 "signal_number": signum,
                 "requested_status": SIGNAL_STATUS[signum],
                 "phase": phase, "observed_utc": utc_now(),
                 "forward_result": "not_running"}
        if first_requested is None:
            first_requested = event
        if supervisor is not None and supervisor_ready and supervisor.poll() is None:
            try:
                os.kill(supervisor.pid, signum)
                event["forward_result"] = "forwarded_to_supervisor"
            except ProcessLookupError:
                event["forward_result"] = "supervisor_ESRCH"
        events.append(event)

    for number in HANDLED:
        signal.signal(number, requested)

    def enter(name, ordered=True):
        nonlocal phase
        phase = name
        if ordered:
            append_order(name)
        if pause_phase == name:
            ready = work / "hooks" / (name + ".ready")
            release = work / "hooks" / (name + ".release")
            atomic_text(ready, "ready\n")
            deadline = time.monotonic() + 8
            while not release.exists():
                if time.monotonic() >= deadline:
                    raise RuntimeError("phase hook timed out")
                time.sleep(.005)

    segment_status = 125
    try:
        command = [sys.executable, "-B",
                   str(package / "future-protocol/supervise-v6.py"),
                   "--timeout", os.environ.get("SEGMENT_TIMEOUT", "5"),
                   "--term-grace", os.environ.get("TERM_GRACE", "1"),
                   "--post-kill-grace", os.environ.get(
                       "POST_KILL_GRACE", "1"),
                   "--quiet-interval", os.environ.get(
                       "QUIET_INTERVAL", ".05"),
                   "--poll", os.environ.get("POLL_INTERVAL", ".01"),
                   "--preflight-dir", str(work / "raw/preflight"),
                   "--status", str(work / "raw/supervisor.json"),
                   "--stdout", str(work / "raw/stdout"),
                   "--stderr", str(work / "raw/stderr"),
                   "--cwd", str(root), "--ready",
                   str(work / "raw/supervisor.ready"), "--", *argv[1:]]
        supervisor = subprocess.Popen(command)
        enter("supervisor_started")
        ready = work / "raw/supervisor.ready"
        deadline = time.monotonic() + 8
        while not ready.exists():
            if supervisor.poll() is not None:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError("supervisor ready timeout")
            time.sleep(.005)
        supervisor_ready = ready.exists()
        for event in events:
            if event["forward_result"] == "not_running" and supervisor.poll() is None:
                os.kill(supervisor.pid, event["signal_number"])
                event["forward_result"] = "forwarded_after_launch"
        phase = "supervisor_wait"
        if pause_phase == phase:
            enter(phase, ordered=False)
        segment_status = shell_status(supervisor.wait())
        enter("supervisor_wait_complete")
    except BaseException as error:
        print("collect-v6: supervisor phase failed: %s" % error,
              file=sys.stderr)
        if supervisor is not None and supervisor.poll() is None:
            try:
                os.kill(supervisor.pid, signal.SIGTERM)
                supervisor.wait(timeout=4)
            except BaseException:
                try:
                    supervisor.kill()
                    supervisor.wait(timeout=2)
                except BaseException:
                    pass
        append_order("supervisor_wait_complete")
        segment_status = 125

    enter("raw_seal")
    seal_status = 0
    try:
        rows = []
        for relative in ("raw/stdout", "raw/stderr", "raw/supervisor.json"):
            path = work / relative
            if path.exists():
                rows.append("%s  %s\n" % (
                    hashlib.sha256(path.read_bytes()).hexdigest(), relative))
            else:
                rows.append("ABSENT  %s\n" % relative)
        atomic_text(work / "raw.seal.sha256", "".join(rows))
    except BaseException as error:
        seal_status = 1
        print("collect-v6: raw seal failed: %s" % error, file=sys.stderr)

    enter("artifact_audit")
    artifact_status = 0
    auditor = pathlib.Path(os.environ.get(
        "ARTIFACT_AUDITOR",
        str(package / "future-protocol/audit-artifacts-v5.sh")))
    try:
        completed = subprocess.run([
            str(auditor), "--root", str(root), "--package-dir", str(package),
            "--scratch-root", str(scratch_root), "--work", str(work),
            "--scratch-dir", str(tmp), "--output", str(artifact_output)],
            check=False, env=os.environ.copy())
        artifact_status = shell_status(completed.returncode)
        if artifact_status == 0 and artifact_output.read_bytes() != reference.read_bytes():
            artifact_status = 1
    except BaseException:
        artifact_status = 1

    enter("process_audit")
    endpoint_status = 0
    try:
        result = subprocess.run(["pgrep", "-a", os.environ["ENDPOINT_PATTERN"]],
                                text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, check=False)
        endpoint_status = 0 if result.returncode == 1 else 1
        endpoint_text = "matches=none\n" if endpoint_status == 0 else (
            result.stdout or "pgrep_status=%d\n" % result.returncode)
    except BaseException as error:
        endpoint_status, endpoint_text = 1, "audit_error=%s\n" % error
    atomic_text(work / "audits/final-endpoint.txt", endpoint_text)

    supervisor_row = {}
    try:
        supervisor_row = json.loads((work / "raw/supervisor.json").read_text())
    except BaseException:
        pass
    containment = ("cleared" if supervisor_row.get("containment_cleared")
                   else supervisor_row.get("classification", "unreadable"))
    provenance = supervisor_row.get("containment_preflight") or {}
    enter("final_status_publication")
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)
    cleanup_failure = int(
        seal_status != 0 or artifact_status != 0 or endpoint_status != 0 or
        segment_status == 125 or
        (supervisor_row.get("benchmark_launched") and
         not supervisor_row.get("containment_cleared")))
    final_status = (125 if cleanup_failure else
                    first_requested["requested_status"] if first_requested else
                    segment_status)
    atomic_text(work / "outer-signals.json", json.dumps({
        "events": events,
        "publication_signal_mask": [signal.Signals(item).name
                                    for item in HANDLED],
        "previous_signal_mask": [signal.Signals(item).name
                                 for item in previous_mask]}, sort_keys=True) + "\n")
    append_order("final_status")
    lines = [
        "outer_requested_signal=%s\n" % (
            "none" if first_requested is None else first_requested["signal"]),
        "outer_requested_status=%s\n" % (
            "none" if first_requested is None else
            first_requested["requested_status"]),
        "outer_signal_count=%d\n" % len(events),
        "actual_supervisor_status=%d\n" % segment_status,
        "supervisor_classification=%s\n" % supervisor_row.get(
            "classification", "unreadable"),
        "containment_status=%s\n" % containment,
        "containment_kind=%s\n" % supervisor_row.get(
            "containment_kind", "none"),
        "containment_launcher_path=%s\n" % provenance.get(
            "launcher_path", "unavailable"),
        "containment_launcher_sha256=%s\n" % provenance.get(
            "launcher_sha256", "unavailable"),
        "raw_seal_status=%d\n" % seal_status,
        "artifact_audit_status=%d\n" % artifact_status,
        "endpoint_audit_status=%d\n" % endpoint_status,
        "cleanup_or_audit_failure=%d\n" % cleanup_failure,
        "final_status=%d\n" % final_status,
        "publication_signals_blocked=true\n",
        "work_preserved=%s\n" % work,
    ]
    atomic_text(work / "final-status.txt", "".join(lines))
    os._exit(final_status)


if __name__ == "__main__":
    raise SystemExit(main())
