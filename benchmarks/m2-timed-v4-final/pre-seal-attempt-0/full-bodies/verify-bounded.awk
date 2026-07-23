#!/usr/bin/awk -f
BEGIN { FS="|" }
function fail(s) { if (!bad) print "verify-bounded: " s > "/dev/stderr"; bad=1; exit 1 }
function nat(x) { return x ~ /^(0|[1-9][0-9]*)$/ }
$1 == "BOUNDED" {
  if (NF != 7) fail("attempt schema")
  if (!nat($2)||!nat($3)||!nat($4)||!nat($5)||!nat($6)||!nat($7))
    fail("attempt lexical grammar")
  key=$2 SUBSEP $3 SUBSEP $4
  if (seen[key]++) fail("duplicate attempt")
  if ($6 != 1) fail("terminal summary read identity")
  if ($7 != 0) fail("retained trace allocation zero")
  count[$2]++; seq[$2]+=$5; summary[$2]+=$6; trace[$2]+=$7
  next
}
$1 == "BOUNDED_SUMMARY" {
  if (NF != 7) fail("summary schema")
  for(i=2;i<=7;i++) if(!nat($i)) fail("summary lexical grammar")
  pos=$2
  if (summaries[pos]++) fail("duplicate summary")
  if ($4 != count[pos] || $5 != seq[pos] || $6 != summary[pos] ||
      $7 != trace[pos]) fail("attempt/summary arithmetic")
  next
}
{ fail("legal record enum") }
END {
  if (bad) exit 1
  if (count[1]!=1 || count[2]!=3 || count[3]!=1 ||
      summaries[1]!=1 || summaries[2]!=1 || summaries[3]!=1) {
    print "verify-bounded: completeness/order" > "/dev/stderr"; exit 1
  }
  print "bounded reads/allocations/schema/arithmetic: PASS"
}
