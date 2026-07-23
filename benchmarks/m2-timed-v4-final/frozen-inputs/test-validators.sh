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

# Every additive timed-v4 scalar receives its own lexical adversary.
for field in 23 24 25 26 27 28 29; do
  target_case "field_$field" 'v4 minor count grammar'
done
for field in 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47; do
  target_case "field_$field" 'v4 minor time grammar'
done
for field in 48 49 50 51 52; do
  target_case "field_$field" 'v4 pull count grammar'
done
for field in 53 54 55 56 57 58 59 60 61 62; do
  target_case "field_$field" 'v4 pull time grammar'
done

target_case binding_failure_identity 'binding failure/event relationship'
target_case traversal_partition 'v4 traversal subcomponent partition'
target_case minor_classical 'minor/classical identity'
target_case cleanup_zero 'cleanup zero relationship'
target_case minor_max_category 'v4 minor maximum/category relationship'
target_case minor_max_overall 'v4 minor overall maximum relationship'
target_case pull_count_identity 'pull outcome/count identity'
target_case pull_snapshot_identity 'pull classical snapshot relationship'
target_case terminal_read_identity 'terminal statistics read identity'
target_case pull_time_partition 'pull outcome-time partition'
target_case pull_alternative_identity 'pull/residual alternative identity'
target_case pull_max_category 'pull maximum/category relationship'
target_case pull_max_overall 'pull overall maximum relationship'
target_case attempt_residual 'attempt residual'

awk -F '\t' -v OFS='\t' 'NR==2{$2="999.000000000"}{print}' \
  "$scratch/cal-summary.tsv" > "$scratch/cal-summary-drift.tsv"
status=0
"$dir/verify-summaries.sh" "$scratch/cal.tsv" "$scratch/active.tsv" \
  "$scratch/target.tsv" "$scratch/cal-summary-drift.tsv" \
  "$scratch/target-summary.tsv" > "$logs/summary-drift.log" 2>&1 || status=$?
check_failure summary-drift "$logs/summary-drift.log" \
  'verify-summaries: calibration summary drift' "$status" \
  'verify-summaries.sh calibration-summary-drift'

echo 'synthetic positives and 88 independent adversaries: PASS'
