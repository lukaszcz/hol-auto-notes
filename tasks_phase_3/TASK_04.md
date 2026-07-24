# TASK_04 — `tableauLib.CS_BLAST_DEPTH_TAC` (D33/D36)

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

Plan task 04 (`PLAN_phase_3.md` §3.3): export a raw claset-explicit
fixed-depth tableau entry for `AUTO_TAC`'s blast leg (the analogue of
`Blast.depth_tac ctxt m` as used by `mk_auto_tac`,
`clasimp.ML:152`).

## Spec

Read first: `PLAN_phase_3.md` §3.3, §0.1 (D33, D36, D39), §0.2 item 4;
`tableauLib.sml:110–183` (`run_depths` and the private
`blast_depth_tac`).

1. Export:

       val CS_BLAST_DEPTH_TAC : clasetLib.claset -> int -> tactic

2. Single tableau search at exactly the given resource bound:
   literally `run_depths cs (SOME depth) (fn _ => NONE)` — no
   `DEEPEN`, no `depth_limit` consultation (F3's negative-limit
   semantics do not apply), no marker processing, no `ABBRS_THEN`, no
   insertion (the caller supplies a finished claset and has already
   inserted its facts).  No new twins (D39): reuse `run_depths`.
3. Untranslatable goals and search failure = ordinary tactic failure.
   Reconstruction and PROOF-FAILED backtracking behave as in
   `BLAST_TAC`.
4. The delivered module-private `blast_depth_tac : int -> thm list ->
   tactic` (`tableauLib.sml:183`) is the theorem-list entry behind
   `BLAST_DEPTH_TAC` and is unrelated; retain both, private one keeps
   its name.
5. Selftests (`src/auto/blast/selftest.sml`, per §10.7): a bound test
   — a goal solvable at depth `n` succeeds at `n` and fails at a
   smaller bound; an untranslatable-goal ordinary-failure test; a
   check that no marker/insertion preprocessing happens (e.g. a
   marker-wrapped list element is not interpreted).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on `src/auto/blast/`.
4. Public `BLAST_TAC`/`BLAST_DEPTH_TAC` packaging unchanged.

## Dependencies

TASK_03 (both edit `tableauLib`; serialize).
