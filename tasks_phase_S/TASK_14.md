# TASK_14 — `PLAN.md` record updates (bookkeeping)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgraded the simplifier in
`src/simp/src/`.  This task records the phase's decisions and status in
the master plan so later phases build on an accurate record.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T12: update `.agent-files/PLAN.md` (the master plan, not the phase
plan) with the Phase S record.

## Spec

Read PLAN_phase_S §0 (D14–D20), §7 (in-engine `mut_impc` revisit), §10
(T12 row), and the relevant sections of `.agent-files/PLAN.md` (§2
decision record, §5 simplifier plan, §11 promotion/records section).
Match the existing style of those sections exactly.

1. §2 decision table: append D14–D20 (copy the substance from
   PLAN_phase_S §0, condensed to the table's existing style).
2. §5: mark the Phase S items' status (delivered in `src/simp/src`,
   defaults off, promotion pending §11).
3. §11: record the Phase S micro-decisions that later phases rely on
   (layer simpsets set `cond_depth` 40; freeze list pointer to
   PLAN_phase_S §12), and the benchmark-gated revisit item: in-engine
   `mut_impc` becomes its own planned item if Phase 8 benchmarks show
   gaps attributable to in-engine mutuality.
4. Add the gate record entry for Phase S with the per-task gate runs
   noted and the full-build gate marked pending TASK_15 (TASK_15 will
   fill in the result).

Note: this file is gitignored planning material — keep references to
`.agent-files` out of any committed files (repo policy); this task edits
only `.agent-files/PLAN.md`.

## Acceptance criteria

1. `.agent-files/PLAN.md` §2, §5, §11 updated in the existing style;
   no other sections disturbed.
2. No committed (tracked) file references `.agent-files`.

## Dependencies

TASK_13 (all substantive work done, so the record is final except the
TASK_15 gate result).
