#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v2
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure/selfcheck
rm -rf "$scratch"
mkdir -p "$scratch"
(cd "$root" && sha256sum -c "$dir/checksums.sha256")
(cd "$root" && sha256sum -c "$dir/AUTHORITATIVE_RAW.sha256")
"$dir/verify-target.awk" "$dir/raw.tsv"
"$dir/validate-calibration.sh" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv"
awk -f "$dir/summarize-calibration.awk" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" > "$scratch/calibration-summary.tsv"
cmp "$scratch/calibration-summary.tsv" "$dir/calibration-summary.tsv"
awk -f "$dir/summarize-target.awk" "$dir/raw.tsv" \
  > "$scratch/target-summary.tsv"
cmp "$scratch/target-summary.tsv" "$dir/target-summary.tsv"
"$dir/test-validator.sh" "$dir"
"$dir/verify-audit.sh" "$dir"
(cd "$root" && sha256sum -c "$dir/source-after.sha256")
if git diff --quiet -- src/auto/classical src/auto/blast; then :; else
  echo 'tracked source differs from HEAD' >&2; exit 1
fi
if git status --porcelain --untracked-files=no | grep -q .; then
  echo 'tracked worktree/staging scope is not clean' >&2; exit 1
fi
echo 'package checksums/regeneration/source scope: PASS'
