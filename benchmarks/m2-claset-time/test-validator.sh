#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-claset-time
validator=$dir/verify-claset-time.awk
awk -f "$validator" "$dir/raw.tsv" > /dev/null
awk -f "$validator" \
  "$dir/fixtures/good-partial-positive-zero-time.tsv" > /dev/null
if [ -f "$dir/regenerated-final-raw.tsv" ]; then
  awk -f "$validator" "$dir/regenerated-final-raw.tsv" > /dev/null
fi
for fixture in bad-negative-time bad-phase-sum bad-attempt-bound bad-status \
  bad-zero-count-positive-time bad-record-order bad-schema; do
  if awk -f "$validator" "$dir/fixtures/$fixture.tsv" > /dev/null 2>&1; then
    echo "negative fixture unexpectedly accepted: $fixture" >&2
    exit 1
  fi
done

calibration_validator=$dir/validate-calibrations.sh
"$calibration_validator" "$dir" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" "$dir/calibration-schedule.tsv" \
  "$dir/active-calibration-schedule.tsv" \
  "$dir/calibration-summary.tsv" > /dev/null
if "$calibration_validator" "$dir" "$dir/calibration-raw.tsv" \
    "$dir/active-calibration-raw.tsv" \
    "$dir/fixtures/bad-calibration-schedule-order.tsv" \
    "$dir/active-calibration-schedule.tsv" \
    "$dir/calibration-summary.tsv" > /dev/null 2>&1; then
  echo 'bad representative schedule order unexpectedly accepted' >&2
  exit 1
fi
if "$calibration_validator" "$dir" "$dir/calibration-raw.tsv" \
    "$dir/active-calibration-raw.tsv" \
    "$dir/calibration-schedule.tsv" \
    "$dir/fixtures/bad-active-calibration-schedule-mode.tsv" \
    "$dir/calibration-summary.tsv" \
    > /dev/null 2>&1; then
  echo 'bad active schedule mode unexpectedly accepted' >&2
  exit 1
fi
if "$calibration_validator" "$dir" "$dir/calibration-raw.tsv" \
    "$dir/fixtures/bad-active-calibration-raw-order.tsv" \
    "$dir/calibration-schedule.tsv" \
    "$dir/active-calibration-schedule.tsv" \
    "$dir/calibration-summary.tsv" \
    > /dev/null 2>&1; then
  echo 'bad active raw order unexpectedly accepted' >&2
  exit 1
fi

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/m2-claset-time-adversary.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
awk -F '\t' 'BEGIN {OFS = FS} NR == 2 {$6 = sprintf("%.9f", $6 + 1)} {print}' \
  "$dir/regenerated-final-calibration-raw.tsv" \
  > "$tmpdir/bad-timing-summary-drift.tsv"
if "$calibration_validator" "$dir" \
    "$tmpdir/bad-timing-summary-drift.tsv" \
    "$dir/regenerated-final-active-calibration-raw.tsv" \
    "$dir/calibration-schedule.tsv" \
    "$dir/active-calibration-schedule.tsv" \
    "$dir/regenerated-final-calibration-summary.tsv" \
    > /dev/null 2>&1; then
  echo 'timing-summary-drift adversary unexpectedly accepted' >&2
  exit 1
fi

expectation_validator=$dir/verify-final-expectations.awk
if [ -f "$dir/regenerated-final-expectations.tsv" ]; then
  awk -f "$expectation_validator" \
    "$dir/regenerated-final-expectations.tsv" \
    "$dir/regenerated-final-attempts.tsv"
  for fixture in bad-final-counter bad-final-context; do
    if awk -f "$expectation_validator" \
        "$dir/regenerated-final-expectations.tsv" \
        "$dir/fixtures/$fixture.tsv" > /dev/null 2>&1; then
      echo "exact expectation fixture unexpectedly accepted: $fixture" >&2
      exit 1
    fi
  done
fi
echo 'all positives accepted; 13 adversarial cases rejected'
