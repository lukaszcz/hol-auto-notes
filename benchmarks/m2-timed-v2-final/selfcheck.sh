#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:-$(pwd -P)}")
dir=$(realpath -e -- \
  "${PACKAGE_DIR:-$root/.agent-files/benchmarks/m2-timed-v2-final}")
[ -d "$root" ] || { echo 'ROOT is not a directory' >&2; exit 2; }
[ -d "$dir" ] || { echo 'PACKAGE_DIR is not a directory' >&2; exit 2; }
scratch_root=${1:-${SCRATCH_ROOT:-}}
scratch_input=${2:-${SCRATCH_DIR:-}}
[ -n "$scratch_root" ] || {
  echo 'caller-provided scratch root required' >&2
  exit 2
}
[ -n "$scratch_input" ] || {
  echo 'caller-provided scratch directory required' >&2
  exit 2
}
scratch=$("$dir/validate-scratch-path.sh" "$scratch_root" "$scratch_input")
case "$scratch/" in "$dir/"*)
  echo 'selfcheck scratch must be outside the package' >&2
  exit 2
esac
case "$dir/" in "$scratch/"*)
  echo 'selfcheck scratch must not contain the package' >&2
  exit 2
esac
export TMPDIR=$scratch/tmp
rm -rf -- "$scratch"
mkdir -p "$TMPDIR"

package_snapshot() {
  output=$1
  printf 'type\tpath\tsha256\tlink_target\n' > "$output"
  find "$dir" -type f -printf '%P\n' | LC_ALL=C sort |
  while IFS= read -r path; do
    hash=$(sha256sum "$dir/$path" | awk '{print $1}')
    printf 'regular\t%s\t%s\t-\n' "$path" "$hash"
  done >> "$output"
  find "$dir" -type l -printf '%P\n' | LC_ALL=C sort |
  while IFS= read -r path; do
    target=$(readlink "$dir/$path")
    printf 'symlink\t%s\t-\t%s\n' "$path" "$target"
  done >> "$output"
}
package_snapshot "$scratch/package-before.tsv"

"$dir/verify-package-integrity.sh" "$dir" "$scratch/integrity"

# INPUTS.sha256 is immutable pre-clock evidence.  The current selfcheck is the
# sole post-collection override, so verify all other entries and the frozen
# original selfcheck body rather than falsifying the historical manifest.
prefix=.agent-files/benchmarks/m2-timed-v2-final/
awk -v prefix="$prefix" '
  $2 == prefix "selfcheck.sh" {next}
  {
    path=$2
    if (index(path,prefix)==1) path=substr(path,length(prefix)+1)
    print $1 "  " path
  }
' "$dir/INPUTS.sha256" > "$scratch/sealed-inputs.sha256"
(cd "$dir" && sha256sum -c "$scratch/sealed-inputs.sha256")

ROOT=$root PACKAGE_DIR=$dir "$dir/final-audit.sh" \
  "$scratch/final-artifact-audit"
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
done
for name in task7gcalibration task7gactive task7gmeasurement; do
  grep -F 'wrapper_pid=' "$dir/endpoint-preflight/$name.log" >/dev/null
  grep -F 'child_pid=' "$dir/endpoint-preflight/$name.log" >/dev/null
done

git -C "$root" diff --cached --quiet
git -C "$root" diff --quiet -- src/auto
git -C "$root/.agent-files" diff --cached --quiet

package_snapshot "$scratch/package-after.tsv"
cmp "$scratch/package-before.tsv" "$scratch/package-after.tsv"
echo 'final package selfcheck (regular bytes and symlink targets): PASS'
