#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:-$(pwd -P)}")
dir=$(realpath -e -- \
  "${PACKAGE_DIR:-$root/.agent-files/benchmarks/m2-timed-v3-final}")
[ -d "$root" ] || { echo 'ROOT is not a directory' >&2; exit 2; }
[ -d "$dir" ] || { echo 'PACKAGE_DIR is not a directory' >&2; exit 2; }
scratch_root=${1:-${SCRATCH_ROOT:-}}
scratch_input=${2:-${SCRATCH_DIR:-}}
[ -n "$scratch_root" ] || { echo 'caller-provided scratch root required' >&2; exit 2; }
[ -n "$scratch_input" ] || { echo 'caller-provided scratch directory required' >&2; exit 2; }
scratch=$("$dir/validate-scratch-path.sh" "$scratch_root" "$scratch_input")
case "$scratch/" in "$dir/"*)
  echo 'selfcheck scratch must be outside the package' >&2; exit 2;;
esac
case "$dir/" in "$scratch/"*)
  echo 'selfcheck scratch must not contain the package' >&2; exit 2;;
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
    printf 'symlink\t%s\t-\t%s\n' "$path" "$(readlink "$dir/$path")"
  done >> "$output"
}
package_snapshot "$scratch/package-before.tsv"
"$dir/verify-package-integrity.sh" "$dir" "$scratch/integrity"

# This is the documented post-collection override. Verify every other live
# sealed input and the frozen original selfcheck body.
prefix=.agent-files/benchmarks/m2-timed-v3-final/
awk -v prefix="$prefix" '
  $2 == prefix "selfcheck.sh" {next}
  {path=$2;if(index(path,prefix)==1)path=substr(path,length(prefix)+1);
   print $1 "  " path}
' "$dir/INPUTS.sha256" > "$scratch/sealed-inputs.sha256"
(cd "$dir" && sha256sum -c "$scratch/sealed-inputs.sha256")

ROOT=$root PACKAGE_DIR=$dir "$dir/final-audit.sh" \
  "$scratch/final-artifact-audit"
awk -f "$dir/validate-calibration.awk" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" "$dir/calibration-schedule.tsv" \
  "$dir/active-calibration-schedule.tsv"
awk -f "$dir/summarize-calibration.awk" "$dir/calibration-raw.tsv" \
  "$dir/active-calibration-raw.tsv" > "$scratch/calibration-summary.tsv"
cmp "$scratch/calibration-summary.tsv" "$dir/calibration-summary.tsv"

rc=0
awk -f "$dir/verify-target.awk" "$dir/raw.tsv" \
  > "$scratch/target-validation.log" 2>&1 || rc=$?
[ "$rc" -eq 1 ]
cmp "$scratch/target-validation.log" "$dir/target-validation.log"
[ "$(cat "$dir/target-validation.status")" = 1 ]
[ "$(wc -l < "$dir/raw.tsv")" -eq 2 ]
sed -n '1p' "$dir/raw.tsv" | grep -Fx \
  'Task7h timed-v3 raw protocol v1' >/dev/null
sed -n '2p' "$dir/raw.tsv" | grep -Fx 'STATUS|1|34|143' >/dev/null
[ "$(sha256sum "$dir/raw.tsv" | awk '{print $1}')" = \
  6cfa72862bca61ad68aad044ceb48263a5c5d253ef2ecb0fff13d47234292805 ]
[ "$(sha256sum "$dir/collection-status.tsv" | awk '{print $1}')" = \
  5b5e15200ef9e6a8f15a948a7af130af0f2093521361bdd16f8d8f61c55f2a0b ]
cmp "$dir/raw.tsv" "$dir/collection-attempt-0/raw.tsv"
cmp "$dir/collection-status.tsv" \
  "$dir/collection-attempt-0/collection-status.tsv"
grep -Fx '  else process_rc=143; fi' \
  "$dir/frozen-inputs/collect-locked.sh" >/dev/null
grep -F 'not an observed child exit' \
  "$dir/FINAL_REVIEW_ERRATA.md" >/dev/null
grep -F 'No ablation or profile separated those candidates.' \
  "$dir/FINAL_REVIEW_ERRATA.md" >/dev/null
grep -F 'escalate to KILL if needed, prove the' \
  "$dir/FINAL_REVIEW_ERRATA.md" >/dev/null
grep -F 'group is gone, reap the supervised process' \
  "$dir/FINAL_REVIEW_ERRATA.md" >/dev/null

"$dir/test-validators.sh" "$scratch/validator-work" \
  "$scratch/validator-logs" "$scratch/validator-status.tsv"
awk -F '\t' '
  NR==1{next}
  {n++}
  $1=="cal-valid"||$1=="target-valid"||$1=="summary-valid"{
    if($3!="0")exit 1;positives++;next}
  {if($3=="0")exit 1;negatives++}
  END{if(n!=91||positives!=3||negatives!=88)exit 1}
' "$dir/validator-status.tsv"
awk -F '\t' 'NR>1&&$4!="0"{exit 1}' "$dir/preflight-status.tsv"
awk -F '\t' '
  NR==1{next}
  $2=="representative-process"{r++;if($4!="0")exit 1;next}
  $2=="active-process"{a++;if($4!="0")exit 1;next}
  $2=="target-process"{p++;if($4!="143")exit 1;next}
  $2=="target-watchdog"{w++;if($4!="124")exit 1;next}
  $2=="process-audit"{e++;if($4!="0")exit 1;next}
  $2=="identity"&&$1~/-artifacts$/{m++;if($4!="0")exit 1;next}
  {if($4!="0")exit 1}
  END{if(r!=12||a!=10||p!=1||w!=1||e!=6||m!=6)exit 1}
' "$dir/collection-status.tsv"
for segment in representative active target; do
  grep -Fx 'matches=none' \
    "$dir/provenance/$segment-pre-processes.txt" >/dev/null
  grep -Fx 'matches=none' \
    "$dir/provenance/$segment-post-processes.txt" >/dev/null
done
for name in task7hcalibration task7hactive task7hmeasurement; do
  grep -F 'wrapper_pid=' "$dir/endpoint-preflight/$name.log" >/dev/null
  grep -F 'child_pid=' "$dir/endpoint-preflight/$name.log" >/dev/null
done
[ ! -s "$dir/process-logs/target-1.stdout" ]
[ ! -s "$dir/process-logs/target-1.stderr" ]

git -C "$root" diff --cached --quiet
git -C "$root" diff --quiet -- src/auto
git -C "$root/.agent-files" diff --cached --quiet
package_snapshot "$scratch/package-after.tsv"
cmp "$scratch/package-before.tsv" "$scratch/package-after.tsv"
echo 'final failed-measurement package selfcheck (read-only): PASS'
