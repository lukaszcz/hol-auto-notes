(* Task 7h authoritative timed-v3 target harness. *)
open HolKernel boolSyntax

val problems =
  [(34, “((?x:'a. !y. p x <=> p y) <=>
           ((?x. q x) <=> (!y. p y))) <=>
          ((?x. !y. q x <=> q y) <=>
           ((?x. p x) <=> (!y. q y)))”),
   (41, “(!z:'a. ?y. !x. f x y <=> (f x z /\ ~f x x)) ==>
          ~(?z. !x. f x z)”),
   (45, “(!x:'a. f x /\
                 (!y. g y /\ h x y ==> j x y) ==>
                 !y. g y /\ h x y ==> k y) /\
          ~(?y. l y /\ k y) /\
          (?x. f x /\ (!y. h x y ==> l y) /\
               (!y. g y /\ h x y ==> j x y)) ==>
          ?x. f x /\ ~(?y. g y /\ h x y)”) ]

fun required name =
  case OS.Process.getEnv name of SOME value => value
    | NONE => raise Fail ("missing " ^ name)
fun integer name =
  case Int.fromString (required name) of SOME value => value
    | NONE => raise Fail ("invalid " ^ name)
fun proposition number =
  case List.find (fn (candidate, _) => candidate = number) problems of
      SOME (_, value) => value
    | NONE => raise Fail "unknown problem"

val position = integer "T7H_POSITION"
val number = integer "T7H_PROBLEM"
val depth = integer "T7H_DEPTH"
val budget_seconds = integer "T7H_BUDGET_SECONDS"
val _ = if budget_seconds = 30 then () else raise Fail "budget changed"
val goal : goal = ([], proposition number)
val cs =
  clasetLib.invocation_claset {prefix = "__blast_extra_"}
    (clasetLib.add_selims
      [("blast_not_imp", clasetSeedTheory.NOT_IMP_CELIM_THM),
       ("blast_not_forall", clasetSeedTheory.NOT_FORALL_CELIM_THM)]
      (clasetLib.the_claset ())) []

fun ints values = String.concatWith "," (map Int.toString values)
fun times values = String.concatWith "," (map (Time.fmt 9) values)
fun emit fields =
  (TextIO.output (TextIO.stdErr, String.concatWith "|" fields ^ "\n");
   TextIO.flushOut TextIO.stdErr)
fun completion blastReconstruct.Completed = "completed"
  | completion blastReconstruct.Interrupted = "interrupted"
fun result NONE = "none" | result (SOME _) = "proof"
fun boundary blastReconstruct.Enter = "enter"
  | boundary blastReconstruct.Exit = "exit"
fun step blastReconstruct.HypSubstStep = "hyp_subst"
  | step blastReconstruct.CloseAssumeStep = "close_assume"
  | step blastReconstruct.CloseContradictionStep = "close_contradiction"
  | step blastReconstruct.SafeRuleStep = "safe_rule"
  | step blastReconstruct.DeferGoalStep = "defer_goal"
  | step blastReconstruct.UnsafeRuleStep = "unsafe_rule"
fun phase blastReconstruct.ReplayRecursion = "replay_recursion"
  | phase blastReconstruct.AlternativeEnumeration = "alternative_enumeration"
  | phase (blastReconstruct.TypedStep kind) = "typed_" ^ step kind
  | phase blastReconstruct.StoredRuleSetup = "stored_rule_setup"
  | phase blastReconstruct.StoredRuleTransition = "stored_rule_transition"
  | phase blastReconstruct.DuplicateChildMove = "duplicate_child_move"
  | phase blastReconstruct.FinishOpenGoals = "finish_open_goals"
  | phase blastReconstruct.GroundReplay = "ground_replay"
  | phase blastReconstruct.KernelReplay = "kernel_replay"
  | phase blastReconstruct.FinishResidualGoals = "finish_residual_goals"
fun current NONE = "none,none"
  | current (SOME ({boundary = b, phase = p} :
                     blastReconstruct.observation)) =
      boundary b ^ "," ^ phase p
fun rboundary clasetStep.RuleEnter = "enter"
  | rboundary clasetStep.RuleExit = "exit"
fun rphase clasetStep.AttemptSelection = "attempt_selection"
  | rphase clasetStep.FresheningSetup = "freshening_setup"
  | rphase clasetStep.MinorUnification = "minor_unification"
  | rphase clasetStep.EliminationMajorUnification = "major_unification"
  | rphase clasetStep.RuleInstantiation = "rule_instantiation"
  | rphase clasetStep.ChildStoreConstruction = "child_store_construction"
  | rphase clasetStep.DirectResultConstruction = "direct_result_construction"
  | rphase clasetStep.LazyResultYield = "lazy_result_yield"
  | rphase clasetStep.DirectChildReplacement = "direct_child_replacement"
  | rphase clasetStep.ReplayRecordConstruction = "replay_record_construction"
  | rphase clasetStep.RecordInsertion = "record_insertion"
fun rkind clasetStep.IntroRule = "intro" | rkind clasetStep.ElimRule = "elim"
fun opt NONE = "none" | opt (SOME n) = Int.toString n
fun stored NONE = "none,none,none,none,none,none,none,none"
  | stored (SOME ({script_position, step_kind, duplicate,
                    rule = {boundary, phase, goal_position, rule_kind,
                            assumption_position}} :
                   blastReconstruct.stored_rule_observation)) =
      String.concatWith ","
        [Int.toString script_position, step step_kind,
         Bool.toString duplicate, rboundary boundary, rphase phase,
         Int.toString goal_position, rkind rule_kind,
         opt assumption_position]

fun stat_fields (s : blastReconstruct.detailed_statistics) =
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

val started = Time.now ()
val budget = Time.fromSeconds (LargeInt.fromInt budget_seconds)
val stop_polls = ref 0
fun stop () =
  (stop_polls := !stop_polls + 1;
   Time.compare (Time.- (Time.now (), started), budget) <> LESS)
val attempts = ref 0
val sum_attempt = ref Time.zeroTime
val sum_classical = ref Time.zeroTime
val sum_alt = ref Time.zeroTime
val sum_replay = ref Time.zeroTime
val sum_other = ref Time.zeroTime
val sum_outer = ref Time.zeroTime
val sum_norm = ref Time.zeroTime
val sum_lookup = ref Time.zeroTime
val sum_structural = ref Time.zeroTime
val sum_decision = ref Time.zeroTime
val sum_binding = ref Time.zeroTime
val sum_traversal_other = ref Time.zeroTime
val sum_traversal = ref Time.zeroTime
val sum_cleanup = ref Time.zeroTime
val sum_minor = ref Time.zeroTime
val sum_minor_calls = ref 0
val sum_minor_failures = ref 0
val sum_norm_events = ref 0
val sum_lookup_events = ref 0
val sum_structural_events = ref 0
val sum_decision_events = ref 0
val sum_binding_events = ref 0
val sum_binding_failures = ref 0
val sum_traversal_other_events = ref 0
val max_norm = ref Time.zeroTime
val max_lookup = ref Time.zeroTime
val max_structural = ref Time.zeroTime
val max_decision = ref Time.zeroTime
val max_binding = ref Time.zeroTime
val max_traversal_other = ref Time.zeroTime
val max_traversal = ref Time.zeroTime
val max_cleanup = ref Time.zeroTime
val max_minor = ref Time.zeroTime
val sum_completed_pulls = ref 0
val sum_failed_pulls = ref 0
val sum_interrupted_pulls = ref 0
val sum_classical_snapshots = ref 0
val sum_statistics_reads = ref 0
val sum_completed_pull = ref Time.zeroTime
val sum_failed_pull = ref Time.zeroTime
val sum_interrupted_pull = ref Time.zeroTime
val sum_pull = ref Time.zeroTime
val sum_pull_residual = ref Time.zeroTime
val max_completed_pull = ref Time.zeroTime
val max_failed_pull = ref Time.zeroTime
val max_interrupted_pull = ref Time.zeroTime
val max_pull = ref Time.zeroTime
fun add reference value = reference := Time.+ (!reference, value)
fun add_int reference value = reference := !reference + value
fun raise_max reference value =
  if Time.< (!reference, value) then reference := value else ()

datatype accepted = Validated of blastSearch.proof | Stopped

fun accept proof =
  let
    val attempt = !attempts + 1
    val _ = attempts := attempt
    val outer_seen = ref 0
    val stored_seen = ref 0
    val stored_entries = ref 0
    val stored_exits = ref 0
    val last_stored =
      ref (NONE : blastReconstruct.stored_rule_observation option)
    fun observe_outer _ = outer_seen := !outer_seen + 1
    fun observe_stored
          (event as {rule = {boundary, ...}, ...} :
             blastReconstruct.stored_rule_observation) =
      (last_stored := SOME event; stored_seen := !stored_seen + 1;
       case boundary of
           clasetStep.RuleEnter => stored_entries := !stored_entries + 1
         | clasetStep.RuleExit => stored_exits := !stored_exits + 1)
    val report =
      blastReconstruct.reconstructWithMeasuredTimedDetailedV3
        {clock = Time.now, observe = SOME observe_outer,
         observe_stored_rule = SOME observe_stored, stop = stop}
        cs goal proof
    val v2 = #base report
    val base = #base v2
    val classical = #classical_times base
    val outer = #outer_reconstruction_times v2
    val minor = #minor_unification_times report
    val pulls = #alternative_pull_times report
    val _ =
      if !last_stored = #current_stored_rule base then ()
      else raise Fail "stored context mismatch"
    val _ = add sum_attempt (#attempt_wall_time base)
    val _ = add sum_classical (#classical_time classical)
    val _ = add sum_alt (#alternative_enumeration_time outer)
    val _ = add sum_replay (#replay_continuation_time outer)
    val _ = add sum_other (#other_outer_time outer)
    val _ = add sum_outer (#outer_reconstruction_time outer)
    val _ = add sum_norm (#normalization_setup_time minor)
    val _ = add sum_lookup (#persistent_store_lookup_walk_time minor)
    val _ = add sum_structural
      (#structural_decomposition_recursion_time minor)
    val _ = add sum_decision (#pattern_occurs_allow_decision_time minor)
    val _ = add sum_binding (#persistent_binding_update_time minor)
    val _ = add sum_traversal_other (#traversal_other_time minor)
    val _ = add sum_traversal (#traversal_decomposition_binding_time minor)
    val _ = add sum_cleanup (#failure_cleanup_time minor)
    val _ = add sum_minor (#minor_unification_time minor)
    val _ = add_int sum_minor_calls (#calls minor)
    val _ = add_int sum_minor_failures (#failures minor)
    val _ = add_int sum_norm_events (#normalization_setup_events minor)
    val _ = add_int sum_lookup_events
      (#persistent_store_lookup_walk_events minor)
    val _ = add_int sum_structural_events
      (#structural_decomposition_recursion_events minor)
    val _ = add_int sum_decision_events
      (#pattern_occurs_allow_decision_events minor)
    val _ = add_int sum_binding_events (#persistent_binding_update_events minor)
    val _ = add_int sum_binding_failures (#binding_operation_failures minor)
    val _ = add_int sum_traversal_other_events (#traversal_other_events minor)
    val _ = raise_max max_norm (#max_normalization_setup_time minor)
    val _ = raise_max max_lookup
      (#max_persistent_store_lookup_walk_time minor)
    val _ = raise_max max_structural
      (#max_structural_decomposition_recursion_time minor)
    val _ = raise_max max_decision
      (#max_pattern_occurs_allow_decision_time minor)
    val _ = raise_max max_binding (#max_persistent_binding_update_time minor)
    val _ = raise_max max_traversal_other (#max_traversal_other_time minor)
    val _ = raise_max max_traversal
      (#max_traversal_decomposition_binding_time minor)
    val _ = raise_max max_cleanup (#max_failure_cleanup_time minor)
    val _ = raise_max max_minor (#max_minor_unification_time minor)
    val _ = add_int sum_completed_pulls (#completed_pulls pulls)
    val _ = add_int sum_failed_pulls (#failed_pulls pulls)
    val _ = add_int sum_interrupted_pulls (#interrupted_pulls pulls)
    val _ = add_int sum_classical_snapshots
      (#classical_elapsed_snapshots pulls)
    val _ = add_int sum_statistics_reads (#sequence_statistics_reads pulls)
    val _ = add sum_completed_pull (#completed_pull_time pulls)
    val _ = add sum_failed_pull (#failed_pull_time pulls)
    val _ = add sum_interrupted_pull (#interrupted_pull_time pulls)
    val _ = add sum_pull (#alternative_pull_time pulls)
    val _ = add sum_pull_residual (#alternative_residual_time pulls)
    val _ = raise_max max_completed_pull (#max_completed_pull_time pulls)
    val _ = raise_max max_failed_pull (#max_failed_pull_time pulls)
    val _ = raise_max max_interrupted_pull (#max_interrupted_pull_time pulls)
    val _ = raise_max max_pull (#max_alternative_pull_time pulls)
    val classical_vector =
      [#attempt_selection_time classical, #freshening_setup_time classical,
       #minor_unification_time classical,
       #elimination_major_unification_time classical,
       #rule_instantiation_time classical,
       #child_store_construction_time classical,
       #direct_result_construction_time classical,
       #lazy_result_yield_time classical,
       #direct_child_replacement_time classical,
       #replay_record_construction_time classical,
       #record_insertion_time classical, #classical_time classical]
    val _ = emit
      ["ATTEMPT", Int.toString position, Int.toString number,
       Int.toString depth, Int.toString attempt,
       completion (#completion base), result (#result base),
       current (#current_phase base), stored (#current_stored_rule base),
       ints (stat_fields (#statistics base)), Int.toString (!outer_seen),
       Int.toString (!stored_seen), Int.toString (!stored_entries),
       Int.toString (!stored_exits), times classical_vector,
       Time.fmt 9 (#attempt_wall_time base),
       Time.fmt 9 (#alternative_enumeration_time outer),
       Time.fmt 9 (#replay_continuation_time outer),
       Time.fmt 9 (#other_outer_time outer),
       Time.fmt 9 (#outer_reconstruction_time outer),
       Int.toString (#calls minor), Int.toString (#failures minor),
       Int.toString (#normalization_setup_events minor),
       Int.toString (#persistent_store_lookup_walk_events minor),
       Int.toString (#structural_decomposition_recursion_events minor),
       Int.toString (#pattern_occurs_allow_decision_events minor),
       Int.toString (#persistent_binding_update_events minor),
       Int.toString (#binding_operation_failures minor),
       Int.toString (#traversal_other_events minor),
       Time.fmt 9 (#normalization_setup_time minor),
       Time.fmt 9 (#persistent_store_lookup_walk_time minor),
       Time.fmt 9 (#structural_decomposition_recursion_time minor),
       Time.fmt 9 (#pattern_occurs_allow_decision_time minor),
       Time.fmt 9 (#persistent_binding_update_time minor),
       Time.fmt 9 (#traversal_other_time minor),
       Time.fmt 9 (#traversal_decomposition_binding_time minor),
       Time.fmt 9 (#failure_cleanup_time minor),
       Time.fmt 9 (#minor_unification_time minor),
       Time.fmt 9 (#max_normalization_setup_time minor),
       Time.fmt 9 (#max_persistent_store_lookup_walk_time minor),
       Time.fmt 9 (#max_structural_decomposition_recursion_time minor),
       Time.fmt 9 (#max_pattern_occurs_allow_decision_time minor),
       Time.fmt 9 (#max_persistent_binding_update_time minor),
       Time.fmt 9 (#max_traversal_other_time minor),
       Time.fmt 9 (#max_traversal_decomposition_binding_time minor),
       Time.fmt 9 (#max_failure_cleanup_time minor),
       Time.fmt 9 (#max_minor_unification_time minor),
       Int.toString (#completed_pulls pulls),
       Int.toString (#failed_pulls pulls),
       Int.toString (#interrupted_pulls pulls),
       Int.toString (#classical_elapsed_snapshots pulls),
       Int.toString (#sequence_statistics_reads pulls),
       Time.fmt 9 (#completed_pull_time pulls),
       Time.fmt 9 (#failed_pull_time pulls),
       Time.fmt 9 (#interrupted_pull_time pulls),
       Time.fmt 9 (#alternative_pull_time pulls),
       Time.fmt 9 (#alternative_residual_time pulls),
       Time.fmt 9 (#max_completed_pull_time pulls),
       Time.fmt 9 (#max_failed_pull_time pulls),
       Time.fmt 9 (#max_interrupted_pull_time pulls),
       Time.fmt 9 (#max_alternative_pull_time pulls),
       Time.fmt 9
         (Time.- (#attempt_wall_time base,
           Time.+ (#classical_time classical,
                   #outer_reconstruction_time outer)))]
  in
    case (#completion base, #result base) of
        (blastReconstruct.Interrupted, _) => Stopped
      | (blastReconstruct.Completed, SOME ([], validation)) =>
          (ignore (validation []); Validated proof)
      | (blastReconstruct.Completed, _) => raise blastSearch.PROOF_FAILED
  end

val search =
  blastSearch.searchGoalMeasured {debug = false, stop = stop}
    cs depth goal accept
val elapsed = Time.- (Time.now (), started)
val search_stats = #statistics search
val outcome =
  case (#completion search, #result search) of
      (blastSearch.Interrupted, _) => "search_interrupted"
    | (blastSearch.Completed, SOME Stopped) => "reconstruction_interrupted"
    | (blastSearch.Completed, SOME (Validated _)) => "validated"
    | (blastSearch.Completed, NONE) => "exhausted"
val _ = print (String.concatWith "|"
  ["SUMMARY", Int.toString position, Int.toString number,
   Int.toString depth, outcome, Time.fmt 9 elapsed,
   Int.toString (!attempts), Int.toString (!stop_polls),
   ints [#cooperative_checkpoints search_stats,
         #inferences_performed search_stats,
         #branches_created search_stats, #branches_closed search_stats,
         #choices_pruned search_stats, #maximum_resource_cost search_stats,
         #rule_cache_hits search_stats, #rule_conversions search_stats],
   String.concatWith ","
     (map Int.toString
       [!sum_minor_calls, !sum_minor_failures, !sum_norm_events,
        !sum_lookup_events, !sum_structural_events, !sum_decision_events,
        !sum_binding_events, !sum_binding_failures,
        !sum_traversal_other_events] @
      map (Time.fmt 9)
       [!sum_attempt, !sum_classical, !sum_alt, !sum_replay,
        !sum_other, !sum_outer, !sum_norm, !sum_lookup, !sum_structural,
        !sum_decision, !sum_binding, !sum_traversal_other, !sum_traversal,
        !sum_cleanup, !sum_minor, !max_norm, !max_lookup, !max_structural,
        !max_decision, !max_binding, !max_traversal_other, !max_traversal,
        !max_cleanup, !max_minor] @
      map Int.toString
       [!sum_completed_pulls, !sum_failed_pulls, !sum_interrupted_pulls,
        !sum_classical_snapshots, !sum_statistics_reads] @
      map (Time.fmt 9)
       [!sum_completed_pull, !sum_failed_pull, !sum_interrupted_pull,
        !sum_pull, !sum_pull_residual, !max_completed_pull,
        !max_failed_pull, !max_interrupted_pull, !max_pull,
        Time.- (elapsed, !sum_attempt)])] ^ "\n")
