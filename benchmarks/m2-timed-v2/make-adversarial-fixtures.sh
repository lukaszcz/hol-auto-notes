#!/bin/sh
set -eu
raw=$1
out=$2
mkdir -p "$out"
mutate_attempt() {
  name=$1; field=$2; value=$3
  awk -F '|' -v OFS='|' -v field="$field" -v value="$value" '
    !done && $1=="ATTEMPT" {$field=value; done=1} {print}
  ' "$raw" > "$out/$name.tsv"
}
mutate_attempt bad-alternative 17 999
mutate_attempt bad-replay 18 999
mutate_attempt bad-other 19 999
mutate_attempt bad-outer-total 20 999
mutate_attempt bad-attempt-wall 16 999
mutate_attempt bad-calls 21 0
mutate_attempt bad-failures 22 999999999
mutate_attempt bad-normalization 23 999
mutate_attempt bad-traversal 24 999
mutate_attempt bad-cleanup 25 1
mutate_attempt bad-minor-total 26 999
mutate_attempt bad-max-normalization 27 999
mutate_attempt bad-max-traversal 28 999
mutate_attempt bad-max-cleanup 29 1
mutate_attempt bad-max-minor 30 999
mutate_attempt bad-attempt-residual 31 1
mutate_attempt bad-context 8 'none,replay_recursion'
awk -F '|' -v OFS='|' '
  !done && $1=="ATTEMPT" {split($15,a,","); a[12]=999; $15=a[1]; for(i=2;i<=12;i++)$15=$15 "," a[i]; done=1} {print}
' "$raw" > "$out/bad-classical-total.tsv"
awk -F '|' -v OFS='|' '
  !done && $1=="SUMMARY" {split($10,a,","); a[11]=999; $10=a[1]; for(i=2;i<=11;i++)$10=$10 "," a[i]; done=1} {print}
' "$raw" > "$out/bad-process-residual.tsv"
awk -F '|' -v OFS='|' '!done&&$1=="STATUS"{$4=1;done=1}{print}' \
  "$raw" > "$out/bad-status.tsv"
awk -F '|' -v OFS='|' '!done&&$1=="ATTEMPT"{$2=2;done=1}{print}' \
  "$raw" > "$out/bad-schedule.tsv"
awk 'NR==2{saved=$0;next} NR==3{print;print saved;next}{print}' "$raw" \
  > "$out/bad-order.tsv"
awk '{print} /^EOF[|]/{print "STATUS|1|34|0"}' "$raw" \
  > "$out/bad-append.tsv"
sed '$d' "$raw" > "$out/bad-missing-eof.tsv"
