#!/bin/sh
set -eu
root=${ROOT:?}
dir=$root/.agent-files/benchmarks/m2-timed-v2-final
out=$1
list=${TMPDIR:?}/task7g-artifact-paths.$$
trap 'rm -f "$list"' EXIT HUP INT TERM

{
  find "$root/src/auto" -type f -printf '%P\n' |
    sed 's#^#src/auto/#'
  printf '%s\n' \
    .agent-files/benchmarks/m2-timed-v2-final/Holmakefile \
    .agent-files/benchmarks/m2-timed-v2-final/task7gactive.sml \
    .agent-files/benchmarks/m2-timed-v2-final/task7gcalibration.sml \
    .agent-files/benchmarks/m2-timed-v2-final/task7gmeasurement.sml \
    .agent-files/benchmarks/m2-timed-v2-final/.hol/objs/task7gactive.ui \
    .agent-files/benchmarks/m2-timed-v2-final/.hol/objs/task7gactive.uo \
    .agent-files/benchmarks/m2-timed-v2-final/.hol/objs/task7gcalibration.ui \
    .agent-files/benchmarks/m2-timed-v2-final/.hol/objs/task7gcalibration.uo \
    .agent-files/benchmarks/m2-timed-v2-final/.hol/objs/task7gmeasurement.ui \
    .agent-files/benchmarks/m2-timed-v2-final/.hol/objs/task7gmeasurement.uo \
    .agent-files/benchmarks/m2-timed-v2-final/task7gactive.exe \
    .agent-files/benchmarks/m2-timed-v2-final/task7gcalibration.exe \
    .agent-files/benchmarks/m2-timed-v2-final/task7gmeasurement.exe \
    bin/Holmake bin/hol bin/hol.state0 \
    tools/configure.sml tools/smart-configure.sml \
    tools-poly/configure.sml tools-poly/smart-configure.sml
} | LC_ALL=C sort -u > "$list"

printf 'path\tsha256\tsize\tmtime_ns\n' > "$out"
while IFS= read -r path; do
  [ -f "$root/$path" ] || {
    echo "missing artifact: $path" >&2
    exit 1
  }
  hash=$(sha256sum "$root/$path" | awk '{print $1}')
  size=$(stat -c '%s' "$root/$path")
  mtime=$(stat -c '%y' "$root/$path")
  printf '%s\t%s\t%s\t%s\n' "$path" "$hash" "$size" "$mtime"
done < "$list" >> "$out"

for tool in awk cmp date env find git mkdir pgrep readlink sed sha256sum \
  sh stat timeout uname; do
  path=$(command -v "$tool")
  path=$(readlink -f "$path")
  hash=$(sha256sum "$path" | awk '{print $1}')
  size=$(stat -c '%s' "$path")
  mtime=$(stat -c '%y' "$path")
  printf 'tool:%s=%s\t%s\t%s\t%s\n' \
    "$tool" "$path" "$hash" "$size" "$mtime"
done >> "$out"
