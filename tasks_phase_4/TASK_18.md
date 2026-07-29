# TASK_18 — Seed percent pass (`clasetSeedScript.sml`)

Plan: `.agent-files/PLAN_phase_4.md` §8 (first bullet, D48); second
part of plan task T13.  Read the plan file in full before starting —
it is the authoritative spec; this task file is a pointer, not a
replacement.

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

- No new seed theory: built-ins + existing claset seeds suffice for
  engine correctness.
- Apply percent annotations mirroring the paper's default corpus
  (§3.4: ∨-intros 50, universal-hypothesis application 75) where the
  existing seed rules diverge from the D48 default of 50% — i.e.
  **only** rules whose intended percent is not 50 get explicit
  `prio` in `clasetSeedScript.sml` (re-recorded deltas; theory
  rebuild).
- Cross-check the paper's §3.4 table
  (`papers/limperg-from2023-aesop.txt`) against the current seed
  declarations before editing; touch nothing whose intended percent
  is 50.
- Selftest/lock: the changed seeds' `rulespec`s carry the expected
  `SOME` percents after reload.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass
  (theory rebuild included).
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_01 (percent attribute args), TASK_02 (schema v2 semantics).
