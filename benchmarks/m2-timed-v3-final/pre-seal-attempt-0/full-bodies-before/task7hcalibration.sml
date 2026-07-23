(* Fresh-process timed-v2/timed-v3 representative calibration. *)
open HolKernel boolSyntax
val problems =
  [(38, “(!x:'a. p a /\ (p x ==> ?y. p y /\ r x y) ==>
                   ?z w. p z /\ r x w /\ r w z) <=>
          (!x. (~p a \/ p x \/
                 (?z w. p z /\ r x w /\ r w z)) /\
               (~p a \/ ~(?y. p y /\ r x y) \/
                 (?z w. p z /\ r x w /\ r w z)))”),
   (43, “(!x:'a y. q x y <=> (!z. p z x <=> p z y)) ==>
          (!x y. q x y <=> q y x)”) ]
fun required name =
  case OS.Process.getEnv name of SOME value => value
    | NONE => raise Fail ("missing " ^ name)
fun integer name =
  case Int.fromString (required name) of SOME value => value
    | NONE => raise Fail ("invalid " ^ name)
val repetition = integer "T7H_REPETITION"
val number = integer "T7H_PROBLEM"
val depth = integer "T7H_DEPTH"
val mode = required "T7H_MODE"
val proposition =
  case List.find (fn (candidate, _) => candidate = number) problems of
      SOME (_, value) => value | NONE => raise Fail "unknown problem"
val goal = ([], proposition)
val cs = clasetLib.invocation_claset {prefix = "__blast_extra_"}
  (clasetLib.add_selims
    [("blast_not_imp", clasetSeedTheory.NOT_IMP_CELIM_THM),
     ("blast_not_forall", clasetSeedTheory.NOT_FORALL_CELIM_THM)]
    (clasetLib.the_claset ())) []
fun ints xs = String.concatWith "," (map Int.toString xs)
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
fun record s =
  (attempts := !attempts + 1; signatures := ints (fields s) :: !signatures)
fun check (base : blastReconstruct.timed_detailed_measured_result) proof =
  let val _ = record (#statistics base)
  in
    case (#completion base, #result base) of
        (blastReconstruct.Completed, SOME ([], validation)) =>
          (ignore (validation []); proof)
      | (blastReconstruct.Completed, _) => raise blastSearch.PROOF_FAILED
      | _ => raise Fail "unexpected interruption"
  end
fun accept proof =
  if mode = "v2" then
    check
      (#base (blastReconstruct.reconstructWithMeasuredTimedDetailedV2
        {clock = Time.now, observe = NONE, observe_stored_rule = NONE,
         stop = fn () => false} cs goal proof)) proof
  else if mode = "v3" then
    check
      (#base (#base
        (blastReconstruct.reconstructWithMeasuredTimedDetailedV3
          {clock = Time.now, observe = NONE, observe_stored_rule = NONE,
           stop = fn () => false} cs goal proof))) proof
  else raise Fail "unknown mode"
val started = Time.now ()
val report = blastSearch.searchGoalMeasured
  {debug = false, stop = fn () => false} cs depth goal accept
val elapsed = Time.- (Time.now (), started)
val s = #statistics report
val outcome =
  case (#completion report, #result report) of
      (blastSearch.Completed, NONE) => "none"
    | (blastSearch.Completed, SOME _) => "proof"
    | _ => "interrupted"
val _ = print (String.concatWith "\t"
  [Int.toString repetition, Int.toString number, Int.toString depth,
   mode, outcome, Time.fmt 9 elapsed, Int.toString (!attempts),
   ints [#cooperative_checkpoints s, #inferences_performed s,
         #branches_created s, #branches_closed s, #choices_pruned s,
         #maximum_resource_cost s, #rule_cache_hits s,
         #rule_conversions s],
   String.concatWith ";" (rev (!signatures))] ^ "\n")
