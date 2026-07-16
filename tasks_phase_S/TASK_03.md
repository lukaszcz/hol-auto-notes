# TASK_03 — `traverse_data` v2 fields, `Cond_rewr` refs, `congLib` update

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`: engine hooks, configurable limits, a tactic-layer loop
with loopers/final solvers, the Isabelle splitter, congproc fragments, and
a `mut_impc`-parity `global_simp_tac`.  Governing constraint: **all
defaults preserve current behavior**.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T2 (§3.3–3.4 + the `traverse_data` surface of §3.2): expose the new
engine hooks through `traverse_data`, add the two overridable refs to
`Cond_rewr` with exception-safe dynamic binding in `TRAVERSE`, and update
`congLib`.

## Spec

Read PLAN_phase_S §3.2–3.4, §2 compat rules 3–4, §11.4, §11.6.  Sources:
`src/simp/src/Traverse.{sig,sml}`, `src/simp/src/Cond_rewr.{sig,sml}`,
`src/simp/src/congLib.sml`.

1. **`traverse_data` fields** (§3.2): add
   `subgoaler : subgoaler option`, `solvers : ssolver list`,
   `cond_depth : int option`, `term_ord : (term * term -> order) option`.
   Wire `subgoaler`/`solvers` into the pipeline TASK_02 built.  Update
   `congLib.sml:273–277` (the only external construction site) to pass
   `NONE`/`[]`/`NONE`/`NONE`.
2. **Per-simpset side-condition depth** (§3.3): `COND_REWR_CONV` keeps
   reading `!Cond_rewr.stack_limit`; when `cond_depth = SOME n`,
   `TRAVERSE` runs its body under an exception-safe save/set/restore of
   the ref (`Lib.with_flag` idiom, cf. `simpLib.sml:1000–1005`).  `NONE`
   leaves the ref alone (the `examples/` global setters keep working —
   compat rule 4: `stack_limit` stays exported, default 4).
3. **Settable term order** (§3.4): `Cond_rewr` gains
   `val term_ord : (term * term -> order) ref` initialized to
   `ac_term_ord`, read at the permutative-rule guard
   (`Cond_rewr.sml:163`); `TRAVERSE` binds it from the field the same
   way.  Bounded (`Once`/`Ntimes`) rewrites keep bypassing the guard.
4. **Selftests** (§8 groups 3–4, plus §11.4 reentrancy and §11.6):
   - cond_depth: a conditional-rule chain of depth 10 failing at default
     4 and succeeding with `cond_depth = SOME 40`; global-ref setting
     still honored when the field is `NONE`.
   - term_ord: an ordered-rewriting case whose normal form flips under a
     custom order; `Once` bypass unaffected.
   - Reentrancy: nested `TRAVERSE` with different `cond_depth`/`term_ord`
     restores correctly, including when an inner solver itself calls
     `SIMP_CONV`; restoration on exception.
   - congLib: make it compile against the new fields and add its first
     smoke test (it has none today) so future field additions fail loudly.

Note: `set_cond_depth`/`set_term_ord` **simpset**-level setters are
TASK_04's job; this task ends at the `traverse_data` seam.

## Acceptance criteria

1. All prior selftests (incl. TASK_01/02 groups) still pass.
2. New group-3/4 tests, reentrancy tests, and congLib smoke test pass.
3. `Cond_rewr.stack_limit` still exported, default 4, and effective when
   `cond_depth = NONE`.
4. `bin/build -t --seq=tools/sequences/upto-parallel` green.
5. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_02.
