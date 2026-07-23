open HolKernel boolSyntax

fun required name =
  case OS.Process.getEnv name of
      SOME value => value
    | NONE => raise Fail ("missing " ^ name)

fun int_env name =
  case Int.fromString (required name) of
      SOME value => value
    | NONE => raise Fail ("bad integer " ^ name)

val mode = required "M2T_MODE"
val repetition = int_env "M2T_REPETITION"
val batch = int_env "M2T_BATCH"
val _ = if batch = 1000 then () else raise Fail "batch changed"
val p = mk_var ("active_calibration_p", bool)
val q = mk_var ("active_calibration_q", bool)
val goal = ([mk_conj (p, q)], p)
val cs =
  clasetLib.add_selims
    [("active-calibration-andE", clasetSeedTheory.CONJ_ELIM_THM)]
    clasetLib.empty_cs
val proof =
  case blastSearch.tryGoal cs 0 goal of
      SOME value => value
    | NONE => raise Fail "fixture search failed"
val expected = ref (NONE : blastReconstruct.detailed_statistics option)

fun check statistics result =
  let
    val _ =
      case !expected of
          NONE => expected := SOME statistics
        | SOME prior =>
            if prior = statistics then ()
            else raise Fail "nondeterministic counters"
  in
    case result of
        SOME ([], validation) => ignore (validation [])
      | _ => raise Fail "fixture replay failed"
  end

fun one () =
  if mode = "untimed" then
    let
      val report =
        blastReconstruct.reconstructWithMeasuredDetailed
          {observe = NONE, observe_stored_rule = NONE,
           stop = fn () => false} cs goal proof
    in
      if #completion report = blastReconstruct.Completed then
        check (#statistics report) (#result report)
      else raise Fail "untimed replay interrupted"
    end
  else if mode = "timed" then
    let
      val report =
        blastReconstruct.reconstructWithMeasuredTimedDetailed
          {clock = Time.now, observe = NONE,
           observe_stored_rule = NONE, stop = fn () => false}
          cs goal proof
    in
      if #completion report = blastReconstruct.Completed andalso
         Time.compare
           (#classical_time (#classical_times report), Time.zeroTime) <>
           LESS andalso
         Time.compare
           (#attempt_wall_time report,
            #classical_time (#classical_times report)) <> LESS then
        check (#statistics report) (#result report)
      else raise Fail "timed replay accounting failed"
    end
  else raise Fail "unknown mode"

fun repeat 0 = ()
  | repeat count = (one (); repeat (count - 1))

val started = Time.now ()
val _ = repeat batch
val elapsed = Time.- (Time.now (), started)
val statistics = valOf (!expected)
val _ =
  print
    (String.concatWith "\t"
       [Int.toString repetition, mode, Int.toString batch,
        Time.fmt 9 elapsed,
        Int.toString (#cooperative_checkpoints statistics),
        Int.toString (#phase_entries statistics),
        Int.toString (#phase_exits statistics),
        Int.toString (#stored_rule_checkpoints statistics),
        Int.toString (#stored_rule_phase_entries statistics),
        Int.toString (#stored_rule_phase_exits statistics),
        Int.toString (#stored_rule_attempt_selections statistics),
        Int.toString (#stored_rule_major_unifications statistics),
        Int.toString (#stored_rule_record_insertions statistics)] ^ "\n")
