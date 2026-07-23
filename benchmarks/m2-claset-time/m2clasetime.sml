(* Final-source timed classical phase diagnosis for P34, P41 and P45.
 *
 * One invocation runs one fixed-depth problem in a fresh process.  Search
 * and every reconstruction attempt share one 30-second cooperative
 * deadline; the shell adds an independent 60-second process watchdog.
 *)

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

fun find_problem number =
  case List.find (fn (candidate, _) => candidate = number) problems of
      SOME (_, proposition) => proposition
    | NONE => raise Fail ("unknown problem " ^ Int.toString number)

fun blast_claset () =
  clasetLib.add_selims
    [("blast_not_imp", clasetSeedTheory.NOT_IMP_CELIM_THM),
     ("blast_not_forall", clasetSeedTheory.NOT_FORALL_CELIM_THM)]
    (clasetLib.the_claset ())

fun invocation_claset () =
  clasetLib.invocation_claset {prefix = "__blast_extra_"}
    (blast_claset ()) []

fun required_env name =
  case OS.Process.getEnv name of
      SOME value => value
    | NONE => raise Fail ("missing environment variable " ^ name)

fun int_arg label value =
  case Int.fromString value of
      SOME result => result
    | NONE => raise Fail ("invalid " ^ label ^ ": " ^ value)

fun bool_arg label "true" = true
  | bool_arg label "false" = false
  | bool_arg label value =
      raise Fail ("invalid " ^ label ^ ": " ^ value)

val run = int_arg "run" (required_env "M2T_RUN")
val position = int_arg "position" (required_env "M2T_POSITION")
val number = int_arg "problem" (required_env "M2T_PROBLEM")
val depth = int_arg "depth" (required_env "M2T_DEPTH")
val debug = bool_arg "debug" (required_env "M2T_DEBUG")
val budget_seconds =
  int_arg "budget" (required_env "M2T_BUDGET_SECONDS")
val _ = if budget_seconds = 30 then () else raise Fail "budget must be 30"

fun marker fields =
  (TextIO.output
     (TextIO.stdErr,
      String.concatWith "|" (Int.toString number :: fields) ^ "\n");
   TextIO.flushOut TextIO.stdErr)

fun step_name blastReconstruct.HypSubstStep = "hyp_subst"
  | step_name blastReconstruct.CloseAssumeStep = "close_assume"
  | step_name blastReconstruct.CloseContradictionStep =
      "close_contradiction"
  | step_name blastReconstruct.SafeRuleStep = "safe_rule"
  | step_name blastReconstruct.DeferGoalStep = "defer_goal"
  | step_name blastReconstruct.UnsafeRuleStep = "unsafe_rule"

fun phase_name blastReconstruct.ReplayRecursion = "replay_recursion"
  | phase_name blastReconstruct.AlternativeEnumeration =
      "alternative_enumeration"
  | phase_name (blastReconstruct.TypedStep kind) =
      "typed_" ^ step_name kind
  | phase_name blastReconstruct.StoredRuleSetup = "stored_rule_setup"
  | phase_name blastReconstruct.StoredRuleTransition =
      "stored_rule_transition"
  | phase_name blastReconstruct.DuplicateChildMove =
      "duplicate_child_move"
  | phase_name blastReconstruct.FinishOpenGoals = "finish_open_goals"
  | phase_name blastReconstruct.GroundReplay = "ground_replay"
  | phase_name blastReconstruct.KernelReplay = "kernel_replay"
  | phase_name blastReconstruct.FinishResidualGoals =
      "finish_residual_goals"

fun boundary_name blastReconstruct.Enter = "enter"
  | boundary_name blastReconstruct.Exit = "exit"

fun rule_phase_name clasetStep.AttemptSelection = "attempt_selection"
  | rule_phase_name clasetStep.FresheningSetup = "freshening_setup"
  | rule_phase_name clasetStep.MinorUnification = "minor_unification"
  | rule_phase_name clasetStep.EliminationMajorUnification =
      "major_unification"
  | rule_phase_name clasetStep.RuleInstantiation = "rule_instantiation"
  | rule_phase_name clasetStep.ChildStoreConstruction =
      "child_store_construction"
  | rule_phase_name clasetStep.DirectResultConstruction =
      "direct_result_construction"
  | rule_phase_name clasetStep.LazyResultYield = "lazy_result_yield"
  | rule_phase_name clasetStep.DirectChildReplacement =
      "direct_child_replacement"
  | rule_phase_name clasetStep.ReplayRecordConstruction =
      "replay_record_construction"
  | rule_phase_name clasetStep.RecordInsertion = "record_insertion"

fun rule_boundary_name clasetStep.RuleEnter = "enter"
  | rule_boundary_name clasetStep.RuleExit = "exit"

fun rule_kind_name clasetStep.IntroRule = "intro"
  | rule_kind_name clasetStep.ElimRule = "elim"

fun option_int NONE = "none"
  | option_int (SOME value) = Int.toString value

fun current_name NONE = ("none", "none")
  | current_name
      (SOME ({boundary, phase} : blastReconstruct.observation)) =
      (boundary_name boundary, phase_name phase)

fun stored_name NONE =
      ["none", "none", "none", "none", "none", "none", "none",
       "none"]
  | stored_name
      (SOME
        ({script_position, step_kind, duplicate,
          rule =
            {boundary, phase, goal_position, rule_kind,
             assumption_position}} :
          blastReconstruct.stored_rule_observation)) =
      [Int.toString script_position, step_name step_kind,
       Bool.toString duplicate, rule_boundary_name boundary,
       rule_phase_name phase, Int.toString goal_position,
       rule_kind_name rule_kind, option_int assumption_position]

fun completion_name blastReconstruct.Completed = "completed"
  | completion_name blastReconstruct.Interrupted = "interrupted"

fun result_name NONE = "none"
  | result_name (SOME _) = "proof"

fun statistics_fields
      (statistics : blastReconstruct.detailed_statistics) =
  map Int.toString
    [#cooperative_checkpoints statistics,
     #phase_entries statistics,
     #phase_exits statistics,
     #replay_recursions statistics,
     #alternative_pulls statistics,
     #typed_steps statistics,
     #hyp_subst_steps statistics,
     #close_assume_steps statistics,
     #close_contradiction_steps statistics,
     #safe_rule_steps statistics,
     #defer_goal_steps statistics,
     #unsafe_rule_steps statistics,
     #stored_rule_setups statistics,
     #stored_rule_transitions statistics,
     #duplicate_child_moves statistics,
     #finish_open_goal_checks statistics,
     #grounding_attempts statistics,
     #kernel_replay_attempts statistics,
     #finish_residual_goal_checks statistics,
     #stored_rule_checkpoints statistics,
     #stored_rule_phase_entries statistics,
     #stored_rule_phase_exits statistics,
     #stored_rule_attempt_selections statistics,
     #stored_rule_freshening_setups statistics,
     #stored_rule_minor_unifications statistics,
     #stored_rule_major_unifications statistics,
     #stored_rule_instantiations statistics,
     #stored_rule_child_store_constructions statistics,
     #stored_rule_direct_result_constructions statistics,
     #stored_rule_lazy_yields statistics,
     #stored_rule_direct_child_replacements statistics,
     #stored_rule_replay_record_constructions statistics,
     #stored_rule_record_insertions statistics,
     #stored_rule_intro_attempts statistics,
     #stored_rule_elim_attempts statistics,
     #stored_rule_safe_attempts statistics,
     #stored_rule_unsafe_attempts statistics]

val proposition = find_problem number
val goal = ([], proposition)
val cs = invocation_claset ()
val budget = Time.fromSeconds (LargeInt.fromInt budget_seconds)
val started = Time.now ()
val stop_polls = ref 0
val attempts = ref 0
val reconstruction_wall = ref Time.zeroTime
val classical_wall = ref Time.zeroTime

fun stop () =
  (stop_polls := !stop_polls + 1;
   Time.compare (Time.- (Time.now (), started), budget) <> LESS)

datatype accepted =
    Validated of blastSearch.proof
  | ReconstructionStopped of
      int * blastReconstruct.timed_detailed_measured_result

fun add_time reference elapsed =
  reference := Time.+ (!reference, elapsed)

fun timing_fields
      (report : blastReconstruct.timed_detailed_measured_result) =
  let
    val times = #classical_times report
  in
    map (Time.fmt 9)
      [#attempt_selection_time times,
       #freshening_setup_time times,
       #minor_unification_time times,
       #elimination_major_unification_time times,
       #rule_instantiation_time times,
       #child_store_construction_time times,
       #direct_result_construction_time times,
       #lazy_result_yield_time times,
       #direct_child_replacement_time times,
       #replay_record_construction_time times,
       #record_insertion_time times,
       #classical_time times,
       #attempt_wall_time report]
  end

fun accept proof =
  let
    val attempt = !attempts + 1
    val _ = attempts := attempt
    val _ = marker ["attempt_enter", Int.toString attempt]
    val outer_observed = ref 0
    val stored_observed = ref 0
    val stored_entries = ref 0
    val stored_exits = ref 0
    val last_stored =
      ref (NONE : blastReconstruct.stored_rule_observation option)
    fun observe_outer (_ : blastReconstruct.observation) =
      outer_observed := !outer_observed + 1
    fun observe_stored
          (event as {rule = {boundary, ...}, ...} :
            blastReconstruct.stored_rule_observation) =
      (last_stored := SOME event;
       stored_observed := !stored_observed + 1;
       case boundary of
           clasetStep.RuleEnter => stored_entries := !stored_entries + 1
         | clasetStep.RuleExit => stored_exits := !stored_exits + 1)
    val report =
      blastReconstruct.reconstructWithMeasuredTimedDetailed
        {clock = Time.now, observe = SOME observe_outer,
         observe_stored_rule = SOME observe_stored,
         stop = stop} cs goal proof
    val statistics = #statistics report
    val _ = add_time reconstruction_wall (#attempt_wall_time report)
    val _ =
      add_time classical_wall
        (#classical_time (#classical_times report))
    val (boundary, phase) = current_name (#current_phase report)
    val _ =
      if !last_stored = #current_stored_rule report then ()
      else raise Fail "stored observer and report snapshots differ"
    val _ =
      marker
        (["attempt_result", Int.toString attempt,
          completion_name (#completion report),
          result_name (#result report), boundary, phase] @
         stored_name (#current_stored_rule report) @
         map Int.toString
           [!outer_observed, !stored_observed,
            !stored_entries, !stored_exits] @
         statistics_fields statistics @ timing_fields report)
  in
    case (#completion report, #result report) of
        (blastReconstruct.Interrupted, _) =>
          ReconstructionStopped (attempt, report)
      | (blastReconstruct.Completed, SOME ([], validation)) =>
          (marker ["validation_enter", Int.toString attempt];
           ignore (validation []);
           marker ["validation_exit", Int.toString attempt];
           Validated proof)
      | (blastReconstruct.Completed, _) =>
          raise blastSearch.PROOF_FAILED
  end

val search_report =
  blastSearch.searchGoalMeasured {debug = debug, stop = stop}
    cs depth goal accept
val elapsed = Time.- (Time.now (), started)
val search_statistics = #statistics search_report

val outcome =
  case (#completion search_report, #result search_report) of
      (blastSearch.Interrupted, _) => "search_interrupted"
    | (blastSearch.Completed, SOME (ReconstructionStopped _)) =>
        "reconstruction_interrupted"
    | (blastSearch.Completed, SOME (Validated _)) => "validated"
    | (blastSearch.Completed, NONE) => "exhausted"

val _ =
  print
    (String.concatWith "|"
       [Int.toString run, Int.toString position, Int.toString number,
        Int.toString depth, Bool.toString debug,
        Int.toString budget_seconds, outcome, Time.fmt 6 elapsed,
        Int.toString (!attempts), Int.toString (!stop_polls),
        Int.toString (#cooperative_checkpoints search_statistics),
        Int.toString (#inferences_performed search_statistics),
        Int.toString (#branches_created search_statistics),
        Int.toString (#branches_closed search_statistics),
        Int.toString (#choices_pruned search_statistics),
        Int.toString (#maximum_resource_cost search_statistics),
        Int.toString (#rule_cache_hits search_statistics),
        Int.toString (#rule_conversions search_statistics),
        Time.fmt 9 (!reconstruction_wall),
        Time.fmt 9 (!classical_wall)] ^ "\n")
