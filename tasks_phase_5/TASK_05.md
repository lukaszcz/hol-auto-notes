# TASK_05 — `linarithSeedScript` (num lemmas + seeds) and the num instance kit

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

TASK_03 (instance record type, `[arith_split]` settype), TASK_04
(decomp — the num instance is exercised through it).

## Read first

- `.agent-files/PLAN_phase_5.md` §2.3 (the num column and shared
  logic row of the theorem inventory — the authoritative list of
  what exists and what to prove), §4.1 (instance record fields),
  §7 (seed script items), §2.2 (canonicalizers/evaluators:
  `reduceLib.REDUCE_CONV`, `numSimps.ADDR_CANON_CONV`).
- `.agent-files/sources/src/HOL/Tools/lin_arith.ML:32–66`
  (`LA_Logic` — what the kit slots mean).
- `src/simp/src/splitLib.sig` (P-form rule shape the split seeds must
  satisfy).
- `src/auto/linarith/linarithData.sig`, `linarithDecomp.sig`.
- The theorem-search agent is available for locating existing num
  lemmas — use it before proving anything from scratch.

## Work items

1. `src/auto/linarith/linarithSeedScript.sml`: prove the num "prove"
   entries of PLAN_phase_5.md §2.3 —
   - `<`+`<` add-mono (no `LT_ADD2` exists) and the mixed
     `≤`+`<` / `<`+`≤` add-monos;
   - num `neqE` in the kit shape
     `x<>y ==> (x<y ==> F) ==> (y<x ==> F) ==> F`
     (from `LESS_CASES`);
   - P-form split rules for num `MIN`, `MAX` (facts
     `MIN_LE`/`MAX_LE`/`MIN_DEF`/`MAX_DEF` exist) and nat
     subtraction: `P (m−n) ⟺ (m<n ⟹ P 0) ∧ ∀d. m=n+d ⟹ P d`.
   Declare the split rules `[arith_split]`.  `[arith]` stays empty
   (Isabelle parity — §7).  Hook the script into the Holmakefile
   (OpenTheory block per §7 if not already present from TASK_03).
2. Num instance record (module `linarithNum.sml` inside the core dir,
   or a substructure of a core module — pick the simplest layout
   consistent with §3's module map, which has linarithLib doing the
   *registration* at load; the record itself can live in its own
   small module that linarithLib references):
   - `dest` bundle: numSyntax-based; `dest_minus = NONE`,
     `dest_neg = NONE`, `dest_div = NONE`, `dest_suc = SOME ...`;
     `dest_lit` covering numerals and SUC-towers; `mk_lit` via
     numSyntax; relations from numSyntax.
   - `kit`: per §2.3 num column (`LESS_EQ_LESS_EQ_MONO`, the new
     add-monos, `LESS_MONO_MULT`/`LT_MULT_LCANCEL`, `NOT_LESS`,
     `NOT_LESS_EQUAL`, `lessD` from `LESS_EQ`+`ADD1`, the new
     `neqE`, `nonneg` = `ZERO_LESS_EQ` specialization for every nat
     atom).
   - `norm_conv`: built from `reduceLib.REDUCE_CONV` +
     `numSimps.ADDR_CANON_CONV`; must meet the data-simpset contract
     (`fast_lin_arith.ML:87–89`): cancel common summands, reduce
     ground relations to T/F.  Add unit tests for this contract
     (PLAN_phase_5.md §11 "norm_conv adequacy" — test BEFORE replay
     trusts it).
   - `discrete = true`; `pre_split` = the proved num split rules;
     `divmod_facts` for `x DIV c`/`x MOD c` with literal `c`:
     decide `0 < c` by evaluation, specialize `DIVISION`.
3. Selftest additions: `norm_conv` contract tests; decomp over real
   num terms (register the num instance locally in the selftest for
   now if registration-at-load is deferred to linarithLib —
   registration wiring is TASK_08's; avoid double registration
   later).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; all §2.3 num
  "prove" entries proved and exported; split seeds validated by the
  `[arith_split]` shape check on declaration.
- Num `norm_conv` contract unit tests pass (contradictory `≤` to
  `F`, common-summand cancellation, ground relation decision).
- Style rules respected; commit the work.
