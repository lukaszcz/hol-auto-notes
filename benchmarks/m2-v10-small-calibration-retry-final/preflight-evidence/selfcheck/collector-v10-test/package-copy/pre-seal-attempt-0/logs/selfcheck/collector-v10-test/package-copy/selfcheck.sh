#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch=${1:?caller-provided scratch required}
rm -rf -- "$scratch"
mkdir -p "$scratch"
diff -qr "$root/.agent-files/benchmarks/m2-timed-v4-final/future-protocol" \
  "$dir/future-protocol" > "$scratch/v10-byte-parity.log"
"$dir/test-validators.sh" "$scratch/validators" > \
  "$scratch/validators.log"
"$dir/future-protocol/test-supervise-v10.sh" \
  "$scratch/supervisor-v10" > "$scratch/supervisor-v10.log"
ROOT="$root" "$dir/future-protocol/test-collector-v10.sh" "$scratch" \
  > "$scratch/collector-v10.log"
grep -F "  $dir/task7lcalibration" "$dir/task7lcalibration.exe" >/dev/null
test "$(git -C "$root" rev-parse HEAD)" = \
  244b01d7189ac803df48e246a483c33b553e3daa
git -C "$root" diff --quiet
git -C "$root" diff --cached --quiet
git -C "$root" check-ignore "$root/.agent-files" >/dev/null
test -z "$(git -C "$root" ls-files .agent-files)"
echo 'task7l validators/v10/launcher/source selfcheck: PASS'
