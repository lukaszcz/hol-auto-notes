#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided scratch required}
rm -rf -- "$scratch"
mkdir -p "$scratch"
python3 -B "$dir/generate-synthetic.py" "$dir/schedule.tsv" \
  "$scratch/valid.tsv"
python3 -B "$dir/validate-results.py" --schedule "$dir/schedule.tsv" \
  --raw "$scratch/valid.tsv" > "$scratch/valid.log"
grep -Fx 'validate-results: PASS' "$scratch/valid.log" >/dev/null
for mutation in append header reorder mode work clock summary trace \
  sequence_reads internal external status eof; do
  python3 -B "$dir/mutate-fixture.py" "$scratch/valid.tsv" \
    "$scratch/$mutation.tsv" "$mutation"
  rc=0
  python3 -B "$dir/validate-results.py" --schedule "$dir/schedule.tsv" \
    --raw "$scratch/$mutation.tsv" > "$scratch/$mutation.stdout" \
    2> "$scratch/$mutation.stderr" || rc=$?
  [ "$rc" -eq 1 ]
  [ ! -s "$scratch/$mutation.stdout" ]
  [ "$(wc -l < "$scratch/$mutation.stderr")" -eq 1 ]
  grep -E '^validate-results: ' "$scratch/$mutation.stderr" >/dev/null
  ! grep -F PASS "$scratch/$mutation.stderr" >/dev/null
done
cp "$dir/schedule.tsv" "$scratch/bad-schedule.tsv"
sed -i '2s/\tA$/\tD/' "$scratch/bad-schedule.tsv"
rc=0
python3 -B "$dir/validate-results.py" --schedule "$scratch/bad-schedule.tsv" \
  --raw "$scratch/valid.tsv" > "$scratch/schedule.stdout" \
  2> "$scratch/schedule.stderr" || rc=$?
[ "$rc" -eq 1 ]
[ ! -s "$scratch/schedule.stdout" ]
[ "$(wc -l < "$scratch/schedule.stderr")" -eq 1 ]
echo 'result validator positive plus 14 adversaries: PASS'
