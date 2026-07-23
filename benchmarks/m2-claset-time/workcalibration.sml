open HolKernel boolSyntax

val problems =
  [(34, “((?x:'a. !y. p x <=> p y) <=>
           ((?x. q x) <=> (!y. p y))) <=>
          ((?x. !y. q x <=> q y) <=>
           ((?x. p x) <=> (!y. q y)))”),
   (38, “(!x:'a. p a /\ (p x ==> ?y. p y /\ r x y) ==>
                   ?z w. p z /\ r x w /\ r w z) <=>
          (!x. (~p a \/ p x \/
                 (?z w. p z /\ r x w /\ r w z)) /\
               (~p a \/ ~(?y. p y /\ r x y) \/
                 (?z w. p z /\ r x w /\ r w z)))”),
   (43, “(!x:'a y. q x y <=> (!z. p z x <=> p z y)) ==>
          (!x y. q x y <=> q y x)”)]

fun required name =
  case OS.Process.getEnv name of SOME value => value
    | NONE => raise Fail ("missing " ^ name)
fun int_env name =
  case Int.fromString (required name) of SOME value => value
    | NONE => raise Fail ("bad integer " ^ name)
val repetition = int_env "M2T_REPETITION"
val number = int_env "M2T_PROBLEM"
val depth = int_env "M2T_DEPTH"
val mode = required "M2T_MODE"
val proposition =
  case List.find (fn (candidate, _) => candidate = number) problems of
      SOME (_, value) => value
    | NONE => raise Fail "unknown problem"
val goal = ([], proposition)
val cs =
  clasetLib.invocation_claset {prefix = "__blast_extra_"}
    (clasetLib.add_selims
      [("blast_not_imp", clasetSeedTheory.NOT_IMP_CELIM_THM),
       ("blast_not_forall", clasetSeedTheory.NOT_FORALL_CELIM_THM)]
      (clasetLib.the_claset ())) []

fun statistics_fields
      (s : blastReconstruct.detailed_statistics) =
  map Int.toString
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
     #stored_rule_freshening_setups s,
     #stored_rule_minor_unifications s,
     #stored_rule_major_unifications s, #stored_rule_instantiations s,
     #stored_rule_child_store_constructions s,
     #stored_rule_direct_result_constructions s,
     #stored_rule_lazy_yields s,
     #stored_rule_direct_child_replacements s,
     #stored_rule_replay_record_constructions s,
     #stored_rule_record_insertions s, #stored_rule_intro_attempts s,
     #stored_rule_elim_attempts s, #stored_rule_safe_attempts s,
     #stored_rule_unsafe_attempts s]

val attempts = ref 0
val signatures = ref ([] : string list)
fun record statistics =
  (attempts := !attempts + 1;
   signatures :=
     String.concatWith "," (statistics_fields statistics) :: !signatures)

fun accept proof =
  if mode = "untimed" then
    let
      val report =
        blastReconstruct.reconstructWithMeasuredDetailed
          {observe = NONE, observe_stored_rule = NONE,
           stop = fn () => false} cs goal proof
      val _ = record (#statistics report)
    in
      case (#completion report, #result report) of
          (blastReconstruct.Completed, SOME ([], validation)) =>
            (ignore (validation []); proof)
        | (blastReconstruct.Completed, _) =>
            raise blastSearch.PROOF_FAILED
        | _ => raise Fail "unexpected interruption"
    end
  else if mode = "timed" then
    let
      val report =
        blastReconstruct.reconstructWithMeasuredTimedDetailed
          {clock = Time.now, observe = NONE,
           observe_stored_rule = NONE, stop = fn () => false}
          cs goal proof
      val _ = record (#statistics report)
    in
      case (#completion report, #result report) of
          (blastReconstruct.Completed, SOME ([], validation)) =>
            (ignore (validation []); proof)
        | (blastReconstruct.Completed, _) =>
            raise blastSearch.PROOF_FAILED
        | _ => raise Fail "unexpected interruption"
    end
  else raise Fail "unknown mode"

val started = Time.now ()
val report =
  blastSearch.searchGoalMeasured {debug = false, stop = fn () => false}
    cs depth goal accept
val elapsed = Time.- (Time.now (), started)
val statistics = #statistics report
val outcome =
  case (#completion report, #result report) of
      (blastSearch.Completed, NONE) => "none"
    | (blastSearch.Completed, SOME _) => "proof"
    | _ => "interrupted"
val _ =
  print
    (String.concatWith "\t"
       [Int.toString repetition, Int.toString number,
        Int.toString depth, mode, outcome, Time.fmt 9 elapsed,
        Int.toString (!attempts),
        Int.toString (#cooperative_checkpoints statistics),
        Int.toString (#inferences_performed statistics),
        Int.toString (#branches_created statistics),
        Int.toString (#branches_closed statistics),
        Int.toString (#choices_pruned statistics),
        Int.toString (#maximum_resource_cost statistics),
        Int.toString (#rule_cache_hits statistics),
        Int.toString (#rule_conversions statistics),
        String.concatWith ";" (rev (!signatures))] ^ "\n")
