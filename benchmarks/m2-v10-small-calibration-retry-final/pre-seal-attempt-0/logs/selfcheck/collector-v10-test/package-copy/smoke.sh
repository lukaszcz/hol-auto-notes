#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch_root=$(realpath -e -- "${SCRATCH_ROOT:?explicit SCRATCH_ROOT required}")
reference=$(realpath -e -- "${ARTIFACT_REFERENCE:?reference required}")
work=$scratch_root/smoke-transaction
[ ! -e "$work" ] || { echo 'smoke: transaction exists' >&2; exit 2; }
mkdir -p "$scratch_root/smoke-endpoints"
rc=0
python3 -B "$dir/endpoint-audit.py" \
  --output "$scratch_root/smoke-endpoints/pre.txt" || rc=$?
printf '%s\n' "$rc" > "$scratch_root/smoke-endpoints/pre.status"
[ "$rc" -eq 0 ] || exit "$rc"
printf '%s\n' "$dir/task7lcalibration.exe" > \
  "$scratch_root/smoke-command-vector.txt"
printf '%s\n' "$root" > "$scratch_root/smoke-child-cwd.txt"
rc=0
ROOT="$root" PACKAGE_DIR="$dir" SCRATCH_ROOT="$scratch_root" \
  SCRATCH_DIR="$work" \
  ENDPOINT_PATTERN='[/]task7lcalibration[.]exe|task7lcalibration$' \
  ARTIFACT_REFERENCE="$reference" ARTIFACT_AUDITOR="$dir/audit-runtime.sh" \
  SEGMENT_TIMEOUT=25 TERM_GRACE=1 POST_KILL_GRACE=1 \
  QUIET_INTERVAL=.05 POLL_INTERVAL=.01 T7L_RUN_KIND=load-only \
  T7L_SEQUENCE=1 T7L_REPETITION=1 T7L_PROBLEM=38 T7L_DEPTH=4 T7L_MODE=A \
  python3 -B "$dir/future-protocol/collect-v10.py" -- \
    "$dir/task7lcalibration.exe" || rc=$?
printf '%s\n' "$rc" > "$scratch_root/smoke-collector.status"
post=0
python3 -B "$dir/endpoint-audit.py" \
  --output "$scratch_root/smoke-endpoints/final.txt" || post=$?
printf '%s\n' "$post" > "$scratch_root/smoke-endpoints/final.status"
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
echo 'actual-launcher load-only smoke: PASS'
