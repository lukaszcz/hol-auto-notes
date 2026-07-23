#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch=${1:?caller-provided new scratch required}
[ ! -e "$scratch" ] || { echo 'preflight: scratch exists' >&2; exit 2; }
mkdir -p "$scratch/logs"
status=$scratch/status.tsv
printf 'label\tstatus\tcommand\n' >"$status"

run() {
  label=$1
  command=$2
  shift 2
  rc=0
  "$@" >"$scratch/logs/$label.stdout" \
    2>"$scratch/logs/$label.stderr" || rc=$?
  printf '%s\t%s\t%s\n' "$label" "$rc" "$command" >>"$status"
  [ "$rc" -eq 0 ]
}

run head 'git rev-parse HEAD' git -C "$root" rev-parse HEAD
grep -Fx 244b01d7189ac803df48e246a483c33b553e3daa \
  "$scratch/logs/head.stdout" >/dev/null
run index-clean 'git diff --cached --quiet' git -C "$root" diff \
  --cached --quiet
run tracked-clean 'git diff --quiet' git -C "$root" diff --quiet
run whitespace 'git diff --check' git -C "$root" diff --check
run source-manifest-before 'tracked src/auto sha256 manifest' sh -c \
  'git -C "$1" ls-files -z src/auto | (cd "$1" && xargs -0 sha256sum)' \
  sh "$root"
run task7k-review-closure 'Task7k external verify-closure.sh' sh \
  "$root/.agent-files/benchmarks/m2-v10-small-calibration-final-review/verify-closure.sh" \
  "$root/.agent-files/benchmarks/m2-v10-small-calibration-final-review" \
  "$scratch/task7k-review"
run task7l-review-closure 'Task7l external verify-closure.sh' sh \
  "$root/.agent-files/benchmarks/m2-v10-small-calibration-retry-final-review/verify-closure.sh" \
  "$root/.agent-files/benchmarks/m2-v10-small-calibration-retry-final-review" \
  "$scratch/task7l-review"
run task7m-review-closure 'Task7m external verify-closure.sh' sh \
  "$root/.agent-files/benchmarks/m2-v10-small-calibration-second-retry-final-review/verify-closure.sh" \
  "$root/.agent-files/benchmarks/m2-v10-small-calibration-second-retry-final-review" \
  "$scratch/task7m-review"
run shell-syntax 'sh -n package shell programs' sh -c \
  'for f in "$1"/*.sh; do sh -n "$f"; done' sh "$dir"
run harness-clean 'bin/Holmake -C package clean' \
  "$root/bin/Holmake" -C "$dir" clean
run harness-build 'bin/Holmake -C package task7nclock.exe' \
  "$root/bin/Holmake" -C "$dir" task7nclock.exe
run package-selfcheck 'selfcheck.sh' env ROOT="$root" PACKAGE_DIR="$dir" \
  "$dir/selfcheck.sh" "$scratch/selfcheck"
run source-manifest-after 'tracked src/auto sha256 manifest' sh -c \
  'git -C "$1" ls-files -z src/auto | (cd "$1" && xargs -0 sha256sum)' \
  sh "$root"
run source-manifest-parity 'cmp source manifests' cmp \
  "$scratch/logs/source-manifest-before.stdout" \
  "$scratch/logs/source-manifest-after.stdout"
run final-index-clean 'git diff --cached --quiet' git -C "$root" diff \
  --cached --quiet
run final-tracked-clean 'git diff --quiet' git -C "$root" diff --quiet
echo 'Task 7n proportional source/harness/protocol preflight: PASS'

