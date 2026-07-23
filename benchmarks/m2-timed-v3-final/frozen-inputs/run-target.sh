#!/bin/sh
set -u
dir=$1
stdout=$2
stderr=$3
status_file=$4
position=$5
problem=$6
depth=$7
budget=$8
status=0
(cd "$dir" && env T7H_POSITION="$position" T7H_PROBLEM="$problem" \
  T7H_DEPTH="$depth" T7H_BUDGET_SECONDS="$budget" \
  ./task7hmeasurement.exe) < /dev/null > "$stdout" 2> "$stderr" || status=$?
printf '%s\n' "$status" > "$status_file"
exit "$status"
