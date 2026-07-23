#!/usr/bin/env python3
"""Future v5 single-segment collector with race-closed finalization."""
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


HANDLED_SIGNALS = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
SIGNAL_STATUS = {signal.SIGHUP: 129, signal.SIGINT: 130,
                 signal.SIGTERM: 143}


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def atomic_text(path, text):
    temporary = path.with_name(path.name + ".tmp.%d" % os.getpid())
    with temporary.open("x", encoding="utf-8", newline="") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def shell_status(returncode):
    return returncode if returncode >= 0 else 128 + (-returncode)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) < 2 or argv[0] != "--":
        print("collect-v5: command must follow --", file=sys.stderr)
        return 2
    command = argv[1:]
    required = ("ROOT", "PACKAGE_DIR", "SCRATCH_ROOT", "SCRATCH_DIR",
                "ENDPOINT_PATTERN", "ARTIFACT_REFERENCE")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        print("collect-v5: required environment missing: %s" %
              ",".join(missing), file=sys.stderr)
        return 2
    root_input = os.environ["ROOT"]
    package_input = os.environ["PACKAGE_DIR"]
    scratch_root_input = os.environ["SCRATCH_ROOT"]
    work_input = os.environ["SCRATCH_DIR"]
    endpoint_pattern = os.environ["ENDPOINT_PATTERN"]
    try:
        reference = pathlib.Path(
            os.environ["ARTIFACT_REFERENCE"]).resolve(strict=True)
        work_spelling = pathlib.Path(work_input)
        if not work_spelling.is_absolute():
            work_spelling = pathlib.Path.cwd() / work_spelling
        tmp_spelling = work_spelling / "tmp"
        output_spelling = work_spelling / "audits/final-artifacts.tsv"
        paths = validate_paths(
            root=root_input, package_dir=package_input,
            scratch_root=scratch_root_input, work=str(work_spelling),
            tmp=str(tmp_spelling), output=str(output_spelling))
    except (OSError, PathValidationError) as error:
        print("collect-v5: %s" % error, file=sys.stderr)
        return 2
    root, package = paths["root"], paths["package_dir"]
    scratch_root, work = paths["scratch_root"], paths["work"]
    tmp, artifact_output = paths["tmp"], paths["output"]
    if work.exists():
        print("collect-v5: scratch exists", file=sys.stderr)
        return 2
    (work / "raw").mkdir(parents=True)
    (work / "audits").mkdir()
    tmp.mkdir()
    (work / "hooks").mkdir()

    order_path = work / "finalization-order.txt"
    signal_path = work / "outer-signals.json"
    status_path = work / "final-status.txt"
    phase = "before_supervisor_launch"
    sequence = 0
    events = []
    first_requested = None
    supervisor = None
    supervisor_ready = False
    supervisor_started = False
    supervisor_wait_complete = False

    def append_order(name):
        with order_path.open("a", encoding="utf-8") as stream:
            stream.write(name + "\n")
            stream.flush()
            os.fsync(stream.fileno())

    def requested(signum, _frame):
        nonlocal sequence, first_requested
        sequence += 1
        event = {"sequence": sequence, "signal": signal.Signals(signum).name,
                 "signal_number": signum, "requested_status":
                 SIGNAL_STATUS[signum], "phase": phase,
                 "observed_utc": utc_now(), "forward_result": "not_running"}
        if first_requested is None:
            first_requested = event
        if (supervisor is not None and supervisor_ready and
                supervisor.poll() is None):
            try:
                os.kill(supervisor.pid, signum)
                event["forward_result"] = "forwarded_to_supervisor"
            except ProcessLookupError:
                event["forward_result"] = "supervisor_ESRCH"
        events.append(event)

    for sig in HANDLED_SIGNALS:
        signal.signal(sig, requested)

    pause_phase = os.environ.get("COLLECT_V5_PAUSE_PHASE", "")

    def enter(name, order=True):
        nonlocal phase
        phase = name
        if order:
            append_order(name)
        if pause_phase == name:
            ready = work / "hooks" / (name + ".ready")
            release = work / "hooks" / (name + ".release")
            atomic_text(ready, "ready\n")
            deadline = time.monotonic() + 5
            while not release.exists():
                if time.monotonic() >= deadline:
                    raise RuntimeError("phase hook release timeout: %s" % name)
                time.sleep(.005)

    try:
        supervisor_command = [
            sys.executable, "-B", str(package / "future-protocol/supervise-v5.py"),
            "--timeout", os.environ.get("SEGMENT_TIMEOUT", "5"),
            "--term-grace", os.environ.get("TERM_GRACE", "1"),
            "--post-kill-grace", os.environ.get("POST_KILL_GRACE", "1"),
            "--quiet-interval", os.environ.get("QUIET_INTERVAL", ".05"),
            "--poll", os.environ.get("POLL_INTERVAL", ".01"),
            "--status", str(work / "raw/supervisor.json"),
            "--stdout", str(work / "raw/stdout"),
            "--stderr", str(work / "raw/stderr"), "--cwd", str(root),
            "--ready", str(work / "raw/supervisor.ready"), "--",
        ] + command
        supervisor = subprocess.Popen(supervisor_command)
        supervisor_started = True
        enter("supervisor_started")
        phase = "supervisor_startup"
        ready_path = work / "raw/supervisor.ready"
        ready_deadline = time.monotonic() + 5
        while not ready_path.exists():
            if supervisor.poll() is not None:
                raise RuntimeError("supervisor exited before ready publication")
            if time.monotonic() >= ready_deadline:
                raise RuntimeError("supervisor ready publication timeout")
            time.sleep(.005)
        supervisor_ready = True
        # Signals captured between handler installation and Popen attachment
        # are now forwarded exactly once in original order.
        for event in events:
            if event["forward_result"] == "not_running" and supervisor.poll() is None:
                try:
                    os.kill(supervisor.pid, event["signal_number"])
                    event["forward_result"] = "forwarded_after_launch"
                except ProcessLookupError:
                    event["forward_result"] = "supervisor_ESRCH"
        phase = "supervisor_wait"
        if pause_phase == phase:
            enter(phase, order=False)
        while supervisor.poll() is None:
            try:
                supervisor.wait(timeout=.05)
            except subprocess.TimeoutExpired:
                pass
        segment_status = shell_status(supervisor.returncode)
        supervisor_wait_complete = True
        enter("supervisor_wait_complete")
    except BaseException as error:
        if not supervisor_started:
            print("collect-v5: supervisor launch failed: %s" % error,
                  file=sys.stderr)
            return 125
        # A post-launch collector error is retained as a segment/finalization
        # failure, but the supervisor is first signalled and reaped.
        try:
            if supervisor.poll() is None:
                os.kill(supervisor.pid, signal.SIGTERM)
                supervisor.wait(timeout=3)
        except BaseException:
            try:
                os.kill(supervisor.pid, signal.SIGKILL)
            except BaseException:
                pass
            try:
                supervisor.wait(timeout=3)
            except BaseException:
                pass
        segment_status = 125
        supervisor_wait_complete = supervisor.poll() is not None
        append_order("supervisor_wait_complete")

    # From here through publication, handlers remain installed. Signals are
    # recorded and deferred; they cannot abort a seal or either audit.
    enter("raw_seal")
    seal_status = 0
    try:
        rows = []
        for name in ("raw/stdout", "raw/stderr", "raw/supervisor.json"):
            path = work / name
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            rows.append("%s  %s\n" % (digest, name))
        atomic_text(work / "raw.seal.sha256", "".join(rows))
    except BaseException as error:
        seal_status = 1
        print("collect-v5: raw seal failed: %s" % error, file=sys.stderr)

    enter("artifact_audit")
    auditor = pathlib.Path(os.environ.get(
        "ARTIFACT_AUDITOR",
        str(package / "future-protocol/audit-artifacts-v5.sh")))
    audit_env = os.environ.copy()
    audit_env.update({"ROOT": str(root), "PACKAGE_DIR": str(package),
                      "SCRATCH_ROOT": str(scratch_root),
                      "SCRATCH_DIR": str(tmp)})
    artifact_status = 0
    try:
        completed = subprocess.run([
            str(auditor), "--root", str(root), "--package-dir", str(package),
            "--scratch-root", str(scratch_root), "--work", str(work),
            "--scratch-dir", str(tmp), "--output", str(artifact_output)],
            env=audit_env, check=False)
        artifact_status = shell_status(completed.returncode)
        if artifact_status == 0 and artifact_output.read_bytes() != reference.read_bytes():
            artifact_status = 1
    except BaseException as error:
        artifact_status = 1
        print("collect-v5: artifact audit failed: %s" % error, file=sys.stderr)

    enter("process_audit")
    endpoint_status = 0
    try:
        completed = subprocess.run(["pgrep", "-a", endpoint_pattern],
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL, text=True,
                                   check=False)
        if completed.returncode == 0 and completed.stdout:
            endpoint_status = 1
            endpoint_text = completed.stdout
        elif completed.returncode == 1:
            endpoint_text = "matches=none\n"
        else:
            endpoint_status = 1
            endpoint_text = "pgrep_status=%d\n" % completed.returncode
    except BaseException as error:
        endpoint_status = 1
        endpoint_text = "process_audit_error=%s\n" % error
    atomic_text(work / "audits/final-endpoint.txt", endpoint_text)

    classification = "unreadable"
    try:
        classification = json.loads(
            (work / "raw/supervisor.json").read_text())["classification"]
    except BaseException:
        pass

    # Let a deterministic control signal this publication phase while normal
    # handlers are still active. Then block the handled set, freeze the event
    # ledger and status decision, atomically publish, and _exit without ever
    # reopening a delivery window.
    enter("final_status_publication")
    blocked_before = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED_SIGNALS)
    cleanup_failure = int(seal_status != 0 or artifact_status != 0 or
                          endpoint_status != 0 or segment_status == 125)
    if cleanup_failure:
        final_status = 125
    elif first_requested is not None:
        final_status = first_requested["requested_status"]
    else:
        final_status = segment_status
    signal_rows = {"events": events, "publication_signal_mask":
                   [signal.Signals(item).name for item in HANDLED_SIGNALS],
                   "previous_signal_mask": [signal.Signals(item).name
                                            for item in blocked_before]}
    publication_error = None
    try:
        atomic_text(signal_path, json.dumps(signal_rows, sort_keys=True) + "\n")
        append_order("final_status")
    except BaseException as error:
        publication_error = error
        final_status = 125
    requested_name = "none" if first_requested is None else first_requested["signal"]
    requested_status = "none" if first_requested is None else str(
        first_requested["requested_status"])
    lines = [
        "outer_requested_signal=%s\n" % requested_name,
        "outer_requested_status=%s\n" % requested_status,
        "outer_signal_count=%d\n" % len(events),
        "supervisor_started=true\n",
        "supervisor_wait_complete=%s\n" %
        ("true" if supervisor_wait_complete else "false"),
        "actual_supervisor_status=%d\n" % segment_status,
        "supervisor_classification=%s\n" % classification,
        "raw_seal_status=%d\n" % seal_status,
        "artifact_audit_status=%d\n" % artifact_status,
        "endpoint_audit_status=%d\n" % endpoint_status,
        "cleanup_or_audit_failure=%d\n" % cleanup_failure,
        "final_status=%d\n" % final_status,
        "publication_signals_blocked=true\n",
        "publication_error=%s\n" % ("none" if publication_error is None else
                                      str(publication_error)),
        "work_preserved=%s\n" % work,
    ]
    try:
        atomic_text(status_path, "".join(lines))
    except BaseException as error:
        os.write(2, ("collect-v5: final status media unwritable: %s\n" %
                     error).encode("utf-8", "replace"))
        final_status = 125
    os._exit(final_status)


if __name__ == "__main__":
    raise SystemExit(main())
