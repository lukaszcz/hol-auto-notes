#!/usr/bin/env python3
"""Future v7 collector with fail-closed transactional finalization."""
from __future__ import annotations

import datetime
import hashlib
import importlib.util
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


def atomic_text(path, value):
    temporary = path.with_name(path.name + ".tmp.%d" % os.getpid())
    try:
        with temporary.open("x", encoding="utf-8", newline="") as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise


def shell_status(value):
    return value if value >= 0 else 128 + (-value)


class Faults:
    def __init__(self):
        self.pending = {item for item in os.environ.get(
            "COLLECT_V7_INJECT", "").split(",") if item}
        self.triggered = []
        self.persistent = False

    def write(self, point):
        persistent_name = "persistent_write_after_%s" % point
        if persistent_name in self.pending:
            self.pending.remove(persistent_name)
            self.triggered.append(persistent_name)
            self.persistent = True
        if "persistent_write" in self.pending:
            if "persistent_write" not in self.triggered:
                self.triggered.append("persistent_write")
            self.persistent = True
        name = "write_%s" % point
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            raise OSError("injected one-shot %s" % name)
        if self.persistent:
            raise OSError("injected persistent transaction write failure")


def load_validator(package):
    path = package / "future-protocol/validate-supervisor-v7.py"
    spec = importlib.util.spec_from_file_location("validate_supervisor_v7",
                                                  path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def mutate_record(path, name):
    """Test-only raw adversary applied after the supervisor has exited."""
    if not name:
        return
    if name == "missing":
        path.unlink()
        return
    if name == "malformed":
        path.write_text("{not-json\n")
        return
    if name == "truncated":
        path.write_bytes(path.read_bytes()[:19])
        return
    if name == "duplicate":
        text = path.read_text()
        path.write_text('{"protocol_version":7,' + text[1:])
        return
    row = json.loads(path.read_text())
    if name == "missing_field":
        del row["kernel_containment_proof"]
    elif name == "extra":
        row["forged"] = True
    elif name == "nested_extra":
        row["wrapper_identity"]["forged"] = True
    elif name == "wrong_type":
        row["benchmark_launched"] = "true"
    elif name == "bad_enum":
        row["classification"] = "forged_success"
    elif name == "bad_launch":
        row["go_committed"] = False
    elif name == "bad_path":
        row["containment_preflight"]["launcher_path"] = "/bin/false"
    elif name == "bad_version":
        row["containment_preflight"]["launcher_version"] = "forged"
    elif name == "bad_hash":
        row["containment_preflight"]["launcher_sha256"] = "0" * 64
    elif name == "bad_options":
        row["containment_preflight"]["launcher_options"] = ["--pid"]
    elif name == "bad_preflight":
        row["containment_preflight"]["disposable_teardown_proved"] = False
    elif name == "missing_preflight":
        del row["containment_preflight"]
    elif name == "bad_proof":
        row["kernel_containment_proof"][
            "namespace_init_pidfd_exit_observed"] = False
    elif name == "exit_mismatch":
        row["supervisor_return_status"] = 7
    elif name == "bad_reap":
        row["reaps"][0]["wait_returncode"] = 7
    elif name == "bad_init_identity":
        row["namespace_init_identity"] = row["wrapper_identity"]
    elif name == "bad_close":
        row["pidfd_closes"][0]["result"] = "forged_closed"
    else:
        raise RuntimeError("unknown record mutation: %s" % name)
    path.write_text(json.dumps(row, sort_keys=True) + "\n")


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) < 2 or argv[0] != "--":
        print("collect-v7: command must follow --", file=sys.stderr)
        return 2
    command = argv[1:]
    required = ("ROOT", "PACKAGE_DIR", "SCRATCH_ROOT", "SCRATCH_DIR",
                "ENDPOINT_PATTERN", "ARTIFACT_REFERENCE")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        print("collect-v7: missing %s" % ",".join(missing), file=sys.stderr)
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
        print("collect-v7: %s" % error, file=sys.stderr)
        return 2
    root, package = paths["root"], paths["package_dir"]
    scratch_root, work = paths["scratch_root"], paths["work"]
    tmp, artifact_output = paths["tmp"], paths["output"]
    if work.exists():
        print("collect-v7: scratch exists", file=sys.stderr)
        return 2
    for path in (work / "raw", work / "audits", tmp, work / "hooks"):
        path.mkdir(parents=True, exist_ok=True)

    faults = Faults()
    errors = []
    order_rows = []
    order_path = work / "finalization-order.txt"

    def note_error(point, error):
        errors.append("%s: %s: %s" % (point, type(error).__name__, error))
        try:
            os.write(2, ("collect-v7: %s\n" % errors[-1]).encode(
                "utf-8", "replace"))
        except BaseException:
            pass

    def guarded_write(point, path, value):
        try:
            faults.write(point)
            atomic_text(path, value)
            return True
        except BaseException as error:
            note_error(point, error)
            return False

    def write_order(name):
        order_rows.append(name)
        return guarded_write("order_" + name, order_path,
                             "".join(item + "\n" for item in order_rows))

    # Exercise every destination directory and atomic replace/fsync path before
    # a supervisor can launch a namespace or benchmark. Failure is 125 and the
    # benchmark command is never passed to Popen.
    preflight_targets = [work / "raw/.transaction-test",
                         work / "audits/.transaction-test",
                         work / ".transaction-test"]
    preflight_ok = True
    for index, path in enumerate(preflight_targets):
        point = "preflight_%d" % index
        try:
            faults.write("preflight")
            atomic_text(path, "test\n")
            path.unlink()
        except BaseException as error:
            note_error(point, error)
            preflight_ok = False
            break
    if not preflight_ok:
        lines = ("benchmark_launched=false\ntransaction_preflight=false\n"
                 "cleanup_or_audit_failure=1\nfinal_status=125\n"
                 "primary_status_file_best_effort=true\n")
        guarded_write("final_status", work / "final-status.txt", lines)
        return 125

    phase = "before_supervisor_launch"
    events, first_requested = [], None
    supervisor, supervisor_ready = None, False
    pause_phase = os.environ.get("COLLECT_V7_PAUSE_PHASE", "")

    def requested(signum, _frame):
        nonlocal first_requested
        event = {"forward_result": "not_running", "observed_utc": utc_now(),
                 "phase": phase, "requested_status": SIGNAL_STATUS[signum],
                 "sequence": len(events) + 1,
                 "signal": signal.Signals(signum).name,
                 "signal_number": signum}
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

    for number in HANDLED:
        signal.signal(number, requested)

    def enter(name, ordered=True):
        nonlocal phase
        phase = name
        if ordered:
            write_order(name)
        if pause_phase == name:
            ready = work / "hooks" / (name + ".ready")
            release = work / "hooks" / (name + ".release")
            guarded_write("hook_" + name, ready, "ready\n")
            deadline = time.monotonic() + 8
            while not release.exists():
                if time.monotonic() >= deadline:
                    raise RuntimeError("phase hook timed out")
                time.sleep(.005)

    segment_status = 125
    try:
        supervisor_program = pathlib.Path(os.environ.get(
            "SUPERVISOR_PROGRAM",
            str(package / "future-protocol/supervise-v7.py")))
        supervisor_command = [
            sys.executable, "-B", str(supervisor_program),
            "--timeout", os.environ.get("SEGMENT_TIMEOUT", "5"),
            "--term-grace", os.environ.get("TERM_GRACE", "1"),
            "--post-kill-grace", os.environ.get("POST_KILL_GRACE", "1"),
            "--quiet-interval", os.environ.get("QUIET_INTERVAL", ".05"),
            "--poll", os.environ.get("POLL_INTERVAL", ".01"),
            "--preflight-dir", str(work / "raw/preflight"),
            "--status", str(work / "raw/supervisor.json"),
            "--stdout", str(work / "raw/stdout"),
            "--stderr", str(work / "raw/stderr"),
            "--cwd", str(root), "--ready",
            str(work / "raw/supervisor.ready"), "--", *command]
        supervisor = subprocess.Popen(supervisor_command)
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
            if (event["forward_result"] == "not_running" and
                    supervisor.poll() is None):
                os.kill(supervisor.pid, event["signal_number"])
                event["forward_result"] = "forwarded_after_launch"
        phase = "supervisor_wait"
        if pause_phase == phase:
            enter(phase, ordered=False)
        segment_status = shell_status(supervisor.wait())
        enter("supervisor_wait_complete")
    except BaseException as error:
        note_error("supervisor_phase", error)
        if supervisor is not None and supervisor.poll() is None:
            try:
                os.kill(supervisor.pid, signal.SIGTERM)
                supervisor.wait(timeout=4)
            except BaseException:
                try:
                    supervisor.kill()
                    supervisor.wait(timeout=2)
                except BaseException as nested:
                    note_error("supervisor_emergency_reap", nested)
        segment_status = 125
        if not order_rows or order_rows[-1] != "supervisor_wait_complete":
            write_order("supervisor_wait_complete")

    try:
        mutate_record(work / "raw/supervisor.json", os.environ.get(
            "COLLECT_V7_MUTATE_SUPERVISOR", ""))
    except BaseException as error:
        note_error("record_adversary", error)

    enter("finalizer_enter")
    enter("raw_seal")
    seal_status = 0
    rows = []
    try:
        for relative in ("raw/stdout", "raw/stderr", "raw/supervisor.json"):
            path = work / relative
            if path.exists():
                rows.append("%s  %s\n" % (
                    hashlib.sha256(path.read_bytes()).hexdigest(), relative))
            else:
                rows.append("ABSENT  %s\n" % relative)
                if relative == "raw/supervisor.json":
                    seal_status = 1
                    errors.append("raw supervisor record absent")
        if not guarded_write("raw_seal", work / "raw.seal.sha256",
                             "".join(rows)):
            seal_status = 1
    except BaseException as error:
        seal_status = 1
        note_error("raw_seal", error)

    schema_status = 0
    supervisor_row = {}
    try:
        supervisor_row = load_validator(package).validate_file(
            work / "raw/supervisor.json", segment_status, command)
    except BaseException as error:
        schema_status = 1
        note_error("supervisor_schema", error)

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
        if (artifact_status == 0 and
                artifact_output.read_bytes() != reference.read_bytes()):
            artifact_status = 1
    except BaseException as error:
        artifact_status = 1
        note_error("artifact_audit", error)

    enter("process_audit")
    endpoint_status = 0
    try:
        result = subprocess.run(["pgrep", "-a",
                                 os.environ["ENDPOINT_PATTERN"]], text=True,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, check=False)
        endpoint_status = 0 if result.returncode == 1 else 1
        endpoint_text = ("matches=none\n" if endpoint_status == 0 else
                         result.stdout or "pgrep_status=%d\n" %
                         result.returncode)
    except BaseException as error:
        endpoint_status, endpoint_text = 1, "audit_error=%s\n" % error
        note_error("process_audit", error)
    if not guarded_write("endpoint_audit",
                         work / "audits/final-endpoint.txt", endpoint_text):
        endpoint_status = 1

    containment = ("cleared" if supervisor_row.get("containment_cleared")
                   else supervisor_row.get("classification", "unreadable"))
    provenance = supervisor_row.get("containment_preflight") or {}
    enter("final_status_publication")
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)

    signal_rows = {"events": events,
                   "previous_signal_mask": [signal.Signals(item).name
                                            for item in previous_mask],
                   "publication_signal_mask": [signal.Signals(item).name
                                                for item in HANDLED]}
    guarded_write("outer_signals", work / "outer-signals.json",
                  json.dumps(signal_rows, sort_keys=True) + "\n")
    write_order("final_status")

    def decide():
        failure = bool(
            errors or seal_status or schema_status or artifact_status or
            endpoint_status or segment_status == 125 or
            not supervisor_row or
            (supervisor_row.get("benchmark_launched") and
             not supervisor_row.get("containment_cleared")))
        status = (125 if failure else
                  first_requested["requested_status"] if first_requested else
                  segment_status)
        return int(failure), status

    cleanup_failure, final_status = decide()

    def status_text(status):
        return "".join([
            "outer_requested_signal=%s\n" % (
                "none" if first_requested is None else
                first_requested["signal"]),
            "outer_requested_status=%s\n" % (
                "none" if first_requested is None else
                first_requested["requested_status"]),
            "outer_signal_count=%d\n" % len(events),
            "actual_supervisor_status=%d\n" % segment_status,
            "supervisor_classification=%s\n" % supervisor_row.get(
                "classification", "unreadable"),
            "supervisor_schema_status=%d\n" % schema_status,
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
            "transaction_error_count=%d\n" % len(errors),
            "transaction_errors_json=%s\n" % json.dumps(
                errors, separators=(",", ":")),
            "cleanup_or_audit_failure=%d\n" % cleanup_failure,
            "final_status=%d\n" % status,
            "publication_signals_blocked=true\n",
            "primary_status_file_best_effort=true\n",
            "work_preserved=%s\n" % work,
        ])

    wrote_status = guarded_write("final_status", work / "final-status.txt",
                                 status_text(final_status))
    if not wrote_status:
        cleanup_failure, final_status = 1, 125
        # One-shot failures get an honest second publication. Persistent or
        # truly unwritable media cannot be promised; stderr plus exit 125 is
        # the only reliable channel left.
        try:
            faults.write("final_status_retry")
            atomic_text(work / "final-status.txt", status_text(125))
            wrote_status = True
        except BaseException as error:
            note_error("final_status_retry", error)
    os._exit(final_status)


if __name__ == "__main__":
    raise SystemExit(main())
