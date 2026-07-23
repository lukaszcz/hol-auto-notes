#!/usr/bin/env python3
"""Task 7n v10 collector with an exact-argv /proc endpoint gate."""
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

STRICT_INTEGER_CATEGORIES = (
    "protocol_version", "supervisor_return_status",
    "preflight_protocol_version", "preflight_identity_pid",
    "preflight_identity_starttime", "wrapper_identity_pid",
    "wrapper_identity_starttime", "namespace_identity_pid",
    "namespace_identity_starttime", "original_pgid",
    "readiness_namespace_pid", "readiness_protocol_version",
    "readiness_pid_namespace_inode", "wrapper_returncode",
    "reap_identity_pid", "reap_identity_starttime", "reap_returncode",
    "requested_signal_sequence", "requested_signal_signal_number",
    "requested_signal_requested_status", "requested_outer_status",
    "signal_number", "signal_target_pgid", "signal_identity_pid",
    "signal_identity_starttime", "scan_identity_pid",
    "scan_identity_starttime", "quiet_empty_proofs",
)


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def shell_status(value):
    return value if value >= 0 else 128 + (-value)


def exact_endpoint(command):
    """Return a status/text pair for exact launcher and module argv."""
    executable = pathlib.Path(command[0]).resolve(strict=False)
    identities = {str(executable).encode()}
    if executable.name.endswith(".exe"):
        identities.add(str(executable)[:-4].encode())
    matches = []
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            argv = (entry / "cmdline").read_bytes().split(b"\0")
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        if any(identity in argv for identity in identities):
            matches.append("%s\t%s" %
                           (entry.name,
                            " ".join(item.decode("utf-8", "replace")
                                     for item in argv if item)))
    return ((0, "matches=none\n") if not matches else
            (1, "\n".join(matches) + "\n"))


class Faults:
    def __init__(self):
        self.pending = {item for item in os.environ.get(
            "COLLECT_V10_INJECT", "").split(",") if item}
        self.triggered = []
        self.persistent_write = False
        self.persistent_fsync = False

    def hit(self, name):
        persistent = "persistent_" + name
        if persistent in self.pending:
            self.pending.remove(persistent)
            self.triggered.append(persistent)
            if name.startswith("fsync"):
                self.persistent_fsync = True
            else:
                self.persistent_write = True
        if "persistent_write" in self.pending:
            if "persistent_write" not in self.triggered:
                self.triggered.append("persistent_write")
            self.persistent_write = True
        if "persistent_fsync" in self.pending:
            if "persistent_fsync" not in self.triggered:
                self.triggered.append("persistent_fsync")
            self.persistent_fsync = True
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            raise OSError("injected %s failure" % name)
        if name.startswith("fsync") and self.persistent_fsync:
            raise OSError("injected persistent fsync failure")
        if name.startswith("write") and self.persistent_write:
            raise OSError("injected persistent write failure")


def fsync_directory(path, faults=None, point="directory"):
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        if faults is not None:
            faults.hit("fsync_dir_" + point)
            faults.hit("fsync_dir")
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def atomic_bytes(path, value, faults=None, point="material"):
    temporary = path.with_name(path.name + ".tmp.%d" % os.getpid())
    try:
        if faults is not None:
            faults.hit("write_" + point)
        with temporary.open("xb") as stream:
            stream.write(value)
            stream.flush()
            if faults is not None:
                faults.hit("fsync_file_" + point)
                faults.hit("fsync_file")
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        fsync_directory(path.parent, faults, point)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise


def atomic_text(path, value, faults=None, point="material"):
    atomic_bytes(path, value.encode("utf-8"), faults, point)


def durable_mkdir(path, faults, point):
    missing = []
    probe = path
    while not probe.exists():
        missing.append(probe)
        probe = probe.parent
    for directory in reversed(missing):
        faults.hit("setup_mkdir")
        directory.mkdir()
        fsync_directory(directory, faults, "setup_" + point)
        fsync_directory(directory.parent, faults, "setup_parent_" + point)


def durable_republish(path, faults, point):
    atomic_bytes(path, path.read_bytes(), faults, point)


def load_validator(package):
    path = package / "future-protocol/validate-supervisor-v10.py"
    spec = importlib.util.spec_from_file_location("validate_supervisor_v10",
                                                  path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def drain_pending(events, first_requested, phase):
    while True:
        info = signal.sigtimedwait(HANDLED, 0)
        if info is None:
            break
        signum = info.si_signo
        event = {"forward_result": "terminal_blocked",
                 "observed_utc": utc_now(), "phase": phase,
                 "requested_status": SIGNAL_STATUS[signum],
                 "sequence": len(events) + 1,
                 "signal": signal.Signals(signum).name,
                 "signal_number": signum}
        events.append(event)
        if first_requested[0] is None:
            first_requested[0] = event


def wait_hook(work, phase, guarded_write):
    if os.environ.get("COLLECT_V10_PAUSE_PHASE") != phase:
        return
    ready = work / "hooks" / (phase + ".ready")
    release = work / "hooks" / (phase + ".release")
    guarded_write("hook_" + phase, ready, "ready\n")
    deadline = time.monotonic() + 8
    while not release.exists():
        if time.monotonic() >= deadline:
            raise RuntimeError("%s hook timeout" % phase)
        time.sleep(.005)


def mutate_record(path, name):
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
        path.write_text('{"protocol_version":10,' + text[1:])
        return
    if name in ("nan", "infinity", "neg_infinity"):
        token = {"nan": "NaN", "infinity": "Infinity",
                 "neg_infinity": "-Infinity"}[name]
        text = path.read_text()
        path.write_text(text.replace('"elapsed_seconds":',
                                     '"elapsed_seconds":' + token +
                                     ',"discarded_elapsed":', 1))
        return
    row = json.loads(path.read_text())

    def add_signal():
        row["requested_outer_signals"] = [{
            "observed_utc": "forged", "phase": "post_go",
            "requested_status": 129, "sequence": 1,
            "signal": "SIGHUP", "signal_number": 1}]
        row["requested_outer_status"] = 129

    def add_exception():
        row["primary_exception"] = {
            "message": "forged", "traceback": "", "type": "Error"}

    def add_nonzero():
        row["wrapper_returncode"] = 7
        for reap in row["reaps"]:
            if reap["role"] == "containment_wrapper":
                reap["wait_returncode"] = 7

    def signal_numeric(field, value):
        add_signal()
        row["requested_outer_signals"][0][field] = value

    def priority(*states):
        for state in states:
            if state == "containment":
                row["containment_cleared"] = False
            elif state == "degradation":
                row["cleanup_degraded"] = True
                row["cleanup_errors"] = ["forged"]
            elif state == "signal":
                add_signal()
            elif state == "exception":
                add_exception()
            elif state == "timeout":
                row["timed_out"] = True
            elif state == "nonzero":
                add_nonzero()

    def integer_target(category):
        if category in {"protocol_version", "supervisor_return_status",
                        "original_pgid", "wrapper_returncode",
                        "requested_outer_status"}:
            if category == "requested_outer_status":
                add_signal()
            return row, category
        if category == "preflight_protocol_version":
            return row["containment_preflight"], "protocol_version"
        prefixes = (
            ("preflight_identity_",
             row["containment_preflight"]["observed_identities"][0]),
            ("wrapper_identity_", row["wrapper_identity"]),
            ("namespace_identity_", row["namespace_init_identity"]),
            ("readiness_", row["namespace_init_ready"]),
            ("reap_identity_", row["reaps"][0]["identity"]),
        )
        for prefix, target in prefixes:
            if category.startswith(prefix):
                return target, category.removeprefix(prefix)
        if category == "reap_returncode":
            return row["reaps"][0], "wait_returncode"
        if category.startswith("requested_signal_"):
            add_signal()
            return row["requested_outer_signals"][0], \
                category.removeprefix("requested_signal_")
        if category in {"signal_number", "signal_target_pgid"}:
            row["signals"].append({
                "phase": "forged", "result": "sent",
                "scope": "verified_wrapper_pgid", "signal": 15,
                "target_identity": None,
                "target_pgid": row["original_pgid"],
                "verification": "wrapper_pidfd_and_launch_pgid_verified"})
            field = ("signal" if category == "signal_number" else
                     "target_pgid")
            return row["signals"][-1], field
        if category.startswith("signal_identity_"):
            row["signals"].append({
                "phase": "forged", "result": "sent",
                "scope": "containment_wrapper_pidfd", "signal": 15,
                "target_identity": dict(row["wrapper_identity"]),
                "target_pgid": None, "verification": "pidfd"})
            return row["signals"][-1]["target_identity"], \
                category.removeprefix("signal_identity_")
        if category.startswith("scan_identity_"):
            row["scans"].append({
                "known_present": [dict(row["wrapper_identity"])],
                "phase": "forged", "result": "observed"})
            return row["scans"][-1]["known_present"][0], \
                category.removeprefix("scan_identity_")
        if category == "quiet_empty_proofs":
            return row["quiet_results"][0], "empty_proofs"
        raise RuntimeError("unknown integer mutation category: %s" %
                           category)

    if name.startswith("strict_integer__"):
        _prefix, category, kind = name.split("__")
        if kind not in {"bool", "float"}:
            raise RuntimeError("unknown strict integer mutation kind")
        target, field = integer_target(category)
        value = target[field]
        target[field] = bool(value) if kind == "bool" else float(value)
        path.write_text(json.dumps(row, sort_keys=True) + "\n")
        return
    actions = {
        "extra": lambda: row.__setitem__("forged", True),
        "nested_extra": lambda: row["wrapper_identity"].__setitem__(
            "forged", True),
        "bad_suffix": lambda: row["bootstrap_ownership"][
            "full_launch_vector"].append("forged"),
        "forged_bootstrap_program": lambda: row[
            "bootstrap_ownership"].__setitem__(
                "bootstrap_program", "/forged/launch-gate-v8.py"),
        "bad_interpreter": lambda: row["bootstrap_ownership"][
            "full_launch_vector"].__setitem__(0, "/bin/false"),
        "bad_ready": lambda: row["bootstrap_ownership"][
            "full_launch_vector"].__setitem__(-5, "/forged/ready"),
        "bad_go": lambda: row["bootstrap_ownership"][
            "full_launch_vector"].__setitem__(-3, "/forged/go"),
        "bad_command": lambda: row["command"].append("forged"),
        "bad_exception": lambda: row.__setitem__("primary_exception", {
            "message": "forged", "traceback": "", "type": "Error"}),
        "bad_close_flag": lambda: row["pidfd_closes"][0].__setitem__(
            "os_exit_will_close", True),
        "bad_close_result": lambda: row["pidfd_closes"][0].__setitem__(
            "result", "forged"),
        "negative_elapsed": lambda: row.__setitem__("elapsed_seconds", -1),
        "bad_quiet_numeric": lambda: row["quiet_results"][0].__setitem__(
            "quiet_seconds", -1),
        "telemetry_scan": lambda: row["scans"][0].__setitem__(
            "result", "error"),
        "telemetry_fault": lambda: row["faults_triggered"].append("forged"),
        "bad_terminal": lambda: row.__setitem__(
            "terminal_commit_reached", False),
        "bad_bootstrap": lambda: row["bootstrap_ownership"].__setitem__(
            "pidfd_bound_before_go", False),
        "cancellation_wrong_signal": lambda: (
            add_signal(), row.__setitem__(
                "classification", "cancelled_post_go_SIGTERM_contained")),
        "cancellation_extra_suffix": lambda: (
            add_signal(), row.__setitem__(
                "classification",
                "cancelled_post_go_SIGHUP_contained_forged")),
        "signal_sequence_bool": lambda: signal_numeric("sequence", True),
        "signal_sequence_float": lambda: signal_numeric("sequence", 1.0),
        "signal_number_bool": lambda: signal_numeric(
            "signal_number", True),
        "signal_number_float": lambda: signal_numeric(
            "signal_number", 1.0),
        "signal_status_bool": lambda: signal_numeric(
            "requested_status", True),
        "signal_status_float": lambda: signal_numeric(
            "requested_status", 129.0),
        "priority_signal_exception_timeout_nonzero": lambda: priority(
            "signal", "exception", "timeout", "nonzero"),
        "priority_signal_exception": lambda: priority(
            "signal", "exception"),
        "priority_signal_timeout": lambda: priority("signal", "timeout"),
        "priority_signal_nonzero": lambda: priority("signal", "nonzero"),
        "priority_signal_success": lambda: priority("signal"),
        "priority_exception_timeout_nonzero": lambda: priority(
            "exception", "timeout", "nonzero"),
        "priority_exception_timeout": lambda: priority(
            "exception", "timeout"),
        "priority_exception_nonzero": lambda: priority(
            "exception", "nonzero"),
        "priority_exception_success": lambda: priority("exception"),
        "priority_timeout_nonzero": lambda: priority(
            "timeout", "nonzero"),
        "priority_timeout_success": lambda: priority("timeout"),
        "priority_nonzero_success": lambda: priority("nonzero"),
        "priority_degradation_signal": lambda: priority(
            "degradation", "signal"),
        "priority_degradation_exception": lambda: priority(
            "degradation", "exception"),
        "priority_degradation_timeout": lambda: priority(
            "degradation", "timeout"),
        "priority_degradation_nonzero": lambda: priority(
            "degradation", "nonzero"),
        "priority_degradation_success": lambda: priority("degradation"),
        "priority_containment_degradation": lambda: priority(
            "containment", "degradation"),
        "priority_containment_signal": lambda: priority(
            "containment", "signal"),
        "priority_containment_exception": lambda: priority(
            "containment", "exception"),
        "priority_containment_timeout": lambda: priority(
            "containment", "timeout"),
        "priority_containment_nonzero": lambda: priority(
            "containment", "nonzero"),
        "priority_containment_success": lambda: priority("containment"),
        "missing_field": lambda: row.__delitem__("kernel_containment_proof"),
        "wrong_type": lambda: row.__setitem__("benchmark_launched", "true"),
        "bad_enum": lambda: row.__setitem__("classification", "forged"),
        "bad_launch": lambda: row.__setitem__("go_committed", False),
        "bad_path": lambda: row["containment_preflight"].__setitem__(
            "launcher_path", "/bin/false"),
        "bad_version": lambda: row["containment_preflight"].__setitem__(
            "launcher_version", "forged"),
        "bad_hash": lambda: row["containment_preflight"].__setitem__(
            "launcher_sha256", "0" * 64),
        "bad_options": lambda: row["containment_preflight"].__setitem__(
            "launcher_options", ["--pid"]),
        "bad_preflight": lambda: row["containment_preflight"].__setitem__(
            "disposable_teardown_proved", False),
        "missing_preflight": lambda: row.__delitem__(
            "containment_preflight"),
        "bad_proof": lambda: row["kernel_containment_proof"].__setitem__(
            "namespace_init_pidfd_exit_observed", False),
        "exit_mismatch": lambda: row.__setitem__(
            "supervisor_return_status", 7),
        "bad_reap": lambda: row["reaps"][0].__setitem__(
            "wait_returncode", 7),
        "bad_init_identity": lambda: row.__setitem__(
            "namespace_init_identity", row["wrapper_identity"]),
        "bad_close": lambda: row["pidfd_closes"][0].__setitem__(
            "result", "forged_closed"),
    }
    if name not in actions:
        raise RuntimeError("unknown record mutation: %s" % name)
    actions[name]()
    path.write_text(json.dumps(row, sort_keys=True) + "\n")


def main(argv=None):
    # Signal/transaction state and handlers are initialized before the first
    # filesystem mutation, including setup mkdir and destination probes.
    argv = sys.argv[1:] if argv is None else argv
    faults = Faults()
    errors = []
    events = []
    first_requested = [None]
    phase = ["collector_argument_validation"]
    supervisor = [None]
    supervisor_ready = [False]

    def requested(signum, _frame):
        event = {"forward_result": "not_running", "observed_utc": utc_now(),
                 "phase": phase[0],
                 "requested_status": SIGNAL_STATUS[signum],
                 "sequence": len(events) + 1,
                 "signal": signal.Signals(signum).name,
                 "signal_number": signum}
        if first_requested[0] is None:
            first_requested[0] = event
        child = supervisor[0]
        if child is not None and supervisor_ready[0] and child.poll() is None:
            try:
                os.kill(child.pid, signum)
                event["forward_result"] = "forwarded_to_supervisor"
            except ProcessLookupError:
                event["forward_result"] = "supervisor_ESRCH"
        events.append(event)

    for number in HANDLED:
        signal.signal(number, requested)

    if len(argv) < 2 or argv[0] != "--":
        print("collect-v10: command must follow --", file=sys.stderr)
        return 2
    command = argv[1:]
    required = ("ROOT", "PACKAGE_DIR", "SCRATCH_ROOT", "SCRATCH_DIR",
                "ARTIFACT_REFERENCE")
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        print("collect-v10: missing %s" % ",".join(missing), file=sys.stderr)
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
        print("collect-v10: %s" % error, file=sys.stderr)
        return 2
    root, package = paths["root"], paths["package_dir"]
    scratch_root, work = paths["scratch_root"], paths["work"]
    tmp, artifact_output = paths["tmp"], paths["output"]
    if work.exists():
        print("collect-v10: scratch exists", file=sys.stderr)
        return 2

    def note_error(point, error):
        errors.append("%s: %s: %s" %
                      (point, type(error).__name__, error))
        try:
            os.write(2, ("collect-v10: %s\n" % errors[-1]).encode(
                "utf-8", "replace"))
        except BaseException:
            pass

    def guarded_write(point, path, value):
        try:
            atomic_text(path, value, faults, point)
            return True
        except BaseException as error:
            note_error(point, error)
            return False

    setup_ok = True
    phase[0] = "collector_setup"
    try:
        for label, path in (("work", work), ("raw", work / "raw"),
                            ("audits", work / "audits"), ("tmp", tmp),
                            ("hooks", work / "hooks")):
            durable_mkdir(path, faults, label)
        wait_hook(work, "setup", guarded_write)
        for index, target in enumerate((work / "raw/.transaction-test",
                                        work / "audits/.transaction-test",
                                        work / ".transaction-test")):
            atomic_text(target, "test\n", faults,
                        "setup_probe_%d" % index)
            target.unlink()
            fsync_directory(target.parent, faults,
                            "setup_unlink_%d" % index)
    except BaseException as error:
        note_error("collector_setup", error)
        setup_ok = False

    def setup_failure_status(status):
        try:
            signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)
            drain_pending(events, first_requested, "setup_terminal_commit")
            if errors:
                status = 125
            elif first_requested[0] is not None:
                status = first_requested[0]["requested_status"]
            text = ("benchmark_launched=false\n"
                    "transaction_preflight=false\n"
                    "setup_signal_count=%d\n"
                    "cleanup_or_audit_failure=1\n"
                    "final_status=%d\n"
                    "primary_status_file_best_effort=true\n" %
                    (len(events), status))
            if work.exists():
                if not guarded_write("final_status", work /
                                     "final-status.txt", text):
                    status = 125
        except BaseException as error:
            note_error("setup_terminal_commit", error)
            status = 125
        os._exit(status)

    if not setup_ok:
        setup_failure_status(125)
    if events:
        setup_failure_status(first_requested[0]["requested_status"])

    order_rows = []
    order_path = work / "finalization-order.txt"

    def write_order(name):
        order_rows.append(name)
        return guarded_write("order_" + name, order_path,
                             "".join(item + "\n" for item in order_rows))

    def enter(name, ordered=True):
        phase[0] = name
        if ordered:
            write_order(name)
        wait_hook(work, name, guarded_write)

    segment_status = 125
    supervisor_program = pathlib.Path(os.environ.get(
        "SUPERVISOR_PROGRAM",
        str(package / "future-protocol/supervise-v10.py")))
    preflight_dir = work / "raw/preflight"
    supervisor_command = [
        sys.executable, "-B", str(supervisor_program),
        "--timeout", os.environ.get("SEGMENT_TIMEOUT", "5"),
        "--term-grace", os.environ.get("TERM_GRACE", "1"),
        "--post-kill-grace", os.environ.get("POST_KILL_GRACE", "1"),
        "--quiet-interval", os.environ.get("QUIET_INTERVAL", ".05"),
        "--poll", os.environ.get("POLL_INTERVAL", ".01"),
        "--preflight-dir", str(preflight_dir),
        "--status", str(work / "raw/supervisor.json"),
        "--stdout", str(work / "raw/stdout"),
        "--stderr", str(work / "raw/stderr"),
        "--cwd", str(root), "--ready", str(work / "raw/supervisor.ready")]
    if os.environ.get("SUPERVISOR_V10_TERMINAL_HOOK_DIR"):
        supervisor_command += ["--terminal-hook-dir",
                               os.environ["SUPERVISOR_V10_TERMINAL_HOOK_DIR"]]
    supervisor_command += ["--", *command]
    try:
        supervisor[0] = subprocess.Popen(supervisor_command)
        enter("supervisor_started")
        ready_path = work / "raw/supervisor.ready"
        deadline = time.monotonic() + 8
        while not ready_path.exists():
            if supervisor[0].poll() is not None:
                break
            if time.monotonic() >= deadline:
                raise RuntimeError("supervisor ready timeout")
            time.sleep(.005)
        supervisor_ready[0] = ready_path.exists()
        for event in events:
            if event["forward_result"] == "not_running" and \
                    supervisor[0].poll() is None:
                os.kill(supervisor[0].pid, event["signal_number"])
                event["forward_result"] = "forwarded_after_launch"
        phase[0] = "supervisor_wait"
        wait_hook(work, "supervisor_wait", guarded_write)
        segment_status = shell_status(supervisor[0].wait())
        enter("supervisor_wait_complete")
    except BaseException as error:
        note_error("supervisor_phase", error)
        child = supervisor[0]
        if child is not None and child.poll() is None:
            try:
                os.kill(child.pid, signal.SIGTERM)
                child.wait(timeout=4)
            except BaseException:
                try:
                    child.kill()
                    child.wait(timeout=2)
                except BaseException as nested:
                    note_error("supervisor_emergency_reap", nested)
        segment_status = 125
        if not order_rows or order_rows[-1] != "supervisor_wait_complete":
            write_order("supervisor_wait_complete")

    record_path = work / "raw/supervisor.json"
    try:
        mutate_record(record_path, os.environ.get(
            "COLLECT_V10_MUTATE_SUPERVISOR", ""))
    except BaseException as error:
        note_error("record_adversary", error)

    enter("finalizer_enter")
    enter("raw_durable_publication")
    raw_status = 0
    try:
        for path in sorted(p for p in (work / "raw").rglob("*")
                           if p.is_file()):
            durable_republish(path, faults, "raw_" +
                              path.relative_to(work / "raw").as_posix().
                              replace("/", "_"))
        fsync_directory(work / "raw", faults, "raw_directory")
    except BaseException as error:
        raw_status = 1
        note_error("raw_durable_publication", error)

    enter("raw_seal")
    seal_status = 0
    seal_rows = []
    try:
        for path in sorted(p for p in (work / "raw").rglob("*")
                           if p.is_file()):
            relative = path.relative_to(work).as_posix()
            seal_rows.append("%s  %s\n" %
                             (hashlib.sha256(path.read_bytes()).hexdigest(),
                              relative))
        if not record_path.exists():
            seal_rows.append("ABSENT  raw/supervisor.json\n")
            seal_status = 1
        if not guarded_write("raw_seal", work / "raw.seal.sha256",
                             "".join(seal_rows)):
            seal_status = 1
    except BaseException as error:
        seal_status = 1
        note_error("raw_seal", error)

    expected_exec = [
        "/usr/bin/unshare", "--user", "--map-root-user", "--pid", "--fork",
        "--kill-child=KILL", "--mount-proc", sys.executable, "-B",
        str(package / "future-protocol/namespace-init-v8.py"),
        "--ready", str(preflight_dir.with_name(
            preflight_dir.name + ".session-ready")),
        "--go", str(preflight_dir.with_name(
            preflight_dir.name + ".session-ready.go")), "--", *command]
    expected_full = [sys.executable, "-B",
                     str(package / "future-protocol/launch-gate-v8.py"),
                     "--", *expected_exec]
    schema_status = 0
    supervisor_row = {}
    try:
        supervisor_row = load_validator(package).validate_file(
            record_path, segment_status, command, expected_full)
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
        if artifact_status == 0:
            durable_republish(artifact_output, faults, "artifact_output")
            if artifact_output.read_bytes() != reference.read_bytes():
                artifact_status = 1
    except BaseException as error:
        artifact_status = 1
        note_error("artifact_audit", error)

    enter("process_audit")
    endpoint_status = 0
    try:
        endpoint_status, endpoint_text = exact_endpoint(command)
    except BaseException as error:
        endpoint_status = 1
        endpoint_text = "audit_error=%s\n" % error
        note_error("process_audit", error)
    if not guarded_write("endpoint_audit",
                         work / "audits/final-endpoint.txt", endpoint_text):
        endpoint_status = 1

    enter("terminal_status_boundary")
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)
    drain_pending(events, first_requested, "terminal_pre_commit")
    # This empty drain is the collector terminal commit. Later signals are
    # outside the transaction and remain blocked through os._exit.
    drain_pending(events, first_requested, "terminal_pre_commit")
    enter("final_status_publication")
    signal_rows = {
        "events": events,
        "previous_signal_mask": [signal.Signals(item).name
                                 for item in previous_mask],
        "publication_signal_mask": [signal.Signals(item).name
                                     for item in HANDLED],
        "terminal_commit_linearization":
            "final_empty_blocked_signal_drain_before_durable_publication"}
    guarded_write("outer_signals", work / "outer-signals.json",
                  json.dumps(signal_rows, sort_keys=True,
                             allow_nan=False) + "\n")
    write_order("final_status")

    containment = ("cleared" if supervisor_row.get("containment_cleared")
                   else supervisor_row.get("classification", "unreadable"))
    provenance = supervisor_row.get("containment_preflight") or {}

    def decide():
        failure = bool(errors or raw_status or seal_status or schema_status or
                       artifact_status or endpoint_status or
                       segment_status == 125 or not supervisor_row or
                       (supervisor_row.get("benchmark_launched") and
                        not supervisor_row.get("containment_cleared")))
        status = (125 if failure else
                  first_requested[0]["requested_status"]
                  if first_requested[0] else segment_status)
        return int(failure), status

    cleanup_failure, final_status = decide()

    def status_text(status):
        return "".join([
            "outer_requested_signal=%s\n" % (
                "none" if first_requested[0] is None else
                first_requested[0]["signal"]),
            "outer_requested_status=%s\n" % (
                "none" if first_requested[0] is None else
                first_requested[0]["requested_status"]),
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
            "raw_durability_status=%d\n" % raw_status,
            "raw_seal_status=%d\n" % seal_status,
            "artifact_audit_status=%d\n" % artifact_status,
            "endpoint_audit_status=%d\n" % endpoint_status,
            "transaction_error_count=%d\n" % len(errors),
            "transaction_errors_json=%s\n" % json.dumps(
                errors, separators=(",", ":")),
            "cleanup_or_audit_failure=%d\n" % cleanup_failure,
            "final_status=%d\n" % status,
            "terminal_signals_blocked_through_exit=true\n",
            "durable_file_and_parent_directory_fsync=true\n",
            "primary_status_file_best_effort=true\n",
            "work_preserved=%s\n" % work])

    wrote = guarded_write("final_status", work / "final-status.txt",
                          status_text(final_status))
    if not wrote:
        cleanup_failure, final_status = 1, 125
        try:
            atomic_text(work / "final-status.txt", status_text(125), faults,
                        "final_status_retry")
        except BaseException as error:
            note_error("final_status_retry", error)
    os._exit(final_status)


if __name__ == "__main__":
    raise SystemExit(main())
