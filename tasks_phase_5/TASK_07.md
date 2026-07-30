# TASK_07 — `linarithReplay` part 2: forward prover + tactic replay

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

TASK_06 (`mkthm`, atom generalization).

## Read first

- `.agent-files/PLAN_phase_5.md` §4.4 (forward prover and tactic
  replay blocks), §4.2 (`elim_neq` two-pass case-order contract),
  §11 (case-order drift risk).
- `.agent-files/sources/src/Provers/Arith/fast_lin_arith.ML:683–707`
  (`refute_tac`), `741–795` (`splitasms`/`fwdproof`/`prover`).
- Landed `linarithReplay` from TASK_06; `linarithSolve.sig`
  (`elim_neq`/`split_items`, `prove`).

## Work items

Extend `src/auto/linarith/linarithReplay.sml` + `.sig`:

1. **Forward prover** (backs `LINARITH_PROVE`/`LINARITH_CONV`/the
   reducer/the solver):
   - `splitasms`: build the `≠`-split tree by COMP-ing each
     splittable assumption against its *type's* `neqE` (by-type
     selection through the registry, matching TASK_02's `elim_neq`
     discipline; upstream 757–772);
   - `fwdproof`: recurse producing `F`-theorems per leaf and
     discharge the two case hypotheses (774–781);
   - `prover`: assume the negated conclusion, run `fwdproof`, close
     with `CCONTR`/`EQF_INTRO`/`EQT_INTRO` (784–793).
2. **Tactic replay**: per split-case `REPEAT` of the by-type `neqE`
   eliminations followed by resolution with the case's `mkthm`
   result (upstream `refute_tac` 683–707).  Case order must be a
   function of premise order only — guaranteed by the preserved
   two-pass `elim_neq` structure.
3. Selftest additions:
   - forward-prover checks at the ML level over num systems with
     `≠` premises (single and nested splits, up to the limit);
   - the §11 case-order test: permute `≠` premises (across types
     once instances exist — for now num-only permutations, extended
     later by the instances task) and assert both replay styles
     still succeed;
   - a tactic-replay smoke test applying the tactic form to explicit
     goals (through `Tactical.VALID`).

Note: the D62 public wrappers (`LINARITH_PROVE` etc.) belong to
`linarithLib` (TASK_08) — here expose the un-sugared engine entry
points they will wrap (naming per `.sig` review, e.g.
`fwd_prove : config -> thm list -> term -> thm` and
`refute_tac`-style tactic given decomposed premises).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; new forward/
  tactic replay tests pass, including the `≠`-permutation test.
- Both replay styles share `mkthm` and the by-type `neqE` selection;
  no duplicated case-splitting logic beyond the upstream
  tactic/forward split.
- Style rules respected; commit the work.
