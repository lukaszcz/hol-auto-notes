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
(cd "$dir" && env T7G_POSITION="$position" T7G_PROBLEM="$problem" \
  T7G_DEPTH="$depth" T7G_BUDGET_SECONDS="$budget" \
  ./task7gmeasurement.exe) < /dev/null > "$stdout" 2> "$stderr" || status=$?
printf '%s\n' "$status" > "$status_file"
exit "$status"
