BEGIN {
  FS = "\t"
  OFS = "\t"

  expected_position["34:7"] = 1
  expected_position["41:6"] = 2
  expected_position["45:11"] = 3
  expected_attempts["34:7"] = 1
  expected_attempts["41:6"] = 3
  expected_attempts["45:11"] = 1

  expected_completion["34:7", 1] = "interrupted"
  expected_completion["41:6", 1] = "completed"
  expected_completion["41:6", 2] = "completed"
  expected_completion["41:6", 3] = "interrupted"
  expected_completion["45:11", 1] = "interrupted"

  phase["replay_recursion"] = 1
  phase["alternative_enumeration"] = 1
  phase["typed_hyp_subst"] = 1
  phase["typed_close_assume"] = 1
  phase["typed_close_contradiction"] = 1
  phase["typed_safe_rule"] = 1
  phase["typed_defer_goal"] = 1
  phase["typed_unsafe_rule"] = 1
  phase["stored_rule_setup"] = 1
  phase["stored_rule_transition"] = 1
  phase["duplicate_child_move"] = 1
  phase["finish_open_goals"] = 1
  phase["ground_replay"] = 1
  phase["kernel_replay"] = 1
  phase["finish_residual_goals"] = 1
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

function natural(value) {
  return value ~ /^[0-9]+$/
}

function enter_block(key, position) {
  if (key == current_key) return
  if (current_key != "" && !terminal[current_key])
    reject("problem block changed before terminal status: " current_key)
  if (position != current_position + 1)
    reject("problem block out of order: " key)
  current_key = key
  current_position = position
}

NR == 1 {
  if (NF != 9 || $1 != "run" || $2 != "position" ||
      $3 != "problem" || $4 != "depth" || $5 != "debug" ||
      $6 != "budget_seconds" || $7 != "watchdog_seconds" ||
      $8 != "record" || $9 != "payload")
    reject("invalid reconstruction raw header")
  next
}

{
  if (NF != 9) {
    reject("raw row " NR " has " NF " fields, expected 9")
    next
  }

  key = $3 ":" $4
  if (!(key in expected_position)) {
    reject("unexpected reconstruction key: " key)
    next
  }
  position = expected_position[key]
  enter_block(key, position)

  if ($1 != 1 || $2 != position || $5 != "false" ||
      $6 != 30 || $7 != 60)
    reject("protocol mismatch: " key)
  if (terminal[key]) reject("record after terminal status: " key)

  if ($8 == "marker") {
    fields = split($9, item, "|")
    if (item[1] != $3) {
      reject("marker problem label mismatch: " key)
      next
    }

    event = item[2]
    attempt = item[3] + 0
    if (!natural(item[3]) || attempt < 1 ||
        attempt > expected_attempts[key]) {
      reject("invalid attempt number: " key ":" item[3])
      next
    }

    if (event == "attempt_enter") {
      if (fields != 3)
        reject("attempt_enter field count: " key)
      if (active[key] || attempt != entered[key] + 1)
        reject("attempt_enter order: " key ":" attempt)
      active[key] = attempt
      entered[key]++
    } else if (event == "boundary") {
      if (fields != 5)
        reject("boundary field count: " key ":" attempt)
      if (active[key] != attempt)
        reject("boundary outside active attempt: " key ":" attempt)
      if (item[4] != "enter" && item[4] != "exit")
        reject("unknown boundary: " key ":" item[4])
      if (!(item[5] in phase))
        reject("unknown phase: " key ":" item[5])
      boundary_count[key, attempt]++
      if (item[4] == "enter") observed_entries[key, attempt]++
      else observed_exits[key, attempt]++
      last_boundary[key, attempt] = item[4]
      last_phase[key, attempt] = item[5]
    } else if (event == "attempt_result") {
      if (fields != 26) {
        reject("attempt_result field count: " key ":" attempt)
        next
      }
      if (active[key] != attempt || result_seen[key, attempt])
        reject("attempt_result order: " key ":" attempt)
      if (item[4] != expected_completion[key, attempt])
        reject("attempt completion mismatch: " key ":" attempt)
      if (item[5] != "none")
        reject("pathological attempt unexpectedly reconstructed: " key)
      if (item[6] != last_boundary[key, attempt] ||
          item[7] != last_phase[key, attempt])
        reject("snapshot is not the last observed boundary: " key)

      for (i = 8; i <= 26; i++)
        if (!natural(item[i]))
          reject("non-natural counter " i ": " key ":" attempt)

      checkpoints = item[8] + 0
      entries = item[9] + 0
      exits = item[10] + 0
      typed = item[13] + 0
      typed_sum = 0
      for (i = 14; i <= 19; i++)
        typed_sum += item[i]
      entry_sum = item[11] + item[12] + item[13]
      for (i = 20; i <= 26; i++)
        entry_sum += item[i]

      if (checkpoints != entries + exits)
        reject("checkpoint/entry/exit mismatch: " key ":" attempt)
      if (checkpoints != boundary_count[key, attempt] ||
          entries != observed_entries[key, attempt] ||
          exits != observed_exits[key, attempt])
        reject("observer/counter mismatch: " key ":" attempt)
      if (typed != typed_sum)
        reject("typed-step subtotal mismatch: " key ":" attempt)
      if (entries != entry_sum)
        reject("phase-entry subtotal mismatch: " key ":" attempt)

      completion[key, attempt] = item[4]
      result[key, attempt] = item[5]
      current_boundary[key, attempt] = item[6]
      current_phase[key, attempt] = item[7]
      for (i = 8; i <= 26; i++)
        counter[key, attempt, i] = item[i]
      result_seen[key, attempt] = 1
      active[key] = 0
    } else if (event == "validation_enter" ||
               event == "validation_exit") {
      reject("unexpected validation for pathological target: " key)
    } else {
      reject("unknown marker event: " key ":" event)
    }
  } else if ($8 == "stdout") {
    fields = split($9, item, "|")
    if (fields != 14)
      reject("stdout field count: " key)
    else {
      if (item[1] != 1 || item[2] != position || item[3] != $3 ||
          item[4] != $4 || item[5] != "false" || item[6] != 30 ||
          item[7] != "reconstruction_interrupted")
        reject("stdout protocol/outcome mismatch: " key)
      if ((item[8] + 0) < 30 || (item[8] + 0) >= 60)
        reject("elapsed time outside cooperative/watchdog interval: " key)
      if (item[9] != expected_attempts[key])
        reject("stdout attempt count mismatch: " key)
      for (i = 9; i <= 14; i++)
        if (!natural(item[i]))
          reject("stdout non-natural field " i ": " key)
      process_seconds[key] = item[8]
      stdout_seen[key]++
    }
  } else if ($8 == "status") {
    if ($9 != 0) reject("process status is not zero: " key)
    if (stdout_seen[key] != 1)
      reject("status before exactly one stdout row: " key)
    if (active[key]) reject("status with active attempt: " key)
    if (++statuses[key] != 1)
      reject("duplicate terminal status: " key)
    terminal[key] = 1
  } else {
    reject("unknown raw record kind: " $8)
  }
}

END {
  for (key in expected_position) {
    if (entered[key] != expected_attempts[key])
      reject("attempt count mismatch: " key)
    if (statuses[key] != 1 || !terminal[key])
      reject("missing terminal status: " key)
    for (attempt = 1; attempt <= expected_attempts[key]; attempt++)
      if (!result_seen[key, attempt])
        reject("missing attempt result: " key ":" attempt)
  }
  if (current_position != 3)
    reject("incomplete problem block sequence")
  if (failed) exit 1

  print "problem", "depth", "attempt", "process_seconds", "completion", \
        "result", \
        "current_boundary", "current_phase", "cooperative_checkpoints", \
        "phase_entries", "phase_exits", "replay_recursions", \
        "alternative_pulls", "typed_steps", "hyp_subst_steps", \
        "close_assume_steps", "close_contradiction_steps", \
        "safe_rule_steps", "defer_goal_steps", "unsafe_rule_steps", \
        "stored_rule_setups", "stored_rule_transitions", \
        "duplicate_child_moves", "finish_open_goal_checks", \
        "grounding_attempts", "kernel_replay_attempts", \
        "finish_residual_goal_checks"
  for (position = 1; position <= 3; position++) {
    for (key in expected_position) if (expected_position[key] == position) {
      split(key, problem_fields, ":")
      for (attempt = 1; attempt <= expected_attempts[key]; attempt++) {
        printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s", \
          problem_fields[1], problem_fields[2], attempt, \
          process_seconds[key], \
          completion[key, attempt], result[key, attempt], \
          current_boundary[key, attempt], current_phase[key, attempt]
        for (i = 8; i <= 26; i++)
          printf "\t%s", counter[key, attempt, i]
        printf "\n"
      }
    }
  }
}
