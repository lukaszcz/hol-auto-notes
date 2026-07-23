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
mkdir -p "$collection/endpoints"
cp "$dir/schedule.tsv" "$collection/schedule.tsv"

endpoint() {
  label=$1
  rc=0
  python3 -B "$dir/endpoint-audit.py" \
    --output "$collection/endpoints/$label.txt" || rc=$?
  printf '%s\n' "$rc" > "$collection/endpoints/$label.status"
  return "$rc"
}

sha256sum -c "$dir/GO-SEAL.txt" > "$collection/go-seal-check.log"
test ! -w "$dir"
endpoint pre-child-1
while IFS="$(printf '\t')" read -r sequence repetition problem depth mode; do
  [ "$sequence" = sequence ] && continue
  if [ "$sequence" -ne 1 ]; then endpoint "pre-child-$sequence"; fi
  child=$collection/child-$sequence
  rc=0
  ROOT="$root" PACKAGE_DIR="$dir" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$child" \
    ENDPOINT_PATTERN='[/]task7lcalibration[.]exe|task7lcalibration$' \
    ARTIFACT_REFERENCE="$reference" ARTIFACT_AUDITOR="$dir/audit-runtime.sh" \
    SEGMENT_TIMEOUT=25 TERM_GRACE=1 POST_KILL_GRACE=1 \
    QUIET_INTERVAL=.05 POLL_INTERVAL=.01 T7L_RUN_KIND=calibration \
    T7L_SEQUENCE="$sequence" T7L_REPETITION="$repetition" \
    T7L_PROBLEM="$problem" T7L_DEPTH="$depth" T7L_MODE="$mode" \
    python3 -B "$dir/future-protocol/collect-v10.py" -- \
      "$dir/task7lcalibration.exe" || rc=$?
  printf '%s\t%s\n' "$sequence" "$rc" >> "$collection/driver-status.tsv"
  endpoint_rc=0
  endpoint "final-child-$sequence" || endpoint_rc=$?
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
echo 'v10 P38 small calibration retry: PASS'
