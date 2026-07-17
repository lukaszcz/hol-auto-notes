# TASK_01 — `src/auto/classical/` skeleton, build wiring, `searchHeap`

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phases
1–2 (`.agent-files/PLAN_phase_1_2.md`) build the classical reasoner in
`src/auto/classical/` and `src/auto/blast/` on top of the Phase-0
claset infrastructure (`src/auto/rules/`): a shared typed-metavariable
search engine (store, unifier, goals, step cascade, replay, drivers),
public tactics `SAFE_TAC`/`CLARIFY_TAC`/`FAST_TAC`/…/`DEEPEN_TAC`,
and a faithful port of Isabelle's blast (`BLAST_TAC`).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T1 (§2, §3.6 heap part): create the `src/auto/classical/`
directory skeleton, wire it into the build, and implement the one
dependency-free module, `searchHeap`.

## Spec

Read first: `PLAN_phase_1_2.md` §2; `src/auto/CLAUDE.md`;
`src/auto/rules/Holmakefile`; `src/metis/mlibHeap.sml` (lines 6–30,
the model — do NOT depend on it).

1. `src/auto/classical/Holmakefile` modeled on `src/auto/rules/`
   (`HOLHEAP = $(HOLDIR)/bin/hol.state0`, INCLUDES `src/auto/rules`).
2. `searchHeap.{sig,sml}`: leftist min-heap parameterized by an
   ordering, modeled on `mlibHeap.sml:6–30` (~40 loc).  Needed ops
   (see §3.6 BEST_FIRST): empty, add, is_empty, min, delete_min, size,
   and a `delete_all_min`-style helper (pop all minimal-key entries).
   Local to this directory — `src/metis` is outside the dependency
   stratification band (M-heap, §7).
3. `selftest.sml` (testutils-based) with heap unit tests: ordering,
   duplicate keys, delete_all_min, empty-heap failures.
4. Build wiring: add `src/auto/classical` to
   `tools/sequences/upto-auto` after `src/auto/rules` (before the
   `!…/theory_tests` line); add it to `SRCRELNAMES` in
   `src/parallel_builds/core/Holmakefile`.  Do NOT touch
   `src/auto/blast` wiring here (TASK_18).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant` clean on new files; no tabs, no trailing
   whitespace, < 80 columns.
4. No changes outside the files listed above.

## Dependencies

None.
