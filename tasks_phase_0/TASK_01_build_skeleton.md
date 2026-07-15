# TASK_01 — Build skeleton: directory, Holmakefile, build sequence

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset") — nondeterministic tactic combinators, a
dual-mode discrimination net, rule preprocessing, persistent per-theory rule
declarations via attributes, and a seed rule corpus.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §2 (directory, build, portability) — the
  authoritative spec for this task.
- `src/parallel_builds/core/Holmakefile` (the `SRCRELNAMES` list, line 4).
- An existing simple library `Holmakefile` for the idiom, e.g.
  `src/marker/Holmakefile`.
- `tools/sequences/base-hol` and other files in `tools/sequences/` for the
  sequence-file `#include` idiom.

## Deliverables

1. `src/auto/rules/Holmakefile` — a minimal Holmakefile so the (initially
   empty) directory builds cleanly.  The directory must **not** be
   `[poly]`-tagged anywhere: all Phase 0 code must stay Moscow-ML-compatible.
2. `tools/sequences/upto-auto` — new development sequence:
   ```
   #include sequences/kernel
   #include sequences/core-theories
   src/auto/rules
   ```
3. `src/auto/rules` added to `SRCRELNAMES` in
   `src/parallel_builds/core/Holmakefile` so the default full build
   (`bin/build -F`) exercises the directory.

## Constraints

- Follow `CLAUDE.md` style: no tabs, no trailing whitespace, < 80 columns.
- Do not create any `.sml`/`.sig` sources yet — later tasks add them.

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` completes green.
- `git status` shows only the three deliverables above (plus any generated
  files properly ignored).

## Dependencies

None (first task).
