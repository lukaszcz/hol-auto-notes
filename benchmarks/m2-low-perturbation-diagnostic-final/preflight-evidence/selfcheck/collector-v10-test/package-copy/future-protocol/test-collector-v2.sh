#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

run_case() {
  label=$1 expected=$2
  shift 2
  work=$base/$label
  rc=0
  ROOT=$base PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[t]7j-future-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    "$package/future-protocol/collect-v2.sh" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "collector case $label: expected $expected got $rc" >&2
    exit 1
  }
  [ -f "$work/raw.seal.sha256" ]
  (cd "$work" && sha256sum -c raw.seal.sha256) >/dev/null
  grep -Fx "outer_status_at_finalizer=$expected" "$work/final-status.txt" >/dev/null
  grep -Fx "segment_status=$expected" "$work/final-status.txt" >/dev/null
  grep -Fx 'endpoint_audit_status=0' "$work/final-status.txt" >/dev/null
  grep -Fx 'artifact_audit_status=0' "$work/final-status.txt" >/dev/null
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
}

run_case ordinary 0 /bin/sh -c 'printf ordinary; exit 0'
run_case nonzero 7 /bin/sh -c 'printf failed >&2; exit 7'

# The artifact auditor is invoked even when the segment fails. Its deliberate
# mismatch is retained and changes an otherwise-successful final status.
printf '%s\n' drift > "$base/drift.tsv"
work=$base/audit-failure
rc=0
ROOT=$base PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root SCRATCH_DIR=$work \
  ENDPOINT_PATTERN='[t]7j-future-no-match' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/drift.tsv \
  "$package/future-protocol/collect-v2.sh" -- /bin/true || rc=$?
[ "$rc" -eq 125 ]
grep -Fx 'artifact_audit_status=1' "$work/final-status.txt" >/dev/null
grep -Fx 'final_status=125' "$work/final-status.txt" >/dev/null
(cd "$work" && sha256sum -c raw.seal.sha256) >/dev/null

echo 'collect-v2 immediate seal/unconditional audits/status/preservation: PASS'
