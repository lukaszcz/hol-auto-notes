# TASK_12 — Instances directory: build wiring + `linarithInstScript` (int/real/rat lemmas and seeds)

## Context

This task is part of Phase 5 of the Isabelle-tactics project: porting
Isabelle's `Fast_Lin_Arith` linear-arithmetic engine to HOL4 as a
generic, registry-driven decision procedure in `src/auto/linarith/`
(core) and `src/auto/linarith/instances/` (int/real/rat).  The
ultimate goals of the whole plan (`.agent-files/PLAN_phase_5.md`) are:

1. A faithful untrusted Fourier–Motzkin engine with Farkas-certificate
   (`injust`) trees and kernel replay in both tactic and forward styles.
2. Instance records for `num`, `int`, `real`, `rat` via a live
   in-memory registry (rat is a net-new capability).
3. Goal-level preprocessing per decision D59: relevance filtering,
   splitLib-driven operator splitting, div/mod fact-augmentation, NNF.
4. The D62 public surface (`LINARITH_TAC`, `SIMPLE_LINARITH_TAC`,
   `CFG_LINARITH_TAC`, `LINARITH_PROVE`, `LINARITH_CONV`), the
   `[arith]`/`[arith_split]` theorem sets, `LINARITH_ss`, and the
   `"lin_arith"` unsafe solver wired into clasimp and aesop (D56).
5. Selftests (unit, per-instance, persistence, strength corpus) and
   user documentation.

Quality is judged by resulting automation strength — general,
principled, extensible; no recognition shortcuts.  Any work done in
this task must be a step toward these goals, **but the plan goals
above are NOT this task's acceptance criteria** — only the criteria
listed below are.

## Depends on

TASK_09 (core surface and settypes complete; per D60 the instances
directory sits outside `upto-auto`, so its build is validated
per-directory).

## Read first

- `.agent-files/PLAN_phase_5.md` §0 (D60), §2.3 (int/real/rat
  columns — the authoritative existing-lemma/"prove" inventory,
  incl. the injections row), §7 (instances Holmakefile,
  `linarithInstScript` items, SRCRELNAMES).
- `src/integer/`, `src/real/`, `src/rational/` theorem sources as
  needed to locate cited lemmas (use the theorem-search agent before
  proving anything).
- `src/simp/src/splitLib.sig` (P-form shape).
- Core linarith Holmakefile (pattern) and
  `src/parallel_builds/core/Holmakefile`.

## Work items

1. Create `src/auto/linarith/instances/` with Holmakefile per §7:
   `INCLUDES = .. ../../integer ../../real ../../rational` (plus
   whatever those pull in), selftest scaffold
   (`linarith-instances-selftest.log`, placeholder `selftest.sml`),
   OpenTheory block for the theory script, `EXTRA_CLEANS`.  NOT
   added to `upto-auto` (D60).  Add `auto/linarith/instances` to
   `src/parallel_builds/core/Holmakefile` `SRCRELNAMES`.
2. `linarithInstScript.sml` proving the §2.3 "prove" entries for
   int/real/rat:
   - int: mixed add-monos (from `INT_LT_ADD2`/`INT_LE_LT`), `neqE`
     (from `INT_LT_TOTAL`), min/max P-form iffs + split rules (only
     weak `INT_MIN_LT`/`INT_MAX_LT` exist), abs split rule (from
     `INT_ABS`);
   - real: `neqE` (from `REAL_LT_TOTAL`), min/max/abs P-form split
     rules (`REAL_MIN_LE`/`REAL_MAX_LE`/`min_def`/`max_def`/
     `ABS_BOUNDS`/`abs` exist);
   - rat: `<`+`<` and mixed add-monos, ≤-scaling
     (`RAT_LEQ_LMUL_POS` analogue), `neqE` (from `RAT_LES_TOTAL`),
     nonneg `0 ≤ &n` (from `RAT_OF_NUM_LEQ`).  No rat
     min/max/abs (constants don't exist — out of scope).
   Declare the int and real split rules `[arith_split]`.
3. Validate the build per-directory (`Holmake` in the instances dir;
   check the CLAUDE.md band note — this directory is post-boss
   parallel band, so plain `Holmake` applies) and via
   `src/parallel_builds`.

## Acceptance criteria

- Instances directory builds green standalone (`Holmake` incl. the
  theory script and placeholder selftest);
  `bin/build -t --seq=tools/sequences/upto-auto` stays green
  (core untouched or trivially touched).
- All §2.3 int/real/rat "prove" entries proved with the exact slot
  semantics (kit shapes: conj-premise add-monos, `neqE` shape
  `x<>y ==> (x<y ==> F) ==> (y<x ==> F) ==> F`); split rules pass
  the `[arith_split]` shape validation.
- Style rules respected; commit the work.
