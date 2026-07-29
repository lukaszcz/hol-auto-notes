# TASK_14 — `aesopSearch` part 1: loop skeleton + safe phase

Plan: `.agent-files/PLAN_phase_4.md` §4.4 (loop, safe phase,
multi-rule prohibition), §5.3 loop prevention; first half of plan
task T11.  Read the plan file in full before starting — it is the
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

`src/auto/aesop/aesopSearch`, first slice:

- **Loop skeleton** (paper §2.3): pop the best unknown,
  still-relevant goal from the `searchHeap` queue (lazy irrelevance
  check); ensure normalised via `aesopNorm` on first expansion.
- **Safe phase** (§2.4/§4.4): try safe rules in the fixed TASK_09
  order.  Goal with empty `deps`: rules run in `Match` mode; first
  successful alternative committed (classical `SAFE_TAC`
  discipline), rapp installed, goal never re-queued.  Goal with
  metavariables: safe rules run in `Unify` mode; a result with empty
  `assigned` installs as safe; a result that assigned metas is
  **postponed** (stored on the goal, not installed).  If some safe
  rule installs, postponed results are dropped; if none installs,
  the postponed list is carried into the unsafe phase (consumed in
  TASK_15).
- **Multi-rule prohibition** (§2.7): a `MultiStep`/multi-alternative
  application in the safe phase (or branching in norm) fails that
  rule *dynamically* — rule treated as inapplicable.
- **Forward loop prevention** (plan §5.3): track the branch's
  forward-added hypothesis list per goal node (inherited by children
  and copies); before installing a forward rapp, fail on an
  `aconv`-equal hypothesis under `instantiate` of the current store
  (use the TASK_10 duplicate-test function).
- Rapp installation goes through the TASK_11/12 tree API (copying
  runs on install).
- Safe-only saturation entry point (deterministic, drives
  `AESOP_SAFE_TAC` later): run normalisation + safe phase to
  saturation over the frontier.
- Selftests: safe-phase commitment and ordering; postponement
  storage/drop semantics (assumption-close under metavariables);
  dynamic multi-rule prohibition; forward loop prevention; safe
  saturation on representative goals with exact frontiers.

The unsafe phase, limits, termination/safe-goals reporting are
**out of scope** — they are TASK_15.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_10 (all builders), TASK_12 (tree + copying), TASK_13 (norm).
