# TASK_03 — New-kind attributes + cross-version theory_tests

Plan: `.agent-files/PLAN_phase_4.md` §3.3 (D46, D47) and §12.6;
second half of plan task T02.  Read the plan file in full before
starting — it is the authoritative spec; this task file is a pointer,
not a replacement.

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

1. Attribute registrations (D47), building on the TASK_01 parsing
   infrastructure and the TASK_02 schema:
   - `[norm]` / `[norm=k]` — kind `Norm`, integer penalty (any int;
     default 0 semantics documented; negative penalties run before
     the built-in simp).
   - `[forward]` / `[forward=NN]` — kind `Forward`, unsafe, percent
     in `[1,100]`.
   - `[sforward]` — kind `Forward`, safe; rejects arguments.
2. Attribute-parsing selftests: acceptance and clean-error rejection
   cases for the three new attributes (mirroring the TASK_01 tests).
3. Cross-version theory_tests (plan §12.6): an ancestor theory with
   v1-only deltas loaded by v2 code; a theory exporting Forward/Norm
   deltas reloads correctly (v2 round-trip across
   export/`ThyDataSexp` reload).  Follow the existing
   `src/auto/rules/theory_tests` pattern.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass
  (including the theory_tests subdirectory).
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_01 (digit-leading attribute values + integer-arg parsing),
TASK_02 (schema v2: kinds and codec).
