# TASK_07 — Markers `Norm` / `Forward` / `SForward`

Plan: `.agent-files/PLAN_phase_4.md` §3.6 (freeze-list amendment);
plan task T06.  Read the plan file in full before starting — it is
the authoritative spec; this task file is a pointer, not a
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

`clasetMarkerScript.sml` + `clasetLib`:

- New marker constructors `Norm : thm -> thm`,
  `Forward : thm -> thm`, `SForward : thm -> thm` (the plan's
  2026-07-28 grep found no collisions in `src/**.sig`; re-verify
  before committing).
- `process_claset_tags`'s pass-through contract for unrecognized
  markers is preserved; the new markers are consumed only by aesop's
  argument pipeline (later task, TASK_17) — for now they must pass
  through untouched by the classical/clasimp pipelines.
- Percent/penalty arguments do not ride markers; per-invocation
  priorities use the programmatic `CS_` path (no argument plumbing
  here).
- Selftests: marker round-trip through `process_claset_tags`
  pass-through; existing marker behaviour unchanged.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

None (independently gateable).
