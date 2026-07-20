#!/bin/sh
set -eu

# Run from the repository root after compiling m2benchmark.uo as documented.
# Schedule columns are: position, problem, depth, debug.

root=${ROOT:-$(pwd)}
schedule=${SCHEDULE:-.agent-files/benchmarks/m2/schedule.tsv}
output=${OUTPUT:-.agent-files/benchmarks/m2/raw.tsv}
run=${M2_RUN:-1}
budget=${M2_BUDGET_SECONDS:-30}
watchdog=${M2_WATCHDOG_SECONDS:-60}

header='run\tposition\tproblem\tdepth\tdebug\tbudget_seconds\tcompletion'
header="$header\tsearch_result\tseconds\tconfigured_depth"
header="$header\tmaximum_resource_cost"
header="$header\tinferences_performed\tbranches_created\tbranches_closed"
header="$header\tchoices_pruned\trule_cache_hits\trule_conversions"
header="$header\tstop_polls\ttrace_states\tmaximum_live_branches"
header="$header\tmaximum_state_formula_slots"
printf '%b\n' "$header" > "$output"

tail -n +2 "$schedule" |
while read -r position problem depth debug; do
  row_file=$(mktemp)
  status=0
  (cd "$root/src/auto/blast" &&
    timeout "${watchdog}s" env \
      M2_RUN=$run M2_POSITION=$position M2_PROBLEM=$problem \
      M2_DEPTH=$depth M2_DEBUG=$debug M2_BUDGET_SECONDS=$budget \
      "$root/bin/hol" --gcthreads=1 run \
        --holstate="$root/bin/hol.state0" m2benchmark) > "$row_file" ||
    status=$?
  if [ "$status" -eq 0 ]; then
    cat "$row_file" >> "$output"
  elif [ "$status" -eq 124 ]; then
    prefix="$run\t$position\t$problem\t$depth\t$debug\t$budget"
    suffix="$depth\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA"
    printf '%b\n' "$prefix\tunobserved\twatchdog_killed\t>=${watchdog}.000000\t$suffix" \
      >> "$output"
  else
    cat "$row_file" >&2
    rm -f "$row_file"
    exit "$status"
  fi
  rm -f "$row_file"
done
