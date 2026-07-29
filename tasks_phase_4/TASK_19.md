# TASK_19 — Selftest completion: strength smoke set + §9 sweep

Plan: `.agent-files/PLAN_phase_4.md` §9 (items 1–6 completeness
check; item 5 is the main new work); first part of plan task T14.
Read the plan file in full before starting — it is the authoritative
spec; this task file is a pointer, not a replacement.

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

1. **Strength smoke set** (§9 item 5): a listTheory mini-corpus
   (append/length/reverse/membership lemmas solvable without
   induction) run under `AESOP_TAC []`; a Pelletier propositional
   subset for sanity; exact `AESOP_SAFE_TAC` residues on
   representative goals.
2. **Coverage sweep**: audit `src/auto/aesop/selftest.sml` (and the
   substrate selftests touched in earlier tasks) against the plan's
   §9 items 1–6; fill any gaps left by earlier tasks rather than
   duplicating what already exists.
3. Conventions per `src/auto/CLAUDE.md`: successes through
   `Tactical.VALID`, exact residues asserted, negative cases,
   no state leaks, expected failures asserted as failures, no
   benchmark recognition.

## Notes

- If smoke-set goals fail, diagnose whether the failure is an engine
  bug (fix or file precisely) versus an out-of-scope strength gap
  (plan §12 risk 5 → Phase-8 benchmarks); do not weaken close-or-fail
  semantics to make tests pass.
- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_17 (full surface), TASK_18 (seed percents in place).
