#!/usr/bin/env python3
"""Exact syntactic and semantic validator for v7 supervisor records."""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys


HERE = pathlib.Path(__file__).resolve().parent
EXPECTATIONS = json.loads((HERE / "UNSHARE_V7.json").read_text())
SIGNALS = {"SIGHUP": (1, 129), "SIGINT": (2, 130),
           "SIGTERM": (15, 143)}


class Invalid(ValueError):
    pass


def unique_object(pairs):
    row = {}
    for key, value in pairs:
        if key in row:
            raise Invalid("duplicate JSON field: %s" % key)
        row[key] = value
    return row


def exact(row, keys, where):
    if type(row) is not dict:
        raise Invalid("%s must be object" % where)
    got, wanted = set(row), set(keys)
    if got != wanted:
        raise Invalid("%s fields missing=%s unknown=%s" %
                      (where, sorted(wanted - got), sorted(got - wanted)))


def boolean(value, where):
    if type(value) is not bool:
        raise Invalid("%s must be boolean" % where)


def integer(value, where, minimum=None):
    if type(value) is not int or (minimum is not None and value < minimum):
        raise Invalid("%s must be integer" % where)


def string(value, where, nonempty=True):
    if type(value) is not str or (nonempty and not value):
        raise Invalid("%s must be string" % where)


def identity(value, where):
    exact(value, {"pid", "starttime"}, where)
    integer(value["pid"], where + ".pid", 1)
    integer(value["starttime"], where + ".starttime", 1)


def identity_list(values, where):
    if type(values) is not list:
        raise Invalid("%s must be list" % where)
    seen = set()
    for index, value in enumerate(values):
        identity(value, "%s[%d]" % (where, index))
        key = (value["pid"], value["starttime"])
        if key in seen:
            raise Invalid("%s duplicate identity" % where)
        seen.add(key)


def close_rows(values, where, require_closed):
    if type(values) is not list:
        raise Invalid("%s must be list" % where)
    for index, value in enumerate(values):
        at = "%s[%d]" % (where, index)
        exact(value, {"os_exit_will_close", "result", "role"}, at)
        boolean(value["os_exit_will_close"], at + ".os_exit_will_close")
        string(value["result"], at + ".result")
        string(value["role"], at + ".role")
        if require_closed and value["result"] != "closed":
            raise Invalid("%s close was not successful" % at)


def validate_preflight(value):
    keys = {"classification", "cleanup_cleared", "cleanup_errors",
            "disposable_teardown_proved", "fixture_endpoint_roles",
            "launcher_options", "launcher_path", "launcher_sha256",
            "launcher_version", "namespace_init_identity_bound",
            "observed_identities", "pidfd_closes", "protocol_version"}
    exact(value, keys, "containment_preflight")
    if value["classification"] != "preflight_supported":
        raise Invalid("preflight classification")
    if value["protocol_version"] != 7:
        raise Invalid("preflight protocol version")
    for name in ("cleanup_cleared", "disposable_teardown_proved",
                 "namespace_init_identity_bound"):
        if value[name] is not True:
            raise Invalid("preflight %s false" % name)
    if value["cleanup_errors"] != []:
        raise Invalid("preflight cleanup errors")
    if value["fixture_endpoint_roles"] != ["escape", "leader", "signal"]:
        raise Invalid("preflight endpoint proof")
    for name in ("launcher_path", "launcher_sha256", "launcher_version"):
        if value[name] != EXPECTATIONS[name]:
            raise Invalid("preflight %s mismatch" % name)
    if value["launcher_options"] != EXPECTATIONS["options"]:
        raise Invalid("preflight launcher options mismatch")
    identity_list(value["observed_identities"],
                  "preflight.observed_identities")
    if len(value["observed_identities"]) < 3:
        raise Invalid("preflight identity proof incomplete")
    close_rows(value["pidfd_closes"], "preflight.pidfd_closes", True)
    roles = {row["role"] for row in value["pidfd_closes"]}
    if not {"owned", "init", "wrapper"} <= roles:
        raise Invalid("preflight close roles incomplete")


RUNTIME_KEYS = {
    "benchmark_launched", "classification", "cleanup_degraded",
    "cleanup_errors", "command", "containment_cleared",
    "containment_guarantee", "containment_kind", "containment_preflight",
    "containment_required", "discovery_errors", "elapsed_seconds",
    "ended_utc", "faults_triggered", "go_commit_linearization",
    "go_committed", "kernel_containment_proof", "launcher_invocation",
    "namespace_init_identity", "namespace_init_ready", "original_pgid",
    "pidfd_closes", "primary_exception", "protocol_version",
    "quiet_results", "reaps", "record_kind", "requested_outer_signals",
    "requested_outer_status", "scans", "signals", "started_utc",
    "supervisor_return_status", "timed_out", "wrapper_identity",
    "wrapper_returncode",
}


def validate_runtime(row, expected_status, expected_command):
    exact(row, RUNTIME_KEYS, "record")
    if row["protocol_version"] != 7 or row["record_kind"] != "runtime":
        raise Invalid("record version/kind")
    if row["supervisor_return_status"] != expected_status:
        raise Invalid("supervisor exit mismatch")
    if row["command"] != expected_command:
        raise Invalid("command mismatch")
    if (type(row["command"]) is not list or
            not all(type(item) is str and item for item in row["command"])):
        raise Invalid("command type")
    for name in ("benchmark_launched", "cleanup_degraded",
                 "containment_cleared", "containment_required",
                 "go_committed", "timed_out"):
        boolean(row[name], name)
    if row["containment_kind"] != "unprivileged_user_pid_namespace":
        raise Invalid("containment kind")
    if row["containment_required"] is not True:
        raise Invalid("containment is not mandatory")
    if row["go_commit_linearization"] != \
            "final_empty_blocked_signal_drain":
        raise Invalid("GO commit definition")
    string(row["containment_guarantee"], "containment_guarantee")
    for name in ("started_utc", "ended_utc"):
        string(row[name], name)
    if (type(row["elapsed_seconds"]) not in (int, float) or
            isinstance(row["elapsed_seconds"], bool) or
            not math.isfinite(row["elapsed_seconds"]) or
            row["elapsed_seconds"] < 0):
        raise Invalid("elapsed_seconds")
    for name in ("cleanup_errors", "discovery_errors", "faults_triggered"):
        if (type(row[name]) is not list or
                not all(type(item) is str and item for item in row[name])):
            raise Invalid("%s type" % name)
    validate_preflight(row["containment_preflight"])
    identity(row["wrapper_identity"], "wrapper_identity")
    identity(row["namespace_init_identity"], "namespace_init_identity")
    if row["wrapper_identity"] == row["namespace_init_identity"]:
        raise Invalid("wrapper/init identity collision")
    integer(row["original_pgid"], "original_pgid", 1)
    if row["original_pgid"] != row["wrapper_identity"]["pid"]:
        raise Invalid("wrapper/PGID inconsistency")
    ready = row["namespace_init_ready"]
    exact(ready, {"namespace_pid", "pid_namespace_inode",
                  "proc_pid_one_present", "protocol_version"},
          "namespace_init_ready")
    if (ready["namespace_pid"] != 1 or ready["protocol_version"] != 7 or
            ready["proc_pid_one_present"] is not True):
        raise Invalid("namespace readiness semantics")
    integer(ready["pid_namespace_inode"], "pid_namespace_inode", 1)
    if type(row["wrapper_returncode"]) is not int:
        raise Invalid("wrapper returncode")
    close_rows(row["pidfd_closes"], "pidfd_closes", True)
    if {item["role"] for item in row["pidfd_closes"]} != {
            "containment_wrapper", "namespace_init"}:
        raise Invalid("runtime close roles")

    proof = row["kernel_containment_proof"]
    exact(proof, {"all_pidfds_closed",
                  "namespace_init_pidfd_exit_observed",
                  "pidfd_close_failures", "wrapper_pidfd_exit_observed",
                  "wrapper_wait_reaped"}, "kernel_containment_proof")
    for name in ("all_pidfds_closed", "namespace_init_pidfd_exit_observed",
                 "wrapper_pidfd_exit_observed", "wrapper_wait_reaped"):
        if proof[name] is not True:
            raise Invalid("containment proof %s false" % name)
    if proof["pidfd_close_failures"] != []:
        raise Invalid("pidfd close failure proof")
    if row["containment_cleared"] is not True:
        raise Invalid("containment absent")
    if row["cleanup_degraded"] or row["cleanup_errors"]:
        raise Invalid("successful-close record is degraded")

    launch_prefix = [EXPECTATIONS["launcher_path"], *EXPECTATIONS["options"]]
    if row["launcher_invocation"][:len(launch_prefix)] != launch_prefix:
        raise Invalid("launcher invocation mismatch")
    if type(row["launcher_invocation"]) is not list or len(
            row["launcher_invocation"]) < len(launch_prefix) + 7:
        raise Invalid("launcher invocation type")

    if type(row["reaps"]) is not list:
        raise Invalid("reaps type")
    wrapper_reaps = []
    for index, value in enumerate(row["reaps"]):
        exact(value, {"identity", "role", "wait_returncode"},
              "reaps[%d]" % index)
        identity(value["identity"], "reaps[%d].identity" % index)
        integer(value["wait_returncode"], "reaps[%d].wait_returncode" % index)
        if value["role"] == "containment_wrapper":
            wrapper_reaps.append(value)
    if len(wrapper_reaps) != 1 or wrapper_reaps[0]["identity"] != row[
            "wrapper_identity"] or wrapper_reaps[0]["wait_returncode"] != row[
                "wrapper_returncode"]:
        raise Invalid("wrapper reap/identity/status inconsistency")

    events = row["requested_outer_signals"]
    if type(events) is not list:
        raise Invalid("requested signals type")
    for index, value in enumerate(events):
        exact(value, {"observed_utc", "phase", "requested_status",
                      "sequence", "signal", "signal_number"},
              "requested_outer_signals[%d]" % index)
        if value["sequence"] != index + 1 or value["signal"] not in SIGNALS:
            raise Invalid("requested signal order/enum")
        number, status = SIGNALS[value["signal"]]
        if (value["signal_number"], value["requested_status"]) != (
                number, status) or value["phase"] not in ("pre_go", "post_go"):
            raise Invalid("requested signal semantics")
        string(value["observed_utc"], "requested signal timestamp")
    expected_requested = None if not events else events[0]["requested_status"]
    if row["requested_outer_status"] != expected_requested:
        raise Invalid("requested status mismatch")

    classification = row["classification"]
    allowed = {"completed_exit_0", "completed_exit_nonzero",
               "timeout_contained", "failure_exception_contained",
               "failure_missing_wrapper_status",
               "failure_containment_uncleared",
               "failure_cleanup_degraded_contained"}
    if (classification not in allowed and
            not classification.startswith("cancelled_pre_go_") and
            not classification.startswith("cancelled_post_go_")):
        raise Invalid("classification enum")
    if classification == "completed_exit_0":
        if not (expected_status == 0 and row["wrapper_returncode"] == 0 and
                row["benchmark_launched"] and row["go_committed"] and
                not events and not row["timed_out"]):
            raise Invalid("completed exit-0 semantics")
    elif classification == "completed_exit_nonzero":
        value = row["wrapper_returncode"]
        shell = value if value >= 0 else 128 + (-value)
        if expected_status != shell or value == 0 or not row["go_committed"]:
            raise Invalid("nonzero semantics")
    elif classification == "timeout_contained":
        if expected_status != 124 or not row["timed_out"]:
            raise Invalid("timeout semantics")
    elif classification.startswith("cancelled_pre_go_"):
        if (not events or expected_status != events[0]["requested_status"] or
                row["go_committed"] or row["benchmark_launched"] or
                any(item["phase"] != "pre_go" for item in events)):
            raise Invalid("pre-GO cancellation semantics")
    elif classification.startswith("cancelled_post_go_"):
        if (not events or expected_status != events[0]["requested_status"] or
                not row["go_committed"] or not row["benchmark_launched"]):
            raise Invalid("post-GO cancellation semantics")
    elif expected_status != 125:
        raise Invalid("failure classification/status mismatch")

    # Telemetry is exact-shape too, even though it does not define success.
    for index, value in enumerate(row["signals"]):
        exact(value, {"phase", "result", "scope", "signal",
                      "target_identity", "target_pgid", "verification"},
              "signals[%d]" % index)
        integer(value["signal"], "signals[%d].signal" % index)
        for name in ("phase", "result", "scope", "verification"):
            string(value[name], "signals[%d].%s" % (index, name))
        if value["target_identity"] is not None:
            identity(value["target_identity"], "signal target identity")
        if value["target_pgid"] is not None:
            integer(value["target_pgid"], "signal target pgid", 1)
    for index, value in enumerate(row["scans"]):
        exact(value, {"known_present", "phase", "result"},
              "scans[%d]" % index)
        identity_list(value["known_present"], "scan known_present")
        string(value["phase"], "scan phase")
        if value["result"] not in ("observed", "error"):
            raise Invalid("scan result enum")
    for index, value in enumerate(row["quiet_results"]):
        exact(value, {"empty_proofs", "phase", "quiet_seconds", "result"},
              "quiet_results[%d]" % index)
        integer(value["empty_proofs"], "quiet empty proofs", 0)
        if value["result"] not in ("cleared", "deadline"):
            raise Invalid("quiet result enum")
        if type(value["quiet_seconds"]) not in (int, float):
            raise Invalid("quiet seconds type")
    if row["primary_exception"] is not None:
        exact(row["primary_exception"], {"message", "traceback", "type"},
              "primary_exception")
        for value in row["primary_exception"].values():
            if type(value) is not str:
                raise Invalid("primary exception type")


def validate_file(path, expected_status, expected_command):
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except BaseException as error:
        raise Invalid("record unreadable: %s" % error)
    if not text.endswith("\n") or text.count("\n") != 1:
        raise Invalid("record must be one newline-terminated JSON value")
    try:
        row = json.loads(text, object_pairs_hook=unique_object)
    except (json.JSONDecodeError, UnicodeError) as error:
        raise Invalid("malformed JSON: %s" % error)
    if row.get("record_kind") != "runtime":
        raise Invalid("non-runtime record cannot authorize success")
    validate_runtime(row, expected_status, expected_command)
    return row


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", required=True)
    parser.add_argument("--expected-status", type=int, required=True)
    parser.add_argument("--command-json", required=True)
    args = parser.parse_args(argv)
    try:
        command = json.loads(args.command_json)
        if type(command) is not list:
            raise Invalid("command-json must decode to list")
        validate_file(args.record, args.expected_status, command)
    except BaseException as error:
        print("validate-supervisor-v7: %s" % error, file=sys.stderr)
        return 1
    print("validate-supervisor-v7: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
