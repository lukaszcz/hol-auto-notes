BEGIN {
  FS = "\t"
}

function retained(field) {
  return field != 4 && field < 67
}

NR == FNR {
  if (FNR == 1) {
    for (i = 1; i <= NF; i++)
      if (retained(i)) expected_header[i] = $i
    expected_nf = NF
    next
  }
  expected_rows++
  for (i = 1; i <= NF; i++)
    if (retained(i)) expected[expected_rows, i] = $i
  next
}

FNR == 1 {
  if (NF != expected_nf) bad = 1
  for (i = 1; i <= NF; i++)
    if (retained(i) && $i != expected_header[i]) bad = 1
  next
}

{
  row = FNR - 1
  if (row > expected_rows || NF != expected_nf) bad = 1
  for (i = 1; i <= NF; i++)
    if (retained(i) && $i != expected[row, i]) {
      print "final expectation mismatch at row " row ", field " i \
        > "/dev/stderr"
      bad = 1
    }
}

END {
  if (FNR - 1 != expected_rows) bad = 1
  exit bad
}
