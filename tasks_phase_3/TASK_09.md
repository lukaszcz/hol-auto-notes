# TASK_09 — `AUTO_TAC`/`AUTO_DEPTH_TAC`/`FORCE_TAC`

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phase 3
(`.agent-files/PLAN_phase_3.md`) ports Isabelle's clasimp layer
(`Provers/clasimp.ML`) into `src/auto/clasimp/` on top of the delivered
classical stack (`src/auto/rules`, `src/auto/classical`,
`src/auto/blast`) and the Phase-S simplifier: the clasimpset,
simp-wrapper combinators, `AUTO_TAC`/`FORCE_TAC`/`FASTFORCE_TAC`/
`SLOWSIMP_TAC`/`BESTSIMP_TAC`/`CLARSIMP_TAC` with context-explicit
`CS_*` forms, the `[iff]` attribute, `Simp`/`Iff` markers, and the
layer-wide plain-theorem insertion convention (D30).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan task 09 (`PLAN_phase_3.md` §7.1, §7.2): implement `AUTO_TAC`
(port of `mk_auto_tac`, `clasimp.ML:147–161`), `AUTO_DEPTH_TAC`,
`FORCE_TAC` (port of `force_tac`, `clasimp.ML:167–173`) and their
`CS_*` forms, with selftests.

## Spec

Read first: `PLAN_phase_3.md` §7.1, §7.2, §1.1 items 1 and 3, §0.1
(D34, D36); the delivered TASK_02/04 exports (`CS_DEPTH_SOLVE_TAC`,
`CS_BLAST_DEPTH_TAC`).

1. `CS_AUTO_TAC : {blast : int, depth : int} -> clasetLib.claset ->
   simpLib.simpset -> tactic`.  For a single goal, with
   `cs' = add_simp_wrapper ss cs`:

       1  asm_full_simp ss                     (* may be a no-op *)
       2  THEN TRY (DETERM (CS_SAFE_TAC cs))
       3  THEN (on every remaining subgoal)
            TRY (CS_BLAST_DEPTH_TAC cs m
                 ORELSE DETERM (CS_DEPTH_SOLVE_TAC {dup=false} n cs'))
       4  THEN TRY (DETERM (CS_SAFE_TAC (add_safe_simp_wrapper ss cs)))
       overall: fail iff nothing changed (D27 / CHANGED_PROP).

   Record the one-`TRY`-per-subgoal equivalence argument (Isabelle's
   `REPEAT_DETERM (FIRSTGOAL …)` loop only re-tries goals whose
   schematic variables were instantiated by solving other goals; HOL4
   kernel subgoals cannot share metavariables) as a source comment.
   Isabelle's step 5 `prune_params_tac` is vacuous in HOL4 — dropped.
2. `AUTO_DEPTH_TAC {blast : int, depth : int} : thm list -> tactic`
   exposes the bounds; `AUTO_TAC = AUTO_DEPTH_TAC {blast = 4,
   depth = 2}` (Isabelle defaults).
3. `CS_FORCE_TAC cs ss`, with `cs' = add_simp_wrapper ss cs`:

       DETERM (CS_CLARIFY_TAC cs')  (* simp wrapper inert here *)
       THEN asm_full_simp ss
       THEN on every remaining subgoal: DETERM (CS_FIRST_BEST_TAC cs')
       overall: fail unless zero subgoals remain.

   The wrapper inertness under clarify (§1.1.1) is deliberate — port
   literally, document in a source comment.
4. Uppercase forms read `the_claset()`/`clasimp_ss()` and run the
   argument processor with insertion before step 1.
5. Selftests (§10.3, §10.4): Isabelle regression corpus translations
   for `auto`/`force` plus HOL4-native goals; `AUTO_TAC`
   change-or-fail and `FORCE_TAC` must-close negatives; AUTO
   idempotence — `AUTO_TAC` residue re-run is a no-op on a corpus
   without blast instantiations; a goal exercising the clasimpset
   splitter (auto splits `if`/`case` where `SIMP_TAC (srw_ss())` does
   not).  `Tactical.VALID`, exact residues for non-closing cases, no
   recognition, no state left behind.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on `src/auto/clasimp/`.
4. `AUTO_TAC` defaults are `{blast = 4, depth = 2}`; both equivalence
   and inertness comments present in the source.

## Dependencies

TASK_04 (`CS_BLAST_DEPTH_TAC`), TASK_07 (wrappers + processor;
`CS_DEPTH_SOLVE_TAC` arrives via TASK_02, an ancestor).
