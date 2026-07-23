#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch=${1:?caller-provided scratch required}
rm -rf -- "$scratch"
mkdir -p "$scratch/logs"
status=$scratch/status.tsv
printf 'label\tstatus\tcommand\n' > "$status"

run() {
  label=$1 command=$2
  shift 2
  rc=0
  "$@" > "$scratch/logs/$label.log" 2>&1 || rc=$?
  printf '%s\t%s\t%s\n' "$label" "$rc" "$command" >> "$status"
  [ "$rc" -eq 0 ]
}

run head 'git rev-parse HEAD' git -C "$root" rev-parse HEAD
grep -Fx 244b01d7189ac803df48e246a483c33b553e3daa \
  "$scratch/logs/head.log" >/dev/null
run index-clean 'git diff --cached --quiet' git -C "$root" diff \
  --cached --quiet
run tracked-clean 'git diff --quiet' git -C "$root" diff --quiet
run classical-clean 'bin/Holmake -C src/auto/classical clean' \
  "$root/bin/Holmake" -C "$root/src/auto/classical" clean
run classical-build 'bin/Holmake -C src/auto/classical' \
  "$root/bin/Holmake" -C "$root/src/auto/classical"
run classical-selftest \
  'cd src/auto/classical; HOLSELFTESTLEVEL=2 ./selftest.exe' \
  sh -c 'cd "$1"; HOLSELFTESTLEVEL=2 ./selftest.exe' sh \
  "$root/src/auto/classical"
run blast-clean 'bin/Holmake -C src/auto/blast clean' \
  "$root/bin/Holmake" -C "$root/src/auto/blast" clean
run blast-build 'bin/Holmake -C src/auto/blast' \
  "$root/bin/Holmake" -C "$root/src/auto/blast"
run blast-selftest 'cd src/auto/blast; HOLSELFTESTLEVEL=2 ./selftest.exe' \
  sh -c 'cd "$1"; HOLSELFTESTLEVEL=2 ./selftest.exe' sh \
  "$root/src/auto/blast"
run harness-clean 'bin/Holmake -C package clean' \
  "$root/bin/Holmake" -C "$dir" clean
run harness-build 'bin/Holmake -C package task7lcalibration.exe' \
  "$root/bin/Holmake" -C "$dir" task7lcalibration.exe
run package-selfcheck 'selfcheck.sh' env ROOT="$root" PACKAGE_DIR="$dir" \
  "$dir/selfcheck.sh" "$scratch/selfcheck"
run final-index-clean 'git diff --cached --quiet' git -C "$root" diff \
  --cached --quiet
run final-tracked-clean 'git diff --quiet' git -C "$root" diff --quiet
echo 'formal preflight: PASS'
