#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided scratch required}
rm -rf -- "$scratch"
mkdir -p "$scratch"

run() {
  label=$1 expected=$2 inject=$3 timeout=$4
  shift 4
  rc=0
  SUPERVISE_V8_INJECT=$inject python3 -B "$dir/supervise-v8.py" \
    --timeout "$timeout" --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v8 $label expected $expected got $rc" >&2; exit 1;
  }
}

run ordinary 0 '' 2 /bin/true
run nonzero 7 '' 2 /bin/sh -c 'exit 7'
run timeout 124 '' .05 /bin/sh -c 'trap "" TERM; sleep 30'
python3 -B - "$dir/validate-supervisor-v8.py" \
  "$scratch/ordinary.json" <<'PY'
import json, subprocess, sys
validator, record = sys.argv[1:]
row = json.load(open(record))
subprocess.run([sys.executable, '-B', validator, '--record', record,
 '--expected-status', '0', '--command-json', '["/bin/true"]',
 '--expected-full-launch-json',
 json.dumps(row['bootstrap_ownership']['full_launch_vector'])], check=True)
PY

# Acquisition failure closes the control pipe, boundedly reaps the direct
# child, and cannot exec unshare or create namespace/benchmark markers.
marker=$scratch/live-pidfd.benchmark
run live-pidfd 125 live_bootstrap_pidfd_open 2 /bin/sh -c \
  'echo launched > "$1"' sh "$marker"
[ ! -e "$marker" ]
[ ! -e "$scratch/live-pidfd-preflight.session-ready" ]
python3 -B - "$scratch/live-pidfd.json" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); p=r['bootstrap_ownership']
assert r['record_kind']=='preflight' and not r['benchmark_launched']
assert p['gate_closed_without_go'] and p['reaped_direct_child']
assert not p['unshare_exec_permitted']
PY

# Slow bootstrap still preserves identity. Stuck and exec-failing gates are
# contained and never launch the benchmark command.
rc=0
LAUNCH_GATE_V8_INJECT=slow python3 -B "$dir/supervise-v8.py" \
  --timeout 2 --term-grace .1 --post-kill-grace 1 \
  --quiet-interval .03 --poll .01 \
  --preflight-dir "$scratch/slow-preflight" --status "$scratch/slow.json" \
  --stdout "$scratch/slow.stdout" --stderr "$scratch/slow.stderr" \
  --cwd "$scratch" -- /bin/true || rc=$?
[ "$rc" -eq 0 ]
for mode in stuck exec_failure; do
  marker=$scratch/$mode.benchmark
  rc=0
  LAUNCH_GATE_V8_INJECT=$mode python3 -B "$dir/supervise-v8.py" \
    --timeout .05 --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$mode-preflight" \
    --status "$scratch/$mode.json" --stdout "$scratch/$mode.stdout" \
    --stderr "$scratch/$mode.stderr" --cwd "$scratch" -- \
    /bin/sh -c 'echo launched > "$1"' sh "$marker" || rc=$?
  [ "$rc" -eq 125 ]
  [ ! -e "$marker" ]
done

# HUP/INT/TERM, repeated and mixed signals at each terminal boundary are all
# drained before the distinct terminal commit and none may yield success.
terminal_case() {
  label=$1 phase=$2 names=$3 expected=$4
  hook=$scratch/$label-hook result=$scratch/$label-result.json
  python3 -B "$dir/supervisor-signal-driver-v8.py" \
    "$result" "$hook" "$phase" "$names" python3 -B \
    "$dir/supervise-v8.py" --timeout 2 --term-grace .1 \
    --post-kill-grace 1 --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" \
    --terminal-hook-dir "$hook" --terminal-hook-phase "$phase" -- /bin/true
  python3 -B - "$result" "$scratch/$label.json" "$expected" <<'PY'
import json, sys
result=json.load(open(sys.argv[1])); row=json.load(open(sys.argv[2]))
assert result['status']==int(sys.argv[3]) != 0
assert row['terminal_commit_reached']
assert row['classification'].startswith('cancelled_post_go_')
assert row['requested_outer_signals']
PY
}
terminal_case close-hup pidfd_close HUP 129
terminal_case class-int classification INT 130
terminal_case write-term status_write_boundary TERM 143
for phase in pidfd_close classification status_write_boundary; do
  terminal_case mixed-$phase "$phase" HUP,INT,TERM,HUP 129
done

# File and parent-directory fsync failures can never return success.
for point in status_file_fsync status_directory_fsync; do
  run fsync-$point 125 "$point" 2 /bin/true
done

echo 'supervise-v8 bootstrap/vector/terminal/signals/fsync: PASS'
