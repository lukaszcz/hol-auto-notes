#!/bin/sh
set -eu
root=${ROOT:-$(pwd)}
dir=$root/.agent-files/benchmarks/m2-timed-v2-final
scratch=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure-final-fix
export TMPDIR=$scratch/tmp
mkdir -p "$TMPDIR" "$scratch/preflight-logs"
[ ! -e "$dir/INPUTS.sha256" ] || {
  echo 'already frozen' >&2
  exit 2
}
status=$dir/preflight-status.tsv
printf 'label\tcategory\tstarted_utc\tstatus\tcommand\n' > "$status"
run() {
  label=$1
  category=$2
  command=$3
  shift 3
  started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  rc=0
  "$@" > "$scratch/preflight-logs/$label.log" 2>&1 || rc=$?
  printf '%s\t%s\t%s\t%s\t%s\n' "$label" "$category" "$started" \
    "$rc" "$command" >> "$status"
  [ "$rc" -eq 0 ] || return "$rc"
}

run root-index-clean identity 'git diff --cached --quiet' \
  git diff --cached --quiet
run source-worktree-clean identity 'git diff --quiet -- src/auto' \
  git diff --quiet -- src/auto
run agent-index-clean identity 'git -C .agent-files diff --cached --quiet' \
  git -C .agent-files diff --cached --quiet
run classical-clean build 'bin/Holmake -C src/auto/classical clean' \
  bin/Holmake -C src/auto/classical clean
run classical-build build \
  'bin/Holmake -C src/auto/classical (full default build after clean)' \
  bin/Holmake -C src/auto/classical
run classical-selftest selftest \
  'cd src/auto/classical && HOLSELFTESTLEVEL=2 ./selftest.exe' \
  sh -c 'cd src/auto/classical && HOLSELFTESTLEVEL=2 ./selftest.exe'
run blast-clean build 'bin/Holmake -C src/auto/blast clean' \
  bin/Holmake -C src/auto/blast clean
run blast-build build \
  'bin/Holmake -C src/auto/blast (full default build after clean)' \
  bin/Holmake -C src/auto/blast
run blast-selftest selftest \
  'cd src/auto/blast && HOLSELFTESTLEVEL=2 ./selftest.exe' \
  sh -c 'cd src/auto/blast && HOLSELFTESTLEVEL=2 ./selftest.exe'
run harness-clean build \
  'bin/Holmake -C .agent-files/benchmarks/m2-timed-v2-final clean' \
  bin/Holmake -C "$dir" clean
run harness-build build \
  'bin/Holmake -C .agent-files/benchmarks/m2-timed-v2-final task7gmeasurement.exe task7gcalibration.exe task7gactive.exe' \
  bin/Holmake -C "$dir" task7gmeasurement.exe task7gcalibration.exe \
    task7gactive.exe
run endpoint-synthetic process-audit \
  'endpoint-preflight.sh scratch/endpoint-preflight' \
  "$dir/endpoint-preflight.sh" "$scratch/endpoint-preflight"
run validator-synthetic validator \
  'test-validators.sh caller-scratch caller-logs caller-status' \
  "$dir/test-validators.sh" "$scratch/validator-work" \
    "$scratch/preflight-validator-logs" "$scratch/validator-status.tsv"

cp -R "$scratch/preflight-logs" "$dir/preflight-logs"
cp -R "$scratch/preflight-validator-logs" "$dir/preflight-validator-logs"
cp -R "$scratch/endpoint-preflight" "$dir/endpoint-preflight"
cp "$scratch/validator-status.tsv" "$dir/validator-status.tsv"
{
  printf 'captured_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'revision=%s\n' "$(git rev-parse HEAD)"
  printf 'host='; uname -a
  printf 'poly='; poly --version 2>&1 | sed -n '1p'
  printf 'clock=Time.now\nprocess_option=--gcthreads=1\n'
  printf 'heap=bin/hol.state0\n'
  printf 'scratch=%s\n' "$scratch"
  printf 'endpoint_patterns=[t]ask7gcalibration,[t]ask7gactive,[t]ask7gmeasurement\n'
} > "$dir/environment.txt"
printf 'sealed_utc=%s\nrevision=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git rev-parse HEAD)" \
  > "$dir/SEAL_PLAN.md"

inputs='PREDECLARATION.md SEAL_PLAN.md Holmakefile task7gmeasurement.sml task7gcalibration.sml task7gactive.sml schedule.tsv calibration-schedule.tsv active-calibration-schedule.tsv prepare-and-freeze.sh collect-locked.sh run-target.sh artifact-manifest.sh endpoint-preflight.sh validate-calibration.awk verify-target.awk generate-synthetic.awk mutate-fixture.awk test-validators.sh summarize-calibration.awk summarize-target.awk verify-summaries.sh selfcheck.sh'
mkdir -p "$dir/frozen-inputs"
: > "$dir/INPUTS.sha256"
printf 'path\tsha256\tsize\tmtime_ns\tfrozen_copy\n' \
  > "$dir/INPUT-MANIFEST.tsv"
for name in $inputs; do
  cp "$dir/$name" "$dir/frozen-inputs/$name"
  hash=$(sha256sum "$dir/$name" | awk '{print $1}')
  frozen_hash=$(sha256sum "$dir/frozen-inputs/$name" | awk '{print $1}')
  [ "$hash" = "$frozen_hash" ]
  size=$(stat -c '%s' "$dir/$name")
  mtime=$(stat -c '%y' "$dir/$name")
  printf '%s  %s\n' "$hash" \
    ".agent-files/benchmarks/m2-timed-v2-final/$name" \
    >> "$dir/INPUTS.sha256"
  printf '%s  %s\n' "$frozen_hash" \
    ".agent-files/benchmarks/m2-timed-v2-final/frozen-inputs/$name" \
    >> "$dir/INPUTS.sha256"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$hash" "$size" "$mtime" \
    "frozen-inputs/$name" >> "$dir/INPUT-MANIFEST.tsv"
done
run artifact-freeze identity \
  'ROOT=$root artifact-manifest.sh ARTIFACTS-FROZEN.tsv' \
  env ROOT="$root" "$dir/artifact-manifest.sh" \
    "$dir/ARTIFACTS-FROZEN.tsv"
run closure-required identity \
  'require blastSearch/blastRule/blastTerm/tableauLib/clasetLib/clasetSeedTheory in complete closure' \
  sh -c 'for name in blastSearch blastRule blastTerm tableauLib clasetLib clasetSeedTheory; do grep -E "src/auto/.*/$name[.](sml|sig|ui|uo)" "$1" >/dev/null || exit 1; done' \
    sh "$dir/ARTIFACTS-FROZEN.tsv"
echo 'preflight builds/selftests/endpoints/validators/full-body and closure freeze: PASS'
