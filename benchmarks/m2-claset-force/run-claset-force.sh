#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
directory=$root/.agent-files/benchmarks/m2-claset-force
schedule=${SCHEDULE:-$directory/schedule.tsv}
output=${OUTPUT:-$directory/raw.tsv}
run=${M2C_RUN:-1}
budget=${M2C_BUDGET_SECONDS:-30}
watchdog=${M2C_WATCHDOG_SECONDS:-60}
lock=$directory/driver.lock
audit=$directory/process-audit.txt
lock_held=false

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
  echo "another cooperating claset-force driver holds $lock" >&2
  exit 2
fi
lock_held=true
trap cleanup EXIT HUP INT TERM

acquired=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  echo 'M2 exact stored-rule forcing process/lock audit'
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
pre_matches=$(pgrep -af '[m]2clasetforce' || true)
{
  echo
  echo "Pre-run endpoint audit: $pre_time"
  echo "Command: pgrep -af '[m]2clasetforce'"
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
  echo "claset-force schedule requires 30/60-second boundaries" >&2
  exit 2
fi

protocol=$(awk 'NR > 1 {
  value = $1 ":" $2 ":" $3 ":" $4
  result = result (result == "" ? "" : ",") value
} END { print result }' "$schedule")
if [ "$protocol" != \
     '1:34:7:false,2:41:6:false,3:45:11:false' ]; then
  echo "unexpected claset-force schedule: $protocol" >&2
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
      M2C_RUN=$run M2C_POSITION=$position M2C_PROBLEM=$problem \
      M2C_DEPTH=$depth M2C_DEBUG=$debug M2C_BUDGET_SECONDS=$budget \
      "$root/bin/hol" --gcthreads=1 run \
        --holstate="$root/bin/hol.state0" m2clasetforce) \
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
post_matches=$(pgrep -af '[m]2clasetforce' || true)
{
  echo
  echo "Post-run endpoint audit: $post_time"
  echo "Command: pgrep -af '[m]2clasetforce'"
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
