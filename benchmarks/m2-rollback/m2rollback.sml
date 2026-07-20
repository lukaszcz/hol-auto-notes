(* Phase-local fixed-depth diagnosis for the six open Pelletier problems.
 *
 * One invocation measures one problem in a fresh process.  The internal
 * cooperative deadline remains 30 seconds; the shell watchdog is only a
 * safety net.  Debug traces are summarized, never printed.
 *)

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
   (41, “(!z:'a. ?y. !x. f x y <=> (f x z /\ ~f x x)) ==>
          ~(?z. !x. f x z)”),
   (42, “~(?y:'a. !x. p x y <=> ~(?z. p x z /\ p z x))”),
   (43, “(!x:'a y. q x y <=> (!z. p z x <=> p z y)) ==>
          (!x y. q x y <=> q y x)”),
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

fun accept cs goal proof =
  case blastReconstruct.reconstructWith cs goal proof of
      SOME ([], validation) => (ignore (validation []); proof)
    | SOME _ => raise blastSearch.PROOF_FAILED
    | NONE => raise blastSearch.PROOF_FAILED

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

fun max_int values = List.foldl Int.max 0 values

fun pair_slots (safe, unsafe) = length safe + length unsafe

fun branch_slots ({pairs, lits, ...} : blastSearch.branch) =
  length lits + List.foldl (fn (pair, total) => pair_slots pair + total) 0
    pairs

fun trace_summary full_trace =
  let
    val live_branches = map length full_trace
    val state_slots =
      map
        (fn branches =>
          List.foldl
            (fn (branch, total) => branch_slots branch + total) 0 branches)
        full_trace
  in
    (length full_trace, max_int live_branches, max_int state_slots)
  end

val run = int_arg "run" (required_env "M2P_RUN")
val position = int_arg "position" (required_env "M2P_POSITION")
val number = int_arg "problem" (required_env "M2P_PROBLEM")
val depth = int_arg "depth" (required_env "M2P_DEPTH")
val debug = bool_arg "debug" (required_env "M2P_DEBUG")
val budget_seconds = int_arg "budget" (required_env "M2P_BUDGET_SECONDS")
val _ = if budget_seconds = 30 then () else raise Fail "budget must be 30"

val proposition = find_problem number
val goal = ([], proposition)
val cs = invocation_claset ()
val budget = Time.fromSeconds (LargeInt.fromInt budget_seconds)
val started = Time.now ()
val stop_polls = ref 0

fun stop () =
  (stop_polls := !stop_polls + 1;
   Time.compare (Time.- (Time.now (), started), budget) <> LESS)

val report =
  blastSearch.searchGoalMeasured {debug = debug, stop = stop}
    cs depth goal (accept cs goal)
val elapsed = Time.- (Time.now (), started)
val statistics = #statistics report
val completion =
  case #completion report of
      blastSearch.Completed => "completed"
    | blastSearch.Interrupted => "interrupted"
val search_result =
  if Option.isSome (#result report) then "proof" else "none"
val (trace_states, maximum_live_branches, maximum_state_slots) =
  trace_summary (#fullTrace report)

val _ =
  print
    (String.concatWith "\t"
       [Int.toString run, Int.toString position, Int.toString number,
        Int.toString depth, Bool.toString debug,
        Int.toString budget_seconds, completion, search_result,
        Time.fmt 6 elapsed,
        Int.toString (#configured_depth statistics),
        Int.toString (#maximum_resource_cost statistics),
        Int.toString (#inferences_performed statistics),
        Int.toString (#branches_created statistics),
        Int.toString (#branches_closed statistics),
        Int.toString (#choices_pruned statistics),
        Int.toString (#rule_cache_hits statistics),
        Int.toString (#rule_conversions statistics),
        Int.toString (!stop_polls),
        Int.toString (#cooperative_checkpoints statistics),
        Int.toString (#candidate_rules_enumerated statistics),
        Int.toString (#candidate_conversions_attempted statistics),
        Int.toString (#safe_rule_attempts statistics),
        Int.toString (#unsafe_rule_attempts statistics),
        Int.toString (#rule_unification_attempts statistics),
        Int.toString (#rule_unification_successes statistics),
        Int.toString (#equality_substitution_attempts statistics),
        Int.toString (#equality_substitution_successes statistics),
        Int.toString (#literal_close_attempts statistics),
        Int.toString (#literal_close_successes statistics),
        Int.toString trace_states,
        Int.toString maximum_live_branches,
        Int.toString maximum_state_slots] ^ "\n")
