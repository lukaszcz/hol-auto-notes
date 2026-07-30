# TASK_09 — `linarithLib` part 2: D59 preprocessing pipeline, `LINARITH_TAC`/`CFG_LINARITH_TAC`, num battery

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

TASK_08 (`linarithLib` core surface).

## Read first

- `.agent-files/PLAN_phase_5.md` §0 (D59), §5 (the pipeline spec —
  authoritative), §4.5, §8 item 3, §11 (preprocessing-loops risk).
- `.agent-files/sources/src/HOL/Tools/lin_arith.ML:107–114`
  (nnf corpus), `364–441` (split-limit semantics and trace message
  439–441), `547–718` (the upstream div/mod splits this design
  replaces), `762–772` (`filter_prems_tac`, notE closer), `898–942`
  (`tac` — the semantics being mirrored on the real goal).
- `src/simp/src/splitLib.sig` (`SPLIT_TAC`/`SPLIT_ASM_TAC`, cmap
  hoisting).
- Landed `linarithLib` and other linarith sigs.

## Work items

Extend `src/auto/linarith/linarithLib.sml` + `.sig` per
PLAN_phase_5.md §5:

1. Pipeline steps (after TASK_08's insertion + negation):
   - **Relevance filter**: drop premises that are neither
     `is_relevant` nor connective/quantifier shells over relevant
     leaves; filtered premises never re-enter.
   - **Split fixpoint**: rule set = `arith_split_thms()` ∪ per-call
     `Split` rules ∪ each registered instance's `pre_split`; one
     splitLib pack per round, cmap hoisted once per invocation;
     rounds bounded by `#split_limit cfg`; exceeding fails with the
     upstream trace message (`lin_arith.ML:439–441`).  After each
     round: NNF of new premises with the fixed rewrite list
     (`imp_conv_disj`, de Morgan, `NOT_FORALL`/`NOT_EXISTS`,
     `NOT_NOT`), conj/disj/exists flattening (disjunctions branch
     subgoals), and the `notE + assumption`
     immediate-contradiction closer.
   - **div/mod fact-augmentation** (§5 step 5): for each `decomp`
     atom `x DIV c`/`x MOD c` (num; int comes with instances) with
     literal divisor, decide the guard by evaluation and
     `ASSUME_TAC` the `DIVISION` specialization, div/mod terms left
     as atoms; iterate to fixpoint over nested divisors, counted
     against `split_limit`; mark processed atoms (no loops);
     non-literal divisors untouched.  Route through the instance's
     `divmod_facts` field — no num-specific code in the pipeline.
2. `CFG_LINARITH_TAC : linarith_config -> thm list -> tactic` =
   insertion, pipeline, then per-subgoal SIMPLE-core;
   close-or-fail (FORCE-family semantics, D34).
   `LINARITH_TAC = CFG_LINARITH_TAC default_config`.  `Split th`
   arguments accepted here (validated).
3. Num tactic battery (§8 item 3): discreteness
   (`x < y ==> x + 1 <= y` uses); `≠`-splitting up to and at
   `neq_limit` (boundary: exceeded ⇒ `≠` premises ignored, not
   failure); MIN/MAX-free goals; nat-subtraction splits; DIV/MOD
   augmentation goals (`0 < n ==> n MOD 3 < 3` etc.); `Split`
   marker; marker rejection; `CFG_` limit overrides; a
   `SIMPLE_` vs full strength difference witness (a goal only the
   full tactic proves).  Successes through `Tactical.VALID`.

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; the full num
  battery passes.
- The forward/reducer path (`PROVE`/`CONV`) still performs none of
  pipeline steps 3–5 (upstream `do_pre = false` parity) — assert by
  test that `LINARITH_PROVE` does not prove a goal needing a MIN
  split while `LINARITH_TAC` does.
- Split fixpoint and div/mod augmentation both provably bounded
  (counted against `split_limit`; tests exercise the bound).
- `.sig` now matches the §12 freeze list minus
  `LINARITH_ss`/`linarith_solver`/`clear_linarith_caches` (TASK_10).
- Style rules respected; commit the work.
