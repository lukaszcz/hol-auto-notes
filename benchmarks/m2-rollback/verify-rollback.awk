BEGIN {
  FS = "\t"
  expected["34:7"] = 1
  expected["41:6"] = 2
  expected["45:11"] = 3
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

NR == 1 {
  if (NF != 32) reject("rollback header has " NF " fields, expected 32")
  next
}

{
  if (NF != 32) {
    reject("rollback row " NR " has " NF " fields, expected 32")
    next
  }
  key = $3 ":" $4
  if (!(key in expected))
    reject("unexpected rollback key: " key)
  else if (++seen[key] != 1)
    reject("duplicate rollback key: " key)
  else if ($2 != expected[key] || $5 != "false" || $6 != 30)
    reject("rollback protocol mismatch: " key)
  else if ($7 != "unobserved" || $8 != "watchdog_killed" ||
           $9 != ">=60.000000")
    reject("rollback outcome mismatch: " key)
}

END {
  for (key in expected)
    if (seen[key] != 1) reject("missing rollback key: " key)
  if (failed) exit 1
  print "all three rollback rows have the exact 30/60 protocol and " \
        "watchdog-censored outcome"
}
