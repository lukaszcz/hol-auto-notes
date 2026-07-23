#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v4-final
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7j_v4_measure_fresh
work=$scratch/collection
lock=$scratch/collection.lock
export TMPDIR=$scratch/tmp
mkdir -p "$TMPDIR"
[ ! -e "$work" ] || { echo 'collect: scratch collection exists' >&2; exit 2; }
mkdir "$lock" || { echo 'collect: lock held' >&2; exit 2; }
trap 'rmdir "$lock"' EXIT HUP INT TERM
mkdir -p "$work/logs" "$work/status" "$work/audits"
status=$work/collection-status.tsv
printf 'label\tclass\tstatus\tcommand\n' > "$status"
record() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$status"; }

audit() {
  label=$1
  out=$work/audits/$label.txt
  matches=$(pgrep -af '[/]task7j(calibration|active|measurement)[.]exe|bin/hol.*task7j(calibration|active|measurement)' || true)
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" > "$out"
    record "$label" process-audit 2 'pgrep task7j endpoints'
    return 2
  fi
  echo 'matches=none' > "$out"
  record "$label" process-audit 0 'pgrep task7j endpoints'
}

identity() {
  label=$1
  out=$work/audits/$label-artifacts.tsv
  ROOT=$root "$dir/artifact-manifest.sh" "$out"
  cmp "$dir/ARTIFACTS-FROZEN.tsv" "$out" >/dev/null
  record "$label-artifacts" identity 0 \
    'artifact-manifest.sh; cmp ARTIFACTS-FROZEN.tsv'
}

run_child() {
  label=$1; timeout=$2; stdout=$3; stderr=$4; shift 4
  child_status=$work/status/$label.json
  set +e
  python3 "$dir/supervise.py" --timeout "$timeout" --grace 3 \
    --status "$child_status" --stdout "$stdout" --stderr "$stderr" \
    --cwd "$dir" -- "$@"
  rc=$?
  set -e
  record "$label" supervised-child "$rc" "$*"
  [ "$rc" -eq 0 ]
}

cp "$dir/INPUTS.sha256" "$work/INPUTS.sha256"
(cd "$root" && sha256sum -c "$dir/INPUTS.sha256") > "$work/input-check.log"
audit pre-collection
identity pre-collection

cal=$work/calibration-raw.tsv
printf 'repetition\tproblem\tdepth\tmode\toutcome\telapsed\tattempts\tsearch_counters\treconstruction_signatures\n' > "$cal"
while IFS="$(printf '\t')" read -r sequence repetition position problem depth mode; do
  [ "$sequence" = sequence ] && continue
  run_child "representative-$sequence" 45 \
    "$work/logs/representative-$sequence.stdout" \
    "$work/logs/representative-$sequence.stderr" \
    env T7J_REPETITION="$repetition" T7J_PROBLEM="$problem" \
      T7J_DEPTH="$depth" T7J_MODE="$mode" ./task7jcalibration.exe
  cat "$work/logs/representative-$sequence.stdout" >> "$cal"
done < "$dir/calibration-schedule.tsv"

active=$work/active-calibration-raw.tsv
printf 'repetition\tmode\tbatch\telapsed\tcounter_signature\n' > "$active"
while IFS="$(printf '\t')" read -r sequence repetition fixture batch mode; do
  [ "$sequence" = sequence ] && continue
  run_child "active-$sequence" 15 "$work/logs/active-$sequence.stdout" \
    "$work/logs/active-$sequence.stderr" env T7J_REPETITION="$repetition" \
      T7J_BATCH="$batch" T7J_MODE="$mode" ./task7jactive.exe
  cat "$work/logs/active-$sequence.stdout" >> "$active"
done < "$dir/active-calibration-schedule.tsv"

awk -f "$dir/validate-calibration.awk" "$cal" "$active" \
  "$dir/calibration-schedule.tsv" "$dir/active-calibration-schedule.tsv" \
  > "$work/calibration-validation.log"
awk -f "$dir/summarize-calibration.awk" "$cal" "$active" \
  > "$work/calibration-summary.tsv"
set +e
awk -f "$dir/calibration-gate.awk" "$work/calibration-summary.tsv" \
  > "$work/calibration-gate.log" 2>&1
gate_rc=$?
set -e
record calibration-gate stop-go "$gate_rc" 'calibration-gate.awk calibration-summary.tsv'
audit post-calibration
identity post-calibration
if [ "$gate_rc" -ne 0 ]; then
  echo FAIL > "$work/GATE-RESULT"
  cp -R "$work" "$dir/collection"
  exit 3
fi
echo PASS > "$work/GATE-RESULT"

raw=$work/raw.tsv
bounded=$work/bounded-raw.tsv
printf 'Task7j timed-v4 raw protocol v1\n' > "$raw"
: > "$bounded"
while IFS="$(printf '\t')" read -r position problem depth debug budget watchdog; do
  [ "$position" = position ] && continue
  run_child "target-$position" 45 "$work/logs/target-$position.stdout" \
    "$work/logs/target-$position.stderr" env T7J_POSITION="$position" \
      T7J_PROBLEM="$problem" T7J_DEPTH="$depth" \
      T7J_BUDGET_SECONDS="$budget" ./task7jmeasurement.exe
  sed -n '/^ATTEMPT|/p' "$work/logs/target-$position.stderr" >> "$raw"
  sed -n '/^BOUNDED|/p' "$work/logs/target-$position.stderr" >> "$bounded"
  sed -n '/^SUMMARY|/p' "$work/logs/target-$position.stdout" >> "$raw"
  sed -n '/^BOUNDED_SUMMARY|/p' "$work/logs/target-$position.stdout" >> "$bounded"
  printf 'STATUS|%s|%s|0\n' "$position" "$problem" >> "$raw"
done < "$dir/schedule.tsv"
echo 'EOF|Task7j timed-v4 raw protocol v1' >> "$raw"
awk -f "$dir/verify-target.awk" "$raw" > "$work/target-validation.log"
awk -f "$dir/verify-bounded.awk" "$bounded" > "$work/bounded-validation.log"
awk -f "$dir/summarize-target.awk" "$raw" > "$work/target-summary.tsv"
"$dir/verify-summaries.sh" "$cal" "$active" "$raw" \
  "$work/calibration-summary.tsv" "$work/target-summary.tsv" \
  > "$work/summary-validation.log"
audit post-target
identity post-target
cp -R "$work" "$dir/collection"
echo 'fresh v4 collection: PASS'
