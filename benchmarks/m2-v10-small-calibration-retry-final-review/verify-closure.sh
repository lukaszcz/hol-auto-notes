#!/bin/sh
set -eu
dir=$(realpath -e -- "${1:?review package required}")
scratch=$(realpath -m -- "${2:?scratch directory required}")
mkdir -p "$scratch"

(cd "$dir" && sha256sum -c checksums.sha256)

find "$dir" -type f ! -path "$dir/checksums.sha256" -printf '%P\n' |
  LC_ALL=C sort > "$scratch/regular-files.txt"
sed 's#^[0-9a-f][0-9a-f]*  ./##' "$dir/checksums.sha256" |
  LC_ALL=C sort > "$scratch/checksummed-files.txt"
cmp "$scratch/regular-files.txt" "$scratch/checksummed-files.txt"

python3 "$dir/inventory.py" "$dir" "$scratch/PACKAGE-INVENTORY.tsv" \
  --exclude PACKAGE-INVENTORY.tsv --exclude checksums.sha256
cmp "$scratch/PACKAGE-INVENTORY.tsv" "$dir/PACKAGE-INVENTORY.tsv"

cmp "$dir/SEALED-PACKAGE-MANIFEST-BEFORE.tsv" \
  "$dir/SEALED-PACKAGE-MANIFEST-AFTER.tsv"
echo 'external Task7l review package closure: PASS'
