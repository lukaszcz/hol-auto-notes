# TASK_06 — `linarithReplay` part 1: `mkthm` + atom generalization; golden tests

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

TASK_02, TASK_03, TASK_04, TASK_05 (golden tests replay against the
num instance kit).

## Read first

- `.agent-files/PLAN_phase_5.md` §4.4 (first two blocks: atom
  generalization, `mkthm`), §8 item 2, §11 (replay/search
  misalignment risk — golden tests land BEFORE the tactic surface).
- `.agent-files/sources/src/Provers/Arith/fast_lin_arith.ML:355–508`
  (`mkthm` and helpers, incl. injection add-fallback 407–417,
  `mult_by_add` 419–445, `FalseE` escape 380–381/452–454, non-`F`
  warning text 498–502).
- `.agent-files/sources/src/HOL/Tools/lin_arith.ML:295–361`
  (upstream abstraction — superseded here; understand why, §4.4).
- `src/num/arith/src/Instance.sml`/`.sig` (`INSTANCE_T_CONV`
  pattern for atom generalization).
- Landed sigs: `linarithSolve.sig`, `linarithData.sig`,
  `linarithDecomp.sig`, the num instance module.

## Work items

Create `src/auto/linarith/linarithReplay.sml` + `.sig` (this task
delivers `mkthm` and atom generalization; the forward prover and
tactic replay are TASK_07 and extend this module):

1. **Atom generalization at entry** (recorded deviation from
   upstream's threaded abstraction): collect `decomp` atoms that are
   not variables/literals, abstract to fresh variables, prove the
   generalized sequent, instantiate back (`INSTANCE_T_CONV` pattern —
   reuse or adapt it; shared atoms dedup once globally).
2. **`mkthm : instance-env -> thm list -> injust -> thm`** per §4.4:
   - `Asm i` from the indexed assumption list; `Nonneg i` from the
     instance `nonneg`;
   - `LessD`/`NotLessD`/`NotLeD`/`NotLeDD` by MATCH_MP against kit
     lemmas;
   - `Added` via conj-premise `add_mono` (CONJ then first matching
     MATCH_MP) with the injection fallback exactly as upstream
     407–417 (lift one side through `hom` lemmas, retry);
   - `Multiplied` by specializing a `mult_mono` lemma to `mk_lit n`,
     discharging `0 < n` with `norm_conv` (EQT-elim), falling back
     to iterated addition (`mult_by_add`) as upstream 419–445;
     `=`-scaling via `AP_TERM` + `norm_conv` (no lemma needed);
   - after every `Added`: `norm_conv` on both relation arguments
     (`BINOP_CONV`) with the early-`False` escape;
   - final theorem must be `F` on the premises' hypotheses; a
     non-`F` result raises/warns with the upstream warning text
     under the `"linarith"` trace — never a silent fallback.
3. **Golden replay tests** (§8 item 2) in the core selftest: one
   goal per `injust` constructor per shipped kit slot — `Asm`,
   `Nonneg`, `LessD`, `NotLessD`, `NotLeD`, `NotLeDD`, `Multiplied`
   including the mult-mono-fails→`mult_by_add` fallback, `Added`
   (the injection-fallback case needs an injection pair — if only
   num is registered at this point, test the injection fallback with
   a synthetic instance/injection registered locally in the
   selftest, or defer that single case to the instances selftest
   with a TODO recorded in the test file).  Drive them by
   constructing `injust` values directly (or via
   `linarithSolve.prove` on hand-picked systems) and asserting
   kernel acceptance of the resulting `F` theorem.

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; golden tests
  pass and cover every `injust` constructor (with at most the
  injection-fallback case deferred, explicitly marked).
- Errors in replay are loud (trace/warning per upstream 498–502);
  no silent fallbacks.
- Style rules respected; commit the work.
