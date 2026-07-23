#!/usr/bin/env python3
"""Future v10 supervisor: strict integer schema and shared derivation."""
from __future__ import annotations

import argparse
import ctypes
import datetime
import errno
import importlib.util
import json
import math
import os
import pathlib
import signal
import subprocess
import sys
import time
import traceback


HERE = pathlib.Path(__file__).resolve().parent
HANDLED = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
SIGNAL_STATUS = {signal.SIGHUP: 129, signal.SIGINT: 130,
                 signal.SIGTERM: 143}
PR_SET_CHILD_SUBREAPER = 36
PR_GET_CHILD_SUBREAPER = 37


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


V7 = load("supervise_v7_base", "supervise-v7.py")
BOOTSTRAP = load("launch_bootstrap_v8", "launch_bootstrap_v8.py")
CLASSIFY = load("classification_status_v9", "classification_status_v9.py")
STRICT_INTEGER = load("strict_integer_v10", "strict_integer_v10.py")


class PreflightError(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise PreflightError(message)


class Faults:
    def __init__(self):
        self.pending = {item for item in os.environ.get(
            "SUPERVISE_V10_INJECT", "").split(",") if item}
        self.triggered = []
        self.runtime_armed = False

    def arm(self):
        self.runtime_armed = True

    def take(self, name):
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            return True
        return False

    def hit(self, name):
        if (name == "proc_scan" and
                "persistent_proc_scan" in self.pending and
                self.runtime_armed):
            if "persistent_proc_scan" not in self.triggered:
                self.triggered.append("persistent_proc_scan")
            raise RuntimeError("injected persistent proc_scan failure")
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            raise RuntimeError("injected %s failure" % name)

    def inject_close(self, name):
        if name in self.pending:
            self.pending.remove(name)
            self.triggered.append(name)
            return True
        return False


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def status_argument(argv):
    for index, item in enumerate(argv):
        if item == "--status" and index + 1 < len(argv):
            return argv[index + 1]
        if item.startswith("--status="):
            return item.split("=", 1)[1]
    return None


def atomic_json(path, row, faults=None):
    target = pathlib.Path(path)
    temporary = target.with_name(target.name + ".tmp.%d" % os.getpid())
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(row, stream, sort_keys=True, allow_nan=False)
            stream.write("\n")
            stream.flush()
            if faults is not None:
                faults.hit("status_file_fsync")
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        descriptor = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            if faults is not None:
                faults.hit("status_directory_fsync")
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise


def preflight_record(path, diagnostic, classification, provenance=None,
                     bootstrap=None):
    row = {"benchmark_launched": False, "bootstrap_ownership": bootstrap,
           "classification": classification,
           "containment_preflight": provenance, "diagnostic": diagnostic,
            "protocol_version": 10, "record_kind": "preflight",
           "supervisor_return_status": 125}
    try:
        if path:
            atomic_json(path, row)
            return
    except BaseException as error:
        diagnostic += "; status_write=%s" % error
    print("supervise-v10: %s" % diagnostic, file=sys.stderr)


def enable_and_verify_subreaper():
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))
    state = ctypes.c_int()
    if libc.prctl(PR_GET_CHILD_SUBREAPER, ctypes.byref(state), 0, 0, 0) != 0:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number))
    if state.value != 1:
        raise OSError(errno.ENOTSUP, "subreaper state did not persist")


def require_pidfds(faults, closes):
    if not hasattr(os, "pidfd_open") or not hasattr(signal,
                                                     "pidfd_send_signal"):
        raise OSError(errno.ENOSYS, "Python pidfd API unavailable")
    descriptor = os.pidfd_open(os.getpid(), 0)
    errors = []
    V7.close_once("temp_preflight", descriptor, faults.inject_close(
        "temp_preflight_pidfd_close"), closes, errors)
    if errors:
        raise OSError(errno.EIO, errors[0])


def load_preflight():
    return load("containment_preflight_v8", "containment-preflight-v8.py")


class Controller(V7.Controller):
    def attach_bound_gate(self, child, descriptor):
        self.wrapper = child
        self.pgid = child.pid
        self.wrapper_pidfd = descriptor
        row = V7.proc_row(child.pid)
        if row is None:
            raise RuntimeError("launch gate vanished before identity bind")
        self.wrapper_identity = (child.pid, row["starttime"])

    def bind_init_v8(self, ready):
        deadline = time.monotonic() + 3
        while not ready.exists():
            if self.wrapper.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("namespace init readiness failed")
            time.sleep(.005)
        self.namespace_ready = json.loads(ready.read_text())
        mutation = os.environ.get("SUPERVISE_V10_MUTATE_READY", "")
        if mutation:
            field, kind = mutation.rsplit("_", 1)
            if field not in self.namespace_ready or kind not in {
                    "bool", "float"}:
                raise RuntimeError("unknown readiness mutation")
            value = self.namespace_ready[field]
            self.namespace_ready[field] = (bool(value) if kind == "bool"
                                           else float(value))
        snapshot = V7.proc_snapshot()
        candidates = [row for row in snapshot.values()
                      if row["ppid"] == self.wrapper.pid]
        if len(candidates) != 1:
            raise RuntimeError("namespace init host identity is not unique")
        init = candidates[0]
        self.init_identity = (init["pid"], init["starttime"])
        self.init_pidfd = os.pidfd_open(init["pid"], 0)
        verify = V7.proc_row(init["pid"])
        if verify is None or verify["starttime"] != init["starttime"]:
            raise RuntimeError("namespace init identity changed during bind")
        self.last_snapshot = snapshot
        # Bind identity and pidfd before interpreting fallible readiness
        # semantics, so every malformed record still has exact containment.
        if set(self.namespace_ready) != {
                "namespace_pid", "pid_namespace_inode",
                "proc_pid_one_present", "protocol_version"}:
            raise RuntimeError("namespace init semantic proof failed")
        try:
            STRICT_INTEGER.require(
                self.namespace_ready["protocol_version"],
                "namespace_init_ready.protocol_version", literal=8)
            STRICT_INTEGER.require(
                self.namespace_ready["namespace_pid"],
                "namespace_init_ready.namespace_pid", literal=1)
            STRICT_INTEGER.require(
                self.namespace_ready["pid_namespace_inode"],
                "namespace_init_ready.pid_namespace_inode", minimum=1)
        except ValueError as error:
            raise RuntimeError(str(error))
        if type(self.namespace_ready["proc_pid_one_present"]) is not bool or \
                self.namespace_ready["proc_pid_one_present"] is not True:
            raise RuntimeError("namespace init proc PID 1 proof failed")


def parse_args(argv):
    parser = Parser()
    for name in ("timeout", "term-grace", "post-kill-grace"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--quiet-interval", default=".05")
    parser.add_argument("--poll", default=".01")
    parser.add_argument("--status", required=True)
    parser.add_argument("--stdout", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--preflight-dir", required=True)
    parser.add_argument("--ready")
    parser.add_argument("--go-hook-dir")
    parser.add_argument("--terminal-hook-dir")
    parser.add_argument("--terminal-hook-phase")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if not args.command or args.command[0] != "--" or len(args.command) == 1:
        raise PreflightError("command must follow --")
    for name in ("timeout", "term_grace", "post_kill_grace",
                 "quiet_interval", "poll"):
        try:
            value = float(getattr(args, name))
        except ValueError:
            raise PreflightError("%s must be a finite number" %
                                 name.replace("_", "-"))
        if not math.isfinite(value):
            raise PreflightError("%s must be finite" % name.replace("_", "-"))
        setattr(args, name, value)
    if min(args.timeout, args.term_grace, args.post_kill_grace) < 0:
        raise PreflightError("timeouts must be nonnegative")
    if args.poll <= 0 or args.quiet_interval < args.poll:
        raise PreflightError("poll/quiet-interval relationship invalid")
    return args


def signal_event(signum, sequence, phase):
    return {"observed_utc": utc_now(), "phase": phase,
            "requested_status": SIGNAL_STATUS[signum],
            "sequence": sequence, "signal": signal.Signals(signum).name,
            "signal_number": signum}


def drain_pending(events, phase):
    while True:
        info = signal.sigtimedwait(HANDLED, 0)
        if info is None:
            break
        events.append(signal_event(info.si_signo, len(events) + 1, phase))


def wait_hook(directory, name):
    if not directory:
        return
    hook = pathlib.Path(directory)
    hook.mkdir(parents=True, exist_ok=True)
    (hook / (name + ".ready")).write_text("ready\n", encoding="ascii")
    deadline = time.monotonic() + 8
    while not (hook / (name + ".release")).exists():
        if time.monotonic() >= deadline:
            raise RuntimeError("%s hook timeout" % name)
        time.sleep(.005)


def classification_record(controller, cleared, cancellation,
                          primary_exception, timed_out):
    return {
        "cleanup_errors": controller.cleanup_errors,
        "containment_cleared": cleared,
        "go_committed": controller.go_committed,
        "primary_exception": primary_exception,
        "requested_outer_signals": cancellation,
        "timed_out": timed_out,
        "wrapper_returncode": controller.wrapper_returncode,
    }


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    status_path = status_argument(argv)
    temp_closes = []
    try:
        args = parse_args(argv)
        faults = Faults()
        enable_and_verify_subreaper()
        require_pidfds(faults, temp_closes)
    except PreflightError as error:
        preflight_record(status_path, str(error), "preflight_invalid")
        return 125
    except BaseException as error:
        preflight_record(status_path, str(error), "preflight_unsupported")
        return 125
    try:
        provenance = load_preflight().proof(args.preflight_dir, faults)
    except BaseException as error:
        provenance = getattr(error, "provenance", None)
        preflight_record(args.status, "%s: %s" %
                         (type(error).__name__, error),
                         "preflight_unsupported", provenance)
        return 125
    try:
        controller = Controller(args.poll, args.quiet_interval, faults,
                                provenance)
    except BaseException as error:
        preflight_record(args.status, "controller bootstrap failed: %s" %
                         error, "preflight_failed", provenance)
        return 125

    cancellation = []
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)
    for number in HANDLED:
        signal.signal(number, lambda signum, _frame: cancellation.append(
            signal_event(signum, len(cancellation) + 1,
                         "post_go" if controller.go_committed else "pre_go")))
    if args.ready:
        try:
            pathlib.Path(args.ready).write_text("ready\n", encoding="ascii")
        except BaseException as error:
            preflight_record(args.status, "ready publication failed: %s" %
                             error, "preflight_failed", provenance)
            return 125

    started, started_utc = time.monotonic(), utc_now()
    timed_out = False
    primary_exception = None
    pre_go_cancelled = False
    ready = pathlib.Path(args.preflight_dir).with_name(
        pathlib.Path(args.preflight_dir).name + ".session-ready")
    go = ready.with_name(ready.name + ".go")
    exec_vector = [
        provenance["launcher_path"], *provenance["launcher_options"],
        sys.executable, "-B", str(HERE / "namespace-init-v8.py"),
        "--ready", str(ready), "--go", str(go), "--", *args.command[1:]]
    full_vector = BOOTSTRAP.full_vector(exec_vector)
    gate_write = None
    bootstrap_ownership = {
        "bootstrap_program": str(HERE / "launch-gate-v8.py"),
        "full_launch_vector": full_vector,
        "go_sent_only_after_pidfd_bound": False,
        "pidfd_bound_before_go": False,
        "same_pid_and_pidfd_after_exec": False,
        "unshare_exec_permitted_before_pidfd": False,
    }
    try:
        with open(args.stdout, "xb") as stdout, open(
                args.stderr, "xb") as stderr:
            child, descriptor, gate_write, actual = BOOTSTRAP.spawn_bound(
                exec_vector, cwd=args.cwd, stdout=stdout, stderr=stderr,
                faults=faults, fault_point="live_bootstrap_pidfd_open")
            bootstrap_ownership["full_launch_vector"] = actual
            bootstrap_ownership["pidfd_bound_before_go"] = True
            controller.attach_bound_gate(child, descriptor)
            bound_identity = controller.wrapper_identity
            BOOTSTRAP.commit_go(gate_write)
            gate_write = None
            bootstrap_ownership["go_sent_only_after_pidfd_bound"] = True
            controller.bind_init_v8(ready)
            bootstrap_ownership["same_pid_and_pidfd_after_exec"] = (
                controller.wrapper_identity == bound_identity and
                not V7.pidfd_dead(controller.wrapper_pidfd))
            wait_hook(args.go_hook_dir, "go_commit")
            drain_pending(cancellation, "pre_go")
            if cancellation:
                pre_go_cancelled = True
            else:
                temporary = go.with_name(go.name + ".tmp.%d" % os.getpid())
                temporary.write_text("go\n", encoding="ascii")
                os.replace(temporary, go)
                descriptor_dir = os.open(go.parent,
                                         os.O_RDONLY | os.O_DIRECTORY)
                try:
                    os.fsync(descriptor_dir)
                finally:
                    os.close(descriptor_dir)
                controller.go_committed = True
                controller.benchmark_launched = True
                faults.arm()
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            if not pre_go_cancelled:
                deadline = time.monotonic() + args.timeout
                while child.poll() is None and not cancellation:
                    controller.observe("runtime-wait")
                    if time.monotonic() >= deadline:
                        timed_out = True
                        break
                    time.sleep(min(args.poll,
                                   max(0, deadline - time.monotonic())))
    except BaseException as error:
        if gate_write is not None:
            os.close(gate_write)
        primary_exception = {
            "message": str(error),
            "traceback": "".join(traceback.format_exception_only(
                type(error), error)).strip(),
            "type": type(error).__name__}
        proof = getattr(error, "proof", None)
        if proof:
            bootstrap_ownership.update(proof)
        if controller.wrapper is None:
            preflight_record(args.status, "launcher bootstrap failed: %s" %
                             error, "launch_failed", provenance,
                             bootstrap_ownership)
            return 125
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)

    cleared = V7.cleanup(controller, args)
    signal.pthread_sigmask(signal.SIG_BLOCK, HANDLED)
    def terminal_hook(name):
        if args.terminal_hook_phase == name:
            wait_hook(args.terminal_hook_dir, name)

    terminal_hook("pidfd_close")
    drain_pending(cancellation, "post_go" if controller.go_committed else
                  "pre_go")
    controller.close_pidfds()
    terminal_hook("classification")
    drain_pending(cancellation, "post_go" if controller.go_committed else
                  "pre_go")
    # The status-write-boundary hook is deliberately before the terminal
    # commit. Every queued HUP/INT/TERM here must affect classification.
    terminal_hook("status_write_boundary")
    drain_pending(cancellation, "post_go" if controller.go_committed else
                  "pre_go")
    classification_value, return_status = CLASSIFY.derive(
        classification_record(controller, cleared, cancellation,
                              primary_exception, timed_out))
    # This final empty drain is the terminal-status commit. Signals generated
    # after it are outside the completed transaction; they stay blocked until
    # the durable replace and immediate os._exit.
    drain_pending(cancellation, "post_go" if controller.go_committed else
                  "pre_go")
    classification_value, return_status = CLASSIFY.derive(
        classification_record(controller, cleared, cancellation,
                              primary_exception, timed_out))
    degraded = bool(controller.cleanup_errors)
    first_status = (None if not cancellation else
                    cancellation[0]["requested_status"])

    proof = {
        "all_pidfds_closed": controller.close_complete and not any(
            item["result"] != "closed" for item in controller.pidfd_closes),
        "namespace_init_pidfd_exit_observed": cleared,
        "pidfd_close_failures": [item for item in controller.pidfd_closes
                                 if item["result"] != "closed"],
        "wrapper_pidfd_exit_observed": cleared,
        "wrapper_wait_reaped": controller.wrapper_returncode is not None,
    }
    record = {
        "benchmark_launched": controller.benchmark_launched,
        "bootstrap_ownership": bootstrap_ownership,
        "classification": classification_value,
        "cleanup_degraded": degraded,
        "cleanup_errors": controller.cleanup_errors,
        "command": args.command[1:], "containment_cleared": cleared,
        "containment_guarantee": (
            "pinned unshare kills namespace PID 1 and every member"),
        "containment_kind": "unprivileged_user_pid_namespace",
        "containment_preflight": provenance, "containment_required": True,
        "discovery_errors": controller.discovery_errors,
        "elapsed_seconds": round(time.monotonic() - started, 9),
        "ended_utc": utc_now(), "faults_triggered": faults.triggered,
        "go_commit_linearization": "final_empty_blocked_signal_drain",
        "go_committed": controller.go_committed,
        "kernel_containment_proof": proof,
        "launcher_invocation": exec_vector,
        "namespace_init_identity": V7.identity_json(controller.init_identity),
        "namespace_init_ready": controller.namespace_ready,
        "original_pgid": controller.pgid,
        "pidfd_closes": controller.pidfd_closes,
        "primary_exception": primary_exception,
        "protocol_version": 10, "quiet_results": controller.quiet_results,
        "reaps": controller.reaps, "record_kind": "runtime",
        "requested_outer_signals": cancellation,
        "requested_outer_status": first_status, "scans": controller.scans,
        "signals": controller.signals, "started_utc": started_utc,
        "status_directory_fsync_succeeded": True,
        "status_file_fsync_succeeded": True,
        "supervisor_return_status": return_status,
        "terminal_commit_linearization":
            "final_empty_blocked_signal_drain_before_durable_status",
        "terminal_commit_reached": True,
        "terminal_signals_blocked_through_exit": True,
        "timed_out": timed_out,
        "wrapper_identity": V7.identity_json(controller.wrapper_identity),
        "wrapper_returncode": controller.wrapper_returncode,
    }
    try:
        atomic_json(args.status, record, faults)
    except BaseException as error:
        print("supervise-v10: durable status publication failed: %s" % error,
              file=sys.stderr)
        return_status = 125
    os._exit(return_status)


if __name__ == "__main__":
    raise SystemExit(main())
