#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v7-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

expected_order() {
  printf '%s\n' supervisor_started supervisor_wait_complete finalizer_enter \
    raw_seal artifact_audit process_audit final_status_publication final_status
}

run_case() {
  label=$1 expected=$2 inject=$3 mutation=$4
  shift 4
  work=$base/$label
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]7-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    COLLECT_V7_INJECT=$inject COLLECT_V7_MUTATE_SUPERVISOR=$mutation \
    python3 -B "$package/future-protocol/collect-v7.py" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "collect-v7 $label: expected $expected got $rc" >&2; exit 1;
  }
}

run_case ordinary 0 '' '' /bin/true
expected_order > "$base/order"
cmp "$base/order" "$base/ordinary/finalization-order.txt"
grep -Fx 'supervisor_schema_status=0' \
  "$base/ordinary/final-status.txt" >/dev/null
grep -Fx 'final_status=0' "$base/ordinary/final-status.txt" >/dev/null

# Every malformed, forged or provenance-inconsistent supervisor record is
# sealed as observed but can never authorize collector success.
for mutation in missing malformed truncated duplicate missing_field extra \
  nested_extra wrong_type bad_enum bad_launch bad_path bad_version bad_hash \
  bad_options bad_preflight missing_preflight bad_proof bad_reap \
  bad_init_identity bad_close exit_mismatch; do
  run_case "schema-$mutation" 125 '' "$mutation" /bin/true
  grep -Fx 'supervisor_schema_status=1' \
    "$base/schema-$mutation/final-status.txt" >/dev/null
  grep -Fx 'final_status=125' \
    "$base/schema-$mutation/final-status.txt" >/dev/null
  [ -f "$base/schema-$mutation/raw.seal.sha256" ]
done
grep -F 'ABSENT  raw/supervisor.json' \
  "$base/schema-missing/raw.seal.sha256" >/dev/null

# The destination transaction is exercised before Popen. A failure has no
# benchmark marker and returns classified 125 through any writable fallback.
marker=$base/preflight-marker
run_case write-preflight 125 write_preflight '' /bin/sh -c \
  'echo launched > "$1"' sh "$marker"
[ ! -e "$marker" ]
grep -Fx 'final_status=125' \
  "$base/write-preflight/final-status.txt" >/dev/null
marker=$base/persistent-preflight-marker
run_case persistent-preflight 125 persistent_write '' /bin/sh -c \
  'echo launched > "$1"' sh "$marker"
[ ! -e "$marker" ]

# One-shot failures at every materialization phase are accumulated. Cleanup,
# schema validation and endpoint audit still run; the final status is 125 and
# the next atomic order write reconstructs the complete ledger where possible.
n=1
for point in order_supervisor_started order_supervisor_wait_complete \
  order_finalizer_enter order_raw_seal raw_seal order_artifact_audit \
  order_process_audit endpoint_audit order_final_status_publication \
  outer_signals order_final_status final_status; do
  label=write-$point marker_name=v7w${point%_*}
  run_case "$label" 125 "write_$point" '' /bin/true
  grep -Fx 'final_status=125' "$base/$label/final-status.txt" >/dev/null
  grep -F 'transaction_error_count=' "$base/$label/final-status.txt" \
    >/dev/null
  grep -Fx 'endpoint_audit_status=0' "$base/$label/final-status.txt" \
    >/dev/null || [ "$point" = endpoint_audit ]
done

# The same phase matrix is exercised with persistent failure beginning at the
# selected write. Cleanup and the in-memory final decision still complete;
# primary status publication is honestly absent once the medium stays bad.
for point in order_supervisor_started order_supervisor_wait_complete \
  order_finalizer_enter order_raw_seal raw_seal order_artifact_audit \
  order_process_audit endpoint_audit order_final_status_publication \
  outer_signals order_final_status final_status; do
  label=persistent-$point marker=v7pw$n
  work=$base/$label endpoint=$base/$label.endpoints
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN="$marker" \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv SEGMENT_TIMEOUT=.05 \
    COLLECT_V7_INJECT="persistent_write_after_$point" python3 -B \
    "$package/future-protocol/collect-v7.py" -- python3 -B \
    "$package/future-protocol/process-tree-fixture-v7.py" \
    "$endpoint" "$marker" 2> "$base/$label.stderr" || rc=$?
  [ "$rc" -eq 125 ]
  ! pgrep -a "$marker" >/dev/null
  [ ! -e "$work/final-status.txt" ]
  grep -F 'injected persistent transaction write failure' \
    "$base/$label.stderr" >/dev/null
  n=$((n + 1))
done

# Persistent loss after the supervisor is reaped makes primary publication
# impossible. The collector makes no promise that final-status.txt exists;
# raw endpoint cleanup still completes and process exit is deterministically
# 125. stderr is the surviving error channel.
work=$base/persistent-write
marker=v7persistwrite
endpoint=$base/persistent-write.endpoints
rc=0
ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root SCRATCH_DIR=$work \
  ENDPOINT_PATTERN="$marker" ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
  COLLECT_V7_INJECT=persistent_write_after_raw_seal SEGMENT_TIMEOUT=.05 \
  python3 -B "$package/future-protocol/collect-v7.py" -- python3 -B \
  "$package/future-protocol/process-tree-fixture-v7.py" \
  "$endpoint" "$marker" 2> "$base/persistent-write.stderr" || rc=$?
[ "$rc" -eq 125 ]
! pgrep -a "$marker" >/dev/null
grep -F 'injected persistent transaction write failure' \
  "$base/persistent-write.stderr" >/dev/null
[ ! -e "$work/final-status.txt" ]

# Late HUP/INT/TERM and mixed/repeated requests remain deferred through both
# audits. Requested status wins only when no transaction/audit error exists.
signal_case() {
  label=$1 phase=$2 names=$3 expected=$4
  work=$base/$label result=$base/$label-result.json
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]7-signal-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv python3 -B \
    "$package/future-protocol/collector-signal-driver-v7.py" \
    "$result" "$work" "$phase" "$names" python3 -B \
    "$package/future-protocol/collect-v7.py" -- /bin/true
  python3 -B - "$result" "$expected" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))["status"] == int(sys.argv[2])
PY
  expected_order > "$base/order"
  cmp "$base/order" "$work/finalization-order.txt"
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
  grep -Fx 'artifact_audit_status=0' "$work/final-status.txt" >/dev/null
  grep -Fx 'endpoint_audit_status=0' "$work/final-status.txt" >/dev/null
}
signal_case late-hup raw_seal HUP 129
signal_case late-int artifact_audit INT 130
signal_case late-term process_audit TERM 143
signal_case late-mixed artifact_audit TERM,HUP,TERM 143
grep -Fx 'outer_signal_count=3' \
  "$base/late-mixed/final-status.txt" >/dev/null

# Clean-environment real auditor operation is retained for canonical and
# copied packages; copy and work are disjoint siblings below scratch_root.
real_case() {
  label=$1 test_package=$2
  ref_work=$base/$label-reference
  mkdir -p "$ref_work/tmp" "$ref_work/audits"
  reference=$ref_work/audits/reference.tsv
  env -i PATH="$PATH" HOME="${HOME:-/}" \
    "$test_package/future-protocol/audit-artifacts-v5.sh" \
    --root "$root" --package-dir "$test_package" \
    --scratch-root "$scratch_root" --work "$ref_work" \
    --scratch-dir "$ref_work/tmp" --output "$reference"
  work=$base/$label-work
  env -i PATH="$PATH" HOME="${HOME:-/}" ROOT="$root" \
    PACKAGE_DIR="$test_package" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[v]7-real-no-match' \
    ARTIFACT_REFERENCE="$reference" python3 -B \
    "$test_package/future-protocol/collect-v7.py" -- /bin/true
  cmp "$reference" "$work/audits/final-artifacts.tsv"
  grep -Fx 'final_status=0' "$work/final-status.txt" >/dev/null
}
real_case original "$package"
package_copy=$base/package-copy
cp -a "$package" "$package_copy"
real_case copy "$package_copy"

echo 'collect-v7 schema/transaction/signals/audits/publication: PASS'
