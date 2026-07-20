BEGIN {
  FS = "\t"
  expected["34:7"] = "unobserved:watchdog_killed"
  expected["38:4"] = "completed:none"
  expected["41:6"] = "unobserved:watchdog_killed"
  expected["42:4"] = "interrupted:none"
  expected["43:5"] = "completed:none"
  expected["45:11"] = "unobserved:watchdog_killed"
}

function deterministic_signature(    result, field) {
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
  else if (($7 ":" $8) != expected[key])
    reject("unexpected raw status/result: " key)
  else
    first[key] = deterministic_signature()
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
  else if (($7 ":" $8) != expected[key])
    reject("unexpected repeat status/result: " key)
  else if ($7 == "completed" &&
           first[key] != deterministic_signature())
    reject("completed counter/poll/trace mismatch: " key)
  else if ($7 == "interrupted" &&
           first[key] != deterministic_signature())
    interrupted_nondeterministic[key] = 1
}

END {
  for (key in expected) {
    if (!(key in raw_seen))
      reject("missing raw key: " key)
    if (!(key in repeat_seen))
      reject("missing repeat key: " key)
  }
  if (failed) exit 1
  print "all six status/result pairs reproduced; completed-row counters, " \
        "polls, and traces reproduced"
  for (key in interrupted_nondeterministic)
    print key ": interrupted partial counters differ (time-censored)"
}
