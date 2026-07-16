# TASK_01 — Default-equivalence golden selftest suite (pre-refactor lock)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation (`auto`, `blast`, `force`, upgraded `simp`,
arithmetic, …) that are **at least as strong** as the Isabelle originals,
with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`: engine hooks (context theorems, solver stacks, subgoaler),
configurable limits, a tactic-layer loop with loopers/final solvers, the
Isabelle splitter (`splitLib`), congproc fragments, and a `mut_impc`-parity
`global_simp_tac`.  Governing constraint: **all defaults preserve current
behavior**; nothing is enabled in any distribution simpset during Phase S.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Land the default-equivalence selftest suite **before** the Traverse engine
refactor (TASK_02), per PLAN_phase_S §8 group 1 and risk §11.1.  This is
the "D14 zero-change lock": golden cases whose results must be identical
before and after the solver-pipeline refactor.

## Spec

Read PLAN_phase_S §3.2 (the pipeline the refactor will introduce), §8
(selftest conventions), §11.1 (risk this suite mitigates).  Read
`src/simp/src/selftest.sml` (existing ~490-line suite — the canary) and
`src/simp/src/Traverse.sml` (especially `ctxt_solver`, lines ~241–246, and
the limit save/restore at ~242–245).

Add to `src/simp/src/selftest.sml` a clearly delimited group of golden
tests exercising exactly the behaviors the refactor could silently change:

- conditional rewriting where side conditions are discharged by the
  recursive traversal (`EQT_ELIM (trav …)` path);
- side conditions that *fail* to prove — rewrite must not apply, and the
  simplification must still succeed elsewhere (limit save/restore on
  failure);
- side-condition stack depth interaction with `Cond_rewr.stack_limit`
  (default 4): a chain that succeeds at depth ≤ 4 and one that fails
  beyond it;
- `UNCHANGED` propagation subtleties (`Traverse.sml:158–178`): cases where
  subterm simplification raises `UNCHANGED` and the result must reflect it;
- congruence-rule assumption usage (context distributed to reducers), e.g.
  rewriting under `==>` / `let` where the hypothesis feeds the rhs.

Use `testutils` helpers (`tprint` + `OK`/`die`, `convtest`, `shouldfail`),
per CLAUDE.md.  Record expected results as concrete theorems/terms, not
"whatever the current run prints".

## Acceptance criteria

1. New test group compiles and passes on the **unmodified** engine.
2. Whole existing selftest suite still passes:
   `Holmake` in `src/simp/src` then run its selftest (check how
   `selftest.sml` is built/run in that directory's Holmakefile).
3. `bin/build -t --seq=tools/sequences/upto-parallel` green.
4. Style: no tabs, no trailing whitespace, < 80 columns
   (`tools/h4pedant`).

## Dependencies

None.  Must land before TASK_02.
