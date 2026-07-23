#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v2-final
scratch=${1:?caller-provided scratch directory required}
mandated=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure-final-fix/
case "$scratch/" in "$mandated"*) ;; *)
  echo "selfcheck scratch must be under $mandated" >&2
  exit 2
esac
export TMPDIR=$scratch/tmp
rm -rf "$scratch"
mkdir -p "$TMPDIR"

package_manifest() {
  output=$1
  printf 'path\tsha256\tsize\tmtime_ns\n' > "$output"
  find "$dir" -type f -printf '%P\n' | LC_ALL=C sort |
  while IFS= read -r path; do
    hash=$(sha256sum "$dir/$path" | awk '{print $1}')
    size=$(stat -c '%s' "$dir/$path")
    mtime=$(stat -c '%y' "$dir/$path")
    printf '%s\t%s\t%s\t%s\n' "$path" "$hash" "$size" "$mtime"
  done >> "$output"
}
package_manifest "$scratch/package-before.tsv"

(cd "$root" && sha256sum -c "$dir/INPUTS.sha256")
ROOT=$root "$dir/artifact-manifest.sh" "$scratch/artifacts.tsv"
cmp "$scratch/artifacts.tsv" "$dir/ARTIFACTS-FROZEN.tsv"
for name in blastSearch blastRule blastTerm tableauLib clasetLib \
  clasetSeedTheory; do
  grep -E "src/auto/.*/$name[.](sml|sig|ui|uo)" \
    "$dir/ARTIFACTS-FROZEN.tsv" >/dev/null
done
awk -f "$dir/validate-calibration.awk" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" "$dir/calibration-schedule.tsv" \
  "$dir/active-calibration-schedule.tsv"
awk -f "$dir/verify-target.awk" "$dir/raw.tsv"
"$dir/verify-summaries.sh" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" "$dir/raw.tsv" \
  "$dir/calibration-summary.tsv" "$dir/target-summary.tsv"
"$dir/test-validators.sh" "$scratch/validator-work" \
  "$scratch/validator-logs" "$scratch/validator-status.tsv"

awk -F '\t' '
  NR==1{next}
  $2=="representative-process"{r++}
  $2=="active-process"{a++}
  $2=="target-process"{p++}
  $2=="target-watchdog"{w++}
  $2=="process-audit"{e++}
  $2=="identity" && $1 ~ /-artifacts$/{m++}
  $4!="0"{exit 1}
  END{if(r!=12||a!=10||p!=3||w!=3||e!=6||m!=6)exit 1}
' "$dir/collection-status.tsv"
awk -F '\t' 'NR>1 && $4!="0"{exit 1}' "$dir/preflight-status.tsv"
awk -F '\t' '
  NR==1{next}
  {n++}
  $1=="cal-valid" || $1=="target-valid" || $1=="summary-valid" {
    if($3!="0")exit 1; positives++; next
  }
  {if($3=="0")exit 1; negatives++}
  END{if(n!=37||positives!=3||negatives!=34)exit 1}
' "$dir/validator-status.tsv"
for segment in representative active target; do
  grep -Fx 'matches=none' \
    "$dir/provenance/$segment-pre-processes.txt" >/dev/null
  grep -Fx 'matches=none' \
    "$dir/provenance/$segment-post-processes.txt" >/dev/null
  cmp "$dir/ARTIFACTS-FROZEN.tsv" \
    "$dir/provenance/$segment-pre-artifacts.tsv"
  cmp "$dir/ARTIFACTS-FROZEN.tsv" \
    "$dir/provenance/$segment-post-artifacts.tsv"
done
for name in task7gcalibration task7gactive task7gmeasurement; do
  grep -F 'wrapper_pid=' "$dir/endpoint-preflight/$name.log" >/dev/null
  grep -F 'child_pid=' "$dir/endpoint-preflight/$name.log" >/dev/null
done

git diff --cached --quiet
git diff --quiet -- src/auto
git -C .agent-files diff --cached --quiet
if [ -f "$dir/checksums.sha256" ]; then
  (cd "$root" && sha256sum -c "$dir/checksums.sha256")
  find "$dir" -type f ! -name checksums.sha256 -printf '%P\n' |
    LC_ALL=C sort > "$scratch/current-files.txt"
  sed 's#^[0-9a-f][0-9a-f]*  .agent-files/benchmarks/m2-timed-v2-final/##' \
    "$dir/checksums.sha256" | LC_ALL=C sort > "$scratch/sealed-files.txt"
  cmp "$scratch/current-files.txt" "$scratch/sealed-files.txt"
fi

package_manifest "$scratch/package-after.tsv"
cmp "$scratch/package-before.tsv" "$scratch/package-after.tsv"
echo 'final package selfcheck (read-only before/after manifest): PASS'
