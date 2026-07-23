#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
directory=$root/.agent-files/benchmarks/m2-claset-time
schedule=${SCHEDULE:-$directory/schedule.tsv}
output=${OUTPUT:-$directory/regenerated-final-raw.tsv}
run=${M2T_RUN:-1}
budget=${M2T_BUDGET_SECONDS:-30}
watchdog=${M2T_WATCHDOG_SECONDS:-60}
lock=$directory/driver.lock
audit=${AUDIT:-$directory/regenerated-final-process-audit.txt}
lock_held=false

if [ -e "$output" ] || [ -e "$audit" ]; then
  echo "refusing to overwrite post-boundary regenerated-final target evidence" >&2
  exit 2
fi

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  if [ "$lock_held" = true ]; then
    released=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '\nLock release: %s\nDriver exit status: %s\n' \
      "$released" "$status" >> "$audit"
    rmdir "$lock"
  fi
  exit "$status"
}

if ! mkdir "$lock" 2>/dev/null; then
  echo "another cooperating claset-time driver holds $lock" >&2
  exit 2
fi
lock_held=true
trap cleanup EXIT HUP INT TERM

acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  echo 'M2 classical phase timing process/lock audit'
  echo '================================================'
  echo
  echo "Lock protocol: atomic mkdir $lock"
  echo "Lock acquisition: $acquired"
  echo "Lock owner PID: $$"
  echo 'Scope: held before the pre-run endpoint audit, across the complete'
  echo 'sequential schedule, and through the post-run endpoint audit.'
  echo 'Guarantee: excludes overlapping cooperating invocations of this driver.'
  echo 'Limit: endpoint snapshots do not prove that no unrelated or manual'
  echo 'matching process existed between the two snapshots.'
} > "$audit"

pre_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
pre_matches=$(pgrep -af '[m]2clasetime' || true)
{
  echo
  echo "Pre-run endpoint audit: $pre_time"
  echo "Command: pgrep -af '[m]2clasetime'"
  if [ -n "$pre_matches" ]; then
    printf 'Result:\n%s\n' "$pre_matches"
  else
    echo 'Result: no other matching process at this endpoint.'
  fi
} >> "$audit"
if [ -n "$pre_matches" ]; then
  echo 'pre-run endpoint audit found another matching process' >&2
  exit 2
fi

if [ "$budget" -ne 30 ] || [ "$watchdog" -ne 60 ]; then
  echo "claset-time schedule requires 30/60-second boundaries" >&2
  exit 2
fi

protocol=$(awk 'NR > 1 {
  value = $1 ":" $2 ":" $3 ":" $4
  result = result (result == "" ? "" : ",") value
} END { print result }' "$schedule")
if [ "$protocol" != \
     '1:34:7:false,2:41:6:false,3:45:11:false' ]; then
  echo "unexpected claset-time schedule: $protocol" >&2
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
      M2T_RUN=$run M2T_POSITION=$position M2T_PROBLEM=$problem \
      M2T_DEPTH=$depth M2T_DEBUG=$debug M2T_BUDGET_SECONDS=$budget \
      ./m2clasetime.exe) \
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

post_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
post_matches=$(pgrep -af '[m]2clasetime' || true)
{
  echo
  echo "Post-run endpoint audit: $post_time"
  echo "Command: pgrep -af '[m]2clasetime'"
  if [ -n "$post_matches" ]; then
    printf 'Result:\n%s\n' "$post_matches"
  else
    echo 'Result: no other matching process at this endpoint.'
  fi
} >> "$audit"
if [ -n "$post_matches" ]; then
  echo 'post-run endpoint audit found another matching process' >&2
  exit 2
fi
