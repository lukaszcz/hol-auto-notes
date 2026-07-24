# TASK_05 — `Simp`/`Iff` marker constructors (D30 amendment)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phase 3
(`.agent-files/PLAN_phase_3.md`) ports Isabelle's clasimp layer
(`Provers/clasimp.ML`) into `src/auto/clasimp/` on top of the delivered
classical stack (`src/auto/rules`, `src/auto/classical`,
`src/auto/blast`) and the Phase-S simplifier: the clasimpset,
simp-wrapper combinators, `AUTO_TAC`/`FORCE_TAC`/`FASTFORCE_TAC`/
`SLOWSIMP_TAC`/`BESTSIMP_TAC`/`CLARSIMP_TAC` with context-explicit
`CS_*` forms, the `[iff]` attribute, `Simp`/`Iff` markers, and the
layer-wide plain-theorem insertion convention (D30).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan task 05 (`PLAN_phase_3.md` §3.5): add the `Simp` and `Iff` marker
constructors to the claset marker theory and `clasetLib`, plus the
rejection path in `invocation_facts`.

## Spec

Read first: `PLAN_phase_3.md` §3.5; `src/auto/rules/
clasetMarkerScript.sml` (existing six constructors + `Del`, incl. the
`OpenTheoryMap` `Unwanted.id` registrations); `clasetLib.sig:70–84`
(the `Intro`/`destIntro` pattern).

1. In `clasetMarkerScript`: `Simp : bool -> bool` (use only as a
   simpset addition), `Iff : bool -> bool` (per-invocation iff: feed
   the temporary claset *and* the temporary simpset through the §8
   decision tree), each with the `OpenTheoryMap` `Unwanted.id`
   registration the existing constructors carry.
2. In `clasetLib`: wrappers/destructors `Simp`/`Iff`/`destSimp`/
   `destIff` mirroring the delivered `Intro`/`destIntro` pattern.
3. `rules/` only defines the constructors (it stays independent of
   `src/simp`); interpretation lives in `clasimpLib`'s argument
   processor (later tasks).
4. `clasetLib.invocation_facts` raises a clear error on `Simp`/`Iff`
   (reached only from `classicalLib`/`tableauLib`, which have no
   simpset), rather than silently inserting the marked theorem.
5. Selftests: wrap/dest round-trips in `src/auto/rules/selftest.sml`;
   rejection tests in `src/auto/classical/selftest.sml` and
   `src/auto/blast/selftest.sml` — e.g. `CS_FAST_TAC`-family and
   `BLAST_TAC` entry points fail with the clear error on
   `[Simp th]`/`[Iff th]` (per §10.1), asserted as failures.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/rules/`,
   `src/auto/classical/` and `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on touched directories.
4. Rejection is a clear error naming the marker, not silent insertion.

## Dependencies

TASK_03 (`invocation_facts` must exist).
