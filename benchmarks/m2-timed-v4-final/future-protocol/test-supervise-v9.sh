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
  SUPERVISE_V9_INJECT=$inject python3 -B "$dir/supervise-v9.py" \
    --timeout "$timeout" --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v9 $label expected $expected got $rc" >&2; exit 1;
  }
}

run ordinary 0 '' 2 /bin/true
run nonzero 7 '' 2 /bin/sh -c 'exit 7'
run timeout 124 '' .05 /bin/sh -c 'trap "" TERM; sleep 30'
python3 -B - "$dir/classification_status_v9.py" <<'PY'
import importlib.util, sys
spec=importlib.util.spec_from_file_location('classification_v9',sys.argv[1])
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
base={'cleanup_errors': [], 'containment_cleared': True,
      'go_committed': True, 'primary_exception': None,
      'requested_outer_signals': [], 'timed_out': False,
      'wrapper_returncode': 0}
def check(expected, **changes):
 row=base.copy(); row.update(changes); assert m.derive(row)==expected
event={'signal':'SIGINT','requested_status':130}
check(('failure_containment_uncleared',125), containment_cleared=False,
      cleanup_errors=['x'], requested_outer_signals=[event],
      primary_exception={}, timed_out=True, wrapper_returncode=7)
check(('failure_cleanup_degraded_contained',125), cleanup_errors=['x'],
      requested_outer_signals=[event], primary_exception={}, timed_out=True,
      wrapper_returncode=7)
check(('cancelled_post_go_SIGINT_contained',130),
      requested_outer_signals=[event], primary_exception={}, timed_out=True,
      wrapper_returncode=7)
check(('cancelled_pre_go_SIGINT_contained',130), go_committed=False,
      requested_outer_signals=[event])
check(('failure_exception_contained',125), primary_exception={},
      timed_out=True, wrapper_returncode=7)
check(('timeout_contained',124), timed_out=True, wrapper_returncode=7)
check(('completed_exit_nonzero',143), wrapper_returncode=-15)
check(('completed_exit_0',0))
PY
python3 -B - "$dir/validate-supervisor-v9.py" "$scratch" <<'PY'
import json, subprocess, sys
validator, scratch = sys.argv[1:]
for name, status in [('ordinary', 0), ('nonzero', 7), ('timeout', 124)]:
 record=scratch+'/'+name+'.json'; row=json.load(open(record))
 subprocess.run([sys.executable, '-B', validator, '--record', record,
  '--expected-status', str(status), '--command-json',
  json.dumps(row['command']), '--expected-full-launch-json',
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
LAUNCH_GATE_V8_INJECT=slow python3 -B "$dir/supervise-v9.py" \
  --timeout 2 --term-grace .1 --post-kill-grace 1 \
  --quiet-interval .03 --poll .01 \
  --preflight-dir "$scratch/slow-preflight" --status "$scratch/slow.json" \
  --stdout "$scratch/slow.stdout" --stderr "$scratch/slow.stderr" \
  --cwd "$scratch" -- /bin/true || rc=$?
[ "$rc" -eq 0 ]
for mode in stuck exec_failure; do
  marker=$scratch/$mode.benchmark
  rc=0
  LAUNCH_GATE_V8_INJECT=$mode python3 -B "$dir/supervise-v9.py" \
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
    "$dir/supervise-v9.py" --timeout 2 --term-grace .1 \
    --post-kill-grace 1 --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" \
    --terminal-hook-dir "$hook" --terminal-hook-phase "$phase" -- /bin/true
  python3 -B - "$result" "$scratch/$label.json" "$expected" \
    "$dir/validate-supervisor-v9.py" <<'PY'
import json, subprocess, sys
result=json.load(open(sys.argv[1])); row=json.load(open(sys.argv[2]))
assert result['status']==int(sys.argv[3]) != 0
assert row['terminal_commit_reached']
assert row['requested_outer_signals']
first=row['requested_outer_signals'][0]['signal']
assert row['classification']=='cancelled_post_go_'+first+'_contained'
subprocess.run([sys.executable,'-B',sys.argv[4],'--record',sys.argv[2],
 '--expected-status',sys.argv[3],'--command-json',json.dumps(row['command']),
 '--expected-full-launch-json',
 json.dumps(row['bootstrap_ownership']['full_launch_vector'])],check=True)
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

echo 'supervise-v9 bootstrap/vector/terminal/signals/fsync: PASS'
