#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v4-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

run_synthetic() {
  label=$1 expected=$2
  shift 2
  work=$base/$label
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]4-synthetic-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v4.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    "$package/future-protocol/collect-v4.sh" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ]
  [ -f "$work/raw.seal.sha256" ]
  (cd "$work" && sha256sum -c raw.seal.sha256) >/dev/null
  grep -Fx 'supervisor_started=true' "$work/final-status.txt" >/dev/null
  ! grep -F '=not_run' "$work/final-status.txt" >/dev/null
  grep -Fx "actual_supervisor_status=$expected" \
    "$work/final-status.txt" >/dev/null
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
  printf '%s\n' supervisor_started supervisor_wait_complete raw_seal \
    artifact_audit process_audit final_status > "$base/expected-order"
  cmp "$base/expected-order" "$work/finalization-order.txt"
}

run_synthetic ordinary 0 /bin/true
run_synthetic nonzero 7 /bin/sh -c 'exit 7'

signal_case() {
  label=$1 sig=$2 expected=$3 mode=$4 repeats=$5
  work=$base/$label
  pidfile=$base/$label.pids
  result=$base/$label-result.json
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN="[v]4e-$label" \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v4.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv SEGMENT_TIMEOUT=30 \
    TERM_GRACE=.2 POST_KILL_GRACE=1 QUIET_INTERVAL=.03 POLL_INTERVAL=.01 \
    python3 "$package/future-protocol/collector-signal-driver-v4.py" \
    "$result" "$work" "$pidfile" "$sig" "$repeats" \
    "$package/future-protocol/collect-v4.sh" -- python3 \
    "$package/future-protocol/process-tree-fixture-v4.py" "$mode" \
    "$pidfile" "v4e-$label"
  python3 - "$result" "$expected" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["status"] == int(sys.argv[2])
assert row["elapsed"] < 4
PY
  grep -Fx "outer_requested_signal=$sig" "$work/final-status.txt" >/dev/null
  grep -Fx "outer_requested_status=$expected" "$work/final-status.txt" \
    >/dev/null
  grep -Fx "actual_supervisor_status=$expected" "$work/final-status.txt" \
    >/dev/null
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
  ! grep -F '=not_run' "$work/final-status.txt" >/dev/null
  printf '%s\n' supervisor_started supervisor_wait_complete raw_seal \
    artifact_audit process_audit final_status > "$base/expected-order"
  cmp "$base/expected-order" "$work/finalization-order.txt"
  while IFS= read -r pid; do ! kill -0 "$pid" 2>/dev/null; done < "$pidfile"
  python3 - "$work/raw/supervisor.json" "$expected" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["cleanup_cleared"]
assert row["requested_outer_status"] == int(sys.argv[2])
assert row["supervisor_return_status"] == int(sys.argv[2])
PY
}

signal_case hup HUP 129 same-group-resistant 1
signal_case int INT 130 setsid-resistant 1
signal_case term TERM 143 double-fork-resistant 1
signal_case repeated TERM 143 same-group-resistant 2
count=$(sed -n 's/^outer_signal_count=//p' \
  "$base/repeated/final-status.txt")
[ "$count" -ge 2 ]

# A supervisor cleanup degradation and an artifact mismatch both override an
# otherwise possible success with status 125.
SUPERVISE_V4_INJECT=signal run_synthetic cleanup-failure 125 \
  /bin/sh -c 'trap "" TERM; sleep 30'
grep -Fx 'cleanup_or_audit_failure=1' \
  "$base/cleanup-failure/final-status.txt" >/dev/null

printf '%s\n' drift > "$base/drift.tsv"
work=$base/artifact-failure
rc=0
ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
  SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]4-artifact-no-match' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v4.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/drift.tsv \
  "$package/future-protocol/collect-v4.sh" -- /bin/true || rc=$?
[ "$rc" -eq 125 ]
grep -Fx 'actual_supervisor_status=0' "$work/final-status.txt" >/dev/null
grep -Fx 'artifact_audit_status=1' "$work/final-status.txt" >/dev/null
grep -Fx 'final_status=125' "$work/final-status.txt" >/dev/null

# Shared path validator positives: original and copied packages, clean env,
# with copied package and work as disjoint scratch-root siblings.
real_case() {
  label=$1 test_package=$2
  ref_work=$base/$label-ref-work
  mkdir -p "$ref_work/tmp" "$ref_work/audits"
  reference=$ref_work/audits/reference.tsv
  env -i PATH="$PATH" HOME="${HOME:-/}" \
    "$test_package/future-protocol/audit-artifacts-v4.sh" \
    --root "$root" --package-dir "$test_package" \
    --scratch-root "$scratch_root" --work "$ref_work" \
    --scratch-dir "$ref_work/tmp" --output "$reference"
  work=$base/$label-work
  env -i PATH="$PATH" HOME="${HOME:-/}" ROOT="$root" \
    PACKAGE_DIR="$test_package" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[v]4-real-no-match' \
    ARTIFACT_REFERENCE="$reference" \
    "$test_package/future-protocol/collect-v4.sh" -- /bin/true
  cmp "$reference" "$work/audits/final-artifacts.tsv"
}
real_case original "$package"
copy=$base/package-copy
cp -a "$package" "$copy"
real_case copy "$copy"

reject_path() {
  label=$1 test_root=$2 test_package=$3 work=$4
  marker=$base/$label-marker
  printf '%s\n' preserved > "$marker"
  rc=0
  env -i PATH="$PATH" HOME="${HOME:-/}" ROOT="$test_root" \
    PACKAGE_DIR="$test_package" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[v]4-reject-no-match' \
    ARTIFACT_REFERENCE="$base/reference.tsv" \
    "$package/future-protocol/collect-v4.sh" -- /bin/true \
    > "$base/$label.stdout" 2> "$base/$label.stderr" || rc=$?
  [ "$rc" -eq 2 ]
  [ ! -e "$work" ]
  [ "$(cat "$marker")" = preserved ]
}

fake_root=$base/fake-root
mkdir -p "$fake_root"
reject_path root-overlap "$fake_root" "$package" "$fake_root/work"
reject_path package-overlap "$root" "$copy" "$copy/work"
ln -s "$copy" "$base/package-alias"
reject_path symlink-package-alias "$root" "$copy" \
  "$base/package-alias/alias-work"

echo 'collect-v4 signals/order/path-disjointness/relocation: PASS'
