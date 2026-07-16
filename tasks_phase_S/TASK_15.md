# TASK_15 — Full-distribution build gate (`bin/build -F -t`)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgraded the simplifier in
`src/simp/src/`.  The full-distribution build with selftests is the
regression gate for the governing constraint that **all defaults preserve
current behavior**; Phase S is not done until it is green.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T13: run the full build with selftests and get it green.

## Spec

1. Run `bin/build -F -t` from the repo root (use `-F` explicitly — bare
   `bin/build` reuses the previous `--seq`).  This takes a long time;
   run it in the background and monitor.
2. Any failure traced to Phase S changes: diagnose and fix minimally,
   staying within the phase plan's constraints (defaults preserve
   behavior; frozen interfaces per PLAN_phase_S §2 and §12).  Rerun
   until green.  A failure that pre-exists Phase S (verify against the
   branch base commit if suspected) is reported, not silently fixed.
3. Record the gate result (date, commit, outcome) in the Phase S gate
   record in `.agent-files/PLAN.md` §11 (the slot TASK_14 left pending).
4. Confirm `tools/h4pedant` is clean (it runs as part of the regression
   suite; if it flags Phase S files, fix them).

## Acceptance criteria

1. `bin/build -F -t` completes green.
2. Gate result recorded in `.agent-files/PLAN.md`.
3. Any pre-existing (non-Phase-S) failures documented in the task
   completion report rather than patched.

## Dependencies

All other tasks (TASK_01–TASK_14).
