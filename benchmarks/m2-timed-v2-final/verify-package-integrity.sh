#!/bin/sh
set -eu
dir=$(realpath -e -- "${1:?package directory required}")
[ -d "$dir" ] || { echo 'package path is not a directory' >&2; exit 2; }
scratch=${2:?scratch directory required}
mkdir -p "$scratch"

(cd "$dir" && sha256sum -c checksums.sha256)
find "$dir" -type f ! -path "$dir/checksums.sha256" -printf '%P\n' |
  LC_ALL=C sort > "$scratch/regular-files.txt"
sed 's#^[0-9a-f][0-9a-f]*  ##' "$dir/checksums.sha256" |
  LC_ALL=C sort > "$scratch/checksummed-files.txt"
cmp "$scratch/regular-files.txt" "$scratch/checksummed-files.txt"

"$dir/package-inventory.sh" "$dir" "$scratch/PACKAGE-INVENTORY.tsv"
if ! cmp "$scratch/PACKAGE-INVENTORY.tsv" \
  "$dir/PACKAGE-INVENTORY.tsv"; then
  echo 'package inventory mismatch (regular bytes or symlink target)' >&2
  exit 1
fi

regular=$(awk -F '\t' '$1=="regular"{n++} END{print n+0}' \
  "$dir/PACKAGE-INVENTORY.tsv")
symlinks=$(awk -F '\t' '$1=="symlink"{n++} END{print n+0}' \
  "$dir/PACKAGE-INVENTORY.tsv")
printf 'package integrity: PASS (%s inventory regular files; %s symlinks)\n' \
  "$regular" "$symlinks"
