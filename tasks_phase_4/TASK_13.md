# TASK_13 — `aesopNorm`: normalisation fixpoint + built-in chain

Plan: `.agent-files/PLAN_phase_4.md` §6 (D50), §12 risk 4; plan task
T10.  Read the plan file in full before starting — it is the
authoritative spec; this task file is a pointer, not a replacement.

## Context

Phase 4 of the isabelle-tactics project builds a full aesop-style
best-first proof search engine (Limperg & From, CPP 2023) in
`src/auto/aesop/`, on top of the shared claset rule DB and the Phase-2
metavariable/replay substrate.  Ultimate goals of the whole plan:
`AESOP_TAC`/`AESOP_SAFE_TAC` (+ `CS_` forms) with close-or-fail
semantics, kernel-checked replay, the paper's full metavariable
algorithm, and a single shared rule DB extended with Forward/Norm
kinds, percent/penalty attributes, and an `aesop_simp` settype.
All work must be a step toward these goals, but the ultimate goals are
**not** acceptance criteria for this task — only the gate below is.

## Scope

`src/auto/aesop/aesopNorm` — per goal, on first expansion:

- Fixpoint over norm rules ordered by penalty, restarting from the
  lowest penalty after every success; each rule must prove the goal
  or yield exactly one subgoal; results accumulate as the goal's
  `norm_state` chain (records + final cgoal + store — no
  rapp/alternative structure).
- Fixed built-in chain at penalty 0 (relative order within 0 fixed
  and documented): `blast_disch_step`-style assumption introduction,
  `blast_gen_step` ∀-introduction, hyp-subst
  (`blast_hyp_subst_step`, incl. variable elimination), then the
  built-in simp rule (safe-mode `GEN_GLOBAL_SIMP_TAC` with clasimp's
  mut_impc-parity `asm_full_simp_config` over
  `aesopData.aesop_ss()` + invocation additions, run through
  `render`/`unrender`).  Assumptions used by the simp call by
  default; disable via the existing generic controls.
- User `[norm]` rules: engine `Match`-mode apply-style application,
  ≤ 1 subgoal enforced dynamically; negative penalties run before
  the built-ins, positive after.
- Rigid rendering + `Match` mode structurally enforce the paper's
  §4.5 no-metavariable rule for the whole phase; a norm application
  that branches or binds a metavariable fails that rule dynamically.
- Loop protection (plan §12 risk 4): the fixpoint counts iterations
  against a `max_depth`-derived bound.
- Selftests: fixpoint order (penalty ordering, restart semantics,
  ≤1-subgoal enforcement, simp-at-0 with a negative-penalty user rule
  before it); dynamic failure on branching/meta-binding norm
  applications; iteration bound triggers cleanly.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_08 (`aesop_ss`), TASK_09 (rule model, `RNorm`), TASK_11
(`norm_state` slot on goal nodes).
