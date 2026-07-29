# TASK_15 — `aesopSearch` part 2: unsafe phase, limits, termination

Plan: `.agent-files/PLAN_phase_4.md` §4.4 (unsafe phase,
postponement re-offer, limits, termination) and §9 item 4; second
half of plan task T11.  Read the plan file in full before starting —
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

Complete `aesopSearch`:

- **Unsafe phase**: apply the single best remaining unsafe candidate
  (rule percent order, then claset order); **all** unification
  alternatives of that rule become sibling rapps (the multi-rule
  generalisation, paper §2.7); re-queue the goal if candidates
  remain.
- **Postponed re-offer**: safe results postponed by TASK_14 are
  re-offered as extra `RUnsafe 90` pseudo-rules whose application
  just installs the stored result (§4.4).
- **Limits**: `{max_rapps : int, max_depth : int}` in
  `aesop_config`, defaults 200 and 30 (tunable numerics per parent
  plan §11); depth limit stops expansion of the offending branch,
  rapp limit stops the search — both lead to the failure path.
- **Termination**: root proved → hand off to extraction (TASK_16);
  root stuck or limits → failure path: complete all applicable safe
  expansions on the relevant frontier, then compute and report the
  **safe goals** (§2.6) at trace level 1.
- Trace `"aesop"` output at levels 1–3 (outcome/safe-goals,
  expansions/copying, full nodes).
- Selftests (§9 item 4): transitivity chains (`x ≤ z` via `≤`-trans
  with both reflexivity and hypothesis instantiations — the paper's
  §4 motivating example); postponed-rapp re-offer at 90; limits
  (max_rapps, max_depth) trigger cleanly; expected failures asserted
  as failures.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_14 (loop + safe phase).
