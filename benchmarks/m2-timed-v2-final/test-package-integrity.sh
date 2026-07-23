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
  echo 'integrity selftest scratch must be outside the package' >&2
  exit 2
esac
case "$dir/" in "$scratch/"*)
  echo 'integrity selftest scratch must not contain the package' >&2
  exit 2
esac
rm -rf -- "$scratch"
mkdir -p "$scratch/copy-root/.agent-files/benchmarks"
copy=$scratch/copy-root/.agent-files/benchmarks/m2-timed-v2-final
cp -a "$dir" "$copy"

ROOT=$root PACKAGE_DIR=$copy "$copy/selfcheck.sh" \
  "$scratch_root" "$scratch/ordinary-selfcheck" \
  > "$scratch/ordinary-selfcheck.log" 2>&1

canonical=$(realpath -e -- "$copy")
parent=$(dirname -- "$canonical")
relative=./$(basename -- "$canonical")
"$copy/package-inventory.sh" "$canonical" \
  "$scratch/inventory-canonical.tsv"
"$copy/package-inventory.sh" "$canonical/" \
  "$scratch/inventory-trailing.tsv"
(cd "$parent" && "$relative/package-inventory.sh" "$relative" \
  "$scratch/inventory-relative.tsv")
cmp "$copy/PACKAGE-INVENTORY.tsv" "$scratch/inventory-canonical.tsv"
cmp "$scratch/inventory-canonical.tsv" "$scratch/inventory-trailing.tsv"
cmp "$scratch/inventory-canonical.tsv" "$scratch/inventory-relative.tsv"

"$copy/verify-package-integrity.sh" "$canonical" \
  "$scratch/verify-canonical" > "$scratch/verify-canonical.log"
"$copy/verify-package-integrity.sh" "$canonical/" \
  "$scratch/verify-trailing" > "$scratch/verify-trailing.log"
(cd "$parent" && "$relative/verify-package-integrity.sh" "$relative" \
  "$scratch/verify-relative") > "$scratch/verify-relative.log"
cmp "$scratch/verify-canonical.log" "$scratch/verify-trailing.log"
cmp "$scratch/verify-canonical.log" "$scratch/verify-relative.log"
grep -F 'package integrity: PASS' "$scratch/verify-canonical.log" >/dev/null

path_root=$scratch/path-safety-root
outside_marker=$scratch/outside-marker
mkdir -p "$path_root" "$scratch/symlink-target"
printf '%s\n' preserved > "$outside_marker"

direct=$("$copy/validate-scratch-path.sh" "$path_root" \
  "$path_root/direct")
[ "$direct" = "$path_root/direct" ]
mkdir -p "$direct"
rm -rf -- "$direct"

nested=$("$copy/validate-scratch-path.sh" "$path_root" \
  "$path_root/one/two")
[ "$nested" = "$path_root/one/two" ]
mkdir -p "$nested"
rm -rf -- "$nested"

mkdir -p "$path_root/ordinary"
ordinary_trailing=$("$copy/validate-scratch-path.sh" "$path_root/" \
  "$path_root/ordinary/")
ordinary_repeated=$("$copy/validate-scratch-path.sh" "$path_root//" \
  "$path_root/ordinary//")
ordinary_slash_root=$("$copy/validate-scratch-path.sh" "////" \
  "$path_root/ordinary//")
[ "$ordinary_trailing" = "$path_root/ordinary" ]
[ "$ordinary_repeated" = "$ordinary_trailing" ]
[ "$ordinary_slash_root" = "$ordinary_trailing" ]

(cd "$scratch" && "$copy/validate-scratch-path.sh" \
  ./path-safety-root ./path-safety-root/relative) \
  > "$scratch/relative-result.txt"
[ "$(cat "$scratch/relative-result.txt")" = "$path_root/relative" ]

expect_rejected() {
  label=$1
  shift
  if "$copy/validate-scratch-path.sh" "$@" \
    > "$scratch/rejected-$label.stdout" \
    2> "$scratch/rejected-$label.stderr"; then
    echo "unsafe scratch case accepted: $label" >&2
    exit 1
  fi
  [ "$(cat "$outside_marker")" = preserved ] || {
    echo "outside marker changed by rejected case: $label" >&2
    exit 1
  }
}

expect_rejected root-equality "$path_root" "$path_root"
expect_rejected prefix-sibling "$path_root" "$path_root-sibling/escape"
expect_rejected parent-reference "$path_root" \
  "$path_root/direct/../escape"
expect_rejected relative-parent "$path_root" \
  "$(basename -- "$path_root")/../escape"
ln -s "$scratch/symlink-target" "$path_root/existing-link"
expect_rejected existing-symlink "$path_root" "$path_root/existing-link"
ln -s "$scratch/symlink-target" "$path_root/intermediate-link"
expect_rejected intermediate-symlink "$path_root" \
  "$path_root/intermediate-link/escape"
mkdir -p "$path_root/inside-target"
ln -s "$path_root/inside-target" "$path_root/inside-link"
expect_rejected scratch-symlink-trailing "$path_root" \
  "$path_root/inside-link/"
expect_rejected scratch-symlink-repeated "$path_root" \
  "$path_root/inside-link//"
expect_rejected intermediate-symlink-repeated "$path_root//" \
  "$path_root/inside-link//escape//"
ln -s "$path_root" "$scratch/root-link"
expect_rejected root-symlink-trailing "$scratch/root-link/" \
  "$scratch/root-link/child"
expect_rejected root-symlink-repeated "$scratch/root-link//" \
  "$scratch/root-link//child//"
[ "$(cat "$outside_marker")" = preserved ]

link=$copy/endpoint-preflight/child-task7gactive
[ "$(readlink "$link")" = /bin/sleep ]
ln -sfn /bin/true "$link"
status=0
ROOT=$root PACKAGE_DIR=$copy "$copy/selfcheck.sh" \
  "$scratch_root" "$scratch/mutated-selfcheck" \
  > "$scratch/mutated-selfcheck.log" 2>&1 || \
  status=$?
[ "$status" -ne 0 ] || {
  echo 'mutated symlink target was accepted' >&2
  exit 1
}
grep -F 'package inventory mismatch' "$scratch/mutated-selfcheck.log" \
  >/dev/null
printf '%s%s\n' 'package integrity selftest: PASS (canonical paths, ' \
  'safe scratch spellings, read-only package, and symlink rejection)'
