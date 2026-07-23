#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided scratch directory required}
rm -rf -- "$scratch"
mkdir -p "$scratch"

bounded=$scratch/bounded.tsv
raw=$scratch/raw.tsv
printf '%s\n' \
  'Task7j timed-v4 bounded protocol v2' \
  'BOUNDED|1|34|1|4|1|0' \
  'BOUNDED_SUMMARY|1|34|1|4|1|0' \
  'BOUNDED|2|41|1|5|1|0' \
  'BOUNDED|2|41|2|6|1|0' \
  'BOUNDED|2|41|3|7|1|0' \
  'BOUNDED_SUMMARY|2|41|3|18|3|0' \
  'BOUNDED|3|45|1|8|1|0' \
  'BOUNDED_SUMMARY|3|45|1|8|1|0' \
  'EOF|Task7j timed-v4 bounded protocol v2' > "$bounded"
printf '%s\n' \
  'Task7j timed-v4 raw protocol v2' \
  'ATTEMPT_BOUNDS|1|34|7|1|4|1|0|interrupted|none' \
  'SUMMARY_BOUNDS|1|34|7|1' \
  'ATTEMPT_BOUNDS|2|41|6|1|5|1|0|completed|none' \
  'ATTEMPT_BOUNDS|2|41|6|2|6|1|0|completed|none' \
  'ATTEMPT_BOUNDS|2|41|6|3|7|1|0|interrupted|none' \
  'SUMMARY_BOUNDS|2|41|6|3' \
  'ATTEMPT_BOUNDS|3|45|11|1|8|1|0|interrupted|none' \
  'SUMMARY_BOUNDS|3|45|11|1' \
  'EOF|Task7j timed-v4 raw protocol v2' > "$raw"

"$dir/verify-bounded-v2.py" "$bounded" "$raw" > "$scratch/valid.log"

reject() {
  label=$1 expected=$2 b=$3 r=$4
  rc=0
  "$dir/verify-bounded-v2.py" "$b" "$r" \
    > "$scratch/$label.log" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || { echo "$label unexpectedly passed" >&2; exit 1; }
  [ "$(wc -l < "$scratch/$label.log")" -eq 1 ] || {
    echo "$label emitted multiple diagnostics" >&2; exit 1;
  }
  grep -Fx "verify-bounded-v2: $expected" "$scratch/$label.log" >/dev/null
  ! grep -F PASS "$scratch/$label.log" >/dev/null
}

sed '2,3{2h;2d;3G}' "$bounded" > "$scratch/summary-first.tsv"
reject summary-first 'bounded attempt order' "$scratch/summary-first.tsv" "$raw"
sed '2s/|1|34|1|/|9|999|77|/' "$bounded" > "$scratch/arbitrary.tsv"
reject arbitrary 'bounded exact target/attempt order' "$scratch/arbitrary.tsv" "$raw"
sed '$d' "$bounded" > "$scratch/no-eof.tsv"
reject no-eof 'exact bounded EOF' "$scratch/no-eof.tsv" "$raw"
{ sed -n '1,$p' "$bounded"; printf '%s\n' 'BOUNDED|3|45|1|8|1|0'; } \
  > "$scratch/appended.tsv"
reject appended 'bounded record after EOF' "$scratch/appended.tsv" "$raw"
sed '2s/|4|1|0$/|04|1|0/' "$bounded" > "$scratch/lexical.tsv"
reject lexical 'bounded natural grammar' "$scratch/lexical.tsv" "$raw"
sed '2s/^BOUNDED/ATTEMPT/' "$bounded" > "$scratch/enum.tsv"
reject enum 'bounded attempt order' "$scratch/enum.tsv" "$raw"
sed '7s/|18|3|0$/|19|3|0/' "$bounded" > "$scratch/arithmetic.tsv"
reject arithmetic 'bounded attempt/summary arithmetic' \
  "$scratch/arithmetic.tsv" "$raw"
sed '2s/|1|4|1|0|/|1|5|1|0|/' "$raw" > "$scratch/raw-drift.tsv"
reject raw-drift 'bounded/main-raw attempt/read/allocation mismatch' \
  "$bounded" "$scratch/raw-drift.tsv"
sed '$d' "$raw" > "$scratch/raw-no-eof.tsv"
reject raw-no-eof 'exact raw EOF' "$bounded" "$scratch/raw-no-eof.tsv"
{ sed -n '1,$p' "$raw"; printf '%s\n' 'SUMMARY_BOUNDS|3|45|11|1'; } \
  > "$scratch/raw-appended.tsv"
reject raw-appended 'raw record after EOF' "$bounded" "$scratch/raw-appended.tsv"

echo 'bounded-v2 positive and strong ordering/schema/raw adversaries: PASS'
