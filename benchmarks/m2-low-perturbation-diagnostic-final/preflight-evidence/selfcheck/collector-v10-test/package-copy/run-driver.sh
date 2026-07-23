#!/bin/sh
# Outer owner for one collect.sh transaction and its unconditional endpoint.
set -u
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch_root=$(realpath -e -- "${SCRATCH_ROOT:?explicit SCRATCH_ROOT required}")
reference=$(realpath -e -- "${ARTIFACT_REFERENCE:?reference required}")
evidence=$(realpath -m -- "${DRIVER_EVIDENCE:?driver evidence required}")
mkdir -p "$evidence"
printf '%s\n' "$(pwd -P)" > "$evidence/cwd.txt"
printf '%s\n' \
  "ROOT=$root" "PACKAGE_DIR=$dir" "SCRATCH_ROOT=$scratch_root" \
  "ARTIFACT_REFERENCE=$reference" "DRY_RUN=${DRY_RUN:-0}" \
  > "$evidence/environment.txt"
printf '%s\n' \
  "env ROOT=$root PACKAGE_DIR=$dir SCRATCH_ROOT=$scratch_root ARTIFACT_REFERENCE=$reference DRY_RUN=${DRY_RUN:-0} $dir/collect.sh" \
  > "$evidence/command.txt"

driver_status=125
finalized=0
requested=0

finalize() {
  [ "$finalized" -eq 0 ] || return
  finalized=1
  endpoint_status=0
  python3 -B "$dir/endpoint-audit.py" \
    --output "$evidence/final-endpoint.txt" \
    > "$evidence/final-endpoint.stdout" \
    2> "$evidence/final-endpoint.stderr" || endpoint_status=$?
  printf '%s\n' "$endpoint_status" > "$evidence/final-endpoint.status"
  printf 'driver_status=%s\nendpoint_status=%s\nrequested_signal_status=%s\n' \
    "$driver_status" "$endpoint_status" "$requested" > \
    "$evidence/machine-status.txt"
}

on_signal() {
  requested=$1
  finalize
  exit "$requested"
}
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap finalize EXIT

driver_status=0
ROOT="$root" PACKAGE_DIR="$dir" SCRATCH_ROOT="$scratch_root" \
  ARTIFACT_REFERENCE="$reference" DRY_RUN="${DRY_RUN:-0}" \
  "$dir/collect.sh" > "$evidence/driver.stdout" \
  2> "$evidence/driver.stderr" || driver_status=$?
finalize
endpoint_status=$(cat "$evidence/final-endpoint.status")
[ "$driver_status" -eq 0 ] && [ "$endpoint_status" -eq 0 ] || exit 1
exit 0
