#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided scratch directory required}
logs=${2:?caller-provided log directory required}
status_file=${3:?caller-provided status file required}
rm -rf "$scratch" "$logs"
mkdir -p "$scratch" "$logs"
printf 'label\tcategory\tstatus\tcommand\n' > "$status_file"

record() {
  printf '%s\tvalidator\t%s\t%s\n' "$1" "$2" "$3" >> "$status_file"
}
positive() {
  label=$1
  command=$2
  log=$3
  shift 3
  rc=0
  "$@" > "$log" 2>&1 || rc=$?
  record "$label" "$rc" "$command"
  [ "$rc" -eq 0 ]
}

awk -v kind=calibration -f "$dir/generate-synthetic.awk" > "$scratch/cal.tsv"
awk -v kind=active -f "$dir/generate-synthetic.awk" > "$scratch/active.tsv"
awk -v kind=target -f "$dir/generate-synthetic.awk" > "$scratch/target.tsv"
positive cal-valid \
  'validate-calibration.awk synthetic calibration and active positives' \
  "$logs/cal-valid.log" awk -f "$dir/validate-calibration.awk" \
  "$scratch/cal.tsv" "$scratch/active.tsv" \
  "$dir/calibration-schedule.tsv" "$dir/active-calibration-schedule.tsv"
positive target-valid 'verify-target.awk synthetic target positive' \
  "$logs/target-valid.log" awk -f "$dir/verify-target.awk" \
  "$scratch/target.tsv"
awk -f "$dir/summarize-calibration.awk" "$scratch/cal.tsv" \
  "$scratch/active.tsv" > "$scratch/cal-summary.tsv"
awk -f "$dir/summarize-target.awk" "$scratch/target.tsv" \
  > "$scratch/target-summary.tsv"
positive summary-valid 'verify-summaries.sh synthetic positive summaries' \
  "$logs/summary-valid.log" "$dir/verify-summaries.sh" \
  "$scratch/cal.tsv" "$scratch/active.tsv" "$scratch/target.tsv" \
  "$scratch/cal-summary.tsv" "$scratch/target-summary.tsv"

check_failure() {
  label=$1
  log=$2
  expected=$3
  status=$4
  command=$5
  record "$label" "$status" "$command"
  [ "$status" -ne 0 ] || {
    echo "adversary unexpectedly passed: $log" >&2
    exit 1
  }
  [ "$(wc -l < "$log")" -eq 1 ] || {
    echo "adversary emitted secondary diagnostics: $log" >&2
    exit 1
  }
  grep -Fx "$expected" "$log" >/dev/null
  if grep -F 'PASS' "$log" >/dev/null; then
    echo "adversary emitted PASS: $log" >&2
    exit 1
  fi
}
cal_case() {
  scenario=$1
  expected=$2
  fixture=$scratch/cal-$scenario.tsv
  log=$logs/cal-$scenario.log
  awk -v kind=calibration -v scenario="$scenario" \
    -f "$dir/mutate-fixture.awk" "$scratch/cal.tsv" > "$fixture"
  status=0
  awk -f "$dir/validate-calibration.awk" "$fixture" \
    "$scratch/active.tsv" "$dir/calibration-schedule.tsv" \
    "$dir/active-calibration-schedule.tsv" > "$log" 2>&1 || status=$?
  check_failure "cal-$scenario" "$log" \
    "validate-calibration: $expected" "$status" \
    "validate-calibration.awk cal-$scenario.tsv"
}
target_case() {
  scenario=$1
  expected=$2
  fixture=$scratch/target-$scenario.tsv
  log=$logs/target-$scenario.log
  awk -v kind=target -v scenario="$scenario" \
    -f "$dir/mutate-fixture.awk" "$scratch/target.tsv" > "$fixture"
  status=0
  awk -f "$dir/verify-target.awk" "$fixture" > "$log" 2>&1 || status=$?
  check_failure "target-$scenario" "$log" "verify-target: $expected" \
    "$status" "verify-target.awk target-$scenario.tsv"
}

cal_case header 'exact header/schema'
cal_case schema 'representative row count/schema'
cal_case elapsed 'representative elapsed grammar'
cal_case problem 'representative problem literal'
cal_case depth 'representative depth literal'
cal_case mode 'representative mode/order literal'
cal_case repetition 'representative repetition literal'
cal_case reorder 'representative mode/order literal'
cal_case signature_width 'ordered signature width'
cal_case signature_token 'ordered signature token'

target_case problem 'canonical target schedule literal'
target_case problem_noncanonical 'canonical target schedule literal'
target_case depth 'canonical target schedule literal'
target_case depth_noncanonical 'canonical target schedule literal'
target_case attempt 'canonical attempt literal'
target_case outer_boundary 'outer boundary vocabulary'
target_case outer_phase 'outer phase vocabulary'
target_case step_kind 'stored step vocabulary'
target_case duplicate_vocab 'duplicate vocabulary'
target_case safe_duplicate 'safe duplicate relationship'
target_case stored_boundary 'stored boundary vocabulary'
target_case stored_phase 'stored phase vocabulary'
target_case rule_kind 'rule kind vocabulary'
target_case intro_assumption 'intro assumption relationship'
target_case elim_assumption 'elim assumption relationship'
target_case major_intro 'major-unification rule relationship'
target_case partial_context 'partial stored context'
target_case outer_partition 'outer partition'
target_case minor_partition 'minor partition'
target_case elapsed_grammar 'outer/attempt decimal grammar'
target_case stats_width 'natural CSV width'
target_case status 'status/order/value'
target_case append 'record after EOF'

awk -F '\t' -v OFS='\t' 'NR==2{$2="999.000000000"}{print}' \
  "$scratch/cal-summary.tsv" > "$scratch/cal-summary-drift.tsv"
status=0
"$dir/verify-summaries.sh" "$scratch/cal.tsv" "$scratch/active.tsv" \
  "$scratch/target.tsv" "$scratch/cal-summary-drift.tsv" \
  "$scratch/target-summary.tsv" > "$logs/summary-drift.log" 2>&1 || status=$?
check_failure summary-drift "$logs/summary-drift.log" \
  'verify-summaries: calibration summary drift' "$status" \
  'verify-summaries.sh calibration-summary-drift'

echo 'synthetic positives and 34 independent adversaries: PASS'
