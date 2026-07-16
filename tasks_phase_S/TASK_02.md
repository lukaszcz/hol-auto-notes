# TASK_02 — Traverse engine: `context_thms` + solver/subgoaler pipeline

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

The delicate kernel-plumbing step (plan T1, §3.1–3.2): give `Traverse` a
context-theorem accumulator and a faithful subgoaler/solver pipeline whose
defaults are extensionally identical to today's behavior.

## Spec

Read PLAN_phase_S §3.1–3.2 in full (it contains the exact types and
pipeline pseudocode), plus §11.1 and the freeze list §12.  Read
`.agent-files/research/phaseS-isabelle-simploop.md` §4.a–4.b for the
Isabelle semantics being ported.  Primary sources:
`src/simp/src/Traverse.{sig,sml}`.

1. **`context_thms` accumulation** (§3.1): `TSTATE`
   (`Traverse.sml:57–62`) gains `context_thms : thm list`; `add_context`
   (`Traverse.sml:79–108`) appends the incoming `thms`.  Cons-only, no
   copying.
2. **Public types** (§3.2): add `simp_prover_ctxt`, `ssolver`,
   `subgoaler` to `Traverse.sig` exactly as specified in the plan.
3. **Pipeline**: refactor `ctxt_solver` (`Traverse.sml:241–246`) to the
   subgoaler-then-solvers pipeline in §3.2, preserving the existing limit
   save/restore on failure around the whole pipeline.  With
   `subgoaler = NONE` and `solvers = []` this must be literally today's
   `EQT_ELIM (trav …)`.  Solver exceptions other than `HOL_ERR`
   propagate.
4. For this task, thread `subgoaler`/`solvers` internally with default
   values (`NONE`/`[]`) — the `traverse_data` field additions and the
   `congLib` update are TASK_03's job.  Choose the minimal internal
   plumbing that lets TASK_03 expose them as `traverse_data` fields.
5. **Selftests** (§8 groups 1–2, engine part): TASK_01's golden suite must
   pass unchanged.  Add solver-seam tests to `src/simp/src/selftest.sml`
   at whatever level is testable now (e.g. by calling `TRAVERSE`
   directly with a toy solver if the simpLib surface doesn't exist yet):
   a toy unsafe solver discharging a side condition the recursive
   simplifier cannot; `context_thms` visibility (solver proves a
   condition from a context theorem); limit save/restore on solver
   failure.

Do not touch `REDUCER` or the reducer apply-argument record (frozen,
compat rule 3 in §2).

## Acceptance criteria

1. TASK_01's default-equivalence suite passes bit-for-bit (same theorems).
2. New solver-seam tests pass.
3. `bin/build -t --seq=tools/sequences/upto-parallel` green.
4. `Traverse.sig` exports the three new types with the exact shapes from
   §3.2 (they are frozen at phase completion, §12).
5. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_01 (golden suite must exist first).
