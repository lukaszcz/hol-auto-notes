#!/bin/sh
set -eu

# Run from the current (c7f72c445) repository.  The baseline worktree and
# both executables must already have been configured and built as described
# in README.md.  Each row is a fresh HOL/Poly process.  Revisions alternate
# at every repetition, and the formula order reverses on even repetitions.

baseline=${BASELINE:-/tmp/hol4-m1-be308c56d}
current=${CURRENT:-$(pwd)}
repetitions=${REPETITIONS:-3}
start_repetition=${START_REPETITION:-1}
output=${OUTPUT:-.agent-files/benchmarks/m1/raw.tsv}

if [ "$start_repetition" -eq 1 ]; then
  header='revision\trepetition\tposition\tproblem\tdepth\tbatch'
  header="$header\toutcome\tseconds\tbranches_created\tbranches_closed"
  header="$header\tchoices_pruned\tper_run_created\tper_run_closed"
  header="$header\tper_run_pruned"
  printf '%b\n' "$header" > "$output"
elif [ ! -s "$output" ]; then
  echo "cannot append repetitions: missing output $output" >&2
  exit 1
fi

run_revision () {
  root=$1
  revision=$2
  repetition=$3
  order=$4
  position=0
  for item in $order; do
    position=$((position + 1))
    problem=${item%%:*}
    remainder=${item#*:}
    depth=${remainder%%:*}
    batch=${remainder#*:}
    (cd "$root/src/auto/blast" && \
      M1_REVISION=$revision M1_REPETITION=$repetition \
      M1_POSITION=$position M1_PROBLEM=$problem M1_DEPTH=$depth \
      M1_BATCH=$batch "$root/bin/hol" --gcthreads=1 run \
        --holstate="$root/bin/hol.state0" m1benchmark) >> "$output"
  done
}

forward='34:4:500 38:3:150 41:3:300 42:3:1 43:3:600 45:3:500'
reverse='45:3:500 43:3:600 42:3:1 41:3:300 38:3:150 34:4:500'
repetition=$start_repetition
while [ "$repetition" -le "$repetitions" ]; do
  if [ $((repetition % 2)) -eq 1 ]; then order=$forward; else order=$reverse; fi
  run_revision "$baseline" be308c56d "$repetition" "$order"
  run_revision "$current" c7f72c445 "$repetition" "$order"
  repetition=$((repetition + 1))
done
