#!/bin/sh
set -eu
root=${ROOT:?}
dir=$root/.agent-files/benchmarks/m2-timed-v2-fresh
out=$1
paths="
src/auto/classical/clasetUnify.sig
src/auto/classical/clasetUnify.sml
src/auto/classical/.hol/objs/clasetUnify.ui
src/auto/classical/.hol/objs/clasetUnify.uo
src/auto/classical/clasetStep.sig
src/auto/classical/clasetStep.sml
src/auto/classical/.hol/objs/clasetStep.ui
src/auto/classical/.hol/objs/clasetStep.uo
src/auto/blast/blastReconstruct.sig
src/auto/blast/blastReconstruct.sml
src/auto/blast/.hol/objs/blastReconstruct.ui
src/auto/blast/.hol/objs/blastReconstruct.uo
.agent-files/benchmarks/m2-timed-v2-fresh/task7gcalibration.sml
.agent-files/benchmarks/m2-timed-v2-fresh/.hol/objs/task7gcalibration.ui
.agent-files/benchmarks/m2-timed-v2-fresh/.hol/objs/task7gcalibration.uo
.agent-files/benchmarks/m2-timed-v2-fresh/task7gcalibration.exe
.agent-files/benchmarks/m2-timed-v2-fresh/task7gactive.sml
.agent-files/benchmarks/m2-timed-v2-fresh/.hol/objs/task7gactive.ui
.agent-files/benchmarks/m2-timed-v2-fresh/.hol/objs/task7gactive.uo
.agent-files/benchmarks/m2-timed-v2-fresh/task7gactive.exe
.agent-files/benchmarks/m2-timed-v2-fresh/task7gmeasurement.sml
.agent-files/benchmarks/m2-timed-v2-fresh/.hol/objs/task7gmeasurement.ui
.agent-files/benchmarks/m2-timed-v2-fresh/.hol/objs/task7gmeasurement.uo
.agent-files/benchmarks/m2-timed-v2-fresh/task7gmeasurement.exe
bin/hol
bin/hol.state0
"
printf 'path\tsha256\tsize\tmtime_ns\n' > "$out"
printf '%s\n' "$paths" | sed '/^$/d' |
while IFS= read -r path; do
  [ -f "$root/$path" ] || { echo "missing artifact: $path" >&2; exit 1; }
  hash=$(sha256sum "$root/$path" | awk '{print $1}')
  size=$(stat -c '%s' "$root/$path")
  mtime=$(stat -c '%y' "$root/$path")
  printf '%s\t%s\t%s\t%s\n' "$path" "$hash" "$size" "$mtime"
done >> "$out"
for tool in awk env pgrep sed sha256sum stat timeout; do
  path=$(command -v "$tool")
  path=$(readlink -f "$path")
  hash=$(sha256sum "$path" | awk '{print $1}')
  size=$(stat -c '%s' "$path")
  mtime=$(stat -c '%y' "$path")
  printf 'tool:%s=%s\t%s\t%s\t%s\n' "$tool" "$path" "$hash" "$size" "$mtime"
done >> "$out"
