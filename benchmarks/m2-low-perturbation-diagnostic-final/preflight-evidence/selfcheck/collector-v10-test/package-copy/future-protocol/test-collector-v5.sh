#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v5-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

expected_order() {
  printf '%s\n' supervisor_started supervisor_wait_complete raw_seal \
    artifact_audit process_audit final_status_publication final_status
}

run_synthetic() {
  label=$1 expected=$2
  shift 2
  work=$base/$label
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]5-synthetic-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    python3 -B "$package/future-protocol/collect-v5.py" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ]
  [ -f "$work/raw.seal.sha256" ]
  (cd "$work" && sha256sum -c raw.seal.sha256) >/dev/null
  grep -Fx 'supervisor_started=true' "$work/final-status.txt" >/dev/null
  grep -Fx 'supervisor_wait_complete=true' \
    "$work/final-status.txt" >/dev/null
  grep -Fx "actual_supervisor_status=$expected" \
    "$work/final-status.txt" >/dev/null
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
  ! grep -F '=not_run' "$work/final-status.txt" >/dev/null
  expected_order > "$base/expected-order"
  cmp "$base/expected-order" "$work/finalization-order.txt"
}

run_synthetic ordinary 0 /bin/true
run_synthetic nonzero 7 /bin/sh -c 'exit 7'

# A degraded supervisor cleanup remains status 125 after all collector audits.
SEGMENT_TIMEOUT=.05 SUPERVISE_V5_INJECT=signal \
  run_synthetic cleanup-failure 125 /bin/sh -c 'trap "" TERM; sleep 30'
grep -Fx 'cleanup_or_audit_failure=1' \
  "$base/cleanup-failure/final-status.txt" >/dev/null

signal_case() {
  label=$1 phase=$2 signals=$3 expected=$4
  shift 4
  work=$base/$label
  result=$base/$label-result.json
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN="[v]5-$label" \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv SEGMENT_TIMEOUT=30 \
    TERM_GRACE=.2 POST_KILL_GRACE=1 QUIET_INTERVAL=.03 POLL_INTERVAL=.01 \
    python3 -B "$package/future-protocol/collector-signal-driver-v5.py" \
    "$result" "$work" "$phase" "$signals" \
    "$package/future-protocol/collect-v5.py" -- "$@" || rc=$?
  [ "$rc" -eq 0 ]
  python3 -B - "$result" "$expected" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["status"] == int(sys.argv[2])
assert row["elapsed"] < 5
PY
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
  grep -Fx 'supervisor_started=true' "$work/final-status.txt" >/dev/null
  grep -Fx 'supervisor_wait_complete=true' \
    "$work/final-status.txt" >/dev/null
  ! grep -F '=not_run' "$work/final-status.txt" >/dev/null
  expected_order > "$base/expected-order"
  cmp "$base/expected-order" "$work/finalization-order.txt"
  python3 -B - "$work/outer-signals.json" "$phase" <<'PY'
import json, sys
row = json.load(open(sys.argv[1]))
assert row["events"]
assert all(event["phase"] == sys.argv[2] for event in row["events"])
assert [event["sequence"] for event in row["events"]] == \
       list(range(1, len(row["events"]) + 1))
assert row["publication_signal_mask"] == ["SIGHUP", "SIGINT", "SIGTERM"]
PY
}

# Live resistant same-group, setsid and double-fork/setsid ownership all use
# prompt outer forwarding while the supervisor is active.
for spec in \
  'same same-group-resistant HUP 129' \
  'setsid setsid-resistant INT 130' \
  'double double-fork-resistant TERM 143'
do
  set -- $spec
  label=$1 mode=$2 sig=$3 expected=$4
  pidfile=$base/$label.pids
  COLLECT_V5_WAIT_FILE=$pidfile signal_case "$label" supervisor_wait \
    "$sig" "$expected" python3 \
    "$package/future-protocol/process-tree-fixture-v5.py" "$mode" \
    "$pidfile" "v5-$label"
  while IFS=: read -r role pid; do
    ! kill -0 "$pid" 2>/dev/null
  done < "$pidfile"
  ! pgrep -a "v5-$label" >/dev/null
done

# Every post-supervisor finalization phase retains and defers signals instead
# of aborting the remaining seal/audits/publication.
signal_case seal-signal raw_seal HUP 129 /bin/true
signal_case artifact-signal artifact_audit INT 130 /bin/true
signal_case process-signal process_audit TERM 143 /bin/true
signal_case publication-signal final_status_publication HUP 129 /bin/true
signal_case repeated-signal artifact_audit TERM,TERM 143 /bin/true
grep -Fx 'outer_signal_count=2' \
  "$base/repeated-signal/final-status.txt" >/dev/null

# Audit/cleanup failure has honest precedence over a requested outer status.
work=$base/audit-precedence
result=$base/audit-precedence-result.json
printf '%s\n' drift > "$base/drift.tsv"
ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root SCRATCH_DIR=$work \
  ENDPOINT_PATTERN='[v]5-audit-precedence' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/drift.tsv \
  python3 -B "$package/future-protocol/collector-signal-driver-v5.py" \
  "$result" "$work" artifact_audit TERM \
  "$package/future-protocol/collect-v5.py" -- /bin/true
python3 -B - "$result" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))["status"] == 125
PY
grep -Fx 'outer_requested_status=143' "$work/final-status.txt" >/dev/null
grep -Fx 'artifact_audit_status=1' "$work/final-status.txt" >/dev/null
grep -Fx 'final_status=125' "$work/final-status.txt" >/dev/null

# Positive relationship controls: canonical PACKAGE_DIR is beneath ROOT;
# copied PACKAGE_DIR may instead be elsewhere beside a disjoint work closure.
python3 -B "$package/future-protocol/validate-paths-v5.py" \
  --root "$root" --package-dir "$package" --scratch-root "$scratch_root" \
  --work "$base/path-canonical" --tmp "$base/path-canonical/tmp" \
  --output "$base/path-canonical/audits/out" >/dev/null
copy_parent=$base/path-copy-parent
mkdir -p "$copy_parent/package-copy"
python3 -B "$package/future-protocol/validate-paths-v5.py" \
  --root "$root" --package-dir "$copy_parent/package-copy" \
  --scratch-root "$scratch_root" --work "$copy_parent/work" \
  --tmp "$copy_parent/work/tmp" \
  --output "$copy_parent/work/audits/out" >/dev/null

reject_direct() {
  label=$1 test_package=$2 work=$3 tmp=$4 output=$5
  rc=0
  python3 -B "$package/future-protocol/validate-paths-v5.py" \
    --root "$root" --package-dir "$test_package" --scratch-root / \
    --work "$work" --tmp "$tmp" --output "$output" \
    > "$base/path-$label.stdout" 2> "$base/path-$label.stderr" || rc=$?
  [ "$rc" -eq 2 ]
  [ ! -s "$base/path-$label.stdout" ]
}

safe=$base/path-safe
root_parent=$(dirname -- "$root")
package_parent=$(dirname -- "$package")
reject_direct work-root-equal "$package" "$root" "$safe/tmp" "$safe/out"
reject_direct work-root-ancestor "$package" "$root_parent" \
  "$safe/tmp" "$safe/out"
reject_direct work-root-descendant "$package" "$root/v5-work" \
  "$safe/tmp" "$safe/out"
reject_direct work-package-equal "$package" "$package" \
  "$safe/tmp" "$safe/out"
reject_direct work-package-ancestor "$package" "$package_parent" \
  "$safe/tmp" "$safe/out"
reject_direct work-package-descendant "$package" "$package/v5-work" \
  "$safe/tmp" "$safe/out"
for mutable in tmp output; do
  case $mutable in
    tmp)
      reject_direct tmp-root-equal "$package" "$safe" "$root" "$safe/out"
      reject_direct tmp-root-ancestor "$package" "$safe" "$root_parent" \
        "$safe/out"
      reject_direct tmp-root-descendant "$package" "$safe" "$root/v5-tmp" \
        "$safe/out"
      reject_direct tmp-package-equal "$package" "$safe" "$package" \
        "$safe/out"
      reject_direct tmp-package-ancestor "$package" "$safe" \
        "$package_parent" "$safe/out"
      reject_direct tmp-package-descendant "$package" "$safe" \
        "$package/v5-tmp" "$safe/out"
      ;;
    output)
      reject_direct output-root-equal "$package" "$safe" "$safe/tmp" "$root"
      reject_direct output-root-ancestor "$package" "$safe" "$safe/tmp" \
        "$root_parent"
      reject_direct output-root-descendant "$package" "$safe" "$safe/tmp" \
        "$root/v5-output"
      reject_direct output-package-equal "$package" "$safe" "$safe/tmp" \
        "$package"
      reject_direct output-package-ancestor "$package" "$safe" "$safe/tmp" \
        "$package_parent"
      reject_direct output-package-descendant "$package" "$safe" \
        "$safe/tmp" "$package/v5-output"
      ;;
  esac
done
ln -s "$root" "$base/root-alias"
reject_direct work-root-symlink "$package" "$base/root-alias/v5-work" \
  "$safe/tmp" "$safe/out"
ln -s "$package" "$base/package-alias"
reject_direct work-package-symlink "$package" \
  "$base/package-alias/v5-work" "$safe/tmp" "$safe/out"
reject_direct tmp-root-symlink "$package" "$safe" \
  "$base/root-alias/v5-tmp" "$safe/out"
reject_direct tmp-package-symlink "$package" "$safe" \
  "$base/package-alias/v5-tmp" "$safe/out"
reject_direct output-root-symlink "$package" "$safe" "$safe/tmp" \
  "$base/root-alias/v5-output"
reject_direct output-package-symlink "$package" "$safe" "$safe/tmp" \
  "$base/package-alias/v5-output"

# Real default auditor from canonical and copied packages in a clean env.
real_case() {
  label=$1 test_package=$2
  ref_work=$base/$label-ref-work
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
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[v]5-real-no-match' \
    ARTIFACT_REFERENCE="$reference" \
    python3 -B "$test_package/future-protocol/collect-v5.py" -- /bin/true
  cmp "$reference" "$work/audits/final-artifacts.tsv"
  grep -Fx 'final_status=0' "$work/final-status.txt" >/dev/null
}
real_case original "$package"
package_copy=$base/package-copy
cp -a "$package" "$package_copy"
real_case copy "$package_copy"

echo 'collect-v5 late-signals/order/precedence/exact-path/relocation: PASS'
