#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
directory=$root/.agent-files/benchmarks/m2-rollback
validator=$directory/summarize-continuation.awk
valid=$directory/continuation.raw.tsv
expected=$directory/continuation.tsv
generated=$(mktemp)
diagnostic=$(mktemp)
trap 'rm -f "$generated" "$diagnostic"' EXIT HUP INT TERM

awk -f "$validator" "$valid" > "$generated"
cmp "$generated" "$expected"

for fixture in unknown-event reordered-events stdout-row \
               nonterminal-status; do
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

echo "valid continuation evidence reproduced; all four negative fixtures rejected"
