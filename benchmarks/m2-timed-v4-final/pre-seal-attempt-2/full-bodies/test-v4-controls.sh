#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?scratch required}
rm -rf "$scratch"
mkdir -p "$scratch"

cat > "$scratch/bounded-valid.tsv" <<'EOF'
BOUNDED|1|34|1|0|1|0
BOUNDED_SUMMARY|1|34|1|0|1|0
BOUNDED|2|41|1|0|1|0
BOUNDED|2|41|2|0|1|0
BOUNDED|2|41|3|0|1|0
BOUNDED_SUMMARY|2|41|3|0|3|0
BOUNDED|3|45|1|0|1|0
BOUNDED_SUMMARY|3|45|1|0|1|0
EOF
awk -f "$dir/verify-bounded.awk" "$scratch/bounded-valid.tsv" \
  > "$scratch/bounded-valid.log"
for mutation in trace read arithmetic enum lexical; do
  case $mutation in
    trace) sed '1s/|0$/|1/' "$scratch/bounded-valid.tsv" ;;
    read) sed '1s/|1|0$/|2|0/' "$scratch/bounded-valid.tsv" ;;
    arithmetic) sed '2s/|1|0$/|2|0/' "$scratch/bounded-valid.tsv" ;;
    enum) sed '1s/^BOUNDED/UNKNOWN/' "$scratch/bounded-valid.tsv" ;;
    lexical) sed '1s/|34|/|034|/' "$scratch/bounded-valid.tsv" ;;
  esac > "$scratch/bounded-$mutation.tsv"
  set +e
  awk -f "$dir/verify-bounded.awk" "$scratch/bounded-$mutation.tsv" \
    > "$scratch/bounded-$mutation.log" 2>&1
  rc=$?
  set -e
  [ "$rc" -ne 0 ]
  [ "$(wc -l < "$scratch/bounded-$mutation.log")" -eq 1 ]
  ! grep 'PASS' "$scratch/bounded-$mutation.log" >/dev/null
done

cat > "$scratch/gate-valid.tsv" <<'EOF'
workload	v2_median	v2_min	v2_max	v4_median	v4_min	v4_max	v4_over_v2	percent_change
P38@4	1	1	1	1	1	1	1.000000	0.00
P43@5	1	1	1	1	1	1	1.100000	10.00
active-1000	1	1	1	1	1	1	0.750000	-25.00
EOF
awk -f "$dir/calibration-gate.awk" "$scratch/gate-valid.tsv" \
  > "$scratch/gate-valid.log"
sed '2s/1.000000/1.100001/' "$scratch/gate-valid.tsv" \
  > "$scratch/gate-bad.tsv"
set +e
awk -f "$dir/calibration-gate.awk" "$scratch/gate-bad.tsv" \
  > "$scratch/gate-bad.log" 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ]
[ "$(wc -l < "$scratch/gate-bad.log")" -eq 1 ]
! grep PASS "$scratch/gate-bad.log" >/dev/null

python3 "$dir/supervise.py" --timeout 2 --grace 1 \
  --status "$scratch/exit7.json" --stdout "$scratch/exit7.stdout" \
  --stderr "$scratch/exit7.stderr" --cwd "$scratch" -- /bin/sh -c 'exit 7' \
  >/dev/null 2>&1 && exit 1 || [ "$?" -eq 7 ]
python3 - "$scratch/exit7.json" <<'PY'
import json, sys
x=json.load(open(sys.argv[1]))
assert x['exit_status']==7 and x['term_signal'] is None
assert x['reaped'] and x['group_gone'] and not x['timed_out']
PY

set +e
python3 "$dir/supervise.py" --timeout 0.2 --grace 0.2 \
  --status "$scratch/timeout.json" --stdout "$scratch/timeout.stdout" \
  --stderr "$scratch/timeout.stderr" --cwd "$scratch" -- \
  /bin/sh -c 'trap "" TERM; sleep 30'
rc=$?
set -e
[ "$rc" -eq 124 ]
python3 - "$scratch/timeout.json" <<'PY'
import json, signal, sys
x=json.load(open(sys.argv[1]))
assert x['timed_out'] and x['term_sent'] and x['kill_sent']
assert x['term_signal']==signal.SIGKILL and x['wait_returncode']==-signal.SIGKILL
assert x['reaped'] and x['group_gone']
PY
echo 'bounded/gate/supervision positive and adversarial controls: PASS'
