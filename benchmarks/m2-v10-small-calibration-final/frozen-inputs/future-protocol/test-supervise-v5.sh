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
  python3 -B "$dir/supervise-v5.py" --timeout "$timeout" \
    --term-grace "$term" --post-kill-grace "$post" \
    --quiet-interval .03 --poll .01 \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v5 $label: expected $expected got $rc" >&2
    exit 1
  }
}

run ordinary 0 2 .1 1 /bin/true
run nonzero 7 2 .1 1 /bin/sh -c 'exit 7'
run timeout 124 .05 .1 1 /bin/sh -c 'sleep 30'

# Retain v4's immutable PID/group reuse counterexamples in the current gate.
PYTHONDONTWRITEBYTECODE=1 python3 -B - "$dir/supervise-v5.py" <<'PY'
import importlib.util
import sys
spec = importlib.util.spec_from_file_location("supervise_v5", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
supervisor = 10
new_adoptee = {50: {"pid": 50, "starttime": 200, "ppid": supervisor,
                    "pgid": 50, "sid": 50, "state": "S"}}
assert m.lineage_candidates(new_adoptee, set(), supervisor, set()) == [
    ((50, 200), "adopted_by_supervisor")]
unrelated = {
    60: {"pid": 60, "starttime": 200, "ppid": 1,
         "pgid": 60, "sid": 60, "state": "S"},
    61: {"pid": 61, "starttime": 300, "ppid": 60,
         "pgid": 60, "sid": 60, "state": "S"}}
assert m.lineage_candidates(unrelated, set(), supervisor, set()) == []
c = m.CleanupController.__new__(m.CleanupController)
c.pgid, c.active = 70, {}
c.last_snapshot = {70: {"pid": 70, "starttime": 900, "ppid": 1,
                        "pgid": 70, "sid": 70, "state": "S"}}
safe, reason, owned, foreign = c.original_group_reason()
assert not safe and reason == "skip_foreign_or_reused_group_identity"
assert owned == [] and foreign == [(70, 900)]
PY

# Retain v4's post-launch wait/scan/poll/signal exception funnel in addition
# to the new construction-boundary controls.
for point in wait proc_scan poll signal; do
  label=runtime-$point
  pidfile=$scratch/$label.pid
  rc=0
  SUPERVISE_V5_INJECT=$point python3 -B "$dir/supervise-v5.py" \
    --timeout 2 --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- \
    /bin/sh -c 'echo $$ > "$1"; trap "" TERM; sleep 30' sh "$pidfile" || rc=$?
  [ "$rc" -eq 125 ]
  [ -s "$pidfile" ]
  ! kill -0 "$(cat "$pidfile")" 2>/dev/null
  python3 -B - "$scratch/$label.json" "$point" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["cleanup_cleared"]
assert sys.argv[2] in row["faults_triggered"]
assert row["supervisor_return_status"] == 125
assert row["identity_closure_counts"]["active"] == 0
assert row["identity_closure_counts"]["uncleared"] == 0
PY
done

SUPERVISE_V5_INJECT=status_write run status-write 0 2 .1 1 /bin/true
python3 -B - "$scratch/status-write.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["cleanup_cleared"] and "status_write" in row["faults_triggered"]
PY

# Numeric preflight failures remain no-launch status-125 results.
for spec in 'nan --timeout NaN' 'zero-poll --poll 0'; do
  set -- $spec
  label=$1 option=$2 value=$3
  rc=0
  python3 -B "$dir/supervise-v5.py" --timeout 1 --term-grace 1 \
    --post-kill-grace 1 --quiet-interval .03 --poll .01 \
    "$option=$value" --status "$scratch/invalid-$label.json" \
    --stdout "$scratch/invalid-$label.stdout" \
    --stderr "$scratch/invalid-$label.stderr" --cwd "$scratch" -- \
    /bin/true || rc=$?
  [ "$rc" -eq 125 ]
  [ ! -e "$scratch/invalid-$label.stdout" ]
  [ ! -e "$scratch/invalid-$label.stderr" ]
done

# Each fallible full-session construction boundary is downstream of the
# minimal child/PID/fresh-PGID/pidfd bootstrap attachment. Every failure uses
# the ordinary bounded cleanup machine and produces the same status schema.
for point in bootstrap_attached identity_capture identity_attached \
  session_construct; do
  label=construct-$point
  rc=0
  SUPERVISE_V5_INJECT=$point python3 -B "$dir/supervise-v5.py" \
    --timeout 2 --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- \
    /bin/sh -c 'trap "" TERM; sleep 30' || rc=$?
  [ "$rc" -eq 125 ]
  python3 -B - "$scratch/$label.json" "$point" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["controller_existed_before_launch"]
assert row["subreaper_verified_before_launch"]
assert row["bootstrap_pidfd_result"].startswith("opened")
assert sys.argv[2] in row["faults_triggered"]
assert row["cleanup_cleared"] and not row["cleanup_errors"]
assert row["identity_closure_counts"]["active"] == 0
assert row["identity_closure_counts"]["uncleared"] == 0
assert row["identity_closure_counts"]["supervisor_reaped"] >= 1
PY
done

# A discovered grandchild may be reaped by its own parent. Its identity-bound
# pidfd exit observation is sufficient closure; supervisor wait ownership is
# neither fabricated nor required.
run parent-reaped 124 .30 .15 1 python3 \
  "$dir/process-tree-fixture-v5.py" parent-reaps-grandchild \
  "$scratch/parent-reaped.pids" v5parent
python3 -B - "$scratch/parent-reaped.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
matches = [item for item in row["owned_identities"]
           if item["closure_state"] == "parent_reaped/exit_observed"]
assert len(matches) == 1
assert matches[0]["origin"] == "parent_lineage"
assert matches[0]["exit_observed_by_pidfd"]
assert not matches[0]["reaped"] and not matches[0]["ever_direct_adoptee"]
assert row["cleanup_cleared"]
PY
! pgrep -a v5parent >/dev/null

# Direct adopted zombies are supervisor-waitable and must retain exact
# WNOWAIT-bound supervisor reap evidence.
run adopted-zombie 125 2 .15 1 python3 \
  "$dir/process-tree-fixture-v5.py" adopted-zombie \
  "$scratch/adopted-zombie.pids" v5adopted
python3 -B - "$scratch/adopted-zombie.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
adopted = [item for item in row["owned_identities"]
           if item["origin"] == "adopted_by_supervisor"]
assert adopted and all(item["closure_state"] == "supervisor_reaped"
                       and item["reaped"] for item in adopted)
assert row["cleanup_cleared"]
PY
! pgrep -a v5adopted >/dev/null

# Deterministically pin the v4 waitid(WNOWAIT)-to-waitpid identity race fix.
PYTHONDONTWRITEBYTECODE=1 python3 -B - "$dir/supervise-v5.py" <<'PY'
import importlib.util
import os
import types
import sys

spec = importlib.util.spec_from_file_location("supervise_v5", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
identity = (42, 900)
item = {"identity": m.identity_json(identity), "origin": "adopted_by_supervisor",
        "initial_ppid": 10, "initial_pgid": 42, "initial_sid": 42,
        "ever_direct_adoptee": True, "pidfd_number": 8,
        "pidfd_open_result": "opened_identity_verified",
        "pidfd_close_result": None, "closure_state": "active",
        "exit_observed_by_pidfd": False, "reaped": False, "pidfd": 8}
c = m.CleanupController.__new__(m.CleanupController)
c.active, c.retired, c.reaps = {identity: item}, {}, []
c.leader_identity = None
c.leader_pid = 1
c.leader_returncode = None
c.child = None
c.supervisor_pid = 10
c.cleanup_errors = []
saved_row, saved_waitid, saved_waitpid = m.proc_row, os.waitid, os.waitpid
flags = []
try:
    m.proc_row = lambda pid: {"pid": 42, "starttime": 900, "ppid": 10,
                              "pgid": 42, "sid": 42, "state": "Z"}
    def waitid(kind, pid, options):
        flags.append(options)
        return types.SimpleNamespace(si_pid=42)
    os.waitid = waitid
    os.waitpid = lambda pid, options: (42, 0)
    c.reap()
finally:
    m.proc_row, os.waitid, os.waitpid = saved_row, saved_waitid, saved_waitpid
assert flags and flags[0] & os.WNOWAIT
assert c.retired[identity]["closure_state"] == "supervisor_reaped"
assert c.reaps[0]["identity"] == {"pid": 42, "starttime": 900}
PY

# Stress the real rapid-leader-exit, double-fork, setsid escape. Each exact
# endpoint PID and comm endpoint must be absent after bounded completion.
i=1
while [ "$i" -le 10 ]; do
  marker=v5rapid$i
  run "rapid-$i" 125 2 .15 1 python3 \
    "$dir/process-tree-fixture-v5.py" rapid-double-fork-setsid \
    "$scratch/rapid-$i.pids" "$marker"
  [ -s "$scratch/rapid-$i.pids" ]
  while IFS=: read -r role pid; do
    [ "$role" = escape ]
    ! kill -0 "$pid" 2>/dev/null
  done < "$scratch/rapid-$i.pids"
  ! pgrep -a "$marker" >/dev/null
  python3 -B - "$scratch/rapid-$i.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["cleanup_cleared"]
assert row["identity_closure_counts"]["uncleared"] == 0
assert row["identity_closure_counts"]["supervisor_reaped"] >= 2
assert any(item["initial_sid"] != row["original_pgid"]
           for item in row["owned_identities"])
PY
  i=$((i + 1))
done

python3 -B - "$scratch" <<'PY'
import json, pathlib, sys
for path in pathlib.Path(sys.argv[1]).glob("*.json"):
    row = json.loads(path.read_text())
    assert row["protocol_version"] == 5
    for item in row.get("owned_identities", []):
        assert set(item["identity"]) == {"pid", "starttime"}
        assert item["closure_state"] in (
            "active", "supervisor_reaped", "parent_reaped/exit_observed",
            "uncleared")
PY

echo 'supervise-v5 bootstrap/identity-closure/WNOWAIT/escape controls: PASS'
