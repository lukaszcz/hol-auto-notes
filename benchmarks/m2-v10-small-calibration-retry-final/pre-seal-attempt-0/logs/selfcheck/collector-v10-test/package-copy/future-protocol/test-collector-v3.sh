#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v3-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

run_synthetic() {
  label=$1 expected=$2 expected_class=$3
  shift 3
  work=$base/$label
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[t]7j-v3-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v3.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    "$package/future-protocol/collect-v3.sh" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "collect-v3 $label: expected $expected, got $rc" >&2
    exit 1
  }
  [ -d "$work/tmp" ]
  [ -f "$work/raw.seal.sha256" ]
  (cd "$work" && sha256sum -c raw.seal.sha256) >/dev/null
  grep -Fx "outer_status_at_finalizer=$expected" \
    "$work/final-status.txt" >/dev/null
  grep -Fx "segment_status=$expected" "$work/final-status.txt" >/dev/null
  grep -Fx "supervisor_classification=$expected_class" \
    "$work/final-status.txt" >/dev/null
  grep -Fx 'raw_seal_status=0' "$work/final-status.txt" >/dev/null
  grep -Fx 'endpoint_audit_status=0' "$work/final-status.txt" >/dev/null
  grep -Fx 'artifact_audit_status=0' "$work/final-status.txt" >/dev/null
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
}

run_synthetic ordinary 0 completed_exit_0 /bin/sh -c 'printf ordinary'
run_synthetic nonzero 7 completed_exit_nonzero /bin/sh -c 'exit 7'
run_synthetic anomaly-term 125 lifecycle_anomaly_term_owned_tree_cleared \
  python3 "$package/future-protocol/process-tree-fixture-v3.py" \
  linger-term "$base/anomaly-term.pid"
TERM_GRACE=0.05 run_synthetic anomaly-kill 125 \
  lifecycle_anomaly_kill_owned_tree_cleared \
  python3 "$package/future-protocol/process-tree-fixture-v3.py" \
  linger-kill "$base/anomaly-kill.pid"
TERM_GRACE=0.01 POST_KILL_GRACE=0 run_synthetic anomaly-uncleared 125 \
  lifecycle_anomaly_owned_tree_uncleared \
  python3 "$package/future-protocol/process-tree-fixture-v3.py" \
  linger-uncleared "$base/anomaly-uncleared.pid"

# A real default-auditor mismatch must still preserve and seal raw bytes.
printf '%s\n' drift > "$base/drift.tsv"
work=$base/audit-failure
rc=0
ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root SCRATCH_DIR=$work \
  ENDPOINT_PATTERN='[t]7j-v3-no-match' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  "$package/future-protocol/collect-v3.sh" -- /bin/true || rc=$?
[ "$rc" -eq 125 ]
grep -Fx 'segment_status=0' "$work/final-status.txt" >/dev/null
grep -Fx 'artifact_audit_status=1' "$work/final-status.txt" >/dev/null
grep -Fx 'final_status=125' "$work/final-status.txt" >/dev/null
(cd "$work" && sha256sum -c raw.seal.sha256) >/dev/null

run_real_package() {
  label=$1 test_package=$2
  audit_scratch=$base/$label-auditor-tmp
  reference=$base/$label-reference.tsv
  mkdir -p "$audit_scratch"
  env -i PATH="$PATH" HOME="${HOME:-/}" \
    "$test_package/future-protocol/audit-artifacts-v3.sh" \
    --root "$root" --package-dir "$test_package" \
    --scratch-root "$scratch_root" --scratch-dir "$audit_scratch" \
    --output "$reference"
  work=$base/$label-collector
  env -i PATH="$PATH" HOME="${HOME:-/}" ROOT="$root" \
    PACKAGE_DIR="$test_package" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[t]7j-v3-no-match' \
    ARTIFACT_REFERENCE="$reference" \
    "$test_package/future-protocol/collect-v3.sh" -- /bin/true
  cmp "$reference" "$work/audits/final-artifacts.tsv" >/dev/null
  grep -Fx 'final_status=0' "$work/final-status.txt" >/dev/null
}

# Exercise the actual default auditor from both package locations with no
# inherited TMPDIR. The copy has no canonical-package path in its logic.
run_real_package original "$package"
copy=$base/package-copy
cp -a "$package" "$copy"
run_real_package copy "$copy"

echo 'collect-v3 lifecycle/finalizer/default-auditor relocation: PASS'
