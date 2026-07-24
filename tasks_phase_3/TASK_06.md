# TASK_06 — `src/auto/clasimp/` scaffold, clasimpset, safe solvers

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

Plan task 06 (`PLAN_phase_3.md` §12 row 06, §4): create
`src/auto/clasimp/` with build wiring, and implement the clasimpset
(D28), the safe-solver stack, and the two simp tactics of the phase.

## Spec

Read first: `PLAN_phase_3.md` §4 (all), §0.1 (D28, D31);
`src/auto/CLAUDE.md`; `src/auto/blast/Holmakefile` (model);
`simpLib.sig:162,166,169,171,235–244`; `BasicProvers.sig:21,31,56` and
`BasicProvers.sml:1223–1245,1364`.

1. Scaffold: `src/auto/clasimp/Holmakefile` (`HOLHEAP =
   $(HOLDIR)/bin/hol.state0`, `selftest.exe`, `HOLSELFTESTLEVEL` tee,
   INCLUDES for rules/classical/blast/simp as needed), empty
   `theory_tests/` subdir (populated in TASK_11), `clasimpLib.{sig,sml}`
   skeleton, `selftest.sml`.
2. Build wiring: `tools/sequences/upto-auto` gains `src/auto/clasimp`
   after `src/auto/blast`, plus a `!src/auto/clasimp/theory_tests`
   line (leading `!` raises the selftest level at which the directory
   builds, `tools/build/buildutils.sml:188–192`), mirroring the
   delivered `!src/auto/rules/theory_tests`; same additions in
   `tools/sequences/more-theories`; `src/parallel_builds/core/
   Holmakefile` `SRCRELNAMES` line 5 alongside `auto/rules
   auto/classical auto/blast`.  `rules/theory_tests` is deliberately
   *not* in `SRCTESTDIRS`, so `clasimp/theory_tests` is not either.
3. Clasimpset (§4.1): private derived value

       val clasimp_ss : unit -> simpLib.simpset

   via `BasicProvers.make_simpset_derived_value` (stale-flag cached),
   = `srw_ss()` with `simpLib.set_cond_depth 40`, `++
   simpLib.split_ss`, and `simpLib.set_safe_solvers` of the stack
   below.
4. Safe-solver stack (§4.2, port of `simpdata.ML:146–151`): a
   `mk_tactic_solver` lift of FIRST of — assumption *matching* (goal
   α-equal to an assumption), reflexivity matching (`x = x`),
   `TrueI`-style matching (`T`), contradiction from an assumption
   matching `F`.  No metavariable instantiation, no resolution against
   arbitrary premises.  `set_safe_solvers` replaces the whole safe
   list; the unsafe list keeps delivered default behavior.
5. The two simp tactics (§4.3): `asm_full_simp` /
   `safe_asm_full_simp` = `GEN_GLOBAL_SIMP_TAC {safe = false/true}`
   at `concl_in_fixpoint = true`, `imp_rebuild = true`, with the
   shared `base : simptac_config` constant fixed by reading each flag
   (`{strip, elimvars, droptrues, oldestfirst}`) against Isabelle's
   `asm_full_simp_tac` semantics (mutual assumption rewriting,
   assumptions decomposed per `mksimps_pairs`); record the
   flag-by-flag comparison in a module comment (risk §13.3).  Exported
   or not per what later tasks need — keep module-private if possible.
6. Selftests: safe-solver unit tests (each of the four matchers fires;
   a goal needing instantiation is *not* closed — matching-only
   guard); `clasimp_ss` reflects an `augment_srw_ss` change
   (derived-value recomputation) and carries the splitter (an
   `if`/`case` split test) and cond-depth 40; mutual-simplification
   tests for `asm_full_simp` ported from the Phase-S D17 battery.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green (clasimp now
   in the sequence).
3. `tools/h4pedant/h4pedant` clean on `src/auto/clasimp/`.
4. Wiring matches item 2 exactly (incl. the `!` theory_tests lines and
   SRCRELNAMES placement; nothing added to `SRCTESTDIRS`).

## Dependencies

TASK_01 (mode-parameterized `GEN_GLOBAL_SIMP_TAC`).
