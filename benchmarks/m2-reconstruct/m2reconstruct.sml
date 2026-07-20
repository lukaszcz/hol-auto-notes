(* Final-source reconstruction-local diagnosis for P34, P41 and P45.
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

val run = int_arg "run" (required_env "M2R_RUN")
val position = int_arg "position" (required_env "M2R_POSITION")
val number = int_arg "problem" (required_env "M2R_PROBLEM")
val depth = int_arg "depth" (required_env "M2R_DEPTH")
val debug = bool_arg "debug" (required_env "M2R_DEBUG")
val budget_seconds =
  int_arg "budget" (required_env "M2R_BUDGET_SECONDS")
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

fun current_name NONE = ("none", "none")
  | current_name
      (SOME ({boundary, phase} : blastReconstruct.observation)) =
      (boundary_name boundary, phase_name phase)

fun completion_name blastReconstruct.Completed = "completed"
  | completion_name blastReconstruct.Interrupted = "interrupted"

fun result_name NONE = "none"
  | result_name (SOME _) = "proof"

fun statistics_fields
      (statistics : blastReconstruct.statistics) =
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
     #finish_residual_goal_checks statistics]

val proposition = find_problem number
val goal = ([], proposition)
val cs = invocation_claset ()
val budget = Time.fromSeconds (LargeInt.fromInt budget_seconds)
val started = Time.now ()
val stop_polls = ref 0
val attempts = ref 0

fun stop () =
  (stop_polls := !stop_polls + 1;
   Time.compare (Time.- (Time.now (), started), budget) <> LESS)

datatype accepted =
    Validated of blastSearch.proof
  | ReconstructionStopped of
      int * blastReconstruct.measured_result

fun accept proof =
  let
    val attempt = !attempts + 1
    val _ = attempts := attempt
    val _ = marker ["attempt_enter", Int.toString attempt]
    fun observe ({boundary, phase} : blastReconstruct.observation) =
      marker
        ["boundary", Int.toString attempt, boundary_name boundary,
         phase_name phase]
    val report =
      blastReconstruct.reconstructWithMeasured
        {observe = SOME observe, stop = stop} cs goal proof
    val statistics = #statistics report
    val (boundary, phase) = current_name (#current_phase report)
    val _ =
      marker
        (["attempt_result", Int.toString attempt,
          completion_name (#completion report),
          result_name (#result report), boundary, phase] @
         statistics_fields statistics)
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
        Int.toString (#branches_closed search_statistics)] ^ "\n")
