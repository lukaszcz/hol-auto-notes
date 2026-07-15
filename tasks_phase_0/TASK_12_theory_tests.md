# TASK_12 — `theory_tests/`: cross-theory persistence scenarios

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  The claset's value comes from
persisting across theories; this task regression-tests exactly that —
export, reload, ancestry merge — which in-process selftests cannot cover.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §8 (theory_tests part) — the
  authoritative spec.
- `src/boss/theory_tests/` — the model for structure and Holmakefile
  idiom (scripts + a Holmakefile that builds children and checks
  results).
- `src/parse/AncestryData.sig:72–78` — the sibling-removal merge
  semantics (delta streams, not final values) the diamond test must
  exercise.
- TASK_08's public API (`export_rule`, `delrule`, `the_claset`,
  attributes).

## Deliverables

`src/auto/rules/theory_tests/` with its own Holmakefile, containing at
least:

1. **Parent/child**: `declAScript.sml` declares rules through all three
   surfaces (attribute on `Theorem`, `export_rule`, `delrule`);
   `declBScript.sml` (child theory) checks `the_claset()` contents after
   load — presence, kinds, canonical order, and that the removed rule is
   gone.
2. **Diamond merge**: two sibling theories extend/remove independently
   from a common parent; a common child checks the ancestry-merged
   result, specifically the sibling-removal scenario (removal in one
   branch beats addition in the ancestor).
3. **Reload idempotence**: running `Holmake` twice must not duplicate
   rules — in particular the TypeBase hook refiring on reload must be a
   no-op (statement-keyed dedup).

Wire the directory into the build so `bin/build -t` over
`tools/sequences/upto-auto` runs these tests (follow how
`src/boss/theory_tests` is reached by its sequence, and mirror that for
`src/auto/rules`).

## Constraints

- Moscow-ML-compatible SML; style: no tabs, no trailing whitespace,
  < 80 columns.
- Tests must fail loudly (`die`/nonzero exit) on mismatch — silent
  passes are worthless here.

## Acceptance criteria

- All theory_tests scenarios pass under the build gate;
  `bin/build -t --seq=tools/sequences/upto-auto` green, including a
  second (idempotence) run of the theory_tests directory.

## Dependencies

- TASK_08 (persistence + attributes), TASK_10 (TypeBase hook — for the
  reload-idempotence scenario), TASK_11 (seed theory, as realistic
  ancestry content).
