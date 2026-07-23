#!/usr/bin/awk -f
BEGIN { FS="\t" }
NR == 1 { next }
$1 == "P38@4" || $1 == "P43@5" {
  if ($8 < 0.90 || $8 > 1.10) {
    print "calibration-gate: representative ratio outside [0.90,1.10]" > "/dev/stderr"
    bad=1
    exit 1
  }
  representative++
}
$1 == "active-1000" {
  change=$9+0; if (change < 0) change=-change
  if (change > 25.00) {
    print "calibration-gate: active absolute change exceeds 25%" > "/dev/stderr"
    bad=1
    exit 1
  }
  active++
}
END {
  if (bad) exit 1
  if (representative != 2 || active != 1) {
    print "calibration-gate: incomplete summary" > "/dev/stderr"
    exit 1
  }
  print "representative ratios and active micro-cost: PASS"
}
