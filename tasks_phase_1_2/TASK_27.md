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

## Status: COMPLETED/RECLOSED 2026-07-23 at `f4fc8be66`

The Phase-2 boundary full gate at `5bc674569` remains historical evidence.
Accepted attempt-04 now proves the current committed-state gate at reviewed
commit `f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`, tree
`9f9dd4c4d5c4e3f303a7fa71605ae7b87ca9aa55`.

The accepted package is:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
```

The explicit `bin/build -F -t` was the last build/test command, exited 0
after 1132.087214 s, and ended `Hol built successfully.`  H4pedant over
Rules, Classical and Blast exited 0.  The authoritative gate record is in
`PLAN.md` §11, and the requirement audit is
`PLAN_phase_1_2_green.md` §6.  All three acceptance criteria are met.

Candidate 05 remains historical pre-commit functional evidence only.  It
ran no full build and is not used for current TASK_27 acceptance.

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

1. [x] `bin/build -F -t` green: attempt-04 record/log 014.
2. [x] H4pedant clean on both directories: attempt-04 record/log 011
   also covers Rules.
3. [x] Gate recorded in `PLAN.md` §11.

## Dependencies

All of TASK_01–TASK_26.
