#!/bin/sh
set -eu
root=$(realpath -e -- "${ROOT:-$(pwd -P)}")
dir=$(realpath -e -- \
  "${PACKAGE_DIR:-$root/.agent-files/benchmarks/m2-timed-v3-final}")
[ -d "$root" ] || { echo 'ROOT is not a directory' >&2; exit 2; }
[ -d "$dir" ] || { echo 'PACKAGE_DIR is not a directory' >&2; exit 2; }
scratch=${1:?scratch directory required}
mkdir -p "$scratch"

manifest=$dir/ARTIFACTS-FROZEN.tsv
header=$(sed -n '1p' "$manifest")
expected_header=$(printf 'path\tsha256\tsize\tmtime_ns')
[ "$header" = "$expected_header" ] || {
  echo 'artifact manifest header mismatch' >&2
  exit 1
}

awk -F '\t' '
  NR==1 {next}
  NF!=4 {exit 1}
  $1 ~ /^tool:/ {tools=1; print $1 > tools_out; next}
  tools {exit 1}
  {print $1 > repo_out}
  END {if (NR < 414) exit 1}
' repo_out="$scratch/repository-paths.txt" \
  tools_out="$scratch/tool-records.txt" "$manifest"

LC_ALL=C sort "$scratch/repository-paths.txt" \
  > "$scratch/repository-paths.sorted.txt"
cmp "$scratch/repository-paths.txt" \
  "$scratch/repository-paths.sorted.txt"

{
  find "$root/src/auto" -type f -printf '%P\n' |
    sed 's#^#src/auto/#'
  printf '%s\n' \
    .agent-files/benchmarks/m2-timed-v3-final/Holmakefile \
    .agent-files/benchmarks/m2-timed-v3-final/task7hactive.sml \
    .agent-files/benchmarks/m2-timed-v3-final/task7hcalibration.sml \
    .agent-files/benchmarks/m2-timed-v3-final/task7hmeasurement.sml \
    .agent-files/benchmarks/m2-timed-v3-final/.hol/objs/task7hactive.ui \
    .agent-files/benchmarks/m2-timed-v3-final/.hol/objs/task7hactive.uo \
    .agent-files/benchmarks/m2-timed-v3-final/.hol/objs/task7hcalibration.ui \
    .agent-files/benchmarks/m2-timed-v3-final/.hol/objs/task7hcalibration.uo \
    .agent-files/benchmarks/m2-timed-v3-final/.hol/objs/task7hmeasurement.ui \
    .agent-files/benchmarks/m2-timed-v3-final/.hol/objs/task7hmeasurement.uo \
    .agent-files/benchmarks/m2-timed-v3-final/task7hactive.exe \
    .agent-files/benchmarks/m2-timed-v3-final/task7hcalibration.exe \
    .agent-files/benchmarks/m2-timed-v3-final/task7hmeasurement.exe \
    bin/Holmake bin/hol bin/hol.state0 \
    tools/configure.sml tools/smart-configure.sml \
    tools-poly/configure.sml tools-poly/smart-configure.sml
} | LC_ALL=C sort -u > "$scratch/expected-repository-paths.txt"
cmp "$scratch/expected-repository-paths.txt" \
  "$scratch/repository-paths.txt"

for tool in awk basename bash cat cmp cp date dirname env find git grep ln \
  mkdir pgrep poly readlink realpath rm rmdir sed sha256sum sh sleep sort stat \
  timeout uname wc; do
  path=$(command -v "$tool")
  path=$(readlink -f "$path")
  printf 'tool:%s=%s\n' "$tool" "$path"
done > "$scratch/expected-tool-records.txt"
cmp "$scratch/expected-tool-records.txt" "$scratch/tool-records.txt"

ROOT=$root TMPDIR="$scratch" "$dir/artifact-manifest.sh" \
  "$scratch/current-artifacts.tsv"
cmp "$manifest" "$scratch/current-artifacts.tsv"
for segment in representative active target; do
  cmp "$manifest" "$dir/provenance/$segment-pre-artifacts.tsv"
  cmp "$manifest" "$dir/provenance/$segment-post-artifacts.tsv"
done

repo_count=$(wc -l < "$scratch/repository-paths.txt")
tool_count=$(wc -l < "$scratch/tool-records.txt")
printf 'final artifact audit: PASS (%s C-sorted repository paths; ' \
  "$repo_count"
printf '%s declared-order tool records; six endpoints identical)\n' \
  "$tool_count"
