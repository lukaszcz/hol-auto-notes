#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v2
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure
lock=$scratch/schedule.lock
export TMPDIR=$scratch/tmp
[ -f "$dir/calibration-raw.tsv" ] || { echo 'missing representative ledger' >&2; exit 2; }
for path in "$dir/active-calibration-raw.tsv" "$dir/raw.tsv" "$dir/calibration-summary.tsv"; do
  [ ! -e "$path" ] || { echo "refusing existing output $path" >&2; exit 2; }
done
if ! mkdir "$lock" 2>/dev/null; then echo 'schedule lock held' >&2; exit 2; fi
cleanup(){ status=$?; trap - EXIT HUP INT TERM; rmdir "$lock"; exit "$status"; }
trap cleanup EXIT HUP INT TERM
audit=$scratch/continuation-process-audit.txt
pre=$(pgrep -af '[t]ask7gmeasurement' || true)
{
  echo "lock=$lock"
  echo "acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "owner_pid=$$"
  echo "endpoint_command=pgrep -af '[t]ask7gmeasurement'"
  if [ -n "$pre" ]; then printf 'pre_matches=%s\n' "$pre"; else echo pre_matches=none; fi
} > "$audit"
[ -z "$pre" ] || exit 2

active=$dir/active-calibration-raw.tsv
printf 'repetition\tmode\tbatch\telapsed\tcounter_signature\n' > "$active"
tail -n +2 "$dir/active-calibration-schedule.tsv" |
while IFS="$(printf '\t')" read -r sequence repetition fixture batch mode; do
  (cd "$dir" && env T7G_REPETITION=$repetition T7G_BATCH=$batch \
    T7G_MODE=$mode ./task7gactive.exe) < /dev/null >> "$active"
done
"$dir/validate-calibration.sh" "$dir/calibration-raw.tsv" "$active"
awk -f "$dir/summarize-calibration.awk" "$dir/calibration-raw.tsv" \
  "$active" > "$dir/calibration-summary.tsv"

raw=$dir/raw.tsv
printf 'Task7g timed-v2 raw protocol v1\n' > "$raw"
tail -n +2 "$dir/schedule.tsv" |
while IFS="$(printf '\t')" read -r position problem depth debug budget watchdog; do
  stdout=$TMPDIR/target-$position.stdout
  stderr=$TMPDIR/target-$position.stderr
  status=0
  (cd "$dir" && timeout "${watchdog}s" env T7G_POSITION=$position \
    T7G_PROBLEM=$problem T7G_DEPTH=$depth T7G_BUDGET_SECONDS=$budget \
    ./task7gmeasurement.exe) < /dev/null > "$stdout" 2> "$stderr" || status=$?
  sed -n '/^ATTEMPT|/p' "$stderr" >> "$raw"
  sed -n '/^SUMMARY|/p' "$stdout" >> "$raw"
  printf 'STATUS|%s|%s|%s\n' "$position" "$problem" "$status" >> "$raw"
  [ "$status" -eq 0 ] || exit "$status"
done
echo 'EOF|Task7g timed-v2 raw protocol v1' >> "$raw"
"$dir/verify-target.awk" "$raw" > "$scratch/target-validation.log"
post=$(pgrep -af '[t]ask7gmeasurement' || true)
{
  echo "post_endpoint=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ -n "$post" ]; then printf 'post_matches=%s\n' "$post"; else echo post_matches=none; fi
} >> "$audit"
[ -z "$post" ] || exit 2
cp "$audit" "$dir/process-audit.txt"
cp "$scratch/target-validation.log" "$dir/target-validation.log"
