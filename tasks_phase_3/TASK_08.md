# TASK_08 — `FASTFORCE`/`SLOWSIMP`/`BESTSIMP`/`CLARSIMP` tactics

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

Plan task 08 (`PLAN_phase_3.md` §7.3, §7.4): implement
`FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`, `CLARSIMP_TAC` and
their `CS_*` context-explicit forms, with selftests.

## Spec

Read first: `PLAN_phase_3.md` §7 (preamble), §7.3, §7.4, §0.1
(D34, D36); `classicalLib.sig:22–37`; `clasimp.ML:119–121,178–180`.

1. `CS_*` forms, all `clasetLib.claset -> simpLib.simpset -> tactic`
   (deterministic tactics, not `ntactic`s), with
   `cs' = add_simp_wrapper ss cs`:
   - `CS_FASTFORCE_TAC cs ss = must_close (DETERM (CS_FAST_TAC cs'))`
   - `CS_SLOWSIMP_TAC  cs ss = must_close (DETERM (CS_SLOW_TAC cs'))`
   - `CS_BESTSIMP_TAC  cs ss = must_close (DETERM (CS_BEST_TAC cs'))`
   where `must_close t` fails unless `t` leaves no subgoals (a
   documented guard, not new search semantics).
   - `CS_CLARSIMP_TAC cs ss` = `safe_asm_full_simp ss` THEN (on every
     resulting subgoal) `DETERM (CS_CLARIFY_TAC (add_safe_simp_wrapper
     ss cs))`; overall fail iff nothing changed (D27 change-or-fail =
     Isabelle's `CHANGED_PROP oo clarsimp_tac`).
2. Uppercase `thm list -> tactic` forms (`FASTFORCE_TAC` etc.) read
   `the_claset()` and `clasimp_ss()` at application time and run the
   TASK_07 argument processor (ABBRS_THEN, partition, insertion before
   step 1 of each script).
3. Selftests (§10.3): per-tactic goal batteries translated from the
   Isabelle regression corpus (`fastforce`, `clarsimp` examples) plus
   HOL4-native set/list/option goals; FORCE-family must-close negative
   tests (asserted as failures, exact residues asserted for
   `CLARSIMP_TAC` non-closing cases); `CLARSIMP_TAC` change-or-fail
   tests; a splitter-in-simpset case where clarsimp still splits the
   subgoal (the `Generic.thy:1624–1626` caveat).  Successes through
   `Tactical.VALID`; no goal closed by recognition; no state left
   behind (per `src/auto/CLAUDE.md`).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on `src/auto/clasimp/`.
4. Failure semantics exactly as specified: must-close for the FORCE
   family, change-or-fail for `CLARSIMP_TAC`.

## Dependencies

TASK_07.
