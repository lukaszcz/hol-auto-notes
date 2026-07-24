# TASK_01 — `simpLib` mode-parameterized global simp (D31)

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

Plan task 01 (`PLAN_phase_3.md` §3.1): change `GEN_GLOBAL_SIMP_TAC` to
take a `simp_mode` first argument, mirroring D16's `GEN_SIMP_TAC`
shape, so clasimp can build a safe asm-full-simp (Isabelle's
`safe_asm_full_simp_tac`).

## Spec

Read first: `PLAN_phase_3.md` §3.1 and §0.1 (D31);
`PLAN_phase_S.md` (D16/D17 background); `src/simp/src/simpLib.sig`
(the `GEN_SIMP_TAC`/`GEN_GLOBAL_SIMP_TAC` region, `:221–244`).

1. New signature (replacing, not alongside):

       val GEN_GLOBAL_SIMP_TAC :
         simp_mode -> xsimptac_config -> simpset -> thm list -> tactic

2. Mode semantics identical to D16's on `GEN_SIMP_TAC`: the flag
   selects only the final-solver stack for tactic-level residue
   (`final_solver_tac`); traversal side-condition solving stays on the
   unsafe list; loopers still run.  In the global entry the mode
   applies to every constituent simp invocation's *final* solving —
   assumption passes and conclusion pass alike (Isabelle's
   `safe_asm_full_simp_tac` = same rewriting, different terminal
   solver, `simplifier.ML:361`, `:327`).
3. `global_simp_tac` keeps its signature, delegating with
   `{safe = false}` — zero behavior change for `gvs`/`gs` and every
   in-tree caller.  Known internal callers: `simpLib.sml:1673,1787`
   (definition and `global_simp_tac`); `src/simp/src/selftest.sml`
   (18 call sites, all through the local `xcfg` helper).  Re-grep the
   tree to confirm no other caller has appeared.
4. Selftests (`src/simp/src/selftest.sml`): extend `xcfg` to emit the
   mode, defaulting to `{safe = false}` (mechanical update of existing
   tests).  New tests: (a) safe mode leaves a goal unsolved that the
   unsafe final solver would close by instantiation; (b) safe mode
   still discharges rewrite side conditions using the unsafe list.
5. Add an amendment note to `PLAN_phase_S.md` §12 recording D31.

Note: `Holmake` in `src/simp/src` does not typecheck script-less
sources — `./selftest.exe` (and downstream theory builds) are the real
checks.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/simp/src/`, including the
   two new safe-mode tests.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on touched directories; no tabs, no
   trailing whitespace, < 80 columns.
4. `PLAN_phase_S.md` §12 carries the D31 amendment note.

## Dependencies

None.
