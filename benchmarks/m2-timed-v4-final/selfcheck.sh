#!/bin/sh
set -eu
export PYTHONDONTWRITEBYTECODE=1
root=$(realpath -e -- "${ROOT:?validated ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?validated PACKAGE_DIR required}")
scratch_root=${1:-${SCRATCH_ROOT:-}}
scratch_input=${2:-${SCRATCH_DIR:-}}
[ -n "$scratch_root" ] || {
  echo 'selfcheck: caller-provided scratch root required' >&2; exit 2;
}
[ -n "$scratch_input" ] || {
  echo 'selfcheck: caller-provided scratch directory required' >&2; exit 2;
}
scratch=$("$dir/validate-scratch-path.sh" "$scratch_root" "$scratch_input")
case "$scratch/" in "$dir/"*)
  echo 'selfcheck: scratch must be outside package' >&2; exit 2;;
esac
case "$dir/" in "$scratch/"*)
  echo 'selfcheck: scratch must not contain package' >&2; exit 2;;
esac
rm -rf -- "$scratch"
mkdir -p "$scratch"

# This is deliberately first: a copied package must validate the passed copy,
# and a copied-package symlink mutation must fail here rather than consulting
# the original package.
"$dir/verify-package-integrity.sh" "$dir" "$scratch/integrity" \
  > "$scratch/integrity.log"

canonical=$root/.agent-files/benchmarks/m2-timed-v4-final
if [ "$(realpath -m -- "$canonical")" = "$dir" ]; then
  # The sole intentional live/frozen divergence is the required historical
  # banner on live PREDECLARATION.md. The sealed exact body remains checked
  # through its frozen-inputs row; INPUTS.sha256 itself stays immutable.
  grep -v '  \.agent-files/benchmarks/m2-timed-v4-final/PREDECLARATION.md$' \
    "$dir/INPUTS.sha256" > "$scratch/current-inputs.sha256"
  (cd "$root" && sha256sum -c "$scratch/current-inputs.sha256") \
    > "$scratch/inputs.log"
  grep -Fx '# Historical, superseded predeclaration' \
    "$dir/PREDECLARATION.md" >/dev/null
fi

python3 "$dir/verify-partial-calibration.py" "$dir/collection" \
  > "$scratch/partial.log"
rc=0
python3 "$dir/verify-supervision.py" "$dir/collection/status" \
  > "$scratch/supervision.log" 2>&1 || rc=$?
[ "$rc" -ne 0 ]
[ "$(cat "$scratch/supervision.log")" = \
  'verify-supervision: group not gone at supervisor endpoint' ]
[ "$(cat "$dir/collection/partial-calibration-validation.log")" = \
  'validate-calibration: exact row counts' ]
[ ! -e "$dir/collection/raw.tsv" ]
[ ! -e "$dir/collection/active-calibration-raw.tsv" ]

ROOT=$root PACKAGE_DIR=$dir "$dir/final-audit.sh" \
  "$scratch_root" "$scratch/final-audit" > "$scratch/final-audit.log"
TMPDIR="$scratch/legacy-summary-scratch" \
  "$dir/test-validators.sh" "$scratch/legacy-validator-fixtures" \
  "$scratch/legacy-validator-logs" "$scratch/legacy-validator-status.tsv" \
  > "$scratch/legacy-validators.log"
# The sealed legacy control and complete v5--v9 gates remain active
# compatibility controls. V10 is the current strict-schema gate.
"$dir/future-protocol/test-supervise-v5.sh" \
  "$scratch/supervisor-v5" > "$scratch/supervisor-v5.log"
ROOT="$root" "$dir/future-protocol/test-collector-v5.sh" "$scratch" \
  > "$scratch/collector-v5.log"
"$dir/future-protocol/test-supervise-v6.sh" "$scratch/supervisor" \
  > "$scratch/supervisor.log"
"$dir/future-protocol/test-bounded-v2.sh" "$scratch/bounded" \
  > "$scratch/bounded.log"
ROOT="$root" "$dir/future-protocol/test-collector-v6.sh" "$scratch" \
  > "$scratch/collector.log"
"$dir/future-protocol/test-supervise-v7.sh" "$scratch/supervisor-v7" \
  > "$scratch/supervisor-v7.log"
ROOT="$root" "$dir/future-protocol/test-collector-v7.sh" "$scratch" \
  > "$scratch/collector-v7.log"
"$dir/future-protocol/test-supervise-v8.sh" "$scratch/supervisor-v8" \
  > "$scratch/supervisor-v8.log"
ROOT="$root" "$dir/future-protocol/test-collector-v8.sh" "$scratch" \
  > "$scratch/collector-v8.log"
"$dir/future-protocol/test-supervise-v9.sh" "$scratch/supervisor-v9" \
  > "$scratch/supervisor-v9.log"
ROOT="$root" "$dir/future-protocol/test-collector-v9.sh" "$scratch" \
  > "$scratch/collector-v9.log"
"$dir/future-protocol/test-supervise-v10.sh" "$scratch/supervisor-v10" \
  > "$scratch/supervisor-v10.log"
ROOT="$root" "$dir/future-protocol/test-collector-v10.sh" "$scratch" \
  > "$scratch/collector-v10.log"

test "$(git -C "$root" rev-parse HEAD)" = \
  244b01d7189ac803df48e246a483c33b553e3daa
git -C "$root" diff --quiet
git -C "$root" diff --cached --quiet
git -C "$root" check-ignore "$root/.agent-files" >/dev/null
test -z "$(git -C "$root" ls-files .agent-files)"
echo 'timed-v4 retained-observation/future-protocol-v10 selfcheck: PASS'
