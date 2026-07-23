#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided new scratch required}
[ ! -e "$scratch" ] || { echo 'endpoint test: scratch exists' >&2; exit 2; }
mkdir -p "$scratch"
python3 -B "$dir/endpoint-audit.py" --output "$scratch/clean-before.txt"
/bin/bash -c 'exec -a "$1" /bin/sleep 30' sh "$dir/task7nclock.exe" &
pid=$!
printf '%s\n' "$pid" >"$scratch/synthetic.pid"
rc=0
python3 -B "$dir/endpoint-audit.py" --output "$scratch/detected.txt" || rc=$?
printf '%s\n' "$rc" >"$scratch/detected.status"
[ "$rc" -eq 1 ]
grep -F "$dir/task7nclock.exe" "$scratch/detected.txt" >/dev/null
kill "$pid"
wait "$pid" || :
python3 -B "$dir/endpoint-audit.py" --output "$scratch/clean-after.txt"
echo 'exact argv endpoint positive/negative controls: PASS'

