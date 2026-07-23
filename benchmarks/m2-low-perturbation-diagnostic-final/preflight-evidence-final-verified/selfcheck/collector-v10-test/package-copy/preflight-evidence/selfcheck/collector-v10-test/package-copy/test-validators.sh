#!/bin/sh
set -eu
dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
scratch=${1:?caller-provided new scratch required}
[ ! -e "$scratch" ] || { echo 'validators: scratch exists' >&2; exit 2; }
mkdir -p "$scratch/logs"
raw=$scratch/good.tsv
{
  printf '%s\n' 'protocol	sequence	repetition	mode	exact_count	observed_count	sink_class	external_elapsed	supervisor_status	classification	containment'
  awk 'BEGIN{FS="\t"; OFS="\t"} NR>1 {printf "V10CLOCK\t%s\t%s\t%s\t61486260\t61486260\tnonnegative\t%d.000000000\t0\tcompleted_exit_0\tcleared\n",$1,$2,$3,$1}' "$dir/schedule.tsv"
  printf '%s\n' 'EOF	V10CLOCK'
} >"$raw"
python3 -B "$dir/validate-results.py" --schedule "$dir/schedule.tsv" \
  --raw "$raw" >"$scratch/logs/good.stdout" \
  2>"$scratch/logs/good.stderr"

mutate() {
  label=$1
  expression=$2
  bad=$scratch/$label.tsv
  awk "$expression" "$raw" >"$bad"
  rc=0
  python3 -B "$dir/validate-results.py" --schedule "$dir/schedule.tsv" \
    --raw "$bad" >"$scratch/logs/$label.stdout" \
    2>"$scratch/logs/$label.stderr" || rc=$?
  [ "$rc" -eq 1 ]
  test ! -s "$scratch/logs/$label.stdout"
  grep -Fx 'validate-results: PASS' "$scratch/logs/$label.stderr" && exit 1 || :
  printf '%s\t%s\n' "$label" "$rc" >>"$scratch/status.tsv"
}

printf 'label\tstatus\n' >"$scratch/status.tsv"
mutate count '{sub(/61486260\t61486260/,"61486260\t61486259"); print}'
mutate order 'NR==2{sub(/\t1\t1\tZ\t/,"\t2\t1\tZ\t")} {print}'
mutate mode 'NR==2{sub(/\tZ\t/,"\tN\t")} {print}'
mutate status 'NR==2{sub(/\t0\tcompleted_exit_0/,"\t1\tcompleted_exit_0")} {print}'
mutate elapsed 'NR==2{sub(/1[.]000000000/,"01.000000000")} {print}'
mutate sink 'NR==2{sub(/nonnegative/,"negative")} {print}'
mutate eof 'NR==12{print "APPEND"} {print}'
mutate header 'NR==1{sub(/observed_count/,"count")} {print}'
echo 'Task 7n validators and eight adversaries: PASS'

