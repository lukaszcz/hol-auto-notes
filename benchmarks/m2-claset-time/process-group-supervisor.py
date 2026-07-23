#!/usr/bin/python3
"""Run one command in a new session and synchronously contain signals."""

import argparse
import os
import signal
import subprocess
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--events", required=True)
    parser.add_argument("--pid-file", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        parser.error("missing command after --")

    interrupted = 0
    signal_count = 0
    deadline = None
    child = None
    last_forwarded_count = 0
    termination_grace = 2.0

    def event(message: str) -> None:
        with open(args.events, "a", encoding="utf-8") as stream:
            stream.write(message + "\n")
            stream.flush()

    def forward(signum, _frame) -> None:
        nonlocal interrupted, signal_count, deadline, last_forwarded_count
        signal_count += 1
        if not interrupted:
            interrupted = signum
        forwarded = signal.SIGTERM if signal_count == 1 else signal.SIGKILL
        event(
            f"supervisor_signal received={signal.Signals(signum).name} "
            f"count={signal_count} forwarded={signal.Signals(forwarded).name}"
        )
        if child is not None and child.poll() is None:
            try:
                os.killpg(child.pid, forwarded)
            except ProcessLookupError:
                pass
            else:
                last_forwarded_count = signal_count
        deadline = time.monotonic() + termination_grace

    for caught in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(caught, forward)

    with open(args.pid_file, "w", encoding="ascii") as stream:
        stream.write(f"{os.getpid()}\n")
        stream.flush()
        os.fsync(stream.fileno())
    event(f"supervisor_start pid={os.getpid()} cwd={args.cwd}")

    child = subprocess.Popen(command, cwd=args.cwd, start_new_session=True)
    event(f"command_group_start leader={child.pid} pgid={child.pid}")
    if signal_count > last_forwarded_count:
        deferred = signal.SIGTERM if signal_count == 1 else signal.SIGKILL
        event(
            f"command_group_deferred_forward pgid={child.pid} "
            f"count={signal_count} signal={signal.Signals(deferred).name}"
        )
        try:
            os.killpg(child.pid, deferred)
        except ProcessLookupError:
            pass
        else:
            last_forwarded_count = signal_count
    while child.poll() is None:
        if interrupted and deadline is not None and time.monotonic() >= deadline:
            event(f"command_group_escalate pgid={child.pid} signal=SIGKILL")
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            deadline = time.monotonic() + termination_grace
        time.sleep(0.05)
    child_status = child.wait()

    limit = time.monotonic() + termination_grace
    while True:
        try:
            os.killpg(child.pid, 0)
        except ProcessLookupError:
            break
        if time.monotonic() >= limit:
            event(f"command_group_escalate pgid={child.pid} signal=SIGKILL")
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                break
            limit = time.monotonic() + termination_grace
        time.sleep(0.05)
    event(f"command_group_gone pgid={child.pid} result=PASS")
    if interrupted:
        normalized_status = 128 + interrupted
    elif child_status < 0:
        normalized_status = 128 - child_status
    else:
        normalized_status = child_status
    event(
        f"command_exit raw_status={child_status} "
        f"normalized_status={normalized_status}"
    )
    return normalized_status


if __name__ == "__main__":
    sys.exit(main())
