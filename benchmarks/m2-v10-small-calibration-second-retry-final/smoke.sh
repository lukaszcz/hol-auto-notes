#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch_root=$(realpath -e -- "${SCRATCH_ROOT:?explicit SCRATCH_ROOT required}")
reference=$(realpath -e -- "${ARTIFACT_REFERENCE:?reference required}")
work=$scratch_root/smoke-transaction
[ ! -e "$work" ] || { echo 'smoke: transaction exists' >&2; exit 2; }
mkdir -p "$scratch_root/smoke-endpoints"
printf '%s\n' "$(pwd -P)" > "$scratch_root/cwd.txt"
printf '%s\n' \
  "ROOT=$root" "PACKAGE_DIR=$dir" "SCRATCH_ROOT=$scratch_root" \
  "ARTIFACT_REFERENCE=$reference" "T7M_RUN_KIND=load-only" \
  > "$scratch_root/environment.txt"
printf '%s\n' \
  "python3 -B $dir/future-protocol/collect-v10.py -- $dir/task7mcalibration.exe" \
  > "$scratch_root/command.txt"
pre=0
python3 -B "$dir/endpoint-audit.py" \
  --output "$scratch_root/smoke-endpoints/pre.txt" \
  > "$scratch_root/smoke-endpoints/pre.stdout" \
  2> "$scratch_root/smoke-endpoints/pre.stderr" || pre=$?
printf '%s\n' "$pre" > "$scratch_root/smoke-endpoints/pre.status"
[ "$pre" -eq 0 ] || exit "$pre"
rc=0
ROOT="$root" PACKAGE_DIR="$dir" SCRATCH_ROOT="$scratch_root" \
  SCRATCH_DIR="$work" \
  ENDPOINT_PATTERN='[/]task7mcalibration[.]exe|task7mcalibration$' \
  ARTIFACT_REFERENCE="$reference" ARTIFACT_AUDITOR="$dir/audit-runtime.sh" \
  SEGMENT_TIMEOUT=25 TERM_GRACE=1 POST_KILL_GRACE=1 \
  QUIET_INTERVAL=.05 POLL_INTERVAL=.01 T7M_RUN_KIND=load-only \
  T7M_SEQUENCE=1 T7M_REPETITION=1 T7M_PROBLEM=38 T7M_DEPTH=4 T7M_MODE=A \
  python3 -B "$dir/future-protocol/collect-v10.py" -- \
    "$dir/task7mcalibration.exe" \
    > "$scratch_root/collector.stdout" 2> "$scratch_root/collector.stderr" || \
    rc=$?
printf '%s\n' "$rc" > "$scratch_root/collector.status"
post=0
python3 -B "$dir/endpoint-audit.py" \
  --output "$scratch_root/smoke-endpoints/final.txt" \
  > "$scratch_root/smoke-endpoints/final.stdout" \
  2> "$scratch_root/smoke-endpoints/final.stderr" || post=$?
printf '%s\n' "$post" > "$scratch_root/smoke-endpoints/final.status"
printf 'collector_status=%s\nendpoint_status=%s\n' "$rc" "$post" > \
  "$scratch_root/machine-status.txt"
[ "$rc" -eq 0 ] && [ "$post" -eq 0 ] || exit 1
test "$(cat "$work/raw/stdout")" = LOAD_OK
test ! -s "$work/raw/stderr"
! grep -R -E 'V10CAL2|Time\.now|searchGoal|search row' \
  "$work/raw/stdout" "$work/raw/stderr" >/dev/null
grep -Fx 'actual_supervisor_status=0' "$work/final-status.txt" >/dev/null
grep -Fx 'supervisor_classification=completed_exit_0' \
  "$work/final-status.txt" >/dev/null
grep -Fx 'containment_status=cleared' "$work/final-status.txt" >/dev/null
grep -Fx 'artifact_audit_status=0' "$work/final-status.txt" >/dev/null
grep -Fx 'endpoint_audit_status=0' "$work/final-status.txt" >/dev/null
grep -Fx 'final_status=0' "$work/final-status.txt" >/dev/null
cmp "$reference" "$work/audits/final-artifacts.tsv"
echo 'actual final-launcher load-only smoke: PASS'
