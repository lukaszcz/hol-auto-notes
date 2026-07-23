(* Fresh-process P38@4 A/B/C/D clock ablation. *)
open HolKernel boolSyntax

fun required name =
  case OS.Process.getEnv name of
      SOME value => value
    | NONE => raise Fail ("missing " ^ name)

fun integer name =
  case Int.fromString (required name) of
      SOME value => value
    | NONE => raise Fail ("invalid " ^ name)

val sequence = integer "T7K_SEQUENCE"
val repetition = integer "T7K_REPETITION"
val number = integer "T7K_PROBLEM"
val depth = integer "T7K_DEPTH"
val mode = required "T7K_MODE"
val _ = if number = 38 andalso depth = 4 then ()
        else raise Fail "workload changed"
val proposition =
  “(!x:'a. p a /\ (p x ==> ?y. p y /\ r x y) ==>
                ?z w. p z /\ r x w /\ r w z) <=>
     (!x. (~p a \/ p x \/
           (?z w. p z /\ r x w /\ r w z)) /\
          (~p a \/ ~(?y. p y /\ r x y) \/
           (?z w. p z /\ r x w /\ r w z)))”
val goal : goal = ([], proposition)
val cs =
  clasetLib.invocation_claset {prefix = "__blast_extra_"}
    (clasetLib.add_selims
      [("blast_not_imp", clasetSeedTheory.NOT_IMP_CELIM_THM),
       ("blast_not_forall", clasetSeedTheory.NOT_FORALL_CELIM_THM)]
      (clasetLib.the_claset ())) []

fun ints values = String.concatWith "," (map Int.toString values)
fun fields (s : blastReconstruct.detailed_statistics) =
  [#cooperative_checkpoints s, #phase_entries s, #phase_exits s,
   #replay_recursions s, #alternative_pulls s, #typed_steps s,
   #hyp_subst_steps s, #close_assume_steps s,
   #close_contradiction_steps s, #safe_rule_steps s,
   #defer_goal_steps s, #unsafe_rule_steps s, #stored_rule_setups s,
   #stored_rule_transitions s, #duplicate_child_moves s,
   #finish_open_goal_checks s, #grounding_attempts s,
   #kernel_replay_attempts s, #finish_residual_goal_checks s,
   #stored_rule_checkpoints s, #stored_rule_phase_entries s,
   #stored_rule_phase_exits s, #stored_rule_attempt_selections s,
   #stored_rule_freshening_setups s, #stored_rule_minor_unifications s,
   #stored_rule_major_unifications s, #stored_rule_instantiations s,
   #stored_rule_child_store_constructions s,
   #stored_rule_direct_result_constructions s,
   #stored_rule_lazy_yields s, #stored_rule_direct_child_replacements s,
   #stored_rule_replay_record_constructions s,
   #stored_rule_record_insertions s, #stored_rule_intro_attempts s,
   #stored_rule_elim_attempts s, #stored_rule_safe_attempts s,
   #stored_rule_unsafe_attempts s]

val attempts = ref 0
val signatures = ref ([] : string list)
val clock_reads = ref 0
val summary_reads = ref 0
val sequence_reads = ref 0
val trace_allocations = ref 0
val diagnostic_elapsed = ref Time.zeroTime

fun add_time reference value = reference := Time.+ (!reference, value)
fun count_constant_clock () =
  (clock_reads := !clock_reads + 1; Time.zeroTime)
fun count_real_clock () =
  (clock_reads := !clock_reads + 1; Time.now ())

fun finish (base : blastReconstruct.detailed_measured_result) proof =
  let
    val _ = attempts := !attempts + 1
    val _ = signatures := ints (fields (#statistics base)) :: !signatures
  in
    case (#completion base, #result base) of
        (blastReconstruct.Completed, SOME ([], validation)) =>
          (ignore (validation []); proof)
      | (blastReconstruct.Completed, _) => raise blastSearch.PROOF_FAILED
      | _ => raise Fail "unexpected reconstruction interruption"
  end

fun accept proof =
  if mode = "A" then
    finish
      (blastReconstruct.reconstructWithMeasuredDetailed
        {observe = NONE, observe_stored_rule = NONE,
         stop = fn () => false} cs goal proof) proof
  else if mode = "B" then
    let
      val report =
        blastReconstruct.reconstructWithMeasuredTimedDetailedV2
          {clock = Time.now, observe = NONE, observe_stored_rule = NONE,
           stop = fn () => false} cs goal proof
      val base = #base report
      val _ = add_time diagnostic_elapsed (#attempt_wall_time base)
    in
      finish base proof
    end
  else if mode = "C" orelse mode = "D" then
    let
      val clock = if mode = "C" then count_constant_clock
                  else count_real_clock
      val report =
        blastReconstruct.reconstructWithMeasuredTimedDetailedV4
          {clock = clock, observe = NONE, observe_stored_rule = NONE,
           stop = fn () => false} cs goal proof
      val v2 = #base report
      val base = #base v2
      val pulls = #alternative_pull_times report
      val reads = #summary_statistics_reads pulls
      val seq_reads = #sequence_statistics_reads pulls
      val traces = #retained_trace_allocations pulls
      val _ =
        if reads = 1 andalso seq_reads = 0 andalso traces = 0 then ()
        else raise Fail "bounded summary invariant"
      val _ = summary_reads := !summary_reads + reads
      val _ = sequence_reads := !sequence_reads + seq_reads
      val _ = trace_allocations := !trace_allocations + traces
      val _ =
        if mode = "D" then
          add_time diagnostic_elapsed (#attempt_wall_time base)
        else ()
    in
      finish base proof
    end
  else raise Fail "unknown mode"

val report = blastSearch.searchGoalMeasured
  {debug = false, stop = fn () => false} cs depth goal accept
val search = #statistics report
val outcome =
  case (#completion report, #result report) of
      (blastSearch.Completed, NONE) => "none"
    | (blastSearch.Completed, SOME _) => "proof"
    | _ => "interrupted"
val v4 = mode = "C" orelse mode = "D"
val internal =
  if mode = "B" orelse mode = "D" then
    Time.fmt 9 (!diagnostic_elapsed)
  else "NA"
val _ = print (String.concatWith "\t"
  ["V10CAL1", Int.toString sequence, Int.toString repetition,
   Int.toString number, Int.toString depth, mode, outcome,
   Int.toString (!attempts),
   ints [#cooperative_checkpoints search, #inferences_performed search,
         #branches_created search, #branches_closed search,
         #choices_pruned search, #maximum_resource_cost search,
         #rule_cache_hits search, #rule_conversions search],
   String.concatWith ";" (rev (!signatures)),
   if v4 then Int.toString (!clock_reads) else "NA",
   if v4 then Int.toString (!summary_reads) else "NA",
   if v4 then Int.toString (!trace_allocations) else "NA",
   if v4 then Int.toString (!sequence_reads) else "NA",
   internal] ^ "\n")
