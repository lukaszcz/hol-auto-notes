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
  SUPERVISE_V7_INJECT=$inject python3 -B "$dir/supervise-v7.py" \
    --timeout "$timeout" --term-grace .10 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v7 $label: expected $expected got $rc" >&2; exit 1;
  }
}

run ordinary 0 '' 2 /bin/true
run nonzero 7 '' 2 /bin/sh -c 'exit 7'
run timeout 124 '' .05 /bin/sh -c 'trap "" TERM; sleep 30'
python3 -B "$dir/validate-supervisor-v7.py" \
  --record "$scratch/ordinary.json" --expected-status 0 \
  --command-json '["/bin/true"]' >/dev/null
python3 -B "$dir/validate-supervisor-v7.py" \
  --record "$scratch/nonzero.json" --expected-status 7 \
  --command-json '["/bin/sh","-c","exit 7"]' >/dev/null

# Every preflight exception edge is no-benchmark and the disposable namespace
# is cleared with bound pidfds. Close failures are unsupported, never success.
for point in preflight_after_wrapper preflight_after_init \
  preflight_status preflight_signal preflight_discovery \
  preflight_owned_pidfd_close temp_preflight_pidfd_close; do
  label=pf-$point
  marker=$scratch/$label.benchmark
  run "$label" 125 "$point" 2 /bin/sh -c \
    'echo launched > "$1"' sh "$marker"
  [ ! -e "$marker" ]
  python3 -B - "$scratch/$label.json" "$point" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["record_kind"] == "preflight"
assert row["classification"] == "preflight_unsupported"
assert not row["benchmark_launched"]
if sys.argv[2] != "temp_preflight_pidfd_close":
    proof = row["containment_preflight"]
    assert proof["cleanup_cleared"]
PY
  ! pgrep -a v7pf >/dev/null
done

# Wrapper and init close errors happen only after endpoint teardown. They are
# retained, close-before-status degrades to deterministic 125, and process
# exit is the last-resort owner only for a genuine OS close error.
for spec in init_pidfd_close:init wrapper_pidfd_close:wrapper; do
  point=${spec%:*}; role=${spec#*:}; label=close-$role
  endpoint=$scratch/$label.endpoints
  marker=v7close$role
  run "$label" 125 "$point" .05 python3 -B \
    "$dir/process-tree-fixture-v7.py" "$endpoint" "$marker"
  python3 -B - "$scratch/$label.json" "$role" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["classification"] == "failure_cleanup_degraded_contained"
assert row["containment_cleared"] and row["cleanup_degraded"]
matches = [item for item in row["pidfd_closes"]
           if sys.argv[2] in item["role"]]
assert len(matches) == 1 and matches[0]["result"] == \
       "injected_error_after_close"
assert not row["kernel_containment_proof"]["all_pidfds_closed"]
PY
  ! pgrep -a "$marker" >/dev/null
done

# Persistent observation loss still cannot suppress the bound init/wrapper
# signals or namespace teardown, and close happens before its status record.
i=1
while [ "$i" -le 2 ]; do
  label=persistent-$i marker=v7persistent$i
  endpoint=$scratch/$label.endpoints
  run "$label" 125 persistent_proc_scan .06 python3 -B \
    "$dir/process-tree-fixture-v7.py" "$endpoint" "$marker"
  python3 -B - "$scratch/$label.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["containment_cleared"] and row["cleanup_degraded"]
assert row["kernel_containment_proof"]["all_pidfds_closed"]
assert {x["role"] for x in row["pidfd_closes"]} == {
    "namespace_init", "containment_wrapper"}
assert all(x["result"] == "closed" for x in row["pidfd_closes"])
assert row["discovery_errors"]
PY
  ! pgrep -a "$marker" >/dev/null
  i=$((i + 1))
done

# Signals are blocked before readiness. At the documented commit point the
# final empty drain defines linearization. Any signal drained before it means
# no GO file and no benchmark command; distinct mixed signals preserve order.
pre_go() {
  label=$1 names=$2 expected=$3
  hook=$scratch/$label-hook
  marker=$scratch/$label.benchmark
  result=$scratch/$label-result.json
  rc=0
  python3 -B "$dir/supervisor-signal-driver-v7.py" \
    "$result" "$hook" "$names" python3 -B "$dir/supervise-v7.py" \
    --timeout 2 --term-grace .1 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" \
    --commit-hook-dir "$hook" -- /bin/sh -c \
    'echo launched > "$1"' sh "$marker" || rc=$?
  [ "$rc" -eq 0 ]
  python3 -B - "$result" "$scratch/$label.json" "$expected" <<'PY'
import json, sys
result = json.load(open(sys.argv[1])); row = json.load(open(sys.argv[2]))
assert result["status"] == int(sys.argv[3])
assert row["classification"].startswith("cancelled_pre_go_")
assert not row["go_committed"] and not row["benchmark_launched"]
assert all(item["phase"] == "pre_go"
           for item in row["requested_outer_signals"])
PY
  [ ! -e "$marker" ]
  [ ! -e "$scratch/$label-preflight.session-ready.go" ]
}
pre_go pre-hup HUP 129
pre_go pre-int INT 130
pre_go pre-term TERM 143
pre_go pre-mixed HUP,INT,TERM 129
pre_go pre-repeated-mixed HUP,HUP,INT 129
python3 -B - "$scratch/pre-mixed.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert [x["signal"] for x in row["requested_outer_signals"]] == \
       ["SIGHUP", "SIGINT", "SIGTERM"]
PY
python3 -B - "$scratch/pre-repeated-mixed.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
# Standard HUP requests may coalesce while blocked; the mixed INT remains.
assert [x["signal"] for x in row["requested_outer_signals"]] == \
       ["SIGHUP", "SIGINT"]
PY

echo 'supervise-v7 schema/preflight/close/GO/containment: PASS'
