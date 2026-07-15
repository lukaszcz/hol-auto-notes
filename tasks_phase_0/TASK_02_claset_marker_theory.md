# TASK_02 — `clasetMarkerScript.sml`: per-invocation marker constants

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  Marker constants let users pass
per-invocation rule modifiers to the Phase 1–4 tactics, e.g.
`auto_tac [SIntro th, Del "FOO"]`, exactly as `simpLib` uses
`Cong`/`Excl`/`Once` markers today.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §6.4 — the authoritative spec.
- `src/marker/markerScript.sml` and `src/marker/markerLib.sml` — the
  patterns to follow exactly: thm-carrying markers use the `Cong_def`
  pattern (`markerLib.sml:77`); string-carrying markers use the `Excl_t`
  tagged-term pattern (`markerLib.sml:102`).

## Deliverables

`src/auto/rules/clasetMarkerScript.sml` defining identity marker constants
for:

- thm-carrying: `SIntro`, `Intro`, `SElim`, `Elim`, `SDest`, `Dest`
  (matching the six rule kinds: safe/unsafe × intro/elim/dest);
- string-carrying: `Del` (remove a named rule for this invocation).

Definitions mirror `markerTheory` (identity constants / tagged terms); no
ML constructors/destructors here — those live in `clasetLib` and are a
later task (TASK_09).

Extend `src/auto/rules/Holmakefile` as needed so the theory builds.

## Constraints

- Moscow-ML-compatible SML only; the directory is not `[poly]`-tagged.
- Only dependencies allowed: libraries built before `src/boss` (see plan
  §2); for this script essentially `boolTheory`/`markerTheory`-level
  infrastructure.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Acceptance criteria

- `clasetMarkerTheory` builds in `src/auto/rules`.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_01 (build skeleton).
