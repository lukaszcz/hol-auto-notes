#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
directory=$root/.agent-files/benchmarks/m2-reconstruct
validator=$directory/verify-reconstruction.awk
generated=$(mktemp)
diagnostic=$(mktemp)
trap 'rm -f "$generated" "$diagnostic"' EXIT HUP INT TERM

awk -f "$validator" "$directory/raw.tsv" > "$generated"
cmp "$generated" "$directory/attempts.tsv"

for fixture in bad-header unknown-phase bad-counter; do
  if awk -f "$validator" "$directory/fixtures/$fixture.tsv" \
       > "$generated" 2> "$diagnostic"; then
    echo "validator accepted negative fixture: $fixture" >&2
    exit 1
  fi
  if [ ! -s "$diagnostic" ]; then
    echo "validator rejected without a diagnostic: $fixture" >&2
    exit 1
  fi
done

echo "valid reconstruction evidence reproduced; negative fixtures rejected"
