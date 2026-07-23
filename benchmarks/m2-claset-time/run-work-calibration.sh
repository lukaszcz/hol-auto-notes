#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-claset-time
out=${OUTPUT:-$dir/regenerated-final-calibration-raw.tsv}
if [ -e "$out" ]; then
  echo "refusing to overwrite post-boundary regenerated-final calibration" >&2
  exit 2
fi
printf 'repetition\tproblem\tdepth\tmode\toutcome\telapsed\tattempts\tcheckpoints\tinferences\tbranches_created\tbranches_closed\tchoices_pruned\tmax_cost\tcache_hits\tconversions\treconstruction_signatures\n' > "$out"
tail -n +2 "$dir/calibration-schedule.tsv" |
while IFS="$(printf '\t')" read -r sequence repetition position problem depth mode; do
  (cd "$root/src/auto/blast" &&
    M2T_REPETITION=$repetition M2T_PROBLEM=$problem M2T_DEPTH=$depth \
    M2T_MODE=$mode ./workcalibration.exe) < /dev/null >> "$out"
done
