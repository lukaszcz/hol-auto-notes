# TASK_03 — layer-wide insertion refactor (D30)

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

Plan task 03 (`PLAN_phase_3.md` §3.4): change the meaning of unmarked
theorems in `src/auto` tactic argument lists from
plain-as-unsafe-intro to **inserted as goal assumptions** (Isabelle's
chained-fact channel), centralized in `clasetLib` and consumed by
`classicalLib` and `tableauLib`.

## Spec

Read first: `PLAN_phase_3.md` §3.4, §0.1 (D30), §0.2 items 2–3;
`clasetLib.sml:864–898` (`add_plain_theorems`/`invocation_claset`);
`classicalLib.sml:251,258`; `tableauLib.sml:20,189,200`;
`markerLib.sig:54` region.

1. `clasetLib.invocation_claset` changes to

       val invocation_claset : claset -> thm list -> claset * thm list

   The `{prefix}` argument, `add_plain_theorems`, `next_extra_name`
   and the `__classical_extra_N`/`__blast_extra_N` naming disappear.
   It applies `process_claset_tags` and returns the tagged claset with
   the facts the caller must insert.
2. New helper:

       val invocation_facts : thm list -> thm list

   Unwraps content-bearing generic wrappers with
   `markerLib.dest_generic_simp_wrapper` (so `FAST_TAC [Once th]`
   inserts `th`) and drops the inert generic controls recognized by
   `markerLib.is_generic_simp_marker`.  The marker vocabulary stays
   owned by `markerLib`.
3. `classicalLib.public_raw` and `tableauLib`'s entry points insert
   the resulting facts as assumptions of the goal before the engine
   runs (validation via `PROVE_HYP`, standard `ASSUME_TAC` plumbing;
   the theorem is inserted as-is, universally closed).  For blast,
   inserted facts become branch formulas through the normal
   `fromSubgoal` translation.
4. Marker processing (`process_claset_tags`) is otherwise unchanged;
   explicit roles keep going through markers.
5. Selftest audit (grep-targeted; do not read the two suites
   end-to-end — the plan expects "a handful plus the F2 pair" of
   affected sites): in `src/auto/classical/selftest.sml` and
   `src/auto/blast/selftest.sml`, convert goals that relied on
   plain-as-intro to `Intro th`; re-express the F2 tests that assert
   generated `__classical_extra_N` rule names against insertion.  Add
   insertion regressions: plain-theorem insertion visible in the
   residue of a non-closing tactic; `FAST_TAC [Once th]`
   unwraps-and-inserts `th`.
6. Docfile updates for the Phase-1/2 tactics (insertion semantics)
   are **deferred to TASK_13** — do not edit `help/Docfiles` here.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/rules/`,
   `src/auto/classical/` and `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on the three touched directories.
4. No `__classical_extra_N`/`__blast_extra_N` naming machinery
   remains; grep confirms no in-tree caller still uses the old
   `invocation_claset` shape.

## Dependencies

TASK_02 (both edit `classicalLib`; serialize).
