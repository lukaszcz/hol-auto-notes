BEGIN {
  FS = "\t"
  expected["34:6"] = 1
  expected["38:3"] = 1
  expected["38:4"] = 1
  expected["41:5"] = 1
  expected["42:3"] = 1
  expected["43:4"] = 1
  expected["43:5"] = 1
  expected["45:10"] = 1
}

function signature(    result, field) {
  result = $5 FS $6 FS $7 FS $8
  for (field = 10; field <= 21; field++)
    result = result FS $field
  return result
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

NR == FNR {
  if (NF != 21) {
    reject("raw row " FNR " has " NF " fields, expected 21")
    next
  }
  if (FNR == 1) {
    header = $0
    next
  }
  if ($7 == "completed") {
    key = $3 ":" $4
    if (!(key in expected))
      reject("unexpected completed raw key: " key)
    else if (++raw_seen[key] != 1)
      reject("duplicate completed raw key: " key)
    else
      first[key] = signature()
  }
  next
}

FNR == 1 {
  if (NF != 21)
    reject("repeat header has " NF " fields, expected 21")
  if ($0 != header)
    reject("raw and repeat headers differ")
  next
}

{
  if (NF != 21) {
    reject("repeat row " FNR " has " NF " fields, expected 21")
    next
  }
  key = $3 ":" $4
  if (!(key in expected))
    reject("unexpected repeat key: " key)
  else if (++repeat_seen[key] != 1)
    reject("duplicate repeat key: " key)
  else if ($7 != "completed")
    reject("repeat row is not completed: " key)
  else if (!(key in first))
    reject("repeat has no completed raw row: " key)
  else if (first[key] != signature())
    reject("protocol/outcome/counter/poll/trace mismatch: " key)
}

END {
  for (key in expected) {
    if (!(key in raw_seen))
      reject("missing completed raw key: " key)
    if (!(key in repeat_seen))
      reject("missing repeat key: " key)
  }
  if (failed) exit 1
  print "all eight completed fixed-depth rows have identical protocol " \
        "fields, outcomes, counters, polls, and trace summaries"
}
