BEGIN {
  FS = "\t"
  OFS = "\t"

  phase_name[1] = "attempt_selection"
  phase_name[2] = "freshening_setup"
  phase_name[3] = "minor_unification"
  phase_name[4] = "major_unification"
  phase_name[5] = "rule_instantiation"
  phase_name[6] = "child_store_construction"
  phase_name[7] = "direct_result_construction"
  phase_name[8] = "lazy_result_yield"
  phase_name[9] = "direct_child_replacement"
  phase_name[10] = "replay_record_construction"
  phase_name[11] = "record_insertion"
  for (i = 1; i <= 11; i++) phase_index[phase_name[i]] = i

  if (scenario == "") {
    print "fixture scenario is required" > "/dev/stderr"
    exit 2
  }
}

function reset_payload(    i) {
  for (i in payload) delete payload[i]
  for (i = 1; i <= 56; i++) payload[i] = 0

  payload[1] = 34
  payload[2] = "attempt_result"
  payload[3] = 1
  payload[4] = "interrupted"
  payload[5] = "none"
  payload[6] = "enter"
  payload[7] = "alternative_enumeration"

  # A reachable outer prefix: replay and stored setup enclose a typed
  # unsafe-rule step; AlternativeEnumeration is then entered before forcing.
  payload[16] = 6
  payload[21] = 4
  payload[22] = 2
  payload[23] = 1
  payload[24] = 1
  payload[25] = 1
  payload[31] = 1
  payload[32] = 1
}

function recalculate_stored(exits,    entries, i) {
  entries = 0
  for (i = 42; i <= 52; i++) entries += payload[i]
  payload[18] = entries
  payload[19] = exits
  payload[17] = entries + exits
  payload[39] = payload[17]
  payload[40] = entries
  payload[41] = exits
  payload[20] = payload[16] + payload[39]
  generated_checkpoints = payload[20]
}

function make_before_stored(    i) {
  reset_payload()
  for (i = 8; i <= 15; i++) payload[i] = "none"
  recalculate_stored(0)
}

function make_concrete(phase, boundary, step_kind, duplicate,
                       phase_number, exits, i) {
  reset_payload()
  phase_number = phase_index[phase]
  if (!phase_number || (boundary != "enter" && boundary != "exit")) {
    print "invalid positive phase/boundary" > "/dev/stderr"
    exit 2
  }

  payload[8] = 1
  payload[9] = step_kind
  payload[10] = duplicate
  payload[11] = boundary
  payload[12] = phase
  payload[13] = 1
  payload[14] = "elim"
  payload[15] = 1

  for (i = 1; i <= phase_number; i++) payload[41 + i] = 1
  payload[53] = 0
  payload[54] = 1
  payload[55] = (step_kind == "safe_rule")
  payload[56] = (step_kind == "unsafe_rule")
  exits = phase_number - (boundary == "enter")
  recalculate_stored(exits)
}

function make_fixture(    i) {
  if (scenario == "positive_before") {
    make_before_stored()
  } else if (scenario == "positive_phase") {
    make_concrete(phase, boundary, "unsafe_rule", "false")
  } else if (scenario == "bad_major_minor") {
    make_concrete("major_unification", "enter", "unsafe_rule", "false")
    payload[42] = 2
    payload[43] = 2
    payload[44] = 1
    payload[45] = 2
    payload[54] = 2
    payload[56] = 2
    recalculate_stored(payload[41])
  } else if (scenario == "bad_safe_duplicate") {
    make_concrete("attempt_selection", "enter", "safe_rule", "true")
  } else if (scenario == "bad_partial_context") {
    make_before_stored()
    payload[8] = 1
  } else if (scenario == "bad_absent_counts") {
    make_before_stored()
    payload[42] = 1
    payload[54] = 1
    payload[56] = 1
    recalculate_stored(0)
  } else if (scenario == "bad_outer_current_count") {
    make_concrete("minor_unification", "enter", "unsafe_rule", "false")
    payload[16] = 5
    payload[20]--
    payload[21] = 3
    payload[24] = 0
    generated_checkpoints = payload[20]
  } else if (scenario == "bad_stored_current_count") {
    make_concrete("minor_unification", "enter", "unsafe_rule", "false")
    payload[44] = 0
    recalculate_stored(payload[41])
  } else {
    print "unknown fixture scenario: " scenario > "/dev/stderr"
    exit 2
  }
}

function joined_payload(    result, i) {
  result = payload[1]
  for (i = 2; i <= 56; i++) result = result "|" payload[i]
  return result
}

function joined_items(count,    result, i) {
  result = item[1]
  for (i = 2; i <= count; i++) result = result "|" item[i]
  return result
}

function direct_scenario() {
  return scenario == "bad_stdout_before_attempt" ||
         scenario == "bad_stdout_before_result" ||
         scenario == "bad_marker_after_stdout" ||
         scenario == "bad_noncanonical_run" ||
         scenario == "bad_noncanonical_attempt" ||
         scenario == "bad_noncanonical_status"
}

{
  target = ($3 == 34 && $4 == 7)

  if (scenario == "bad_stdout_before_attempt" && target) {
    if ($8 == "marker") {
      delayed[++delayed_count] = $0
      next
    } else if ($8 == "stdout") {
      print
      for (i = 1; i <= delayed_count; i++) print delayed[i]
      next
    }
  } else if (scenario == "bad_stdout_before_result" && target) {
    if ($8 == "marker" && $9 ~ /\|attempt_result\|/) {
      delayed_result = $0
      next
    } else if ($8 == "stdout") {
      print
      print delayed_result
      next
    }
  } else if (scenario == "bad_marker_after_stdout" && target) {
    if ($8 == "marker" && $9 ~ /\|attempt_result\|/)
      repeated_marker = $0
    else if ($8 == "stdout") {
      print
      print repeated_marker
      next
    }
  }

  if (scenario == "bad_noncanonical_run" && target &&
      $8 == "marker" && $9 ~ /\|attempt_enter\|/)
    $1 = "01"
  else if (scenario == "bad_noncanonical_attempt" && target &&
           $8 == "marker") {
    fields = split($9, item, "|")
    item[3] = "01"
    $9 = joined_items(fields)
  } else if (scenario == "bad_noncanonical_status" && target &&
             $8 == "status")
    $9 = "00"

  if ($3 == 34 && $4 == 7 && $8 == "marker" &&
      $9 ~ /^34\|attempt_result\|1\|/) {
    if (!direct_scenario()) {
      make_fixture()
      $9 = joined_payload()
    }
  } else if ($3 == 34 && $4 == 7 && $8 == "stdout") {
    if (!direct_scenario()) {
      fields = split($9, stdout, "|")
      stdout[8] = "30.000000"
      stdout[10] = generated_checkpoints
      stdout[11] = 0
      stdout[12] = 0
      stdout[13] = 0
      stdout[14] = 0
      $9 = stdout[1]
      for (i = 2; i <= fields; i++) $9 = $9 "|" stdout[i]
    }
  }
  print
}
