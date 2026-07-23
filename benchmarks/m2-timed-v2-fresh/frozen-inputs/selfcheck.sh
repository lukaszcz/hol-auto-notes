#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v2-fresh
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure-fix/selfcheck
export TMPDIR=$scratch/tmp
rm -rf "$scratch"
mkdir -p "$TMPDIR"
(cd "$root" && sha256sum -c "$dir/INPUTS.sha256")
ROOT=$root "$dir/artifact-manifest.sh" "$scratch/artifacts.tsv"
cmp "$scratch/artifacts.tsv" "$dir/ARTIFACTS-FROZEN.tsv"
awk -f "$dir/validate-calibration.awk" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" "$dir/calibration-schedule.tsv" \
  "$dir/active-calibration-schedule.tsv"
awk -f "$dir/verify-target.awk" "$dir/raw.tsv"
"$dir/verify-summaries.sh" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" "$dir/raw.tsv" \
  "$dir/calibration-summary.tsv" "$dir/target-summary.tsv"
"$dir/test-validators.sh"
awk -F '\t' '
  NR==1{next}
  $2=="representative-process"{r++}
  $2=="active-process"{a++}
  $2=="target-process"{p++}
  $2=="target-watchdog"{w++}
  $4!="0"{exit 1}
  END{if(r!=12||a!=10||p!=3||w!=3)exit 1}
' "$dir/collection-status.tsv"
awk -F '\t' 'NR>1 && $4!="0"{exit 1}' "$dir/preflight-status.tsv"
for segment in representative active target; do
  grep -Fx 'matches=none' "$dir/provenance/$segment-pre-processes.txt" >/dev/null
  grep -Fx 'matches=none' "$dir/provenance/$segment-post-processes.txt" >/dev/null
  cmp "$dir/ARTIFACTS-FROZEN.tsv" \
    "$dir/provenance/$segment-pre-artifacts.tsv"
  cmp "$dir/ARTIFACTS-FROZEN.tsv" \
    "$dir/provenance/$segment-post-artifacts.tsv"
done
git diff --cached --quiet
git diff --quiet -- src/auto/classical src/auto/blast
git -C .agent-files diff --cached --quiet
if [ -f "$dir/checksums.sha256" ]; then
  (cd "$root" && sha256sum -c "$dir/checksums.sha256")
  find "$dir" -type f ! -name checksums.sha256 ! -name SEAL_PLAN.md \
    -printf '%P\n' | sort > "$scratch/current-files.txt"
  sed 's#^[0-9a-f][0-9a-f]*  .agent-files/benchmarks/m2-timed-v2-fresh/##' \
    "$dir/checksums.sha256" | sort > "$scratch/sealed-files.txt"
  cmp "$scratch/current-files.txt" "$scratch/sealed-files.txt"
fi
echo 'fresh package selfcheck: PASS'
