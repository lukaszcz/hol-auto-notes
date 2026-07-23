(* Fresh-process active timed-v2/timed-v3 calibration. *)
open HolKernel boolSyntax
fun required name = case OS.Process.getEnv name of SOME x => x
  | NONE => raise Fail ("missing " ^ name)
fun integer name = case Int.fromString (required name) of SOME x => x
  | NONE => raise Fail ("invalid " ^ name)
val mode = required "T7H_MODE"
val repetition = integer "T7H_REPETITION"
val batch = integer "T7H_BATCH"
val _ = if batch = 1000 then () else raise Fail "batch changed"
val p = mk_var ("task7h_active_p", bool)
val q = mk_var ("task7h_active_q", bool)
val goal = ([mk_conj (p, q)], p)
val cs = clasetLib.add_selims
  [("task7h-active-andE", clasetSeedTheory.CONJ_ELIM_THM)]
  clasetLib.empty_cs
val proof = case blastSearch.tryGoal cs 0 goal of SOME x => x
  | NONE => raise Fail "fixture search failed"
val expected = ref (NONE : blastReconstruct.detailed_statistics option)
fun check (base : blastReconstruct.timed_detailed_measured_result) =
  let
    val s = #statistics base
    val _ = case !expected of NONE => expected := SOME s
      | SOME prior => if prior = s then () else raise Fail "counter drift"
  in
    case (#completion base, #result base) of
        (blastReconstruct.Completed, SOME ([], validation)) =>
          ignore (validation [])
      | _ => raise Fail "replay result drift"
  end
fun one () =
  if mode = "v2" then
    check (#base (blastReconstruct.reconstructWithMeasuredTimedDetailedV2
      {clock = Time.now, observe = NONE, observe_stored_rule = NONE,
       stop = fn () => false} cs goal proof))
  else if mode = "v3" then
    check (#base (#base
      (blastReconstruct.reconstructWithMeasuredTimedDetailedV3
        {clock = Time.now, observe = NONE, observe_stored_rule = NONE,
         stop = fn () => false} cs goal proof)))
  else raise Fail "unknown mode"
fun repeat 0 = () | repeat n = (one (); repeat (n - 1))
val started = Time.now ()
val _ = repeat batch
val elapsed = Time.- (Time.now (), started)
val s = valOf (!expected)
val counter_signature = String.concatWith "," (map Int.toString
  [#cooperative_checkpoints s, #phase_entries s, #phase_exits s,
   #stored_rule_checkpoints s, #stored_rule_phase_entries s,
   #stored_rule_phase_exits s, #stored_rule_attempt_selections s,
   #stored_rule_major_unifications s,
   #stored_rule_record_insertions s])
val _ = print (String.concatWith "\t"
  [Int.toString repetition, mode, Int.toString batch,
   Time.fmt 9 elapsed, counter_signature] ^ "\n")
