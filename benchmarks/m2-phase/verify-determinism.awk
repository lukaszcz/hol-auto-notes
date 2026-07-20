BEGIN {
  FS = "\t"
  expected["34:7"] = 1
  expected["38:4"] = 1
  expected["41:6"] = 1
  expected["42:4"] = 1
  expected["43:5"] = 1
  expected["45:11"] = 1
}

function signature(    result, field) {
  result = $5 FS $6 FS $7 FS $8
  for (field = 10; field <= 32; field++)
    result = result FS $field
  return result
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

NR == FNR {
  if (NF != 32) {
    reject("raw row " FNR " has " NF " fields, expected 32")
    next
  }
  if (FNR == 1) {
    header = $0
    next
  }
  key = $3 ":" $4
  if (!(key in expected))
    reject("unexpected raw key: " key)
  else if (++raw_seen[key] != 1)
    reject("duplicate raw key: " key)
  else if ($7 != "completed" && $7 != "interrupted" &&
           $7 != "unobserved")
    reject("raw row has invalid completion status: " key)
  else
    first[key] = signature()
  next
}

FNR == 1 {
  if (NF != 32)
    reject("repeat header has " NF " fields, expected 32")
  if ($0 != header)
    reject("raw and repeat headers differ")
  next
}

{
  if (NF != 32) {
    reject("repeat row " FNR " has " NF " fields, expected 32")
    next
  }
  key = $3 ":" $4
  if (!(key in expected))
    reject("unexpected repeat key: " key)
  else if (++repeat_seen[key] != 1)
    reject("duplicate repeat key: " key)
  else if ($7 != "completed" && $7 != "interrupted" &&
           $7 != "unobserved")
    reject("repeat row has invalid completion status: " key)
  else if (!(key in first))
    reject("repeat has no observed raw row: " key)
  else if (first[key] != signature())
    reject("protocol/status/counter/poll/trace mismatch: " key)
}

END {
  for (key in expected) {
    if (!(key in raw_seen))
      reject("missing raw key: " key)
    if (!(key in repeat_seen))
      reject("missing repeat key: " key)
  }
  if (failed) exit 1
  print "all six phase rows have identical protocol, status, counters, " \
        "polls, and trace summaries (elapsed time excluded)"
}
