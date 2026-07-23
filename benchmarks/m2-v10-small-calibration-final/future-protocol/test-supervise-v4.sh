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
  python3 "$dir/supervise-v4.py" --timeout "$timeout" \
    --term-grace "$term" --post-kill-grace "$post" \
    --quiet-interval 0.03 --poll 0.01 \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v4 $label: expected $expected got $rc" >&2
    exit 1
  }
}

run ordinary 0 2 .1 1 /bin/true
run nonzero 7 2 .1 1 /bin/sh -c 'exit 7'
run timeout 124 .05 .1 1 /bin/sh -c 'sleep 30'
run anomaly 125 2 .1 1 python3 "$dir/process-tree-fixture-v3.py" \
  double-fork "$scratch/anomaly.pid"

# Both numeric-PID reuse counterexamples are deterministic pure-snapshot
# controls. Retired identities are intentionally absent from active seeds.
PYTHONDONTWRITEBYTECODE=1 python3 - "$dir/supervise-v4.py" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("supervise_v4", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

supervisor = 10
new_adoptee = {
    50: {"pid": 50, "starttime": 200, "ppid": supervisor,
         "pgid": 50, "sid": 50, "state": "S"},
}
got = m.lineage_candidates(new_adoptee, set(), supervisor)
assert got == [((50, 200), "adopted_by_supervisor")]

unrelated_reused_parent = {
    60: {"pid": 60, "starttime": 200, "ppid": 1,
         "pgid": 60, "sid": 60, "state": "S"},
    61: {"pid": 61, "starttime": 300, "ppid": 60,
         "pgid": 60, "sid": 60, "state": "S"},
}
assert m.lineage_candidates(unrelated_reused_parent, set(), supervisor) == []

session = m.Session.__new__(m.Session)
session.pgid = 70
session.active = {}
session.last_snapshot = {
    70: {"pid": 70, "starttime": 900, "ppid": 1,
         "pgid": 70, "sid": 70, "state": "S"},
}
safe, reason, owned, foreign = session.original_group_reason()
assert not safe and reason == "skip_foreign_or_reused_group_identity"
assert owned == [] and foreign == [(70, 900)]
PY

# Repeated live stress covers same-group, setsid, and double-fork/adoption.
i=1
while [ "$i" -le 6 ]; do
  run "setsid-$i" 124 .05 .1 1 python3 \
    "$dir/process-tree-fixture-v3.py" setsid "$scratch/setsid-$i.pid"
  run "double-$i" 125 2 .1 1 python3 \
    "$dir/process-tree-fixture-v3.py" double-fork "$scratch/double-$i.pid"
  i=$((i + 1))
done

# Every injected post-launch exception must still kill and reap the endpoint.
for point in wait proc_scan poll signal; do
  pidfile=$scratch/inject-$point.pid
  rc=0
  SUPERVISE_V4_INJECT=$point python3 "$dir/supervise-v4.py" \
    --timeout 2 --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --status "$scratch/inject-$point.json" \
    --stdout "$scratch/inject-$point.stdout" \
    --stderr "$scratch/inject-$point.stderr" --cwd "$scratch" -- \
    /bin/sh -c 'echo $$ > "$1"; trap "" TERM; sleep 30' sh "$pidfile" || rc=$?
  [ "$rc" -eq 125 ]
  [ -s "$pidfile" ]
  pid=$(cat "$pidfile")
  ! kill -0 "$pid" 2>/dev/null
  python3 - "$scratch/inject-$point.json" "$point" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["cleanup_cleared"]
assert sys.argv[2] in row["faults_triggered"]
assert row["supervisor_return_status"] == 125
PY
done

SUPERVISE_V4_INJECT=status_write run status-write 0 2 .1 1 /bin/true
python3 - "$scratch/status-write.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["cleanup_cleared"] and "status_write" in row["faults_triggered"]
PY

# Truly unwritable status media changes the supervisor result but never skips
# child cleanup; the diagnostic is delivered on the supervisor's stderr.
mkdir "$scratch/unwritable"
chmod 500 "$scratch/unwritable"
pidfile=$scratch/unwritable-child.pid
rc=0
python3 "$dir/supervise-v4.py" --timeout .05 --term-grace .1 \
  --post-kill-grace 1 --quiet-interval .03 --poll .01 \
  --status "$scratch/unwritable/status.json" \
  --stdout "$scratch/unwritable.stdout" --stderr "$scratch/unwritable.stderr" \
  --cwd "$scratch" -- /bin/sh -c 'echo $$ > "$1"; sleep 30' sh "$pidfile" \
  2> "$scratch/unwritable-supervisor.stderr" || rc=$?
chmod 700 "$scratch/unwritable"
[ "$rc" -eq 125 ]
! kill -0 "$(cat "$pidfile")" 2>/dev/null
grep -F 'status media unwritable after cleanup' \
  "$scratch/unwritable-supervisor.stderr" >/dev/null

python3 - "$scratch" <<'PY'
import json, pathlib, sys
d = pathlib.Path(sys.argv[1])
for path in d.glob("*.json"):
    row = json.loads(path.read_text())
    assert row["protocol_version"] == 4
    for item in row.get("reaps", []):
        assert set(item["identity"]) == {"pid", "starttime"}
    for field, state in (("active_identities", "active"),
                         ("retired_identities", "retired")):
        for item in row.get(field, []):
            assert item["state"] == state
            assert set(item["identity"]) == {"pid", "starttime"}
PY

echo 'supervise-v4 identity/reuse/fail-closed/stress controls: PASS'
