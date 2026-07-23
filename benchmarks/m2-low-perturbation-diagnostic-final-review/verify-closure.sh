#!/bin/sh
set -eu
dir=$(realpath -e -- "${1:?review package required}")
scratch=$(realpath -m -- "${2:?scratch directory required}")
target=$(realpath -e -- "$dir/../m2-low-perturbation-diagnostic-final")
task7m=$(realpath -e -- \
  "$dir/../m2-v10-small-calibration-second-retry-final")
task7m_review=$(realpath -e -- \
  "$dir/../m2-v10-small-calibration-second-retry-final-review")
mkdir -p "$scratch" "$scratch/task7m-review"

(cd "$dir" && sha256sum -c checksums.sha256)
(cd "$dir" && sha256sum -c REFERENCES.sha256)
(cd "$target" && sha256sum -c checksums.sha256)

find "$dir" -type f ! -path "$dir/checksums.sha256" -printf '%P\n' |
  LC_ALL=C sort > "$scratch/regular-files.txt"
sed 's#^[0-9a-f][0-9a-f]*  ./##' "$dir/checksums.sha256" |
  LC_ALL=C sort > "$scratch/checksummed-files.txt"
cmp "$scratch/regular-files.txt" "$scratch/checksummed-files.txt"

python3 "$dir/inventory.py" "$dir" "$scratch/PACKAGE-INVENTORY.tsv" \
  --exclude PACKAGE-INVENTORY.tsv --exclude checksums.sha256
cmp "$scratch/PACKAGE-INVENTORY.tsv" "$dir/PACKAGE-INVENTORY.tsv"

python3 "$dir/inventory.py" "$target" \
  "$scratch/AUTHORITATIVE-PACKAGE-MANIFEST.tsv"
cmp "$scratch/AUTHORITATIVE-PACKAGE-MANIFEST.tsv" \
  "$dir/AUTHORITATIVE-PACKAGE-MANIFEST-BEFORE.tsv"
cmp "$dir/AUTHORITATIVE-PACKAGE-MANIFEST-BEFORE.tsv" \
  "$dir/AUTHORITATIVE-PACKAGE-MANIFEST-AFTER.tsv"

"$task7m_review/verify-closure.sh" "$task7m_review" \
  "$scratch/task7m-review"
test -d "$task7m"

echo 'external Task7n review closure: PASS'
