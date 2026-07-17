# TASK_14 — `classicalLib` slice 2: the D26 driver surface

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phases
1–2 (`.agent-files/PLAN_phase_1_2.md`) build the classical reasoner in
`src/auto/classical/` and `src/auto/blast/` on top of the Phase-0
claset infrastructure (`src/auto/rules/`): a shared typed-metavariable
search engine (store, unifier, goals, step cascade, replay, drivers),
public tactics `SAFE_TAC`/`CLARIFY_TAC`/`FAST_TAC`/…/`DEEPEN_TAC`,
and a faithful port of Isabelle's blast (`BLAST_TAC`).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T13 (§5): extend `classicalLib` with the full D26 driver
surface: `FAST_TAC`, `SLOW_TAC`, `BEST_TAC`, `SLOW_BEST_TAC`,
`FIRST_BEST_TAC`, `ASTAR_TAC`, `SLOW_ASTAR_TAC`, `DEEPEN_TAC`,
`STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC`, plus the programmatic
layer (`fast_tac`, …, `deepen_tac : claset -> {start:int} ->
ntactic`).

## Spec

Read first: `PLAN_phase_1_2.md` §5, D26 (§0), M-sig (§7);
`.agent-files/sources/src/Provers/classical.ML:660–732, 826–842`
(driver definitions and method defaults).

1. All drivers = thin instantiations of `clasetSearch` over
   `clasetStep`, marker-processed exactly as slice 1 (TASK_06).
2. Solve-completely drivers fail unless they close the goal
   (`SELECT_GOAL (… no_prems …)` semantics collapses to per-goal
   tactics in HOL4).
3. Numeric defaults are Isabelle's: ASTAR weight 5; `DEEPEN_TAC` =
   safe saturation then depth-bounded solve, `DEEPEN (2, 10)`,
   start 4.  All configurable through the programmatic layer only.
4. Step tactics `STEP_TAC`/`SLOW_STEP_TAC`/`INST_STEP_TAC` = single
   applications of `step`/`slow_step`/`inst_step` as tactics (engine
   round-trip + replay on the resulting node).
5. Every driver success replays through the TASK_11 machinery and is
   `Tactical.VALID`-checked in tests; replay failure surfaces as the
   M-e6 hard diagnostic.
6. Smoke tests (the systematic suite is TASK_15): `FAST_TAC []` on a
   quantifier goal needing instantiation (e.g. `?x. x = a`);
   `DEEPEN_TAC` on a goal needing depth > 4 with a raised start;
   failure (not divergence) on a small non-theorem.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Exported names exactly the §2 collision-checked list; signature
   shapes per §5.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_13.
