#!/bin/sh
set -eu
dir=${1:-$(dirname "$0")}
audit=$dir/process-audit.txt
status=$dir/command-status.tsv
grep -F 'lock=/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure/schedule.lock' "$audit" > /dev/null
grep -F "endpoint_command=pgrep -af '[t]ask7gmeasurement'" "$audit" > /dev/null
grep -F 'pre_matches=none' "$audit" > /dev/null
grep -F 'post_matches=none' "$audit" > /dev/null
awk -F '\t' 'NF!=3 || $3!="0"{exit 1} END{if(NR!=8)exit 1}' "$status"
cmp "$dir/source-before.sha256" "$dir/source-after.sha256"
echo 'lock/endpoints/build statuses/source immutability: PASS'
