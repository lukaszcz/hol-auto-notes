#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v3-final
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7h-measure
lock=$scratch/schedule.lock
work=$scratch/collection-evidence
export TMPDIR=$scratch/tmp
mkdir -p "$TMPDIR"
for output in calibration-raw.tsv active-calibration-raw.tsv raw.tsv \
  calibration-summary.tsv target-summary.tsv collection-status.tsv; do
  [ ! -e "$dir/$output" ] || {
    echo "refusing existing output: $output" >&2
    exit 2
  }
done
[ -f "$dir/INPUTS.sha256" ] || {
  echo 'inputs are not frozen' >&2
  exit 2
}
if ! mkdir "$lock" 2>/dev/null; then
  echo "lock held: $lock" >&2
  exit 2
fi
rm -rf "$work"
mkdir -p "$work/provenance" "$work/process-logs"
cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  if [ "$rc" -ne 0 ] && [ ! -e "$dir/collection-attempt-0" ]; then
    cp -R "$work" "$dir/collection-attempt-0"
  fi
  rmdir "$lock"
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM

status=$work/collection-status.tsv
printf 'label\tcategory\tstarted_utc\tstatus\tcommand\n' > "$status"
record() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" \
    >> "$status"
}
identity() {
  segment=$1
  endpoint=$2
  out=$work/provenance/$segment-$endpoint-artifacts.tsv
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  rc=0
  ROOT=$root "$dir/artifact-manifest.sh" "$out" || rc=$?
  if [ "$rc" -eq 0 ]; then
    cmp "$dir/ARTIFACTS-FROZEN.tsv" "$out" >/dev/null 2>&1 || rc=$?
  fi
  record "$segment-$endpoint-artifacts" identity "$started" "$rc" \
    "artifact-manifest.sh $segment-$endpoint-artifacts.tsv; cmp ARTIFACTS-FROZEN.tsv"
  [ "$rc" -eq 0 ]
}
snapshot() {
  segment=$1
  endpoint=$2
  pattern=$3
  out=$work/provenance/$segment-$endpoint-processes.txt
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  matches=$(pgrep -af "$pattern" || true)
  {
    printf 'captured_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'lock=%s\npattern=%s\n' "$lock" "$pattern"
    if [ -n "$matches" ]; then
      printf 'matches=%s\n' "$matches"
    else
      echo 'matches=none'
    fi
  } > "$out"
  if [ -n "$matches" ]; then rc=2; else rc=0; fi
  record "$segment-$endpoint-processes" process-audit "$started" "$rc" \
    "pgrep -af '$pattern'"
  [ "$rc" -eq 0 ]
}
verify_inputs() {
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  rc=0
  (cd "$root" && sha256sum -c "$dir/INPUTS.sha256") \
    > "$work/provenance/input-verification.log" 2>&1 || rc=$?
  record input-verification identity "$started" "$rc" \
    'sha256sum -c INPUTS.sha256 (live inputs and frozen full bodies)'
  [ "$rc" -eq 0 ]
}
verify_inputs

cal=$work/calibration-raw.tsv
printf 'repetition\tproblem\tdepth\tmode\toutcome\telapsed\tattempts\tsearch_counters\treconstruction_signatures\n' \
  > "$cal"
identity representative pre
snapshot representative pre '[t]ask7gcalibration'
segment_rc=0
while IFS="$(printf '\t')" read -r sequence repetition position problem \
  depth mode; do
  [ "$sequence" = sequence ] && continue
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  command="cd $dir && env T7H_REPETITION=$repetition T7H_PROBLEM=$problem T7H_DEPTH=$depth T7H_MODE=$mode ./task7hcalibration.exe"
  rc=0
  (cd "$dir" && env T7H_REPETITION="$repetition" \
    T7H_PROBLEM="$problem" T7H_DEPTH="$depth" T7H_MODE="$mode" \
    ./task7hcalibration.exe) < /dev/null >> "$cal" \
    2> "$work/process-logs/representative-$sequence.stderr" || rc=$?
  record "representative-$sequence" representative-process "$started" \
    "$rc" "$command"
  if [ "$rc" -ne 0 ]; then segment_rc=$rc; break; fi
done < "$dir/calibration-schedule.tsv"
identity representative post
snapshot representative post '[t]ask7gcalibration'
[ "$segment_rc" -eq 0 ] || exit "$segment_rc"

active=$work/active-calibration-raw.tsv
printf 'repetition\tmode\tbatch\telapsed\tcounter_signature\n' > "$active"
identity active pre
snapshot active pre '[t]ask7gactive'
segment_rc=0
while IFS="$(printf '\t')" read -r sequence repetition fixture batch mode; do
  [ "$sequence" = sequence ] && continue
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  command="cd $dir && env T7H_REPETITION=$repetition T7H_BATCH=$batch T7H_MODE=$mode ./task7hactive.exe"
  rc=0
  (cd "$dir" && env T7H_REPETITION="$repetition" T7H_BATCH="$batch" \
    T7H_MODE="$mode" ./task7hactive.exe) < /dev/null >> "$active" \
    2> "$work/process-logs/active-$sequence.stderr" || rc=$?
  record "active-$sequence" active-process "$started" "$rc" "$command"
  if [ "$rc" -ne 0 ]; then segment_rc=$rc; break; fi
done < "$dir/active-calibration-schedule.tsv"
identity active post
snapshot active post '[t]ask7gactive'
[ "$segment_rc" -eq 0 ] || exit "$segment_rc"
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rc=0
awk -f "$dir/validate-calibration.awk" "$cal" "$active" \
  "$dir/calibration-schedule.tsv" "$dir/active-calibration-schedule.tsv" \
  > "$work/calibration-validation.log" 2>&1 || rc=$?
record calibration-validator validator "$started" "$rc" \
  'validate-calibration.awk calibration-raw active-calibration-raw frozen schedules'
[ "$rc" -eq 0 ] || exit "$rc"
awk -f "$dir/summarize-calibration.awk" "$cal" "$active" \
  > "$work/calibration-summary.tsv"

raw=$work/raw.tsv
printf 'Task7h timed-v3 raw protocol v1\n' > "$raw"
identity target pre
snapshot target pre '[t]ask7gmeasurement'
segment_rc=0
while IFS="$(printf '\t')" read -r position problem depth debug budget \
  watchdog; do
  [ "$position" = position ] && continue
  stdout=$TMPDIR/target-$position.stdout
  stderr=$TMPDIR/target-$position.stderr
  inner=$TMPDIR/target-$position.process-status
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  command="timeout ${watchdog}s run-target.sh $position $problem $depth $budget"
  watchdog_rc=0
  timeout "${watchdog}s" "$dir/run-target.sh" "$dir" "$stdout" \
    "$stderr" "$inner" "$position" "$problem" "$depth" "$budget" \
    || watchdog_rc=$?
  if [ -f "$inner" ]; then process_rc=$(sed -n '1p' "$inner")
  else process_rc=143; fi
  record "target-$position-process" target-process "$started" \
    "$process_rc" \
    "run-target.sh T7H_POSITION=$position T7H_PROBLEM=$problem T7H_DEPTH=$depth T7H_BUDGET_SECONDS=$budget ./task7hmeasurement.exe"
  record "target-$position-watchdog" target-watchdog "$started" \
    "$watchdog_rc" "$command"
  sed -n '/^ATTEMPT|/p' "$stderr" >> "$raw"
  sed -n '/^SUMMARY|/p' "$stdout" >> "$raw"
  printf 'STATUS|%s|%s|%s\n' "$position" "$problem" "$process_rc" \
    >> "$raw"
  cp "$stdout" "$work/process-logs/target-$position.stdout"
  cp "$stderr" "$work/process-logs/target-$position.stderr"
  if [ "$process_rc" -ne 0 ] || [ "$watchdog_rc" -ne 0 ]; then
    segment_rc=$watchdog_rc
    [ "$segment_rc" -ne 0 ] || segment_rc=$process_rc
    break
  fi
done < "$dir/schedule.tsv"
if [ "$segment_rc" -eq 0 ]; then
  echo 'EOF|Task7h timed-v3 raw protocol v1' >> "$raw"
fi
identity target post
snapshot target post '[t]ask7gmeasurement'
[ "$segment_rc" -eq 0 ] || exit "$segment_rc"
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rc=0
awk -f "$dir/verify-target.awk" "$raw" \
  > "$work/target-validation.log" 2>&1 || rc=$?
record target-validator validator "$started" "$rc" \
  'verify-target.awk raw.tsv'
[ "$rc" -eq 0 ] || exit "$rc"
awk -f "$dir/summarize-target.awk" "$raw" \
  > "$work/target-summary.tsv"
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
rc=0
"$dir/verify-summaries.sh" "$cal" "$active" "$raw" \
  "$work/calibration-summary.tsv" "$work/target-summary.tsv" \
  > "$work/summary-validation.log" 2>&1 || rc=$?
record summary-validator validator "$started" "$rc" \
  'verify-summaries.sh fresh raw and summaries'
[ "$rc" -eq 0 ] || exit "$rc"

cp "$work/calibration-raw.tsv" "$work/active-calibration-raw.tsv" \
  "$work/raw.tsv" "$work/calibration-summary.tsv" \
  "$work/target-summary.tsv" "$work/calibration-validation.log" \
  "$work/target-validation.log" "$work/summary-validation.log" \
  "$work/collection-status.tsv" "$dir/"
cp -R "$work/provenance" "$dir/provenance"
cp -R "$work/process-logs" "$dir/process-logs"
echo 'fresh representative, active and target collection: PASS'
