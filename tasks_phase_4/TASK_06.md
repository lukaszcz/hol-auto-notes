# TASK_06 — `clasetMeta.absorb` (store merge)

Plan: `.agent-files/PLAN_phase_4.md` §3.5 (D51); plan task T05.
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

Second Phase-2 freeze amendment (D51), additive `clasetMeta` export:

```sml
val absorb : {base : store, extensions : store list} -> store
```

- Keyed-map union of the six keyed maps; any key present twice with
  unequal values raises a diagnostic `HOL_ERR` — an aesop engine bug,
  never silently resolved.
- Rationale (for the sig comment): at proof extraction, sibling
  subtrees under one rapp evolve incomparable store extensions with
  provably disjoint new-binding domains, but replay needs one
  covering store.
- Selftests: golden merges including allow-set and eigen tables;
  conflict detection raises the diagnostic error.

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
