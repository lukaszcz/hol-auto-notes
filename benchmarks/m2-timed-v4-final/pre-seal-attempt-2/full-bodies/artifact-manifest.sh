#!/bin/sh
set -eu
root=${ROOT:?}
dir=$root/.agent-files/benchmarks/m2-timed-v4-final
out=$1
list=${TMPDIR:?}/task7j-artifact-paths.$$
trap 'rm -f "$list"' EXIT HUP INT TERM

{
  find "$root/src/auto" -type f -printf '%P\n' |
    sed 's#^#src/auto/#'
  printf '%s\n' \
    .agent-files/benchmarks/m2-timed-v4-final/Holmakefile \
    .agent-files/benchmarks/m2-timed-v4-final/task7jactive.sml \
    .agent-files/benchmarks/m2-timed-v4-final/task7jcalibration.sml \
    .agent-files/benchmarks/m2-timed-v4-final/task7jmeasurement.sml \
    .agent-files/benchmarks/m2-timed-v4-final/.hol/objs/task7jactive.ui \
    .agent-files/benchmarks/m2-timed-v4-final/.hol/objs/task7jactive.uo \
    .agent-files/benchmarks/m2-timed-v4-final/.hol/objs/task7jcalibration.ui \
    .agent-files/benchmarks/m2-timed-v4-final/.hol/objs/task7jcalibration.uo \
    .agent-files/benchmarks/m2-timed-v4-final/.hol/objs/task7jmeasurement.ui \
    .agent-files/benchmarks/m2-timed-v4-final/.hol/objs/task7jmeasurement.uo \
    .agent-files/benchmarks/m2-timed-v4-final/task7jactive.exe \
    .agent-files/benchmarks/m2-timed-v4-final/task7jcalibration.exe \
    .agent-files/benchmarks/m2-timed-v4-final/task7jmeasurement.exe \
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

for tool in awk basename bash cat cmp cp date dirname env find git grep ln \
  mkdir pgrep poly readlink realpath rm rmdir sed sha256sum sh sleep sort stat \
  timeout uname wc; do
  path=$(command -v "$tool")
  path=$(readlink -f "$path")
  hash=$(sha256sum "$path" | awk '{print $1}')
  size=$(stat -c '%s' "$path")
  mtime=$(stat -c '%y' "$path")
  printf 'tool:%s=%s\t%s\t%s\t%s\n' \
    "$tool" "$path" "$hash" "$size" "$mtime"
done >> "$out"
