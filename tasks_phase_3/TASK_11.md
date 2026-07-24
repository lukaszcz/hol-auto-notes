# TASK_11 — `[iff]` persistence: settype, attribute, `remove_iff`

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

Second half of plan task 10 (`PLAN_phase_3.md` §8.2): the persistent
`[iff]` attribute — settype, apply hook, `remove_iff`, and the
persistence selftests in `clasimp/theory_tests/`.

## Spec

Read first: `PLAN_phase_3.md` §8.2, §0.1 (D29, D12 reference);
`splitLib.sml:100–114` (settype registration model incl. collision
guard); `src/auto/rules/theory_tests/` (round-trip test model);
`BasicProvers.sig:31` (`augment_srw_ss`); `clasetLib.sig:29,34`.

1. Settype `"iff"` via `ThmSetData.export_with_ancestry`, registered
   in `clasimpLib` following the `splitLib` pattern (including the
   registration-collision guard).  The delta carries only ADD/RM of
   the *source* theorem — the declaration is the single source of
   truth; both derived views are recomputed by the apply hook on every
   load.  The claset `cdelta` v1 schema and rules/⊥simp layering are
   untouched.
2. Apply hook: run the TASK_10 decision tree; push the claset half
   through `clasetLib.augment_claset`, the simpset half through
   `BasicProvers.augment_srw_ss` (one small ssfrag per delta).
3. Attribute surface: `Theorem foo[iff]`.  Removal:
   `val remove_iff : string -> unit` writing the RM delta (function-
   based removal, per D12); the hook retracts both halves (claset
   removal by the derived-rule names it created; simpset removal via
   the delta-replayed `srw_ss` state).
4. Record the §8.2 cross-stream ordering caveat (iff vs. intro
   relative recency may permute on reload; tie-break-only) as a source
   comment.
5. Selftests (§10.5 second half), in `clasimp/theory_tests/`
   (populate the TASK_06 scaffold, modeled on
   `rules/theory_tests/`): persistence round-trip — export, reload,
   both stores populated; `remove_iff` retracts both; child-theory
   visibility; diamond merge.  Plus in-module tests that a
   `Theorem …[iff]` declaration immediately affects `the_claset()` and
   `srw_ss()`/`clasimp_ss()`.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/` and its
   `theory_tests/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green (theory_tests
   runs at its `!`-raised selftest level).
3. `tools/h4pedant/h4pedant` clean on touched directories.
4. No `"iff"` settype collision (guard in place); `remove_iff`
   retracts both derived views.

## Dependencies

TASK_10 (decision tree); TASK_06 (`theory_tests/` scaffold and build
wiring).
