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
mkdir -p "$collection"

audit() {
  output=$1
  matches=$(pgrep -af \
    '[/]task7kcalibration[.]exe|bin/hol.*task7kcalibration' || true)
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" > "$output"
    return 2
  fi
  printf 'matches=none\n' > "$output"
}

audit "$collection/pre-endpoint.txt"
cp "$dir/schedule.tsv" "$collection/schedule.tsv"
while IFS="$(printf '\t')" read -r sequence repetition problem depth mode; do
  [ "$sequence" = sequence ] && continue
  child=$collection/child-$sequence
  rc=0
  ROOT="$root" PACKAGE_DIR="$dir" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$child" \
    ENDPOINT_PATTERN='[/]task7kcalibration[.]exe|bin/hol.*task7kcalibration' \
    ARTIFACT_REFERENCE="$reference" SEGMENT_TIMEOUT=25 TERM_GRACE=1 \
    POST_KILL_GRACE=1 QUIET_INTERVAL=.05 POLL_INTERVAL=.01 \
    python3 -B "$dir/future-protocol/collect-v10.py" -- env \
      T7K_SEQUENCE="$sequence" T7K_REPETITION="$repetition" \
      T7K_PROBLEM="$problem" T7K_DEPTH="$depth" T7K_MODE="$mode" \
      "$dir/task7kcalibration.exe" || rc=$?
  printf '%s\t%s\n' "$sequence" "$rc" >> "$collection/driver-status.tsv"
  if [ "$rc" -ne 0 ]; then
    audit "$collection/failure-endpoint.txt" || true
    exit "$rc"
  fi
done < "$dir/schedule.tsv"
audit "$collection/post-endpoint.txt"
python3 -B "$dir/materialize-results.py" --collection "$collection" \
  --output "$collection/raw.tsv"
python3 -B "$dir/validate-results.py" --schedule "$dir/schedule.tsv" \
  --raw "$collection/raw.tsv" --collection "$collection" \
  --artifact-reference "$reference" > "$collection/validation.log"
sha256sum "$collection/raw.tsv" > "$collection/raw.tsv.sha256"
python3 -B "$dir/summarize-results.py" --raw "$collection/raw.tsv" \
  --summary "$collection/summary.tsv" --report "$collection/FINAL_REPORT.md"
echo 'v10 P38 small calibration: PASS'
