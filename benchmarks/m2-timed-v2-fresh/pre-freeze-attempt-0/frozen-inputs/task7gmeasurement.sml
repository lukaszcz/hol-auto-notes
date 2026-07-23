(* Task 7g authoritative timed-v2 target harness. *)
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

val position = integer "T7G_POSITION"
val number = integer "T7G_PROBLEM"
val depth = integer "T7G_DEPTH"
val budget_seconds = integer "T7G_BUDGET_SECONDS"
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
val sum_traversal = ref Time.zeroTime
val sum_cleanup = ref Time.zeroTime
val sum_minor = ref Time.zeroTime
fun add reference value = reference := Time.+ (!reference, value)

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
      blastReconstruct.reconstructWithMeasuredTimedDetailedV2
        {clock = Time.now, observe = SOME observe_outer,
         observe_stored_rule = SOME observe_stored, stop = stop}
        cs goal proof
    val base = #base report
    val classical = #classical_times base
    val outer = #outer_reconstruction_times report
    val minor = #minor_unification_times report
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
    val _ = add sum_traversal (#traversal_decomposition_binding_time minor)
    val _ = add sum_cleanup (#failure_cleanup_time minor)
    val _ = add sum_minor (#minor_unification_time minor)
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
       Time.fmt 9 (#normalization_setup_time minor),
       Time.fmt 9 (#traversal_decomposition_binding_time minor),
       Time.fmt 9 (#failure_cleanup_time minor),
       Time.fmt 9 (#minor_unification_time minor),
       Time.fmt 9 (#max_normalization_setup_time minor),
       Time.fmt 9 (#max_traversal_decomposition_binding_time minor),
       Time.fmt 9 (#max_failure_cleanup_time minor),
       Time.fmt 9 (#max_minor_unification_time minor),
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
   times [!sum_attempt, !sum_classical, !sum_alt, !sum_replay,
          !sum_other, !sum_outer, !sum_norm, !sum_traversal,
          !sum_cleanup, !sum_minor,
          Time.- (elapsed, !sum_attempt)]] ^ "\n")
