(* Fixed-depth M1 benchmark for the six open Pelletier formulae.
 *
 * This source is copied temporarily to src/auto/blast/ in each isolated
 * revision and compiled there.  It deliberately uses the public fixed-depth
 * search and reconstruction APIs, so one measured invocation performs the
 * same work as BLAST_DEPTH_TAC at the asserted depth and reports the complete
 * common search counters available in both revisions.
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

val revision = required_env "M1_REVISION"
val repetition = int_arg "repetition" (required_env "M1_REPETITION")
val position = int_arg "position" (required_env "M1_POSITION")
val number = int_arg "problem" (required_env "M1_PROBLEM")
val depth = int_arg "depth" (required_env "M1_DEPTH")
val batch = int_arg "batch" (required_env "M1_BATCH")

val _ = if batch > 0 then () else raise Fail "batch must be positive"

val proposition = find_problem number
val goal = ([], proposition)

fun run_once () =
  let
    val cs = invocation_claset ()
    val report =
      blastSearch.searchGoalWithStats cs depth goal (accept cs goal)
    val statistics = #statistics report
  in
    (Option.isSome (#result report),
     #branches_created statistics,
     #branches_closed statistics,
     #choices_pruned statistics)
  end

val started = Time.now ()
val first as (proved, created, closed, pruned) = run_once ()

fun repeat 1 = ()
  | repeat remaining =
      if run_once () = first then repeat (remaining - 1)
      else raise Fail "fixed-depth outcome or counters changed within batch"

val _ = repeat batch
val elapsed = Time.- (Time.now (), started)
val outcome = if proved then "proved" else "exhausted"

val _ =
  print
    (String.concatWith "\t"
       [revision, Int.toString repetition, Int.toString position,
        Int.toString number, Int.toString depth, Int.toString batch,
        outcome, Time.fmt 6 elapsed,
        Int.toString (batch * created), Int.toString (batch * closed),
        Int.toString (batch * pruned), Int.toString created,
        Int.toString closed, Int.toString pruned] ^ "\n")
