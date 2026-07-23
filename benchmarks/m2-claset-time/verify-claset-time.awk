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

  outer_phase["replay_recursion"] = 1
  outer_phase["alternative_enumeration"] = 1
  outer_phase["typed_hyp_subst"] = 1
  outer_phase["typed_close_assume"] = 1
  outer_phase["typed_close_contradiction"] = 1
  outer_phase["typed_safe_rule"] = 1
  outer_phase["typed_defer_goal"] = 1
  outer_phase["typed_unsafe_rule"] = 1
  outer_phase["stored_rule_setup"] = 1
  outer_phase["stored_rule_transition"] = 1
  outer_phase["duplicate_child_move"] = 1
  outer_phase["finish_open_goals"] = 1
  outer_phase["ground_replay"] = 1
  outer_phase["kernel_replay"] = 1
  outer_phase["finish_residual_goals"] = 1

  outer_counter["replay_recursion"] = 23
  outer_counter["alternative_enumeration"] = 24
  outer_counter["typed_hyp_subst"] = 26
  outer_counter["typed_close_assume"] = 27
  outer_counter["typed_close_contradiction"] = 28
  outer_counter["typed_safe_rule"] = 29
  outer_counter["typed_defer_goal"] = 30
  outer_counter["typed_unsafe_rule"] = 31
  outer_counter["stored_rule_setup"] = 32
  outer_counter["stored_rule_transition"] = 33
  outer_counter["duplicate_child_move"] = 34
  outer_counter["finish_open_goals"] = 35
  outer_counter["ground_replay"] = 36
  outer_counter["kernel_replay"] = 37
  outer_counter["finish_residual_goals"] = 38

  rule_phase["attempt_selection"] = 1
  rule_phase["freshening_setup"] = 1
  rule_phase["minor_unification"] = 1
  rule_phase["major_unification"] = 1
  rule_phase["rule_instantiation"] = 1
  rule_phase["child_store_construction"] = 1
  rule_phase["direct_result_construction"] = 1
  rule_phase["lazy_result_yield"] = 1
  rule_phase["direct_child_replacement"] = 1
  rule_phase["replay_record_construction"] = 1
  rule_phase["record_insertion"] = 1

  rule_counter["attempt_selection"] = 42
  rule_counter["freshening_setup"] = 43
  rule_counter["minor_unification"] = 44
  rule_counter["major_unification"] = 45
  rule_counter["rule_instantiation"] = 46
  rule_counter["child_store_construction"] = 47
  rule_counter["direct_result_construction"] = 48
  rule_counter["lazy_result_yield"] = 49
  rule_counter["direct_child_replacement"] = 50
  rule_counter["replay_record_construction"] = 51
  rule_counter["record_insertion"] = 52
}

function reject(message) {
  print message > "/dev/stderr"
  failed = 1
}

function natural(value) {
  return value ~ /^[0-9]+$/
}

function canonical_positive(value) {
  return value ~ /^[1-9][0-9]*$/
}

function positive(value) {
  return natural(value) && (value + 0) > 0
}

function fixed_positive(value, expected) {
  return canonical_positive(value) && (value + 0) == expected
}

function elapsed_decimal(value) {
  return value ~ /^[0-9]+([.][0-9]+)?$/
}

function attempt_block_complete(key, attempt) {
  if (entered[key] < 1 || entered[key] != expected_attempts[key] ||
      active[key])
    return 0
  for (attempt = 1; attempt <= expected_attempts[key]; attempt++)
    if (!result_seen[key, attempt]) return 0
  return 1
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
    reject("invalid claset-time raw header")
  next
}

{
  if (NF != 9) {
    reject("raw row " NR " has " NF " fields, expected 9")
    next
  }

  key = $3 ":" $4
  if (!(key in expected_position)) {
    reject("unexpected claset-time key: " key)
    next
  }
  position = expected_position[key]
  enter_block(key, position)

  if ($1 !~ /^1$/ || !fixed_positive($2, position) ||
      $5 != "false" || $6 !~ /^30$/ || $7 !~ /^60$/)
    reject("protocol mismatch: " key)
  if (terminal[key]) reject("record after terminal status: " key)

  if ($8 == "marker") {
    if (stdout_seen[key]) {
      reject("marker after stdout: " key)
      next
    }
    fields = split($9, item, "|")
    if (!fixed_positive(item[1], $3 + 0)) {
      reject("marker problem label mismatch: " key)
      next
    }

    event = item[2]
    attempt = item[3] + 0
    if (!canonical_positive(item[3]) || attempt < 1 ||
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
    } else if (event == "attempt_result") {
      if (fields != 69) {
        reject("attempt_result field count: " key ":" attempt)
        next
      }
      if (active[key] != attempt || result_seen[key, attempt])
        reject("attempt_result order: " key ":" attempt)
      if (item[4] != expected_completion[key, attempt])
        reject("attempt completion mismatch: " key ":" attempt)
      if (item[5] != "none")
        reject("pathological attempt unexpectedly reconstructed: " key)

      if (item[6] != "enter" && item[6] != "exit")
        reject("unknown outer boundary: " key ":" item[6])
      if (!(item[7] in outer_phase))
        reject("unknown outer phase: " key ":" item[7])

      stored_none = 0
      for (i = 8; i <= 14; i++)
        if (item[i] == "none") stored_none++
      stored_concrete = (stored_none == 0)
      stored_absent = (stored_none == 7 && item[15] == "none")
      if (!stored_concrete && !stored_absent)
        reject("partial stored-rule context: " key ":" attempt)
      if (stored_concrete) {
        if (!positive(item[8]))
          reject("invalid script position: " key ":" item[8])
        if (item[9] != "safe_rule" && item[9] != "unsafe_rule")
          reject("invalid stored step kind: " key ":" item[9])
        if (item[10] != "true" && item[10] != "false")
          reject("invalid duplicate flag: " key ":" item[10])
        if (item[9] == "safe_rule" && item[10] == "true")
          reject("safe stored rule marked duplicate: " key ":" attempt)
        if (item[11] != "enter" && item[11] != "exit")
          reject("unknown stored boundary: " key ":" item[11])
        if (!(item[12] in rule_phase))
          reject("unknown stored phase: " key ":" item[12])
        if (!positive(item[13]))
          reject("invalid goal position: " key ":" item[13])
        if (item[14] != "intro" && item[14] != "elim")
          reject("invalid rule kind: " key ":" item[14])
        if (item[14] == "intro" && item[15] != "none")
          reject("intro attempt has an assumption: " key)
        if (item[14] == "elim" && !positive(item[15]))
          reject("elim attempt lacks an assumption: " key)
        if (item[12] == "major_unification" && item[14] != "elim")
          reject("major unification has non-elim context: " key)
      }

      for (i = 16; i <= 56; i++)
        if (!natural(item[i]))
          reject("non-natural counter " i ": " key ":" attempt)
      for (i = 57; i <= 69; i++)
        if (!elapsed_decimal(item[i]))
          reject("invalid elapsed field " i ": " key ":" attempt)
      phase_time_sum = 0
      for (i = 57; i <= 67; i++) phase_time_sum += item[i]
      if (phase_time_sum - item[68] > 0.00000001 ||
          item[68] - phase_time_sum > 0.00000001)
        reject("classical phase sum mismatch: " key ":" attempt)
      if ((item[68] + 0) < 0 || (item[69] + 0) < 0 ||
          (item[68] + 0) > (item[69] + 0) + 0.00000001)
        reject("attempt time bounds mismatch: " key ":" attempt)
      for (i = 42; i <= 52; i++)
        if ((item[i] + 0) == 0 && (item[i + 15] + 0) != 0)
          reject("zero-count phase has elapsed time: " key ":" \
            attempt ":" i)
      reconstruction_seconds[key] += item[69]
      classical_seconds[key] += item[68]

      outer_observed = item[16] + 0
      stored_observed = item[17] + 0
      observed_stored_entries = item[18] + 0
      observed_stored_exits = item[19] + 0
      checkpoints = item[20] + 0
      reconstruction_checkpoints[key] += checkpoints
      outer_entries = item[21] + 0
      outer_exits = item[22] + 0
      typed = item[25] + 0
      typed_sum = 0
      for (i = 26; i <= 31; i++) typed_sum += item[i]
      outer_entry_sum = item[23] + item[24] + item[25]
      for (i = 32; i <= 38; i++) outer_entry_sum += item[i]

      stored_checkpoints = item[39] + 0
      stored_entries = item[40] + 0
      stored_exits = item[41] + 0
      stored_entry_sum = 0
      for (i = 42; i <= 52; i++) stored_entry_sum += item[i]

      if (outer_observed != outer_entries + outer_exits)
        reject("outer observer/counter mismatch: " key ":" attempt)
      if (outer_entries < outer_exits)
        reject("outer entry/exit prefix mismatch: " key ":" attempt)
      if (item[outer_counter[item[7]]] < 1)
        reject("current outer phase was never entered: " key ":" attempt)
      if (item[6] == "exit" && outer_exits < 1)
        reject("current outer exit has no counted exit: " key ":" attempt)
      if (stored_observed != observed_stored_entries + \
          observed_stored_exits ||
          stored_observed != stored_checkpoints ||
          observed_stored_entries != stored_entries ||
          observed_stored_exits != stored_exits)
        reject("stored observer/counter mismatch: " key ":" attempt)
      if (stored_entries < stored_exits)
        reject("stored entry/exit prefix mismatch: " key ":" attempt)
      if (checkpoints != outer_observed + stored_checkpoints)
        reject("combined checkpoint mismatch: " key ":" attempt)
      if (typed != typed_sum)
        reject("typed-step subtotal mismatch: " key ":" attempt)
      if (outer_entries != outer_entry_sum)
        reject("outer phase-entry subtotal mismatch: " key ":" attempt)
      if (stored_entries != stored_entry_sum)
        reject("stored phase-entry subtotal mismatch: " key ":" attempt)
      if (item[42] != item[53] + item[54] ||
          item[42] != item[55] + item[56])
        reject("stored attempt-kind subtotal mismatch: " key ":" attempt)
      if (item[43] > item[42] || item[44] > item[43])
        reject("attempt/fresh/minor schema mismatch: " key ":" attempt)
      if (item[45] > item[44] || item[45] > item[54])
        reject("elim/major schema mismatch: " key ":" attempt)
      if (item[46] > item[44] ||
          item[46] > item[45] + item[53])
        reject("instantiation schema mismatch: " key ":" attempt)
      if (item[47] > item[46] || item[48] > item[47] ||
          item[49] > item[48] || item[50] > item[49] ||
          item[51] > item[50] || item[52] > item[51])
        reject("yield/record schema mismatch: " key ":" attempt)
      if (stored_absent) {
        stored_nonzero = stored_observed + observed_stored_entries + \
          observed_stored_exits
        for (i = 39; i <= 56; i++) stored_nonzero += item[i]
        if (stored_nonzero != 0)
          reject("absent stored context has stored counts: " key ":" attempt)
      } else if (stored_concrete) {
        if (stored_observed < 1)
          reject("concrete stored context was not observed: " key ":" attempt)
        if (item[rule_counter[item[12]]] < 1)
          reject("current stored phase was never entered: " key ":" attempt)
        if (item[11] == "exit" && stored_exits < 1)
          reject("current stored exit has no counted exit: " key ":" attempt)
        if (item[14] == "intro" && item[53] < 1 ||
            item[14] == "elim" && item[54] < 1)
          reject("current stored rule kind was never attempted: " key \
            ":" attempt)
        if (item[9] == "safe_rule" && item[55] < 1 ||
            item[9] == "unsafe_rule" && item[56] < 1)
          reject("current stored step kind was never attempted: " key \
            ":" attempt)
      }

      completion[key, attempt] = item[4]
      result[key, attempt] = item[5]
      for (i = 6; i <= 69; i++) value[key, attempt, i] = item[i]
      result_seen[key, attempt] = 1
      active[key] = 0
    } else if (event == "validation_enter" ||
               event == "validation_exit") {
      reject("unexpected validation for pathological target: " key)
    } else {
      reject("unknown marker event: " key ":" event)
    }
  } else if ($8 == "stdout") {
    if (stdout_seen[key]) {
      reject("duplicate stdout: " key)
      next
    }
    if (entered[key] < 1) {
      reject("stdout before attempt block: " key)
      next
    }
    if (active[key]) {
      reject("stdout with active attempt: " key ":" active[key])
      next
    }
    if (!attempt_block_complete(key)) {
      reject("stdout before complete attempt block: " key)
      next
    }
    fields = split($9, item, "|")
    if (fields != 20)
      reject("stdout field count: " key)
    else {
      if (!fixed_positive(item[1], 1) ||
          !fixed_positive(item[2], position) ||
          !fixed_positive(item[3], $3 + 0) ||
          !fixed_positive(item[4], $4 + 0) ||
          item[5] != "false" || item[6] !~ /^30$/ ||
          item[7] != "reconstruction_interrupted")
        reject("stdout protocol/outcome mismatch: " key)
      if (!elapsed_decimal(item[8]) ||
          (item[8] + 0) < 30 || (item[8] + 0) >= 60)
        reject("process time outside cooperative/watchdog interval: " key)
      if (!fixed_positive(item[9], expected_attempts[key]))
        reject("stdout attempt count mismatch: " key)
      for (i = 10; i <= 18; i++)
        if (!natural(item[i]))
          reject("stdout non-natural field " i ": " key)
      for (i = 19; i <= 20; i++)
        if (!elapsed_decimal(item[i]))
          reject("stdout invalid elapsed field " i ": " key)
      if ((item[19] + 0) > (item[8] + 0) + 0.00000001 ||
          (item[20] + 0) > (item[19] + 0) + 0.00000001)
        reject("process/reconstruction/classical bounds mismatch: " key)
      if (reconstruction_seconds[key] - item[19] > 0.00000001 ||
          item[19] - reconstruction_seconds[key] > 0.00000001 ||
          classical_seconds[key] - item[20] > 0.00000001 ||
          item[20] - classical_seconds[key] > 0.00000001)
        reject("stdout attempt time aggregate mismatch: " key)
      process_seconds[key] = item[8]
      stop_polls[key] = item[10] + 0
      search_checkpoints[key] = item[11] + 0
      search_inferences[key] = item[12] + 0
      search_branches_created[key] = item[13] + 0
      search_branches_closed[key] = item[14] + 0
      search_choices_pruned[key] = item[15] + 0
      search_maximum_cost[key] = item[16] + 0
      search_cache_hits[key] = item[17] + 0
      search_conversions[key] = item[18] + 0
      stdout_seen[key]++
    }
  } else if ($8 == "status") {
    if ($9 !~ /^0$/) reject("process status is not exactly zero: " key)
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
    if (stop_polls[key] != search_checkpoints[key] + \
        reconstruction_checkpoints[key])
      reject("global stop/checkpoint mismatch: " key)
    for (attempt = 1; attempt <= expected_attempts[key]; attempt++)
      if (!result_seen[key, attempt])
        reject("missing attempt result: " key ":" attempt)
  }
  if (current_position != 3)
    reject("incomplete problem block sequence")
  if (failed) exit 1

  print "problem", "depth", "attempt", "process_seconds", \
        "stop_polls", "search_cooperative_checkpoints", \
        "search_inferences", "search_branches_created", \
        "search_branches_closed", "search_choices_pruned", \
        "search_maximum_cost", "search_cache_hits", \
        "search_conversions", \
        "completion", "result", "outer_boundary", "outer_phase", \
        "script_position", "step_kind", "duplicate", \
        "rule_boundary", "rule_phase", "goal_position", "rule_kind", \
        "assumption_position", "outer_observed", "stored_observed", \
        "stored_entries", "stored_exits", "cooperative_checkpoints", \
        "phase_entries", "phase_exits", "replay_recursions", \
        "alternative_pulls", "typed_steps", "hyp_subst_steps", \
        "close_assume_steps", "close_contradiction_steps", \
        "safe_rule_steps", "defer_goal_steps", "unsafe_rule_steps", \
        "stored_rule_setups", "stored_rule_transitions", \
        "duplicate_child_moves", "finish_open_goal_checks", \
        "grounding_attempts", "kernel_replay_attempts", \
        "finish_residual_goal_checks", "stored_rule_checkpoints", \
        "stored_rule_phase_entries", "stored_rule_phase_exits", \
        "stored_rule_attempt_selections", \
        "stored_rule_freshening_setups", \
        "stored_rule_minor_unifications", \
        "stored_rule_major_unifications", \
        "stored_rule_instantiations", \
        "stored_rule_child_store_constructions", \
        "stored_rule_direct_result_constructions", \
        "stored_rule_lazy_yields", \
        "stored_rule_direct_child_replacements", \
        "stored_rule_replay_record_constructions", \
        "stored_rule_record_insertions", "stored_rule_intro_attempts", \
        "stored_rule_elim_attempts", "stored_rule_safe_attempts", \
        "stored_rule_unsafe_attempts", "attempt_selection_seconds", \
        "freshening_setup_seconds", "minor_unification_seconds", \
        "major_unification_seconds", "rule_instantiation_seconds", \
        "child_store_construction_seconds", \
        "direct_result_construction_seconds", \
        "lazy_result_yield_seconds", \
        "direct_child_replacement_seconds", \
        "replay_record_construction_seconds", \
        "record_insertion_seconds", "classical_seconds", \
        "attempt_wall_seconds"
  for (position = 1; position <= 3; position++) {
    for (key in expected_position) if (expected_position[key] == position) {
      split(key, problem_fields, ":")
      for (attempt = 1; attempt <= expected_attempts[key]; attempt++) {
        printf "%s\t%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s", \
          problem_fields[1], problem_fields[2], attempt, \
          process_seconds[key], stop_polls[key], search_checkpoints[key], \
          search_inferences[key], search_branches_created[key], \
          search_branches_closed[key], search_choices_pruned[key], \
          search_maximum_cost[key], search_cache_hits[key], \
          search_conversions[key], completion[key, attempt], \
          result[key, attempt]
        for (i = 6; i <= 69; i++) printf "\t%s", value[key, attempt, i]
        printf "\n"
      }
    }
  }
}
