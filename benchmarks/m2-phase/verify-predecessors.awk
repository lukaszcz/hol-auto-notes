BEGIN { FS = "\t" }

function signature(    result, field) {
  result = $2
  for (field = 3; field <= 8; field++) result = result FS $field
  for (field = 10; field <= 32; field++) result = result FS $field
  return result
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

NR == FNR {
  if (NF != 32) {
    reject("first row " FNR " has " NF " fields, expected 32")
    next
  }
  if (FNR == 1) { header = $0; next }
  key = $3 ":" $4
  if (++first_seen[key] != 1) reject("duplicate first key: " key)
  else first[key] = signature()
  next
}

FNR == 1 {
  if (NF != 32) reject("second header has " NF " fields, expected 32")
  if ($0 != header) reject("headers differ")
  next
}

{
  if (NF != 32) {
    reject("second row " FNR " has " NF " fields, expected 32")
    next
  }
  key = $3 ":" $4
  if (++second_seen[key] != 1) reject("duplicate second key: " key)
  else if (!(key in first)) reject("second-only key: " key)
  else if (first[key] != signature()) reject("row mismatch: " key)
}

END {
  for (key in first_seen)
    if (!(key in second_seen)) reject("first-only key: " key)
  if (failed) exit 1
  print "all predecessor protocol, status, counters, polls, and trace " \
        "summaries are identical (run and elapsed time excluded)"
}
