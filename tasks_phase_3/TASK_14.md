# TASK_14 — Phase-3 gate: full build + gate record

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

Plan task 13 (`PLAN_phase_3.md` §12 row 13): the Phase-3 boundary gate
— full distribution build with selftests, expected **fully green**,
and the gate record in `PLAN.md` §11.

## Spec

1. Run `bin/build -F -t` from the repo root (long — run in the
   background and monitor).  Expectation per §0.2.8: fully green with
   **no** known exceptions (the `src/probability`
   `in_borel_measurable_inv` failure was repaired at `65250f8c3`; the
   `cv_compute/automation` `CHEATED` selftest was closed at
   `f667a716d`).
2. Run `tools/h4pedant/h4pedant` over `src/auto/clasimp/` and the
   other Phase-3-touched directories.
3. Any failure: diagnose; fix only if clearly caused by Phase-3 work
   (with a regression test); genuinely pre-existing failures are
   proven pre-existing (branch-base check) and recorded, not fixed
   here.
4. Record the gate in `.agent-files/PLAN.md` §11's gate record (date,
   command, outcome, wall-clock), matching the existing format, and
   record the `F-CHEAT`/`CHEATED` counts (expected zero) and the
   h4pedant result.
5. Commit state must be clean at completion (work committed by prior
   tasks; this task adds only the PLAN.md record, which lives in the
   separately-versioned `.agent-files`).

## Acceptance criteria

1. `bin/build -F -t` green with zero `F-CHEAT`/`CHEATED` (or any
   deviation proven pre-existing and recorded).
2. h4pedant clean on Phase-3-touched directories.
3. Gate + counts recorded in `PLAN.md` §11.

## Dependencies

TASK_01–TASK_13 (all Phase-3 tasks).
