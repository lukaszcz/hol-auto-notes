# TASK_04 — `linarithDecomp`: registry-driven decomp/demult/poly

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

TASK_02 (`linarithSolve` decomp result type), TASK_03
(`linarithData` registry, instance/injection records).

## Read first

- `.agent-files/PLAN_phase_5.md` §4.3 (the spec), §4.1 (registry
  interfaces consumed), §2.1.
- `.agent-files/sources/src/HOL/Tools/lin_arith.ML:124–292`
  (`decomp`/`demult`/`poly` — the port target) and 199–201, 238–239
  (injection unwrapping).
- `src/auto/linarith/linarithSolve.sig` and `linarithData.sig` as
  landed by TASK_02/TASK_03.

## Work items

Create `src/auto/linarith/linarithDecomp.sml` + `.sig` per
PLAN_phase_5.md §4.3:

1. `poly`: walk `+`; `−` only where the instance provides
   `dest_minus` (num declines — the whole subtraction term becomes an
   atom, upstream 214–215); unary `−` via `dest_neg`; literals via
   `dest_lit` (must cover numerals and `SUC`-towers for num — that
   knowledge lives in the instance's `dest_lit`, not here); `*` and
   field `/` via `demult` (right-bracketing product normalization;
   division only when the divisor `demult`s to a literal, upstream
   165–184; divide-by-zero declines the atom); injection unwrapping
   via the injection registry; anything else is an atom in an
   `aconv`-keyed coefficient map (`Arbrat` coefficients).
2. Relation layer producing the TASK_02 decomp result type: `=`,
   `<`, `≤` and their negations; the carrier's instance is looked up
   by the relation's argument type; unregistered type ⇒ `NONE`.
3. `is_relevant : term -> bool` = `isSome o decomp`.
4. Unit tests in the linarith `selftest.sml`: decomposition of
   representative num terms once the num instance exists is deferred
   to the seed/instance task — here, test with a small *synthetic*
   instance record registered locally in the selftest (covering
   plus/mult/literal/atom paths, demult right-bracketing, division
   by literal vs non-literal, injection unwrap, negated relations,
   `is_relevant`), then deregister/ignore it (use a throwaway type,
   e.g. a locally defined one or an otherwise-unregistered type like
   `:word8`-free custom — keep the selftest self-contained).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; new decomp
  unit tests pass.
- No type-specific constants are hard-wired in `linarithDecomp` —
  everything routes through instance `dest` functions and the
  injection registry (the "no recognition shortcuts" rule).
- `.sig` exposes `decomp`, `poly`/`demult` as needed by replay and
  preprocessing (check §4.4/§5 consumers before choosing), and
  `is_relevant`.
- Style rules respected; commit the work.
