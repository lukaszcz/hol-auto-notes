#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
schedule=${SCHEDULE:-.agent-files/benchmarks/m2-rollback/schedule.tsv}
output=${OUTPUT:-.agent-files/benchmarks/m2-rollback/raw.tsv}
run=${M2R_RUN:-1}
budget=${M2R_BUDGET_SECONDS:-30}
watchdog=${M2R_WATCHDOG_SECONDS:-60}

if [ "$budget" -ne 30 ] || [ "$watchdog" -ne 60 ]; then
  echo "rollback schedule requires the 30/60-second boundaries" >&2
  exit 2
fi

header='run\tposition\tproblem\tdepth\tdebug\tbudget_seconds'
header="$header\tcompletion\tsearch_result\tseconds\tconfigured_depth"
header="$header\tmaximum_resource_cost\tinferences_performed"
header="$header\tbranches_created\tbranches_closed\tchoices_pruned"
header="$header\trule_cache_hits\trule_conversions\tstop_polls"
header="$header\tcooperative_checkpoints\tcandidate_rules_enumerated"
header="$header\tcandidate_conversions_attempted\tsafe_rule_attempts"
header="$header\tunsafe_rule_attempts\trule_unification_attempts"
header="$header\trule_unification_successes"
header="$header\tequality_substitution_attempts"
header="$header\tequality_substitution_successes"
header="$header\tliteral_close_attempts\tliteral_close_successes"
header="$header\ttrace_states\tmaximum_live_branches"
header="$header\tmaximum_state_formula_slots"
printf '%b\n' "$header" > "$output"

tail -n +2 "$schedule" |
while read -r position problem depth debug; do
  row_file=$(mktemp)
  status=0
  (cd "$root/src/auto/blast" &&
    timeout "${watchdog}s" env \
      M2P_RUN=$run M2P_POSITION=$position M2P_PROBLEM=$problem \
      M2P_DEPTH=$depth M2P_DEBUG=$debug M2P_BUDGET_SECONDS=$budget \
      "$root/bin/hol" --gcthreads=1 run \
        --holstate="$root/bin/hol.state0" m2rollback) > "$row_file" ||
    status=$?
  if [ "$status" -eq 0 ]; then
    cat "$row_file" >> "$output"
  elif [ "$status" -eq 124 ]; then
    prefix="$run\t$position\t$problem\t$depth\t$debug\t$budget"
    suffix="$depth\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA"
    suffix="$suffix\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA"
    printf '%b\n' \
      "$prefix\tunobserved\twatchdog_killed\t>=${watchdog}.000000\t$suffix" \
      >> "$output"
  else
    cat "$row_file" >&2
    rm -f "$row_file"
    exit "$status"
  fi
  rm -f "$row_file"
done
