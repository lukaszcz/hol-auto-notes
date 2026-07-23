#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:?validated ROOT required}")
dir=$(realpath -e -- "${PACKAGE_DIR:?validated PACKAGE_DIR required}")
scratch_root=${1:-${SCRATCH_ROOT:-}}
scratch_input=${2:-${SCRATCH_DIR:-}}
[ -n "$scratch_root" ] || {
  echo 'final-audit: caller-provided scratch root required' >&2; exit 2;
}
[ -n "$scratch_input" ] || {
  echo 'final-audit: caller-provided scratch directory required' >&2; exit 2;
}
scratch=$("$dir/validate-scratch-path.sh" "$scratch_root" "$scratch_input")
rm -rf -- "$scratch"
mkdir -p "$scratch"

manifest=$dir/ARTIFACTS-FROZEN.tsv
expected_header=$(printf 'path\tsha256\tsize\tmtime_ns')
[ "$(sed -n '1p' "$manifest")" = "$expected_header" ] || {
  echo 'final-audit: artifact manifest header mismatch' >&2; exit 1;
}
awk -F '\t' '
  NR == 1 {next}
  NF != 4 {exit 1}
  $1 ~ /^tool:/ {tools=1; tool_count++; next}
  tools {exit 1}
  {repo_count++}
  END {
    if (!repo_count || !tool_count) exit 1
    print repo_count > repo_out
    print tool_count > tool_out
  }
' repo_out="$scratch/repo-count" tool_out="$scratch/tool-count" "$manifest" || {
  echo 'final-audit: artifact manifest schema/order' >&2; exit 1;
}

# Only these two materialized endpoint manifests exist. There is no
# `provenance/` directory and no six-endpoint claim.
cmp "$manifest" "$dir/collection/audits/pre-collection-artifacts.tsv" \
  >/dev/null || { echo 'final-audit: pre-collection artifact drift' >&2; exit 1; }
cmp "$manifest" "$dir/collection/audits/post-failure-artifacts.tsv" \
  >/dev/null || { echo 'final-audit: post-failure artifact drift' >&2; exit 1; }

[ "$(sed -n '1p' "$dir/collection/audits/final-process-audit.txt")" = \
  'captured_utc=2026-07-21T05:42:29Z' ] || {
  echo 'final-audit: retained later process audit identity' >&2; exit 1;
}
printf 'retained artifact audit: PASS (%s repository records; %s tools; ' \
  "$(cat "$scratch/repo-count")" "$(cat "$scratch/tool-count")"
printf '%s\n' 'two materialized artifact endpoints; later process audit only)'
