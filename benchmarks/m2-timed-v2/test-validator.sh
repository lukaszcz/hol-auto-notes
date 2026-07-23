#!/bin/sh
set -eu
dir=${1:-$(dirname "$0")}
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure/validator
rm -rf "$scratch"
mkdir -p "$scratch"
"$dir/verify-target.awk" "$dir/raw.tsv" > "$scratch/good.log"
"$dir/make-adversarial-fixtures.sh" "$dir/raw.tsv" "$scratch/fixtures"
for fixture in "$scratch"/fixtures/*.tsv; do
  name=$(basename "$fixture")
  if "$dir/verify-target.awk" "$fixture" > "$scratch/$name.log" 2>&1; then
    echo "validator accepted $name" >&2
    exit 1
  fi
done
if [ -d "$dir/fixtures" ]; then
  diff -ru "$dir/fixtures" "$scratch/fixtures"
fi
count=$(find "$scratch/fixtures" -type f | wc -l)
[ "$count" -eq 24 ] || { echo "expected 24 adversaries, got $count" >&2; exit 1; }
echo "validator accepted authoritative raw and rejected 24 independent adversaries: PASS"
