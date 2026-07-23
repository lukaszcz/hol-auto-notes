#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-claset-time
out=${OUTPUT:-$dir/regenerated-final-active-calibration-raw.tsv}
if [ -e "$out" ]; then
  echo "refusing to overwrite post-boundary regenerated-final calibration" >&2
  exit 2
fi
printf 'repetition\tmode\tbatch\telapsed\tcheckpoints\tentries\texits\tstored_checkpoints\tstored_entries\tstored_exits\tattempts\tmajor\trecords\n' > "$out"
tail -n +2 "$dir/active-calibration-schedule.tsv" |
while IFS="$(printf '\t')" read -r sequence repetition fixture batch mode; do
  (cd "$root/src/auto/blast" &&
    M2T_MODE=$mode M2T_REPETITION=$repetition M2T_BATCH=$batch \
      ./activecalibration.exe) < /dev/null >> "$out"
done
