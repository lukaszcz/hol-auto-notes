#!/bin/sh
set -eu
cal=$1
active=$2
awk -F '\t' '
  NR == 1 { next }
  {
    key=$1 SUBSEP $2; mode=$4
    if (mode != "v1" && mode != "v2") exit 10
    work=$5 FS $7 FS $8 FS $9
    if (seen[key,mode]++) exit 11
    value[key,mode]=work
    count++
  }
  END {
    if (count != 12) exit 12
    for (key in seen) {
      split(key,a,SUBSEP)
      pair=a[1] SUBSEP a[2]
      if (value[pair,"v1"] != value[pair,"v2"]) exit 13
    }
  }
' "$cal"
awk -F '\t' '
  NR == 1 { next }
  {
    key=$1; mode=$2
    if (mode != "v1" && mode != "v2" || $3 != 1000) exit 20
    if (seen[key,mode]++) exit 21
    value[key,mode]=$3 FS $5
    count++
  }
  END {
    if (count != 10) exit 22
    for (r=1;r<=5;r++)
      if (value[r,"v1"] != value[r,"v2"]) exit 23
  }
' "$active"
echo 'calibration work/outcome/counter parity: PASS'
