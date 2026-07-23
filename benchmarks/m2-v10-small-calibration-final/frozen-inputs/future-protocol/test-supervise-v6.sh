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
  SUPERVISE_V6_INJECT=$inject python3 -B "$dir/supervise-v6.py" \
    --timeout "$timeout" --term-grace .10 --post-kill-grace 1 \
    --quiet-interval .03 --poll .01 \
    --preflight-dir "$scratch/$label-preflight" \
    --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
    --stderr "$scratch/$label.stderr" --cwd "$scratch" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "supervise-v6 $label: expected $expected got $rc" >&2; exit 1;
  }
}

run ordinary 0 '' 2 /bin/true
run nonzero 7 '' 2 /bin/sh -c 'exit 7'
run timeout 124 '' .05 /bin/sh -c 'trap "" TERM; sleep 30'

# A copied exact-launcher manifest mismatch is deterministic unsupported/125
# and cannot create the benchmark marker.
mkdir "$scratch/preflight-copy"
cp "$dir/UNSHARE_V6.json" "$dir/containment-preflight-v6.py" \
  "$dir/namespace-init-v6.py" "$dir/process-tree-fixture-v6.py" \
  "$dir/supervise-v6.py" "$scratch/preflight-copy/"
valid=d6380bede9030d3c776ce658b40373c7edf36717ea37e4f2b4c32a8e814c6816
invalid=0000000000000000000000000000000000000000000000000000000000000000
sed "s/$valid/$invalid/" \
  "$scratch/preflight-copy/UNSHARE_V6.json" > "$scratch/bad.json"
mv "$scratch/bad.json" "$scratch/preflight-copy/UNSHARE_V6.json"
rc=0
python3 -B "$scratch/preflight-copy/supervise-v6.py" --timeout 1 \
  --term-grace .1 --post-kill-grace 1 --quiet-interval .03 --poll .01 \
  --preflight-dir "$scratch/unsupported-preflight" \
  --status "$scratch/unsupported.json" --stdout "$scratch/unsupported.stdout" \
  --stderr "$scratch/unsupported.stderr" --cwd "$scratch" -- \
  /bin/sh -c 'echo launched > "$1"' sh "$scratch/forbidden-marker" || rc=$?
[ "$rc" -eq 125 ]
[ ! -e "$scratch/forbidden-marker" ]
[ ! -e "$scratch/unsupported.stdout" ]
python3 -B - "$scratch/unsupported.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["classification"] == "preflight_unsupported"
assert not row["benchmark_launched"]
PY

# Persistent scan failure starts only after wrapper/init binding and GO. Run
# repeatedly against resistant setsid + double-fork + fork-on-TERM fixtures.
i=1
while [ "$i" -le 4 ]; do
  label=persistent-$i
  marker=v6p$i
  endpoint=$scratch/$label.endpoints
  run "$label" 125 persistent_proc_scan .08 python3 -B \
    "$dir/process-tree-fixture-v6.py" "$endpoint" "$marker"
  python3 -B - "$scratch/$label.json" "$endpoint" <<'PY'
import json, pathlib, sys
row = json.load(open(sys.argv[1]))
assert row["classification"] == "failure_cleanup_degraded_contained"
assert row["containment_cleared"] and row["benchmark_launched"]
assert row["discovery_errors"] and "persistent_proc_scan" in row["faults_triggered"]
assert set(pathlib.Path(sys.argv[2]).read_text().splitlines()[i].split(":")[0]
           for i in range(3)) == {"leader", "escape", "signal"}
for number in (15, 9):
    scopes = {item["scope"] for item in row["signals"]
              if item["signal"] == number}
    assert scopes == {"namespace_init_pidfd", "verified_wrapper_pgid",
                      "containment_wrapper_pidfd"}
assert row["kernel_containment_proof"] == {
    "namespace_init_pidfd_exit_observed": True,
    "wrapper_pidfd_exit_observed": True,
    "wrapper_wait_reaped": True}
PY
  ! pgrep -a "$marker" >/dev/null
  i=$((i + 1))
done

# Injected known-target signalling failure is recorded, later known sends and
# the kernel namespace teardown still complete, and status remains degraded.
run known-signal 125 known_signal .05 /bin/sh -c 'trap "" TERM; sleep 30'
python3 -B - "$scratch/known-signal.json" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["containment_cleared"] and row["cleanup_degraded"]
assert "known_signal" in row["faults_triggered"]
assert any(item["result"] == "sent" for item in row["signals"])
PY

# Persistent observation failure under each outer cancellation cannot change
# containment into requested-status success; degraded status 125 wins.
for spec in HUP:129 INT:130 TERM:143; do
  name=${spec%:*}; requested=${spec#*:}; label=outer-$name
  marker=v6o$name
  endpoint=$scratch/$label.endpoints
  rcfile=$scratch/$label.rc
  (
    rc=0
    SUPERVISE_V6_INJECT=persistent_proc_scan python3 -B \
      "$dir/supervise-v6.py" --timeout 30 --term-grace .1 \
      --post-kill-grace 1 --quiet-interval .03 --poll .01 \
      --preflight-dir "$scratch/$label-preflight" \
      --status "$scratch/$label.json" --stdout "$scratch/$label.stdout" \
      --stderr "$scratch/$label.stderr" --cwd "$scratch" -- python3 -B \
      "$dir/process-tree-fixture-v6.py" "$endpoint" "$marker" || rc=$?
    printf '%s\n' "$rc" > "$rcfile"
  ) & driver=$!
  deadline=0
  while [ ! -s "$endpoint" ]; do
    kill -0 "$driver" 2>/dev/null
    deadline=$((deadline + 1)); [ "$deadline" -lt 800 ]
    sleep .01
  done
  supervisor=$(pgrep -P "$driver" -f 'supervise-v6.py' | head -n 1)
  kill -"$name" "$supervisor"
  wait "$driver"
  [ "$(cat "$rcfile")" -eq 125 ]
  python3 -B - "$scratch/$label.json" "$requested" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["requested_outer_status"] == int(sys.argv[2])
assert row["containment_cleared"] and row["cleanup_degraded"]
assert row["supervisor_return_status"] == 125
PY
  ! pgrep -a "$marker" >/dev/null
done

echo 'supervise-v6 preflight/kernel-containment/persistent-failure: PASS'
