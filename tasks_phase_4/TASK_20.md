# TASK_20 — Docfiles + build-sequence integration

Plan: `.agent-files/PLAN_phase_4.md` §10 and §3.7; second part of
plan task T14.  Read the plan file in full before starting — it is
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

1. **Docfiles** (`help/Docfiles`): `aesopLib.AESOP_TAC`,
   `aesopLib.AESOP_SAFE_TAC`, `aesopLib.CS_AESOP_TAC`,
   `aesopLib.CS_AESOP_SAFE_TAC`, `aesopLib.augment_aesop`; the
   `[norm]`/`[forward]`/`[sforward]`/`[aesop_simp]` attributes in
   the attribute documentation alongside `[intro]` etc.; the numeric
   attribute-argument syntax.  `AESOP_TAC`'s entry credits the
   published design (Limperg & From, CPP 2023) and documents the
   divergences: tactic rules cannot bind metavariables; no
   induction; no named rule sets; dropped metavariables grounded to
   `ARB`.
2. **Build integration** (§3.7): add `src/auto/aesop` to
   `tools/sequences/upto-auto` (after `clasimp`) and to
   `SRCRELNAMES` in `src/parallel_builds/core/Holmakefile`; list a
   `theory_tests` subdirectory with `!` like the rules/clasimp ones
   if one exists.

## Notes

- Match existing Docfile format/markup conventions (see neighbouring
  entries for `clasetLib`/clasimp tactics).
- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Docfile validation as done for existing entries (the help build in
  the touched directory succeeds).
- `bin/build -t --seq=tools/sequences/upto-auto` green with
  `src/auto/aesop` now in the sequence.
- `tools/h4pedant` over touched files; `git diff --check` clean.

## Dependencies

TASK_17 (public surface finalized).
