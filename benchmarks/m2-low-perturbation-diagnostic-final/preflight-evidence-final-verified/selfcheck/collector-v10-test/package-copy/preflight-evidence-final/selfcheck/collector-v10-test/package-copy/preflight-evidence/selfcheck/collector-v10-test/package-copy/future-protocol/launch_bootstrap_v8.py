#!/usr/bin/env python3
"""Atomic parent-side ownership bootstrap shared by v8 live/preflight."""
from __future__ import annotations

import os
import pathlib
import signal
import subprocess
import sys
import time


HERE = pathlib.Path(__file__).resolve().parent
GATE = HERE / "launch-gate-v8.py"


class BootstrapFailure(RuntimeError):
    def __init__(self, message, proof):
        super().__init__(message)
        self.proof = proof


def full_vector(exec_vector):
    return [sys.executable, "-B", str(GATE), "--", *exec_vector]


def close_fd(descriptor):
    if descriptor is not None:
        try:
            os.close(descriptor)
        except OSError:
            pass


def spawn_bound(exec_vector, *, cwd, stdout, stderr, faults=None,
                environment=None, fault_point="bootstrap_pidfd_open"):
    """Popen the gate; pidfd_open is the first parent action afterward."""
    injected = bool(faults is not None and hasattr(faults, "take") and
                    faults.take(fault_point))
    def injected_open(_pid, _flags):
        raise OSError("injected %s failure" % fault_point)
    opener = injected_open if injected else os.pidfd_open
    read_fd, write_fd = os.pipe()
    invocation = full_vector(exec_vector)
    child = None
    try:
        child = subprocess.Popen(
            invocation, cwd=cwd, stdin=read_fd, stdout=stdout, stderr=stderr,
            start_new_session=True, env=environment)
        # No close, identity read, hook, allocation, or namespace launch is
        # permitted between Popen's return and this acquisition attempt.
        descriptor = opener(child.pid, 0)
    except BaseException as error:
        close_fd(write_fd)
        close_fd(read_fd)
        reaped = False
        killed_stable_direct_child = False
        if child is not None:
            try:
                child.wait(timeout=.5)
                reaped = True
            except subprocess.TimeoutExpired:
                # This PID still denotes our unreaped direct child. This is
                # the sole numeric-PID fallback allowed by the v8 protocol.
                try:
                    child.send_signal(signal.SIGKILL)
                    killed_stable_direct_child = True
                except ProcessLookupError:
                    pass
                try:
                    child.wait(timeout=1)
                    reaped = True
                except subprocess.TimeoutExpired:
                    pass
        proof = {
            "benchmark_marker_absent": True,
            "gate_closed_without_go": True,
            "killed_stable_unreaped_direct_child":
                killed_stable_direct_child,
            "pidfd_bound_before_go": False,
            "reaped_direct_child": reaped,
            "unshare_exec_permitted": False,
        }
        raise BootstrapFailure("pidfd acquisition failed: %s" % error,
                               proof) from error
    close_fd(read_fd)
    return child, descriptor, write_fd, invocation


def commit_go(write_fd):
    try:
        while True:
            try:
                written = os.write(write_fd, b"G")
                break
            except InterruptedError:
                continue
        if written != 1:
            raise OSError("short gate GO write")
    finally:
        close_fd(write_fd)


def cancel_gate(write_fd, child, descriptor, timeout=.5):
    close_fd(write_fd)
    try:
        child.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        if descriptor is not None:
            try:
                signal.pidfd_send_signal(descriptor, signal.SIGKILL,
                                         None, 0)
            except ProcessLookupError:
                pass
        child.wait(timeout=1)
