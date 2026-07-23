#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch_root=$(realpath -e -- "${SCRATCH_ROOT:?explicit SCRATCH_ROOT required}")
reference=$(realpath -e -- "${ARTIFACT_REFERENCE:?reference required}")
collection=$scratch_root/collection
[ ! -e "$collection" ] || {
  echo 'collect: collection exists' >&2; exit 2;
}
mkdir -p "$collection/pre-go"
cp "$dir/schedule.tsv" "$collection/schedule.tsv"

run_gate() {
  label=$1
  shift
  rc=0
  "$@" > "$collection/pre-go/$label.stdout" \
    2> "$collection/pre-go/$label.stderr" || rc=$?
  printf '%s\n' "$rc" > "$collection/pre-go/$label.status"
  [ "$rc" -eq 0 ]
}

run_gate scoped-seal python3 -B "$dir/verify-go-seal.py" \
  --package "$dir" --seal "$dir/GO-SEAL.txt"
run_gate recursive-read-only python3 -B "$dir/audit-read-only.py" \
  --package "$dir"
run_gate pre-child-endpoint python3 -B "$dir/endpoint-audit.py" \
  --output "$collection/pre-go/pre-child-endpoint.txt"

if [ "${DRY_RUN:-0}" = 1 ]; then
  printf '%s\n' \
    'scoped_seal=passed' \
    'recursive_read_only=passed' \
    'exact_pre_child_endpoint=passed' \
    'collector_invoked=no' \
    'supervisor_invoked=no' \
    'child_invoked=no' > "$collection/DRY-RUN-STOP.txt"
  echo 'collect dry-run: PASS (stopped before collector/supervisor/child)'
  exit 0
fi
[ "${DRY_RUN:-0}" = 0 ] || {
  echo 'collect: DRY_RUN must be 0 or 1' >&2; exit 2;
}

while IFS="$(printf '\t')" read -r sequence repetition problem depth mode; do
  [ "$sequence" = sequence ] && continue
  if [ "$sequence" -ne 1 ]; then
    run_gate "pre-child-$sequence-endpoint" python3 -B \
      "$dir/endpoint-audit.py" --output \
      "$collection/pre-go/pre-child-$sequence-endpoint.txt"
  fi
  child=$collection/child-$sequence
  rc=0
  ROOT="$root" PACKAGE_DIR="$dir" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$child" \
    ENDPOINT_PATTERN='[/]task7mcalibration[.]exe|task7mcalibration$' \
    ARTIFACT_REFERENCE="$reference" ARTIFACT_AUDITOR="$dir/audit-runtime.sh" \
    SEGMENT_TIMEOUT=25 TERM_GRACE=1 POST_KILL_GRACE=1 \
    QUIET_INTERVAL=.05 POLL_INTERVAL=.01 T7M_RUN_KIND=calibration \
    T7M_SEQUENCE="$sequence" T7M_REPETITION="$repetition" \
    T7M_PROBLEM="$problem" T7M_DEPTH="$depth" T7M_MODE="$mode" \
    python3 -B "$dir/future-protocol/collect-v10.py" -- \
      "$dir/task7mcalibration.exe" || rc=$?
  printf '%s\t%s\n' "$sequence" "$rc" >> "$collection/driver-status.tsv"
  endpoint_rc=0
  python3 -B "$dir/endpoint-audit.py" \
    --output "$collection/pre-go/final-child-$sequence-endpoint.txt" \
    > "$collection/pre-go/final-child-$sequence-endpoint.stdout" \
    2> "$collection/pre-go/final-child-$sequence-endpoint.stderr" || \
    endpoint_rc=$?
  printf '%s\n' "$endpoint_rc" > \
    "$collection/pre-go/final-child-$sequence-endpoint.status"
  if [ "$rc" -ne 0 ] || [ "$endpoint_rc" -ne 0 ]; then
    printf '%s\t%s\t%s\n' "$sequence" "$rc" "$endpoint_rc" > \
      "$collection/STOPPED.tsv"
    exit 1
  fi
done < "$dir/schedule.tsv"
python3 -B "$dir/materialize-results.py" --collection "$collection" \
  --output "$collection/raw.tsv"
python3 -B "$dir/validate-results.py" --schedule "$dir/schedule.tsv" \
  --raw "$collection/raw.tsv" --collection "$collection" \
  --artifact-reference "$reference" > "$collection/validation.log"
sha256sum "$collection/raw.tsv" > "$collection/raw.tsv.sha256"
python3 -B "$dir/summarize-results.py" --raw "$collection/raw.tsv" \
  --summary "$collection/summary.tsv" --report "$collection/FINAL_REPORT.md"
echo 'v10 P38 small calibration second retry: PASS'
