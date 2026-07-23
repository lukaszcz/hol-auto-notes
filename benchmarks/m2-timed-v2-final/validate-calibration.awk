#!/usr/bin/awk -f
BEGIN {
  FS = "\t"
  expected_header[1] = "repetition\tproblem\tdepth\tmode\toutcome\telapsed\tattempts\tsearch_counters\treconstruction_signatures"
  expected_header[2] = "repetition\tmode\tbatch\telapsed\tcounter_signature"
  expected_header[3] = "sequence\trepetition\tposition\tproblem\tdepth\tmode"
  expected_header[4] = "sequence\trepetition\tfixture\tbatch\tmode"
  cs = "1,1,1,38,4,v1;2,1,1,38,4,v2;3,1,2,43,5,v1;4,1,2,43,5,v2;5,2,1,43,5,v2;6,2,1,43,5,v1;7,2,2,38,4,v2;8,2,2,38,4,v1;9,3,1,38,4,v1;10,3,1,38,4,v2;11,3,2,43,5,v1;12,3,2,43,5,v2"
  as = "1,1,stored_elim,1000,v1;2,1,stored_elim,1000,v2;3,2,stored_elim,1000,v2;4,2,stored_elim,1000,v1;5,3,stored_elim,1000,v1;6,3,stored_elim,1000,v2;7,4,stored_elim,1000,v2;8,4,stored_elim,1000,v1;9,5,stored_elim,1000,v1;10,5,stored_elim,1000,v2"
  split(cs, tmp, ";")
  for (i = 1; i <= 12; i++) {
    split(tmp[i], a, ",")
    for (j = 1; j <= 6; j++) cal_schedule[i,j] = a[j]
  }
  split(as, tmp, ";")
  for (i = 1; i <= 10; i++) {
    split(tmp[i], a, ",")
    for (j = 1; j <= 5; j++) active_schedule[i,j] = a[j]
  }
}
function fail(message) {
  if (!failed) print "validate-calibration: " message > "/dev/stderr"
  failed = 1
  exit 1
}
function natural(x) { return x ~ /^(0|[1-9][0-9]*)$/ }
function positive(x) { return x ~ /^[1-9][0-9]*$/ }
function elapsed(x) {
  return x ~ /^(0|[1-9][0-9]*)[.][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/
}
function csv(field, width, array, n, i) {
  n = split(field, array, ",")
  if (n != width) fail("ordered signature width")
  for (i = 1; i <= n; i++) if (!natural(array[i]))
    fail("ordered signature token")
  return n
}
FNR == 1 {
  file_number++
  if ($0 != expected_header[file_number]) fail("exact header/schema")
  next
}
file_number == 1 {
  row = ++cal_rows
  if (NF != 9 || row > 12) fail("representative row count/schema")
  if (!positive($1) || $1+0 != cal_schedule[row,2]+0)
    fail("representative repetition literal")
  if (!positive($2) || $2+0 != cal_schedule[row,4]+0)
    fail("representative problem literal")
  if (!positive($3) || $3+0 != cal_schedule[row,5]+0)
    fail("representative depth literal")
  if ($4 != cal_schedule[row,6]) fail("representative mode/order literal")
  if ($5 != "none") fail("representative outcome vocabulary")
  if (!elapsed($6)) fail("representative elapsed grammar")
  expected_attempts = ($2 == "38" ? 22 : 2)
  if ($7 != expected_attempts) fail("representative attempt literal")
  csv($8, 8, counters)
  nsignatures = split($9, signatures, ";")
  if (nsignatures != expected_attempts)
    fail("reconstruction signature count")
  for (i = 1; i <= nsignatures; i++) csv(signatures[i], 37, fields)
  key = $1 SUBSEP $2
  work = $5 FS $7 FS $8 FS $9
  if (seen_cal[key,$4]++) fail("duplicate representative pair member")
  cal_work[key,$4] = work
  next
}
file_number == 2 {
  row = ++active_rows
  if (NF != 5 || row > 10) fail("active row count/schema")
  if (!positive($1) || $1+0 != active_schedule[row,2]+0)
    fail("active repetition literal")
  if ($2 != active_schedule[row,5]) fail("active mode/order literal")
  if ($3 != "1000") fail("active batch literal")
  if (!elapsed($4)) fail("active elapsed grammar")
  csv($5, 9, active_signature)
  key = $1
  work = $3 FS $5
  if (seen_active[key,$2]++) fail("duplicate active pair member")
  active_work[key,$2] = work
  next
}
file_number == 3 {
  row = ++cal_schedule_rows
  if (NF != 6 || row > 12) fail("representative schedule schema/count")
  for (i = 1; i <= 6; i++) if ($i != cal_schedule[row,i])
    fail("representative schedule projection")
  next
}
file_number == 4 {
  row = ++active_schedule_rows
  if (NF != 5 || row > 10) fail("active schedule schema/count")
  for (i = 1; i <= 5; i++) if ($i != active_schedule[row,i])
    fail("active schedule projection")
  next
}
END {
  if (failed) exit 1
  if (file_number != 4 || cal_rows != 12 || active_rows != 10 ||
      cal_schedule_rows != 12 || active_schedule_rows != 10) {
    print "validate-calibration: exact row counts" > "/dev/stderr"
    exit 1
  }
  for (r = 1; r <= 3; r++) {
    for (p = 38; p <= 43; p += 5) {
      key = r SUBSEP p
      if ((key SUBSEP "v1") in seen_cal || (key SUBSEP "v2") in seen_cal) {
        if (cal_work[key,"v1"] != cal_work[key,"v2"]) {
          print "validate-calibration: representative paired work drift" > "/dev/stderr"
          exit 1
        }
      }
    }
  }
  for (r = 1; r <= 5; r++)
    if (active_work[r,"v1"] != active_work[r,"v2"]) {
      print "validate-calibration: active paired work drift" > "/dev/stderr"
      exit 1
    }
  print "calibration schema/schedule/grammar/signatures/parity: PASS"
}
