#!/bin/sh
set -eu
package=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
scratch_root=${1:?caller-provided scratch root required}
base=$scratch_root/collector-v9-test
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
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]9-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv \
    COLLECT_V9_INJECT=$inject COLLECT_V9_MUTATE_SUPERVISOR=$mutation \
    python3 -B "$package/future-protocol/collect-v9.py" -- "$@" \
      > "$base/$label.collector.stdout" \
      2> "$base/$label.collector.stderr" || rc=$?
  [ "$rc" -eq "$expected" ] || {
    echo "collect-v9 $label expected $expected got $rc" >&2; exit 1;
  }
}

run_case ordinary 0 '' '' /bin/true
expected_order > "$base/order"
cmp "$base/order" "$base/ordinary/finalization-order.txt"
grep -Fx 'supervisor_schema_status=0' \
  "$base/ordinary/final-status.txt" >/dev/null
grep -Fx 'final_status=0' "$base/ordinary/final-status.txt" >/dev/null
(cd "$base/ordinary" && sha256sum -c raw.seal.sha256) >/dev/null

# Reuse one valid semantic record for the inherited adversaries and generated
# v9 bootstrap, exact-cancellation, strict-signal and priority contradictions.
python3 -B - "$package" "$base" <<'PY'
import importlib.util, json, pathlib, shutil, subprocess, sys
package=pathlib.Path(sys.argv[1]); base=pathlib.Path(sys.argv[2])
sys.path.insert(0, str(package/'future-protocol'))
def load(name, path):
 spec=importlib.util.spec_from_file_location(name,path)
 m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
c=load('collect_v8',package/'future-protocol/collect-v9.py')
v=load('validate_v8',package/'future-protocol/validate-supervisor-v9.py')
source=base/'ordinary/raw/supervisor.json'
row=json.load(open(source)); command=['/bin/true']
vector=row['bootstrap_ownership']['full_launch_vector']
names='''missing malformed truncated duplicate missing_field extra nested_extra
wrong_type bad_enum bad_launch bad_path bad_version bad_hash bad_options
bad_preflight missing_preflight bad_proof exit_mismatch bad_reap
bad_init_identity bad_close bad_suffix bad_interpreter bad_ready bad_go
bad_command bad_exception bad_close_flag bad_close_result negative_elapsed
bad_quiet_numeric telemetry_scan telemetry_fault bad_terminal bad_bootstrap
nan infinity neg_infinity forged_bootstrap_program
cancellation_wrong_signal cancellation_extra_suffix signal_sequence_bool
signal_sequence_float signal_number_bool signal_number_float
signal_status_bool signal_status_float
priority_signal_exception_timeout_nonzero
priority_signal_exception priority_signal_timeout priority_signal_nonzero
priority_signal_success
priority_exception_timeout_nonzero priority_exception_timeout
priority_exception_nonzero priority_exception_success priority_timeout_nonzero
priority_timeout_success priority_nonzero_success
priority_degradation_signal priority_degradation_exception
priority_degradation_timeout priority_degradation_nonzero
priority_degradation_success priority_containment_degradation
priority_containment_signal priority_containment_exception
priority_containment_timeout priority_containment_nonzero
priority_containment_success'''.split()
for name in names:
 target=base/('adversary-'+name+'.json'); shutil.copyfile(source,target)
 c.mutate_record(target,name)
 try: v.validate_file(target,0,command,vector)
 except Exception: pass
 else: raise AssertionError(name+' unexpectedly passed')
 result=subprocess.run([sys.executable,'-B',str(package/'future-protocol'/
  'validate-supervisor-v9.py'),'--record',str(target),'--expected-status','0',
  '--command-json',json.dumps(command),'--expected-full-launch-json',
  json.dumps(vector)],text=True,capture_output=True)
 assert result.returncode==1, (name,result.returncode)
 assert result.stdout=='', (name,result.stdout)
 lines=result.stderr.splitlines()
 assert len(lines)==1 and lines[0].startswith('validate-supervisor-v9: '), \
  (name,result.stderr)
print('v9 exact-record adversaries:',len(names))
PY

# End-to-end collector schema gate cannot be bypassed by a forged suffix.
run_case schema-suffix 125 '' bad_suffix /bin/true
grep -Fx 'supervisor_schema_status=1' \
  "$base/schema-suffix/final-status.txt" >/dev/null

# Every v9 review adversary crosses the real collector gate, returns 125,
# emits one schema diagnostic and never prints a success marker.
for mutation in forged_bootstrap_program cancellation_wrong_signal \
  cancellation_extra_suffix signal_sequence_bool signal_sequence_float \
  signal_number_bool signal_number_float signal_status_bool \
  signal_status_float priority_signal_exception_timeout_nonzero \
  priority_signal_exception priority_signal_timeout \
  priority_signal_nonzero priority_signal_success \
  priority_exception_timeout_nonzero priority_exception_timeout \
  priority_exception_nonzero priority_exception_success \
  priority_timeout_nonzero priority_timeout_success \
  priority_nonzero_success \
  priority_degradation_signal priority_degradation_exception \
  priority_degradation_timeout priority_degradation_nonzero \
  priority_degradation_success priority_containment_degradation \
  priority_containment_signal priority_containment_exception \
  priority_containment_timeout priority_containment_nonzero \
  priority_containment_success; do
  run_case "schema-$mutation" 125 '' "$mutation" /bin/true
  grep -Fx 'supervisor_schema_status=1' \
    "$base/schema-$mutation/final-status.txt" >/dev/null
  test ! -s "$base/schema-$mutation.collector.stdout"
  test "$(wc -l < "$base/schema-$mutation.collector.stderr")" -eq 1
  grep -E '^collect-v9: supervisor_schema: Invalid: ' \
    "$base/schema-$mutation.collector.stderr" >/dev/null
  ! grep -F PASS "$base/schema-$mutation.collector.stderr" >/dev/null
done

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
  ENDPOINT_PATTERN='[v]9-setup-signal' \
  ARTIFACT_REFERENCE=$base/reference.tsv \
  ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
  SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv python3 -B \
  "$package/future-protocol/collector-signal-driver-v9.py" \
  "$result" "$work" setup HUP,INT,HUP python3 -B \
  "$package/future-protocol/collect-v9.py" -- /bin/sh -c \
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
    SCRATCH_DIR=$work ENDPOINT_PATTERN='[v]9-signal-no-match' \
    ARTIFACT_REFERENCE=$base/reference.tsv \
    ARTIFACT_AUDITOR=$package/future-protocol/synthetic-artifact-audit-v5.sh \
    SYNTHETIC_ARTIFACT_SOURCE=$base/reference.tsv COLLECT_V9_INJECT=$inject \
    python3 -B "$package/future-protocol/collector-signal-driver-v9.py" \
    "$result" "$work" "$phase_name" "$names" python3 -B \
    "$package/future-protocol/collect-v9.py" -- /bin/true
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
    SCRATCH_DIR="$work" ENDPOINT_PATTERN='[v]9-real-no-match' \
    ARTIFACT_REFERENCE="$reference" python3 -B \
    "$test_package/future-protocol/collect-v9.py" -- /bin/true
  cmp "$reference" "$work/audits/final-artifacts.tsv"
  grep -Fx 'final_status=0' "$work/final-status.txt" >/dev/null
}
real_case original "$package"
package_copy=$base/package-copy
cp -a "$package" "$package_copy"
real_case copy "$package_copy"

echo 'collect-v9 schema/setup/durability/signals/audits/relocation: PASS'
