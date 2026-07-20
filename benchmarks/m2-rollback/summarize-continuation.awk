BEGIN {
  FS = "\t"
  expected_position["34:7"] = 1
  expected_position["41:6"] = 2
  expected_position["45:11"] = 3

  expected["34:7", 1] = "continuation_enter"
  expected["34:7", 2] = "status"
  expected_length["34:7"] = 2

  expected["41:6", 1] = "continuation_enter"
  expected["41:6", 2] = "continuation_none"
  expected["41:6", 3] = "continuation_enter"
  expected["41:6", 4] = "continuation_none"
  expected["41:6", 5] = "continuation_enter"
  expected["41:6", 6] = "status"
  expected_length["41:6"] = 6

  expected["45:11", 1] = "continuation_enter"
  expected["45:11", 2] = "status"
  expected_length["45:11"] = 2

  allowed["continuation_enter"] = 1
  allowed["continuation_none"] = 1
  allowed["continuation_residual"] = 1
  allowed["validation_enter"] = 1
  allowed["continuation_exit"] = 1
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

function accept_event(key, event,    sequence_index) {
  sequence_index = ++sequence_length[key]
  if (terminal[key])
    reject("record after terminal status: " key)
  if (sequence_index > expected_length[key] ||
      expected[key, sequence_index] != event)
    reject("unexpected event " sequence_index " for " key ": " event)
  if (event == "status") terminal[key] = 1
  else count[key, event]++
}

NR == 1 {
  if (NF != 9 || $1 != "run" || $2 != "position" ||
      $3 != "problem" || $4 != "depth" || $5 != "debug" ||
      $6 != "budget_seconds" || $7 != "watchdog_seconds" ||
      $8 != "record" || $9 != "payload")
    reject("invalid continuation raw header")
  next
}

{
  if (NF != 9) {
    reject("raw row " NR " has " NF " fields, expected 9")
    next
  }
  key = $3 ":" $4
  if (!(key in expected_position)) {
    reject("unexpected continuation key: " key)
    next
  }
  position = expected_position[key]
  if ($1 != 1 || $2 != position || $5 != "false" ||
      $6 != 30 || $7 != 60)
    reject("protocol mismatch: " key)

  if (key != current_key) {
    if (position != current_position + 1)
      reject("problem block out of order: " key)
    current_key = key
    current_position = position
  }

  if ($8 == "marker") {
    prefix = $3 ":"
    if (index($9, prefix) != 1) {
      reject("unlabelled marker: " key ":" $9)
      next
    }
    event = substr($9, length(prefix) + 1)
    if (!(event in allowed)) {
      reject("unknown marker event: " key ":" event)
      next
    }
    accept_event(key, event)
  } else if ($8 == "status") {
    if ($9 != 124)
      reject("terminal status is not 124: " key)
    if (++statuses[key] != 1)
      reject("duplicate terminal status: " key)
    accept_event(key, "status")
  } else if ($8 == "stdout") {
    reject("stdout is forbidden: " key)
  } else {
    reject("unknown record kind: " $8)
  }
}

END {
  for (key in expected_position) {
    if (statuses[key] != 1)
      reject("missing terminal status: " key)
    if (!terminal[key])
      reject("unterminated event sequence: " key)
    if (sequence_length[key] != expected_length[key])
      reject("event count mismatch: " key)
  }
  if (current_position != 3)
    reject("incomplete problem block sequence")
  if (failed) exit 1

  print "problem\tdepth\twatchdog_seconds\tcontinuation_enter" \
        "\tcontinuation_none\tcontinuation_residual\tvalidation_enter" \
        "\tcontinuation_exit\tstdout_rows\tclassification"
  for (position = 1; position <= 3; position++) {
    for (key in expected_position) if (expected_position[key] == position) {
      split(key, fields, ":")
      entered = count[key, "continuation_enter"] + 0
      none = count[key, "continuation_none"] + 0
      residual = count[key, "continuation_residual"] + 0
      validation = count[key, "validation_enter"] + 0
      exited = count[key, "continuation_exit"] + 0
      if (none + residual == 0)
        verdict = "entered reconstructWith and remained there until watchdog"
      else
        verdict = (none + residual) " reconstructions returned; final " \
                  "reconstructWith remained until watchdog"
      print fields[1] "\t" fields[2] "\t60\t" entered "\t" none \
            "\t" residual "\t" validation "\t" exited "\t0\t" verdict
    }
  }
}
