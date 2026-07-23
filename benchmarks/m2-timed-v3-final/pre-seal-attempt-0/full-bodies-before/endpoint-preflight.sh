#!/bin/bash
set -eu
scratch=${1:?caller-provided scratch directory required}
mkdir -p "$scratch"

check_pattern() {
  name=$1
  pattern=$2
  wrapper=$scratch/wrapper-$name
  child=$scratch/child-$name
  ln -sf /bin/sleep "$wrapper"
  ln -sf /bin/sleep "$child"
  "$wrapper" 30 &
  wrapper_pid=$!
  bash -c 'exec -a "$1/bin/hol --gcthreads=1 '$name'" /bin/sleep 30' \
    bash "$scratch" &
  child_pid=$!
  trap 'kill "$wrapper_pid" "$child_pid" 2>/dev/null || true; wait "$wrapper_pid" "$child_pid" 2>/dev/null || true' RETURN
  sleep 0.1
  matches=$(pgrep -af "$pattern")
  printf 'name=%s\npattern=%s\nwrapper_pid=%s\nchild_pid=%s\n%s\n' \
    "$name" "$pattern" "$wrapper_pid" "$child_pid" "$matches" \
    > "$scratch/$name.log"
  printf '%s\n' "$matches" | grep -E "^$wrapper_pid " >/dev/null
  printf '%s\n' "$matches" | grep -E "^$child_pid " >/dev/null
  count=$(printf '%s\n' "$matches" | wc -l)
  [ "$count" -eq 2 ]
  if printf '%s\n' "$matches" | grep -E "^$$ " >/dev/null; then
    echo "audit process matched itself: $name" >&2
    return 1
  fi
  kill "$wrapper_pid" "$child_pid"
  wait "$wrapper_pid" "$child_pid" 2>/dev/null || true
  trap - RETURN
}

check_pattern task7hcalibration '[t]ask7gcalibration'
check_pattern task7hactive '[t]ask7gactive'
check_pattern task7hmeasurement '[t]ask7gmeasurement'
echo 'wrapper/HOL-child endpoint detection and non-self-match: PASS'
