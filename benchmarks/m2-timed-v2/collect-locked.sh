#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v2
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure
lock=$scratch/schedule.lock
export TMPDIR=$scratch/tmp
outputs="$dir/calibration-raw.tsv $dir/active-calibration-raw.tsv $dir/raw.tsv $dir/build-provenance.txt $dir/source-before.sha256 $dir/source-after.sha256"
for path in $outputs; do
  if [ -e "$path" ]; then
    echo "refusing existing authoritative output: $path" >&2
    exit 2
  fi
done
mkdir -p "$scratch" "$TMPDIR"
if ! mkdir "$lock" 2>/dev/null; then
  echo "schedule lock already held: $lock" >&2
  exit 2
fi
cleanup() { status=$?; trap - EXIT HUP INT TERM; rmdir "$lock"; exit "$status"; }
trap cleanup EXIT HUP INT TERM

audit=$scratch/process-audit.txt
pre=$(pgrep -af '[t]ask7gmeasurement' || true)
{
  echo "lock=$lock"
  echo "acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "owner_pid=$$"
  echo "endpoint_command=pgrep -af '[t]ask7gmeasurement'"
  if [ -n "$pre" ]; then printf 'pre_matches=%s\n' "$pre";
  else echo "pre_matches=none"; fi
} > "$audit"
if [ -n "$pre" ]; then echo "contaminated pre endpoint" >&2; exit 2; fi

git ls-files 'src/auto/classical/**' 'src/auto/blast/**' | sort |
  xargs sha256sum > "$scratch/source-before.sha256"

status_log=$scratch/command-status.txt
run_logged() {
  label=$1
  shift
  log=$scratch/$label.log
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  status=0
  "$@" > "$log" 2>&1 || status=$?
  printf '%s\t%s\t%s\n' "$label" "$started" "$status" >> "$status_log"
  [ "$status" -eq 0 ] || return "$status"
}

: > "$status_log"
run_logged classical-clean bin/Holmake -C src/auto/classical clean
run_logged classical-build bin/Holmake -C src/auto/classical \
  clasetUnify.uo clasetStep.uo selftest.exe
run_logged classical-selftest sh -c \
  'cd src/auto/classical && HOLSELFTESTLEVEL=2 ./selftest.exe'
run_logged blast-clean bin/Holmake -C src/auto/blast clean
run_logged blast-build bin/Holmake -C src/auto/blast \
  blastReconstruct.uo selftest.exe
run_logged blast-selftest sh -c \
  'cd src/auto/blast && HOLSELFTESTLEVEL=2 ./selftest.exe'
run_logged harness-clean bin/Holmake -C "$dir" clean
run_logged harness-build bin/Holmake -C "$dir" \
  task7gmeasurement.exe task7gcalibration.exe task7gactive.exe

cal=$dir/calibration-raw.tsv
printf 'repetition\tproblem\tdepth\tmode\toutcome\telapsed\tattempts\tsearch_counters\treconstruction_signatures\n' > "$cal"
tail -n +2 "$dir/calibration-schedule.tsv" |
while IFS="$(printf '\t')" read -r sequence repetition position problem depth mode; do
  (cd "$dir" && env T7G_REPETITION=$repetition T7G_PROBLEM=$problem \
    T7G_DEPTH=$depth T7G_MODE=$mode ./task7gcalibration.exe) \
    < /dev/null >> "$cal"
done

active=$dir/active-calibration-raw.tsv
printf 'repetition\tmode\tbatch\telapsed\tcounter_signature\n' > "$active"
tail -n +2 "$dir/active-calibration-schedule.tsv" |
while IFS="$(printf '\t')" read -r sequence repetition fixture batch mode; do
  (cd "$dir" && env T7G_REPETITION=$repetition T7G_BATCH=$batch \
    T7G_MODE=$mode ./task7gactive.exe) < /dev/null >> "$active"
done
"$dir/validate-calibration.sh" "$cal" "$active"
awk -f "$dir/summarize-calibration.awk" "$cal" "$active" \
  > "$dir/calibration-summary.tsv"

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
  if [ "$status" -ne 0 ]; then exit "$status"; fi
done
echo 'EOF|Task7g timed-v2 raw protocol v1' >> "$raw"
"$dir/verify-target.awk" "$raw" > "$scratch/target-validation.log"

post=$(pgrep -af '[t]ask7gmeasurement' || true)
{
  echo "released_endpoint=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ -n "$post" ]; then printf 'post_matches=%s\n' "$post";
  else echo "post_matches=none"; fi
} >> "$audit"
if [ -n "$post" ]; then echo "contaminated post endpoint" >&2; exit 2; fi

git ls-files 'src/auto/classical/**' 'src/auto/blast/**' | sort |
  xargs sha256sum > "$scratch/source-after.sha256"
cmp "$scratch/source-before.sha256" "$scratch/source-after.sha256"
cp "$scratch/source-before.sha256" "$dir/source-before.sha256"
cp "$scratch/source-after.sha256" "$dir/source-after.sha256"
cp "$status_log" "$dir/command-status.tsv"
cp "$audit" "$dir/process-audit.txt"
cp "$scratch/target-validation.log" "$dir/target-validation.log"
{
  echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "revision=$(git rev-parse HEAD)"
  echo "host=$(uname -a)"
  echo "poly=$(poly --version 2>&1 | head -n 1)"
  echo "clock=Time.now"
  echo "process_option=--gcthreads=1"
  echo "target_order=P34@7,P41@6,P45@11"
  echo "boundaries=30-second shared cooperative,60-second watchdog"
  sha256sum src/auto/classical/clasetUnify.sig \
    src/auto/classical/clasetUnify.sml src/auto/classical/clasetUnify.ui \
    src/auto/classical/clasetUnify.uo src/auto/classical/clasetStep.sig \
    src/auto/classical/clasetStep.sml src/auto/classical/clasetStep.ui \
    src/auto/classical/clasetStep.uo src/auto/blast/blastReconstruct.sig \
    src/auto/blast/blastReconstruct.sml src/auto/blast/blastReconstruct.ui \
    src/auto/blast/blastReconstruct.uo "$dir/task7gmeasurement.sml" \
    "$dir/task7gmeasurement.uo" "$dir/task7gmeasurement.exe" \
    "$dir/task7gcalibration.sml" "$dir/task7gcalibration.uo" \
    "$dir/task7gcalibration.exe" "$dir/task7gactive.sml" \
    "$dir/task7gactive.uo" "$dir/task7gactive.exe"
  stat -c '%Y.%N' src/auto/classical/clasetUnify.sml \
    src/auto/classical/clasetUnify.ui src/auto/classical/clasetUnify.uo \
    src/auto/classical/clasetStep.sml src/auto/classical/clasetStep.ui \
    src/auto/classical/clasetStep.uo src/auto/blast/blastReconstruct.sml \
    src/auto/blast/blastReconstruct.ui src/auto/blast/blastReconstruct.uo \
    "$dir/task7gmeasurement.sml" "$dir/task7gmeasurement.uo" \
    "$dir/task7gmeasurement.exe"
} > "$dir/build-provenance.txt"
