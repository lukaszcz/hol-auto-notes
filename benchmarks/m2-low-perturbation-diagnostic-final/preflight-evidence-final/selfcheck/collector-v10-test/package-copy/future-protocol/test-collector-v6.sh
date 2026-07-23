#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v6-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

order() {
  printf '%s\n' supervisor_started supervisor_wait_complete raw_seal \
    artifact_audit process_audit final_status_publication final_status
}

run_case() {
  label=$1 expected=$2 inject=$3
  shift 3
  work=$base/$label
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]6-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    SUPERVISE_V6_INJECT=$inject python3 -B \
    "$package/future-protocol/collect-v6.py" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ]
  order > "$base/order"; cmp "$base/order" "$work/finalization-order.txt"
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
  grep -Fx 'containment_kind=unprivileged_user_pid_namespace' \
    "$work/final-status.txt" >/dev/null
  grep -Fx 'containment_status=cleared' "$work/final-status.txt" >/dev/null
  grep -Fx 'containment_launcher_path=/usr/bin/unshare' \
    "$work/final-status.txt" >/dev/null
  python3 -B - "$work" <<'PY'
import hashlib, pathlib, sys
work = pathlib.Path(sys.argv[1])
for line in (work / "raw.seal.sha256").read_text().splitlines():
    digest, relative = line.split("  ", 1)
    if digest == "ABSENT":
        assert not (work / relative).exists()
    else:
        assert hashlib.sha256((work / relative).read_bytes()).hexdigest() == digest
PY
}

run_case ordinary 0 '' /bin/true
run_case persistent 125 persistent_proc_scan python3 -B \
  "$package/future-protocol/process-tree-fixture-v6.py" \
  "$base/persistent.endpoints" v6collectp
! pgrep -a v6collectp >/dev/null
grep -Fx 'cleanup_or_audit_failure=1' \
  "$base/persistent/final-status.txt" >/dev/null

# Collector HUP/INT/TERM all forward while persistent observation failure is
# active; status 125 wins, raw seal and both audits still finalize in order.
for spec in HUP INT TERM; do
  work=$base/signal-$spec
  result=$base/signal-$spec.json
  marker=v6c$spec
  endpoint=$base/signal-$spec.endpoints
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN="$marker" \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    SUPERVISE_V6_INJECT=persistent_proc_scan SEGMENT_TIMEOUT=30 \
    COLLECT_V6_WAIT_FILE=$endpoint python3 -B \
    "$package/future-protocol/collector-signal-driver-v6.py" \
    "$result" "$work" supervisor_wait "$spec" \
    "$package/future-protocol/collect-v6.py" -- python3 -B \
    "$package/future-protocol/process-tree-fixture-v6.py" \
    "$endpoint" "$marker"
  python3 -B - "$result" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))["status"] == 125
PY
  order > "$base/order"; cmp "$base/order" "$work/finalization-order.txt"
  grep -Fx 'containment_status=cleared' "$work/final-status.txt" >/dev/null
  grep -Fx 'final_status=125' "$work/final-status.txt" >/dev/null
  [ -f "$work/raw.seal.sha256" ]
  ! pgrep -a "$marker" >/dev/null
done

# Finalization signals remain deferred and do not skip either audit.
work=$base/late
result=$base/late.json
ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root SCRATCH_DIR=$work \
  ENDPOINT_PATTERN='[v]6-late-no-match' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv python3 -B \
  "$package/future-protocol/collector-signal-driver-v6.py" \
  "$result" "$work" artifact_audit TERM \
  "$package/future-protocol/collect-v6.py" -- /bin/true
python3 -B - "$result" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))["status"] == 143
PY
order > "$base/order"; cmp "$base/order" "$work/finalization-order.txt"

# The real retained auditor and v6 collector operate from both canonical and
# copied packages in a clean environment. Copy and work are disjoint siblings
# beneath the caller's mandated scratch root.
real_case() {
  label=$1 test_package=$2
  ref_work=$base/$label-reference-work
  mkdir -p "$ref_work/tmp" "$ref_work/audits"
  reference=$ref_work/audits/reference.tsv
  env -i PATH="$PATH" HOME="${HOME:-/}" \
    "$test_package/future-protocol/audit-artifacts-v5.sh" \
    --root "$root" --package-dir "$test_package" \
    --scratch-root "$scratch_root" --work "$ref_work" \
    --scratch-dir "$ref_work/tmp" --output "$reference"
  real_work=$base/$label-work
  env -i PATH="$PATH" HOME="${HOME:-/}" ROOT="$root" \
    PACKAGE_DIR="$test_package" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$real_work" ENDPOINT_PATTERN='[v]6-real-no-match' \
    ARTIFACT_REFERENCE="$reference" python3 -B \
    "$test_package/future-protocol/collect-v6.py" -- /bin/true
  cmp "$reference" "$real_work/audits/final-artifacts.tsv"
  grep -Fx 'containment_status=cleared' \
    "$real_work/final-status.txt" >/dev/null
  grep -Fx 'final_status=0' "$real_work/final-status.txt" >/dev/null
}
real_case original "$package"
package_copy=$base/package-copy
cp -a "$package" "$package_copy"
real_case copy "$package_copy"

echo 'collect-v6 containment-seal/signals/audits/finalization: PASS'
