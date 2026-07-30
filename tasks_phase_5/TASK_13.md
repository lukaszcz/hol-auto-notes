# TASK_13 — Instance modules `intLinarith`/`realLinarith`/`ratLinarith` + instance selftests

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

TASK_12 (instances dir + lemmas), TASK_10 (reducer, so per-type
reducer behavior can be tested).

## Read first

- `.agent-files/PLAN_phase_5.md` §2.3 (all columns incl. injections
  row and the note that `ratSyntax` lacks `rat_of_int` term ops —
  build them in `ratLinarith`), §4.1 (record fields), §2.2
  (per-type evaluators/canonicalizers), §8 (instances selftest
  paragraph), §11 (load-order risk).
- The num instance module (TASK_05) as the worked example.
- `src/integer/intSyntax`, `src/real/realSyntax`,
  `src/rational/ratSyntax` sigs; `intReduce`, `RealField`/
  `RealArith`, `ratReduce`/`ratLib` for evaluators
  (`RAT_BASIC_ARITH_CONV` context: `src/rational/ratLib.sml:488`).
- `src/integer/intrealTheory` (int→real hom lemmas).

## Work items

1. `intLinarith.sml`: instance record — discrete = true; dest bundle
   from intSyntax (`dest_minus`/`dest_neg` present, `dest_div` NONE:
   int div/mod handled by `divmod_facts`, not field division); kit
   per §2.3 int column (incl. `INT_LT_LE1` as `lessD`, new `neqE`,
   `nonneg` = `INT_POS` for `&`-atoms); `norm_conv` from
   `intReduce.REDUCE_CONV` + `intSimps.ADDR_CANON_CONV`;
   `pre_split` = int min/max/abs rules; `divmod_facts` via
   `INT_DIVISION`/`INT_DIV_P`/`INT_MOD_P` with `c ≠ 0` decided by
   evaluation.  Register instance + num→int injection
   (`INT_INJ`/`INT_LE`/`INT_LT`/`INT_ADD`/`INT_MUL`) at load.
2. `realLinarith.sml`: dense; `dest_div` SOME (field); kit per §2.3
   real column; `norm_conv` from `RealField.REAL_RAT_REDUCE_CONV` +
   `realSimps.REALADDCANON`/`RealField.REAL_POLY_CONV` (choose and
   unit-test the minimal adequate combination); `pre_split` = real
   min/max/abs rules; no `divmod_facts`.  Register instance +
   num→real and int→real injections (per §2.3).
3. `ratLinarith.sml`: dense; field; kit per §2.3 rat column (the
   TASK_12 lemmas); build the missing `rat_of_int` term operations
   locally; `norm_conv` from `ratReduce`/`ratLib.RAT_CALC_CONV`
   family (unit-test the contract); no min/max/abs `pre_split`.
   Register instance + num→rat and int→rat injections.
4. Per-instance `norm_conv` contract unit tests (the §11 adequacy
   risk) BEFORE the batteries.
5. Instances `selftest.sml` (§8 instances paragraph): per-type
   batteries mirroring the num battery — int abs and
   `INT_DIV_P`-backed div/mod augmentation; real dense behavior (no
   rounding: e.g. `x < y ==> x < (x+y)/2`-style goals); rat goals
   `RAT_BASIC_ARITH_CONV` cannot do; mixed-type injection goals
   (num/int, int/real, num/rat, incl. the `Nonneg`-of-injected-atom
   strengthening); registration idempotence (re-load ⇒ warning, not
   duplication); the cross-type `≠`-premise permutation test
   (extends TASK_07's); `LINARITH_ss` reducer checks over int/real/
   rat side conditions.  Successes through `Tactical.VALID`; also
   complete the injection-fallback golden replay case if TASK_06
   deferred it.

## Acceptance criteria

- Instances directory `Holmake` green with all selftests passing;
  `bin/build -t --seq=tools/sequences/upto-auto` still green.
- No type-specific logic added to core modules — everything flows
  through the registry records.
- Style rules respected; commit the work.
