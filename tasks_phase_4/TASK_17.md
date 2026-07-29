# TASK_17 — `aesopLib` surface + argument pipeline

Plan: `.agent-files/PLAN_phase_4.md` §7 (D49, D27, D30, D36), §8
(TypeBase bullet: `cases_rule_for` surface); first part of plan task
T13.  Read the plan file in full before starting — it is the
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

`src/auto/aesop/aesopLib` public signature per plan §7:
`aesop_config`, `default_config`, `AESOP_TAC`, `AESOP_SAFE_TAC`,
`CS_AESOP_TAC`, `CS_AESOP_SAFE_TAC`, `augment_aesop`, plus
`cases_rule_for : hol_type -> rule` (backed by TASK_10).

- Argument processing mirrors clasimp (`process_clasimp_args`
  pattern): `markerLib.ABBRS_THEN`; `classify_simp_args`; `Simp`
  args → invocation simpset; `Iff` args → `iff_declaration`; claset
  markers via `process_claset_tags`; new `Norm`/`Forward`/
  `SForward` markers consumed into invocation rules (default
  penalties/percentages); plain theorems **inserted** (D30,
  `INSERT_FACTS_TAC`); generic simp controls forwarded to the simp
  calls.
- `AESOP_TAC` = `Tactical.VALID`-wrapped close-or-fail; on failure it
  fails, reporting safe goals at trace ≥ 1 (computed per §4.4).
- `AESOP_SAFE_TAC` = normalisation + safe rules only, run to
  saturation (deterministic; frontier is a genuine goal list per the
  plan's §7 argument); leaves the frontier as subgoals; fails iff it
  changes nothing (D27 semantics via `NCHANGED` around insertion +
  engine, as in `classicalLib`).
- Public entries use `the_claset()` + `aesop_ss()` +
  `default_config`; `CS_` forms are the explicit-context spine
  (D36) with the limits record.
- `augment_aesop {name, phase, tactic}`: session-only, never
  persisted (`src/auto/CLAUDE.md` mandate), wired to the TASK_10
  tactic-rule registry.
- Selftests: argument-pipeline behaviour (markers, Simp/Iff args,
  D30 insertion); close-or-fail lock; exact `AESOP_SAFE_TAC`
  residues on representative goals; D27 no-change failure; no state
  leaks.  Verify the surface actually consumes the marker and
  builder mechanisms from earlier tasks (they must be called, not
  just present).

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_07 (markers), TASK_10 (builders incl. cases/tactic registry),
TASK_15 (search), TASK_16 (extraction/replay).
