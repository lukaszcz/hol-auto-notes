#!/bin/sh
set -eu
cal=$1
active=$2
raw=$3
cal_summary=$4
target_summary=$5
scratch=${TMPDIR:?}/summary-check
rm -rf "$scratch"
mkdir -p "$scratch"
awk -f "$(dirname "$0")/summarize-calibration.awk" "$cal" "$active" \
  > "$scratch/calibration.tsv"
awk -f "$(dirname "$0")/summarize-target.awk" "$raw" \
  > "$scratch/target.tsv"
if ! cmp "$scratch/calibration.tsv" "$cal_summary" >/dev/null 2>&1; then
  echo 'verify-summaries: calibration summary drift' >&2
  exit 1
fi
if ! cmp "$scratch/target.tsv" "$target_summary" >/dev/null 2>&1; then
  echo 'verify-summaries: target summary drift' >&2
  exit 1
fi
echo 'mechanical calibration and target summaries: PASS'
