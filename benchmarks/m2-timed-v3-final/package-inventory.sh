#!/bin/sh
set -eu
dir=$(realpath -e -- "${1:?package directory required}")
[ -d "$dir" ] || { echo 'package path is not a directory' >&2; exit 2; }
out=${2:?output file required}

printf 'type\tpath\tsha256\tlink_target\n' > "$out"
find "$dir" -type f ! -path "$dir/checksums.sha256" \
  ! -path "$dir/PACKAGE-INVENTORY.tsv" -printf '%P\n' | LC_ALL=C sort |
while IFS= read -r path; do
  hash=$(sha256sum "$dir/$path" | awk '{print $1}')
  printf 'regular\t%s\t%s\t-\n' "$path" "$hash"
done >> "$out"

find "$dir" -type l -printf '%P\n' | LC_ALL=C sort |
while IFS= read -r path; do
  target=$(readlink "$dir/$path")
  printf 'symlink\t%s\t-\t%s\n' "$path" "$target"
done >> "$out"
