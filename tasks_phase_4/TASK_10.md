# TASK_10 — Rule builders: forward/destruct, cases, tactic, splits

Plan: `.agent-files/PLAN_phase_4.md` §5.3, §5.4, §5.6, §4.2 (sources
2, 4, 6), §8 (TypeBase bullet); second half of plan task T08.  Read
the plan file in full before starting — it is the authoritative spec;
this task file is a pointer, not a replacement.

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

Extend `aesopRule` (and helpers) with the remaining builders:

1. **forward / destruct** (§5.3): from `[forward]`/`[forward=NN]`/
   `[sforward]` decls (kind `Forward`, safe flag) or per-invocation
   markers.  Apply `MAKE_ELIM_RULE thm` via
   `rule_step {elim = true, ...}` against a matching assumption
   **without consuming it** (`consumed = NONE`; the TASK_05
   non-consuming replay action if it was needed).  Phase-4 default =
   all-immediate: remaining premise subgoals must close immediately
   by assumption; conclusion lands as the new head assumption of the
   single surviving child.  Programmatic registration accepts
   `{immediate : int}` (documented, additive).  **destruct** = the
   existing claset Dest kind, consuming — no new machinery.
   **Loop-prevention data**: expose the per-rule `once` check —
   the branch-level forward-added-hypothesis walk itself is wired in
   the search task (TASK_14); here provide the
   `aconv`-under-`instantiate` duplicate test as a function.
2. **cases** (§5.4): elim application of a cases/nchotomy-shaped
   theorem (consuming, for inductive-relation cases); TypeBase
   supplies theorems; per-invocation/programmatic only — **no**
   global default registration.  Implement the
   `cases_rule_for : hol_type -> rule` backing (nchotomy/cases
   backed; surfaced publicly in TASK_17).  Optional patterns:
   programmatic registration takes a pattern term list; applicability
   requires some assumption to `match_term` a pattern after index
   retrieval.
3. **tactic** (§5.6): rules applied through `render`/`unrender` on
   the goal's single-goal engine node (`RenderedTactic`); rigid
   rendering means tactic rules cannot create or assign engine
   metavariables (document the divergence).  No-op results rejected:
   `unrender` result must differ from the input goal.  Optional
   user-supplied target/hyp pattern for indexing; unindexed
   otherwise.  (The public `augment_aesop` registration API is
   TASK_17; keep a module-level registry here.)
4. **splits** (§4.2 source 4, D50): for each `[split]` theorem, a
   low-order safe rule built on `splitLib` conversions applied as
   `RenderedTactic` — conclusion splits low, assumption splits lower
   still, per the fixed safe order.
5. Selftests: forward all-immediate semantics and non-consumption;
   dest consumption; cases rule construction from TypeBase; pattern
   gating; tactic no-op rejection at builder level; split rules
   produce the expected safe-order slots.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_09 (rule model), TASK_05 (`rule_step` + replay action),
TASK_07 (markers exist, for decl plumbing).
