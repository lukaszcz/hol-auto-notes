#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v8-test
rm -rf -- "$base"
mkdir -p "$base"
printf '%s\n' 'synthetic artifact identity' > "$base/reference.tsv"

expected_order() {
  printf '%s\n' supervisor_started supervisor_wait_complete finalizer_enter \
    raw_durable_publication raw_seal artifact_audit process_audit \
    terminal_status_boundary final_status_publication final_status
}

run_case() {
  label=$1 expected=$2 inject=$3 mutation=$4
  shift 4
  work=$base/$label
  rc=0
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]8-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    COLLECT_V8_INJECT=$inject COLLECT_V8_MUTATE_SUPERVISOR=$mutation \
    python3 -B "$package/future-protocol/collect-v8.py" -- "$@" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "collect-v8 $label expected $expected got $rc" >&2; exit 1;
  }
}

run_case ordinary 0 '' '' /bin/true
expected_order > "$base/order"
cmp "$base/order" "$base/ordinary/finalization-order.txt"
grep -Fx 'supervisor_schema_status=0' \
  "$base/ordinary/final-status.txt" >/dev/null
grep -Fx 'final_status=0' "$base/ordinary/final-status.txt" >/dev/null
(cd "$base/ordinary" && sha256sum -c raw.seal.sha256) >/dev/null

# Reuse one valid semantic record to exercise every v7 adversary plus v8's
# suffix/interpreter/ready/go/command/exception/close/numeric/telemetry set.
python3 -B - "$package" "$base" <<'PY'
import importlib.util, json, pathlib, shutil, sys
package=pathlib.Path(sys.argv[1]); base=pathlib.Path(sys.argv[2])
sys.path.insert(0, str(package/'future-protocol'))
def load(name, path):
 spec=importlib.util.spec_from_file_location(name,path)
 m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
c=load('collect_v8',package/'future-protocol/collect-v8.py')
v=load('validate_v8',package/'future-protocol/validate-supervisor-v8.py')
source=base/'ordinary/raw/supervisor.json'
row=json.load(open(source)); command=['/bin/true']
vector=row['bootstrap_ownership']['full_launch_vector']
names='''missing malformed truncated duplicate missing_field extra nested_extra
wrong_type bad_enum bad_launch bad_path bad_version bad_hash bad_options
bad_preflight missing_preflight bad_proof exit_mismatch bad_reap
bad_init_identity bad_close bad_suffix bad_interpreter bad_ready bad_go
bad_command bad_exception bad_close_flag bad_close_result negative_elapsed
bad_quiet_numeric telemetry_scan telemetry_fault bad_terminal bad_bootstrap
nan infinity neg_infinity'''.split()
for name in names:
 target=base/('adversary-'+name+'.json'); shutil.copyfile(source,target)
 c.mutate_record(target,name)
 try: v.validate_file(target,0,command,vector)
 except Exception: pass
 else: raise AssertionError(name+' unexpectedly passed')
print('v8 exact-record adversaries:',len(names))
PY

# End-to-end collector schema gate cannot be bypassed by a forged suffix.
run_case schema-suffix 125 '' bad_suffix /bin/true
grep -Fx 'supervisor_schema_status=1' \
  "$base/schema-suffix/final-status.txt" >/dev/null

# Setup mkdir/probe/fsync failures occur inside the initialized transaction,
# cannot launch the benchmark, and never leak shell/Python status 1.
for point in setup_mkdir fsync_dir_setup_work fsync_file_setup_probe_0; do
  marker=$base/$point.marker
  run_case setup-$point 125 "$point" '' /bin/sh -c \
    'echo launched > "$1"' sh "$marker"
  [ ! -e "$marker" ]
done
for point in persistent_write persistent_fsync; do
  marker=$base/$point.marker
  run_case setup-$point 125 "$point" '' /bin/sh -c \
    'echo launched > "$1"' sh "$marker"
  [ ! -e "$marker" ]
  [ ! -e "$base/setup-$point/final-status.txt" ]
done

# An early signal after handlers and directory setup but before the first
# destination probe commits cancellation with no supervisor/benchmark launch.
work=$base/setup-signal result=$base/setup-signal-result.json
ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root SCRATCH_DIR=$work \
  ENDPOINT_PATTERN='[v]8-setup-signal' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv python3 -B \
  "$package/future-protocol/collector-signal-driver-v8.py" \
  "$result" "$work" setup HUP,INT,HUP python3 -B \
  "$package/future-protocol/collect-v8.py" -- /bin/sh -c \
  'echo forbidden > "$1"' sh "$base/setup-signal.marker"
python3 -B - "$result" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']==129
PY
[ ! -e "$base/setup-signal.marker" ]
grep -Fx 'benchmark_launched=false' "$work/final-status.txt" >/dev/null

# Every accepted-material class has an injected file or parent-directory
# fsync failure after launch. All degrade to 125 while endpoint cleanup runs.
for point in fsync_file_raw_stdout fsync_dir_raw_directory \
  fsync_file_raw_seal fsync_dir_artifact_output \
  fsync_file_endpoint_audit fsync_dir_outer_signals \
  fsync_file_final_status fsync_dir_final_status; do
  run_case "$point" 125 "$point" '' /bin/true
  grep -Fx 'final_status=125' "$base/$point/final-status.txt" >/dev/null
  if [ "$point" != fsync_file_endpoint_audit ]; then
    grep -Fx 'endpoint_audit_status=0' \
      "$base/$point/final-status.txt" >/dev/null
  fi
done

# Signals at the collector's terminal boundary and during earlier audit
# materialization remain transaction inputs; cleanup/audit 125 still wins.
signal_case() {
  label=$1 phase_name=$2 names=$3 expected=$4 inject=${5:-}
  work=$base/$label result=$base/$label-result.json
  ROOT=$root PACKAGE_DIR=$package SCRATCH_ROOT=$scratch_root \
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]8-signal-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv COLLECT_V8_INJECT=$inject \
    python3 -B "$package/future-protocol/collector-signal-driver-v8.py" \
    "$result" "$work" "$phase_name" "$names" python3 -B \
    "$package/future-protocol/collect-v8.py" -- /bin/true
  python3 -B - "$result" "$expected" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']==int(sys.argv[2])
PY
  expected_order > "$base/order"
  cmp "$base/order" "$work/finalization-order.txt"
  grep -Fx "final_status=$expected" "$work/final-status.txt" >/dev/null
}
signal_case raw-hup raw_seal HUP 129
signal_case audit-int artifact_audit INT 130
signal_case endpoint-term process_audit TERM 143
signal_case terminal-mixed terminal_status_boundary TERM,HUP,TERM 143
signal_case precedence artifact_audit TERM 125 fsync_file_artifact_output

# The retained real auditor is durably accepted from canonical and copied
# package locations under a clean environment.
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
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[v]8-real-no-match' \
    ARTIFACT_REFERENCE="$reference" python3 -B \
    "$test_package/future-protocol/collect-v8.py" -- /bin/true
  cmp "$reference" "$work/audits/final-artifacts.tsv"
  grep -Fx 'final_status=0' "$work/final-status.txt" >/dev/null
}
real_case original "$package"
package_copy=$base/package-copy
cp -a "$package" "$package_copy"
real_case copy "$package_copy"

echo 'collect-v8 schema/setup/durability/signals/audits/relocation: PASS'
