#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
schedule=${SCHEDULE:-.agent-files/benchmarks/m2-rollback/schedule.tsv}
output=${OUTPUT:-.agent-files/benchmarks/m2-rollback/continuation.raw.tsv}
run=${M2C_RUN:-1}
budget=${M2C_BUDGET_SECONDS:-30}
watchdog=${M2C_WATCHDOG_SECONDS:-60}

if [ "$budget" -ne 30 ] || [ "$watchdog" -ne 60 ]; then
  echo "continuation schedule requires the 30/60-second boundaries" >&2
  exit 2
fi

printf '%b\n' \
  'run\tposition\tproblem\tdepth\tdebug\tbudget_seconds\twatchdog_seconds\trecord\tpayload' \
  > "$output"

tail -n +2 "$schedule" |
while read -r position problem depth debug; do
  stdout_file=$(mktemp)
  stderr_file=$(mktemp)
  status=0
  (cd "$root/src/auto/blast" &&
    timeout "${watchdog}s" env \
      M2P_RUN=$run M2P_POSITION=$position M2P_PROBLEM=$problem \
      M2P_DEPTH=$depth M2P_DEBUG=$debug M2P_BUDGET_SECONDS=$budget \
      "$root/bin/hol" --gcthreads=1 run \
        --holstate="$root/bin/hol.state0" m2continuation) \
      > "$stdout_file" 2> "$stderr_file" || status=$?

  while IFS= read -r line; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tmarker\t%s\n' \
      "$run" "$position" "$problem" "$depth" "$debug" "$budget" \
      "$watchdog" "$line" >> "$output"
  done < "$stderr_file"
  while IFS= read -r line; do
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tstdout\t%s\n' \
      "$run" "$position" "$problem" "$depth" "$debug" "$budget" \
      "$watchdog" "$line" >> "$output"
  done < "$stdout_file"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tstatus\t%s\n' \
    "$run" "$position" "$problem" "$depth" "$debug" "$budget" \
    "$watchdog" "$status" >> "$output"
  rm -f "$stdout_file" "$stderr_file"

  if [ "$status" -ne 0 ] && [ "$status" -ne 124 ]; then
    exit "$status"
  fi
done
