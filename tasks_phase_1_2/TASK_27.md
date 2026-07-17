# TASK_27 — Phase-2 gate: full build + gate record (T-fin)

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

Plan T-fin (§8.4): the Phase-2 boundary gate — full distribution
build with selftests, and the gate record.

## Spec

1. Run `bin/build -F -t` from the repo root (long — background it
   and monitor).
2. Run `tools/h4pedant` over `src/auto/classical/` and
   `src/auto/blast/`.
3. Any failure: diagnose; fix only if caused by Phase 1–2 work (with
   a failing-first regression); pre-existing failures recorded, not
   fixed.
4. Record the gate in `.agent-files/PLAN.md` §11 (date, command,
   outcome), matching the TASK_09 record format.

## Acceptance criteria

1. `bin/build -F -t` green (or failures proven pre-existing and
   recorded).
2. h4pedant clean on both directories.
3. Gate recorded in PLAN.md §11.

## Dependencies

All of TASK_01–TASK_26.
