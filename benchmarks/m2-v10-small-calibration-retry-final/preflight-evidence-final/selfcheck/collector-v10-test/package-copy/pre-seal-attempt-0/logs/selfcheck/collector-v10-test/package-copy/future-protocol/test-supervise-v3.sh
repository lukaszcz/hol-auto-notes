#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided scratch directory required}
rm -rf -- "$scratch"
mkdir -p "$scratch"

run() {
  label=$1 expected=$2 timeout=$3 term=$4 post=$5
  shift 5
  rc=0
  python3 "$dir/supervise-v3.py" --timeout "$timeout" \
    --term-grace "$term" --post-kill-grace "$post" \
    --quiet-interval 0.03 --poll 0.01 \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v3 $label: expected $expected, got $rc" >&2
    exit 1
  }
}

run ordinary 0 2 1 1 /bin/sh -c 'exit 0'
run nonzero 7 2 1 1 /bin/sh -c 'exit 7'
run signalled 143 2 1 1 /bin/sh -c 'kill -TERM $$'
run timeout-term 124 0.05 1 1 /bin/sh -c 'sleep 30'

# Repeat the two escape shapes enough times that fork/reparent/scan races are
# exercised rather than represented by a single convenient schedule.
i=1
while [ "$i" -le 12 ]; do
  pidfile=$scratch/setsid-$i.pid
  run setsid-$i 124 0.05 1 1 python3 \
    "$dir/process-tree-fixture-v3.py" setsid "$pidfile"
  i=$((i + 1))
done
i=1
while [ "$i" -le 12 ]; do
  pidfile=$scratch/double-$i.pid
  run double-$i 125 2 1 1 python3 \
    "$dir/process-tree-fixture-v3.py" double-fork "$pidfile"
  i=$((i + 1))
done

run linger-term 125 2 1 1 python3 \
  "$dir/process-tree-fixture-v3.py" linger-term "$scratch/linger-term.pid"
run linger-kill 125 2 0.05 1 python3 \
  "$dir/process-tree-fixture-v3.py" linger-kill "$scratch/linger-kill.pid"
run linger-uncleared 125 2 0.01 0 python3 \
  "$dir/process-tree-fixture-v3.py" linger-uncleared \
  "$scratch/linger-uncleared.pid"

python3 - "$scratch" <<'PY'
import json
import os
import pathlib
import signal
import sys

d = pathlib.Path(sys.argv[1])

def load(label):
    return json.loads((d / (label + ".json")).read_text())

for label, classification in (
    ("ordinary", "completed_exit_0"),
    ("nonzero", "completed_exit_nonzero"),
    ("signalled", "completed_exit_nonzero"),
    ("timeout-term", "timeout_term_owned_tree_cleared"),
    ("linger-term", "lifecycle_anomaly_term_owned_tree_cleared"),
    ("linger-kill", "lifecycle_anomaly_kill_owned_tree_cleared"),
):
    row = load(label)
    assert row["protocol_version"] == 3
    assert row["classification"] == classification
    assert row["group_gone"] and row["owned_pids_all_reaped"]
    assert row["pidfd_guarantee"] and row["subreaper"]
    assert row["quiet_results"][-1]["result"] == "cleared"
    assert row["quiet_results"][-1]["empty_scans"] >= 2

assert load("signalled")["leader_returncode"] == -signal.SIGTERM
uncleared = load("linger-uncleared")
assert uncleared["classification"] == "lifecycle_anomaly_owned_tree_uncleared"
assert uncleared["quiet_results"][-1]["result"] == "deadline"
for prefix in ("setsid", "double"):
    for index in range(1, 13):
        label = "%s-%d" % (prefix, index)
        row = load(label)
        expected = ("timeout_term_owned_tree_cleared" if prefix == "setsid"
                    else "lifecycle_anomaly_term_owned_tree_cleared")
        assert row["classification"] == expected
        assert row["group_gone"] and row["owned_pids_all_reaped"]
        assert any(item["initial_sid"] != row["pgid"]
                   for item in row["owned_identities"]
                   if item["initial_sid"] is not None and
                   item["pid"] != row["leader_pid"])
        assert any(item["origin"] in
                   ("parent_lineage", "adopted_by_supervisor")
                   for item in row["owned_identities"])
        escaped = int((d / (label + ".pid")).read_text())
        try:
            os.kill(escaped, 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("escaped PID survived: %d" % escaped)

assert any(item["scope"] == "owned_pidfd" and item["result"] == "sent"
           for item in load("setsid-1")["signals"])
PY

invalid() {
  label=$1 option=$2 value=$3 expected=$4
  rc=0
  python3 "$dir/supervise-v3.py" --timeout 1 --term-grace 1 \
    --post-kill-grace 1 --quiet-interval 0.03 --poll 0.01 \
    "$option=$value" --status "$scratch/invalid-$label.json" \
    --stdout "$scratch/invalid-$label.stdout" \
    --stderr "$scratch/invalid-$label.stderr" --cwd "$scratch" -- \
    /bin/true || rc=$?
  [ "$rc" -eq 125 ]
  python3 - "$scratch/invalid-$label.json" "$expected" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row == {"classification": "preflight_invalid",
               "diagnostic": sys.argv[2], "protocol_version": 3}
PY
  [ ! -e "$scratch/invalid-$label.stdout" ]
  [ ! -e "$scratch/invalid-$label.stderr" ]
}

invalid nan --timeout NaN 'timeout must be finite'
invalid posinf --term-grace +Inf 'term-grace must be finite'
invalid neginf --post-kill-grace -Inf 'post-kill-grace must be finite'
invalid zero-poll --poll 0 'poll must be positive'
invalid zero-quiet --quiet-interval 0 'quiet-interval must be positive'
invalid quiet-below-poll --quiet-interval 0.001 \
  'quiet-interval must be at least poll'

PYTHONDONTWRITEBYTECODE=1 python3 - "$dir/supervise-v3.py" \
  "$scratch/pidfd-unsupported.json" "$scratch" <<'PY'
import errno
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("supervise_v3", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.enable_subreaper = lambda: None
def unavailable():
    raise OSError(errno.ENOSYS, "pidfd unavailable regression")
module.require_pidfds = unavailable
status, cwd = sys.argv[2:]
rc = module.main([
    "--timeout", "1", "--term-grace", "1", "--post-kill-grace", "1",
    "--quiet-interval", ".03", "--poll", ".01", "--status", status,
    "--stdout", cwd + "/unsupported.stdout",
    "--stderr", cwd + "/unsupported.stderr", "--cwd", cwd,
    "--", "/bin/true",
])
assert rc == 125
row = json.load(open(status))
assert row["classification"] == "preflight_unsupported"
assert row["protocol_version"] == 3
assert "pidfd unavailable regression" in row["diagnostic"]
assert not __import__("os").path.exists(cwd + "/unsupported.stdout")
PY

echo 'supervise-v3 lineage/pidfd/lifecycle/numeric controls: PASS'
