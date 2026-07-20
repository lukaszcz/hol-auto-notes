#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
directory=$root/.agent-files/benchmarks/m2-reconstruct
schedule=${SCHEDULE:-$directory/schedule.tsv}
output=${OUTPUT:-$directory/raw.tsv}
run=${M2R_RUN:-1}
budget=${M2R_BUDGET_SECONDS:-30}
watchdog=${M2R_WATCHDOG_SECONDS:-60}

if [ "$budget" -ne 30 ] || [ "$watchdog" -ne 60 ]; then
  echo "reconstruction schedule requires 30/60-second boundaries" >&2
  exit 2
fi

protocol=$(awk 'NR > 1 {
  value = $1 ":" $2 ":" $3 ":" $4
  result = result (result == "" ? "" : ",") value
} END { print result }' "$schedule")
if [ "$protocol" != \
     '1:34:7:false,2:41:6:false,3:45:11:false' ]; then
  echo "unexpected reconstruction schedule: $protocol" >&2
  exit 2
fi

printf '%b\n' \
  'run\tposition\tproblem\tdepth\tdebug\tbudget_seconds\twatchdog_seconds\trecord\tpayload' \
  > "$output"

for position in 1 2 3; do
  case $position in
    1) problem=34; depth=7; debug=false ;;
    2) problem=41; depth=6; debug=false ;;
    3) problem=45; depth=11; debug=false ;;
  esac
  stdout_file=$(mktemp)
  stderr_file=$(mktemp)
  status=0
  (cd "$root/src/auto/blast" &&
    timeout "${watchdog}s" env \
      M2R_RUN=$run M2R_POSITION=$position M2R_PROBLEM=$problem \
      M2R_DEPTH=$depth M2R_DEBUG=$debug M2R_BUDGET_SECONDS=$budget \
      "$root/bin/hol" --gcthreads=1 run \
        --holstate="$root/bin/hol.state0" m2reconstruct) \
      < /dev/null > "$stdout_file" 2> "$stderr_file" || status=$?

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
