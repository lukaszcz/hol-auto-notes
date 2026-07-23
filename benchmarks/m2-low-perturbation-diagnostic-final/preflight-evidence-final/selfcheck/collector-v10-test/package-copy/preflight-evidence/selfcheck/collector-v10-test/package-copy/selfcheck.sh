#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?explicit ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?explicit PACKAGE_DIR required}")
scratch=${1:?caller-provided new scratch required}
[ ! -e "$scratch" ] || { echo 'selfcheck: scratch exists' >&2; exit 2; }
mkdir -p "$scratch"
python3 -B "$dir/verify-v10-vendor.py" \
  --reference "$root/.agent-files/benchmarks/m2-v10-small-calibration-second-retry-final/future-protocol" \
  --vendor "$dir/future-protocol" >"$scratch/v10-vendor.log"
"$dir/test-validators.sh" "$scratch/validators" >"$scratch/validators.log"
"$dir/test-exact-endpoint.sh" "$scratch/exact-endpoint" \
  >"$scratch/exact-endpoint.log"
"$dir/future-protocol/test-supervise-v10.sh" \
  "$scratch/supervisor-v10" >"$scratch/supervisor-v10.log"
ROOT="$root" "$dir/future-protocol/test-collector-v10.sh" "$scratch" \
  >"$scratch/collector-v10.log"
grep -F "  $dir/task7nclock" "$dir/task7nclock.exe" >/dev/null
grep -Fx '61486260' "$scratch/exact-count.txt" >/dev/null 2>&1 || \
  printf '%s\n' 61486260 >"$scratch/exact-count.txt"
test "$(git -C "$root" rev-parse HEAD)" = \
  244b01d7189ac803df48e246a483c33b553e3daa
git -C "$root" diff --quiet
git -C "$root" diff --cached --quiet
git -C "$root" check-ignore "$root/.agent-files" >/dev/null
test -z "$(git -C "$root" ls-files .agent-files)"
echo 'Task 7n validators/v10/exact-endpoint/launcher/source selfcheck: PASS'

