#!/usr/bin/env python3
"""Closed syntactic/semantic validator for v9 supervisor records."""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib
import re
import sys


HERE = pathlib.Path(__file__).resolve().parent
EXPECT = json.loads((HERE / "UNSHARE_V8.json").read_text())
SIGNALS = {"SIGHUP": (1, 129), "SIGINT": (2, 130),
           "SIGTERM": (15, 143)}


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CLASSIFY = load("classification_status_v9", "classification_status_v9.py")


class Invalid(ValueError):
    pass


def reject_constant(value):
    raise Invalid("non-standard JSON numeric constant: %s" % value)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Invalid("duplicate JSON field: %s" % key)
        result[key] = value
    return result


def exact(value, keys, where):
    if type(value) is not dict:
        raise Invalid("%s must be object" % where)
    got, wanted = set(value), set(keys)
    if got != wanted:
        raise Invalid("%s fields missing=%s unknown=%s" %
                      (where, sorted(wanted - got), sorted(got - wanted)))


def boolean(value, where):
    if type(value) is not bool:
        raise Invalid("%s must be boolean" % where)


def integer(value, where, minimum=None):
    if type(value) is not int or (minimum is not None and value < minimum):
        raise Invalid("%s must be integer" % where)


def number(value, where):
    if (type(value) not in (int, float) or isinstance(value, bool) or
            not math.isfinite(value) or value < 0):
        raise Invalid("%s must be finite nonnegative number" % where)


def string(value, where, nonempty=True):
    if type(value) is not str or (nonempty and not value):
        raise Invalid("%s must be string" % where)


def strings(value, where):
    if type(value) is not list:
        raise Invalid("%s must be list" % where)
    for index, item in enumerate(value):
        string(item, "%s[%d]" % (where, index))


def identity(value, where):
    exact(value, {"pid", "starttime"}, where)
    integer(value["pid"], where + ".pid", 1)
    integer(value["starttime"], where + ".starttime", 1)


def identities(values, where):
    if type(values) is not list:
        raise Invalid("%s must be list" % where)
    seen = set()
    for index, value in enumerate(values):
        identity(value, "%s[%d]" % (where, index))
        key = (value["pid"], value["starttime"])
        if key in seen:
            raise Invalid("%s duplicate identity" % where)
        seen.add(key)


BOOTSTRAP_KEYS = {
    "bootstrap_program", "full_launch_vector",
    "go_sent_only_after_pidfd_bound", "pidfd_bound_before_go",
    "same_pid_and_pidfd_after_exec", "unshare_exec_permitted_before_pidfd",
}


def bootstrap(value, where, expected_vector=None, preflight=False):
    keys = set(BOOTSTRAP_KEYS)
    if preflight:
        keys.add("gate_child_had_no_descendants_before_go")
    exact(value, keys, where)
    string(value["bootstrap_program"], where + ".bootstrap_program")
    strings(value["full_launch_vector"], where + ".full_launch_vector")
    vector = value["full_launch_vector"]
    if (len(vector) < 4 or vector[1] != "-B" or vector[3] != "--"):
        raise Invalid("%s full launch vector gate shape" % where)
    if value["bootstrap_program"] != vector[2]:
        raise Invalid("%s bootstrap program/vector mismatch" % where)
    for name in keys - {"bootstrap_program", "full_launch_vector"}:
        boolean(value[name], where + "." + name)
    if value["unshare_exec_permitted_before_pidfd"] is not False:
        raise Invalid("%s allowed unshare before pidfd" % where)
    if expected_vector is not None and value["full_launch_vector"] != \
            expected_vector:
        raise Invalid("exact full launch vector mismatch")


def close_rows(values, where, require_closed, allow_duplicate_roles=False):
    if type(values) is not list:
        raise Invalid("%s must be list" % where)
    roles = set()
    for index, value in enumerate(values):
        at = "%s[%d]" % (where, index)
        exact(value, {"os_exit_will_close", "result", "role"}, at)
        boolean(value["os_exit_will_close"], at + ".os_exit_will_close")
        string(value["result"], at + ".result")
        string(value["role"], at + ".role")
        if value["role"] in roles and not allow_duplicate_roles:
            raise Invalid("%s duplicate role" % where)
        roles.add(value["role"])
        result = value["result"]
        expected_will_close = result.startswith("error:")
        if value["os_exit_will_close"] is not expected_will_close:
            raise Invalid("%s result/os_exit_will_close inconsistency" % at)
        if result not in ("closed", "not_open",
                          "injected_error_after_close") and not \
                result.startswith("error:"):
            raise Invalid("%s close result enum" % at)
        if require_closed and result != "closed":
            raise Invalid("%s close was not successful" % at)
    return roles


def validate_preflight(value, expected_full_launch):
    keys = {"bootstrap_ownership", "classification", "cleanup_cleared",
            "cleanup_errors", "disposable_teardown_proved",
            "fixture_endpoint_roles", "launcher_options", "launcher_path",
            "launcher_sha256", "launcher_version",
            "namespace_init_identity_bound", "observed_identities",
            "pidfd_closes", "protocol_version"}
    exact(value, keys, "containment_preflight")
    if value["classification"] != "preflight_supported":
        raise Invalid("preflight classification")
    if value["protocol_version"] != 8:
        raise Invalid("preflight protocol version")
    for name in ("cleanup_cleared", "disposable_teardown_proved",
                 "namespace_init_identity_bound"):
        if value[name] is not True:
            raise Invalid("preflight %s false" % name)
    if value["cleanup_errors"] != []:
        raise Invalid("preflight cleanup errors")
    if value["fixture_endpoint_roles"] != ["escape", "leader", "signal"]:
        raise Invalid("preflight endpoint roles")
    for name in ("launcher_path", "launcher_sha256", "launcher_version"):
        if value[name] != EXPECT[name]:
            raise Invalid("preflight %s mismatch" % name)
    if value["launcher_options"] != EXPECT["options"]:
        raise Invalid("preflight launcher options")
    identities(value["observed_identities"], "preflight.observed_identities")
    if len(value["observed_identities"]) < 3:
        raise Invalid("preflight identity proof incomplete")
    roles = close_rows(value["pidfd_closes"], "preflight.pidfd_closes", True,
                       allow_duplicate_roles=True)
    if not {"owned", "init", "wrapper"} <= roles:
        raise Invalid("preflight close roles incomplete")
    bootstrap(value["bootstrap_ownership"], "preflight.bootstrap_ownership",
              preflight=True)
    gate = value["bootstrap_ownership"]
    if not all(gate[name] for name in (
            "go_sent_only_after_pidfd_bound", "pidfd_bound_before_go",
            "same_pid_and_pidfd_after_exec",
            "gate_child_had_no_descendants_before_go")):
        raise Invalid("preflight atomic bootstrap proof")
    runtime_ready = expected_full_launch[
        expected_full_launch.index("--ready") + 1]
    suffix = ".session-ready"
    if not runtime_ready.endswith(suffix):
        raise Invalid("runtime ready path grammar")
    preflight_dir = pathlib.Path(runtime_ready[:-len(suffix)])
    package = pathlib.Path(expected_full_launch[2]).parent
    expected_prefix = [
        expected_full_launch[0], "-B", str(package / "launch-gate-v8.py"),
        "--", EXPECT["launcher_path"], *EXPECT["options"],
        expected_full_launch[0], "-B", str(package / "namespace-init-v8.py"),
        "--ready", str(preflight_dir / "init.ready"),
        "--go", str(preflight_dir / "init.go"), "--",
        expected_full_launch[0], "-B",
        str(package / "process-tree-fixture-v7.py"),
        str(preflight_dir / "fixture.endpoints")]
    preflight_vector = gate["full_launch_vector"]
    if (preflight_vector[:-1] != expected_prefix or
            not re.fullmatch(r"v8pf[0-9a-f]{8}", preflight_vector[-1])):
        raise Invalid("exact disposable-preflight launch vector")


RUNTIME_KEYS = {
    "benchmark_launched", "bootstrap_ownership", "classification",
    "cleanup_degraded", "cleanup_errors", "command", "containment_cleared",
    "containment_guarantee", "containment_kind", "containment_preflight",
    "containment_required", "discovery_errors", "elapsed_seconds",
    "ended_utc", "faults_triggered", "go_commit_linearization",
    "go_committed", "kernel_containment_proof", "launcher_invocation",
    "namespace_init_identity", "namespace_init_ready", "original_pgid",
    "pidfd_closes", "primary_exception", "protocol_version",
    "quiet_results", "reaps", "record_kind", "requested_outer_signals",
    "requested_outer_status", "scans", "signals", "started_utc",
    "status_directory_fsync_succeeded", "status_file_fsync_succeeded",
    "supervisor_return_status", "terminal_commit_linearization",
    "terminal_commit_reached", "terminal_signals_blocked_through_exit",
    "timed_out", "wrapper_identity", "wrapper_returncode",
}


def validate_runtime(row, expected_status, expected_command,
                     expected_full_launch):
    exact(row, RUNTIME_KEYS, "record")
    if row["protocol_version"] != 9 or row["record_kind"] != "runtime":
        raise Invalid("record version/kind")
    integer(row["supervisor_return_status"], "supervisor_return_status", 0)
    if row["supervisor_return_status"] != expected_status:
        raise Invalid("supervisor exit mismatch")
    if row["command"] != expected_command:
        raise Invalid("command mismatch")
    strings(row["command"], "command")
    bootstrap(row["bootstrap_ownership"], "bootstrap_ownership",
              expected_full_launch)
    gate = row["bootstrap_ownership"]
    if not all(gate[name] for name in (
            "go_sent_only_after_pidfd_bound", "pidfd_bound_before_go",
            "same_pid_and_pidfd_after_exec")):
        raise Invalid("runtime atomic bootstrap proof")
    if len(expected_full_launch) < 15 or expected_full_launch[3] != "--":
        raise Invalid("expected full launch vector shape")
    if row["launcher_invocation"] != expected_full_launch[4:]:
        raise Invalid("launcher suffix mismatch")
    strings(row["launcher_invocation"], "launcher_invocation")
    launch = row["launcher_invocation"]
    prefix = [EXPECT["launcher_path"], *EXPECT["options"]]
    if launch[:len(prefix)] != prefix:
        raise Invalid("launcher prefix mismatch")
    # Exact equality above binds interpreter, namespace init, ready/go paths,
    # separator, benchmark command, and every work-specific path.

    for name in ("benchmark_launched", "cleanup_degraded",
                 "containment_cleared", "containment_required",
                 "go_committed", "status_directory_fsync_succeeded",
                 "status_file_fsync_succeeded", "terminal_commit_reached",
                 "terminal_signals_blocked_through_exit", "timed_out"):
        boolean(row[name], name)
    if row["benchmark_launched"] is not row["go_committed"]:
        raise Invalid("benchmark/GO invariant")
    if row["containment_kind"] != "unprivileged_user_pid_namespace" or \
            row["containment_required"] is not True:
        raise Invalid("containment semantics")
    if row["go_commit_linearization"] != \
            "final_empty_blocked_signal_drain":
        raise Invalid("GO commit definition")
    if row["terminal_commit_linearization"] != \
            "final_empty_blocked_signal_drain_before_durable_status":
        raise Invalid("terminal commit definition")
    if not (row["terminal_commit_reached"] and
            row["terminal_signals_blocked_through_exit"] and
            row["status_file_fsync_succeeded"] and
            row["status_directory_fsync_succeeded"]):
        raise Invalid("terminal durable-publication proof")
    string(row["containment_guarantee"], "containment_guarantee")
    string(row["started_utc"], "started_utc")
    string(row["ended_utc"], "ended_utc")
    number(row["elapsed_seconds"], "elapsed_seconds")
    for name in ("cleanup_errors", "discovery_errors", "faults_triggered"):
        strings(row[name], name)
    validate_preflight(row["containment_preflight"], expected_full_launch)
    identity(row["wrapper_identity"], "wrapper_identity")
    identity(row["namespace_init_identity"], "namespace_init_identity")
    if row["wrapper_identity"] == row["namespace_init_identity"]:
        raise Invalid("wrapper/init identity collision")
    integer(row["original_pgid"], "original_pgid", 1)
    if row["original_pgid"] != row["wrapper_identity"]["pid"]:
        raise Invalid("wrapper/PGID invariant")
    ready = row["namespace_init_ready"]
    exact(ready, {"namespace_pid", "pid_namespace_inode",
                  "proc_pid_one_present", "protocol_version"},
          "namespace_init_ready")
    if (ready["namespace_pid"] != 1 or ready["protocol_version"] != 8 or
            ready["proc_pid_one_present"] is not True):
        raise Invalid("namespace readiness")
    integer(ready["pid_namespace_inode"], "pid namespace inode", 1)
    if type(row["wrapper_returncode"]) is not int:
        raise Invalid("wrapper returncode")
    roles = close_rows(row["pidfd_closes"], "pidfd_closes", expected_status == 0)
    if roles != {"containment_wrapper", "namespace_init"}:
        raise Invalid("runtime close roles")

    proof = row["kernel_containment_proof"]
    exact(proof, {"all_pidfds_closed",
                  "namespace_init_pidfd_exit_observed",
                  "pidfd_close_failures", "wrapper_pidfd_exit_observed",
                  "wrapper_wait_reaped"}, "kernel_containment_proof")
    for name in ("all_pidfds_closed", "namespace_init_pidfd_exit_observed",
                 "wrapper_pidfd_exit_observed", "wrapper_wait_reaped"):
        boolean(proof[name], "kernel_containment_proof." + name)
    if type(proof["pidfd_close_failures"]) is not list:
        raise Invalid("pidfd close failures type")
    actual_close_failures = [item for item in row["pidfd_closes"]
                             if item["result"] != "closed"]
    if proof["pidfd_close_failures"] != actual_close_failures:
        raise Invalid("pidfd close failure list invariant")
    if proof["all_pidfds_closed"] != (proof["pidfd_close_failures"] == []):
        raise Invalid("pidfd close proof invariant")
    if type(row["reaps"]) is not list:
        raise Invalid("reaps type")
    wrapper_reaps = []
    for index, value in enumerate(row["reaps"]):
        exact(value, {"identity", "role", "wait_returncode"},
              "reaps[%d]" % index)
        identity(value["identity"], "reaps[%d].identity" % index)
        string(value["role"], "reap role")
        integer(value["wait_returncode"], "reap returncode")
        if value["role"] == "containment_wrapper":
            wrapper_reaps.append(value)
    if len(wrapper_reaps) != 1 or wrapper_reaps[0]["identity"] != row[
            "wrapper_identity"] or wrapper_reaps[0]["wait_returncode"] != row[
                "wrapper_returncode"]:
        raise Invalid("wrapper reap invariant")

    events = row["requested_outer_signals"]
    if type(events) is not list:
        raise Invalid("requested signals type")
    for index, value in enumerate(events):
        exact(value, {"observed_utc", "phase", "requested_status",
                      "sequence", "signal", "signal_number"},
              "requested_outer_signals[%d]" % index)
        integer(value["sequence"], "requested signal sequence", 1)
        integer(value["signal_number"], "requested signal number", 1)
        integer(value["requested_status"], "requested signal status", 1)
        if value["sequence"] != index + 1 or value["signal"] not in SIGNALS:
            raise Invalid("requested signal order/enum")
        number_value, status = SIGNALS[value["signal"]]
        if (value["signal_number"], value["requested_status"]) != (
                number_value, status):
            raise Invalid("requested signal mapping")
        if value["phase"] not in ("pre_go", "post_go"):
            raise Invalid("requested signal phase")
        string(value["observed_utc"], "requested signal time")
    first = None if not events else events[0]["requested_status"]
    if row["requested_outer_status"] is not None:
        integer(row["requested_outer_status"], "requested_outer_status", 1)
    if row["requested_outer_status"] != first:
        raise Invalid("requested status invariant")
    classification = row["classification"]
    string(classification, "classification")
    expected_classification, derived_status = CLASSIFY.derive(row)
    if (classification, row["supervisor_return_status"]) != (
            expected_classification, derived_status):
        raise Invalid("classification/status derivation mismatch")
    if events:
        expected_phase = "post_go" if row["go_committed"] else "pre_go"
        if any(item["phase"] != expected_phase for item in events):
            raise Invalid("requested signal/GO phase invariant")
    if row["cleanup_degraded"] is not bool(row["cleanup_errors"]):
        raise Invalid("cleanup degradation invariant")

    if row["primary_exception"] is not None:
        exact(row["primary_exception"], {"message", "traceback", "type"},
              "primary_exception")
        for name, value in row["primary_exception"].items():
            string(value, "primary_exception." + name, nonempty=False)

    if type(row["signals"]) is not list:
        raise Invalid("signals type")
    degraded_signal = False
    for index, value in enumerate(row["signals"]):
        exact(value, {"phase", "result", "scope", "signal",
                      "target_identity", "target_pgid", "verification"},
              "signals[%d]" % index)
        integer(value["signal"], "signal number", 1)
        for name in ("phase", "result", "scope", "verification"):
            string(value[name], "signal." + name)
        if value["target_identity"] is not None:
            identity(value["target_identity"], "signal target")
        if value["target_pgid"] is not None:
            integer(value["target_pgid"], "signal pgid", 1)
        result = value["result"]
        if value["scope"] not in {"namespace_init_pidfd",
                                  "verified_wrapper_pgid",
                                  "containment_wrapper_pidfd"}:
            raise Invalid("signal scope enum")
        allowed_results = {"sent", "ESRCH", "already_dead",
                           "wrapper_identity_not_live",
                           "wrapper_pidfd_and_snapshot_verified",
                           "wrapper_pidfd_and_launch_pgid_verified"}
        if result not in allowed_results and not result.startswith("error:"):
            raise Invalid("signal result enum")
        if value["scope"] == "verified_wrapper_pgid":
            if (value["target_identity"] is not None or
                    value["target_pgid"] != row["original_pgid"] or
                    value["verification"] not in {
                        "wrapper_identity_not_live",
                        "wrapper_pidfd_and_snapshot_verified",
                        "wrapper_pidfd_and_launch_pgid_verified"}):
                raise Invalid("PGID signal cross-field invariant")
        elif (value["target_identity"] is None or
              value["target_pgid"] is not None or
              value["verification"] != "pidfd"):
            raise Invalid("pidfd signal cross-field invariant")
        if result.startswith("error:") or result == "not_bound":
            degraded_signal = True
    if type(row["scans"]) is not list:
        raise Invalid("scans type")
    scan_error = False
    for index, value in enumerate(row["scans"]):
        exact(value, {"known_present", "phase", "result"},
              "scans[%d]" % index)
        identities(value["known_present"], "scan known_present")
        string(value["phase"], "scan phase")
        if value["result"] not in ("observed", "error"):
            raise Invalid("scan result enum")
        scan_error = scan_error or value["result"] == "error"
    if type(row["quiet_results"]) is not list or len(
            row["quiet_results"]) != 1:
        raise Invalid("quiet results type/empty")
    quiet_bad = False
    for index, value in enumerate(row["quiet_results"]):
        exact(value, {"empty_proofs", "phase", "quiet_seconds", "result"},
              "quiet_results[%d]" % index)
        integer(value["empty_proofs"], "quiet empty proofs", 0)
        string(value["phase"], "quiet phase")
        number(value["quiet_seconds"], "quiet seconds")
        if value["result"] not in ("cleared", "deadline"):
            raise Invalid("quiet result enum")
        quiet_bad = quiet_bad or value["result"] != "cleared"
        if value["phase"] != "kernel-containment-quiet":
            raise Invalid("quiet phase enum")
        if value["result"] == "cleared" and value["empty_proofs"] < 2:
            raise Invalid("quiet cleared proof count")

    # Success is unavailable if any telemetry channel records degradation,
    # even when headline lifecycle fields were forged to look successful.
    if expected_status == 0 and (row["cleanup_degraded"] or
            row["cleanup_errors"] or row["discovery_errors"] or
            row["faults_triggered"] or degraded_signal or scan_error or
            quiet_bad or not proof["all_pidfds_closed"] or
            proof["pidfd_close_failures"] or
            not proof["namespace_init_pidfd_exit_observed"] or
            not proof["wrapper_pidfd_exit_observed"] or
            not proof["wrapper_wait_reaped"] or
            row["primary_exception"] is not None):
        raise Invalid("success telemetry degradation")


def validate_file(path, expected_status, expected_command,
                  expected_full_launch):
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except BaseException as error:
        raise Invalid("record unreadable: %s" % error)
    if not text.endswith("\n") or text.count("\n") != 1:
        raise Invalid("record must be one newline-terminated JSON value")
    try:
        row = json.loads(text, object_pairs_hook=unique_object,
                         parse_constant=reject_constant)
    except (json.JSONDecodeError, UnicodeError) as error:
        raise Invalid("malformed JSON: %s" % error)
    if type(row) is not dict or row.get("record_kind") != "runtime":
        raise Invalid("non-runtime record cannot authorize success")
    validate_runtime(row, expected_status, expected_command,
                     expected_full_launch)
    return row


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", required=True)
    parser.add_argument("--expected-status", type=int, required=True)
    parser.add_argument("--command-json", required=True)
    parser.add_argument("--expected-full-launch-json", required=True)
    args = parser.parse_args(argv)
    try:
        command = json.loads(args.command_json, parse_constant=reject_constant)
        launch = json.loads(args.expected_full_launch_json,
                            parse_constant=reject_constant)
        if type(command) is not list or type(launch) is not list:
            raise Invalid("expected vectors must decode to lists")
        validate_file(args.record, args.expected_status, command, launch)
    except BaseException as error:
        print("validate-supervisor-v9: %s" % error, file=sys.stderr)
        return 1
    print("validate-supervisor-v9: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
