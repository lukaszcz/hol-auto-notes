# TASK_09 — Phase-1 gate: full build + gate record

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

Plan T9 (§8.4): the Phase-1 boundary gate — full distribution build
with selftests, and the gate record in `PLAN.md`.

## Spec

1. Run `bin/build -F -t` from the repo root (this is long — run it in
   the background and monitor).  This also validates the TASK_01
   `SRCRELNAMES`/sequence wiring under the full build.
2. Run `tools/h4pedant` over `src/auto/classical/`.
3. Any failure: diagnose; fix only if clearly caused by Phases 1
   work (with a regression test); pre-existing failures are recorded,
   not fixed here.
4. Record the gate in `.agent-files/PLAN.md` §11's gate record
   (date, command, outcome), matching the existing record format.
5. Commit state must be clean at completion (work committed by prior
   tasks; this task adds only the PLAN.md record, which lives in the
   separately-versioned `.agent-files`).

## Acceptance criteria

1. `bin/build -F -t` green (or failures proven pre-existing on
   `develop`/branch-base and recorded).
2. h4pedant clean on `src/auto/classical/`.
3. Gate recorded in `PLAN.md` §11.

## Dependencies

TASK_01–TASK_08 (all Phase-1 tasks).
