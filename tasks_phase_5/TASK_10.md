# TASK_10 — `LINARITH_ss`, the `"lin_arith"` solver, cache; reducer tests

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

TASK_09 (complete `linarithLib` tactic surface; the shared
`selftest.sml` is also serialized through it).

## Read first

- `.agent-files/PLAN_phase_5.md` §6.1–6.2 (the spec), §8 item 5,
  §11 (cache-soundness risk).
- `src/num/arith/src/numSimps.sml:314–491` (`ARITH_REDUCER`,
  `CTXT_ARITH`, `dp_vars`, admission screens — the pattern being
  transposed).
- `src/portableML/Cache.sig` (RCACHE semantics: hypothesis-subset
  reuse of successes and failures).
- `src/simp/src/Traverse.sig:90–96` (ssolver record),
  `src/simp/src/simpLib.sig:106,163–172` and
  `simpLib.sml:1189–1207` (unsafe solver use).
- `.agent-files/sources/src/HOL/Tools/lin_arith.ML:945–959`
  (solver setup being mirrored; name string `"lin_arith"`).

## Work items

Extend `linarithLib` per PLAN_phase_5.md §6.1–6.2:

1. `CTXT_LINARITH : thm list -> conv` — the forward prover over
   context + goal (prove, else disprove), and
   `CACHED_LINARITH = Cache.RCACHE {capacity=2000, per_key_cap=50}`
   with `linarith_vars` = `decomp` atoms (generic `dp_vars`) and
   `check` accepting boolean `decomp`-relevant terms and `F`.
   `[arith]` facts join the *context argument* at each call — never
   baked in — so the cache's hypothesis-subset logic covers set
   growth.
2. `LINARITH_REDUCER`: `numSimps.ARITH_REDUCER` transposed —
   local-exception context; `addcontext` admits theorems whose
   conclusions `decomp` (post-`CONJUNCTS`), with `contains_forall`
   and triviality screens generalized from `numSimps.sml:314–343`;
   `apply` calls the cached context conversion.
3. `LINARITH_ss` = `named_merge_ss "LINARITH"` over one SSFRAG
   containing the reducer.  NOT added to any distribution simpset.
4. `linarith_solver : Traverse.ssolver` with name string
   `"lin_arith"` (greppable; source comment citing
   `lin_arith.ML:949`): `solve {context_thms, ...} tm` = forward
   prover on `context_thms @ arith_facts()` ⊢ `tm`.  Export the
   value only — registration into clasimp/aesop is TASK_11.
5. `clear_linarith_caches : unit -> unit`.
6. Reducer selftests (§8 item 5): side-condition discharge inside a
   conditional rewrite; context admission screens; cache behavior —
   `clear_linarith_caches`, and failure caching under context growth
   with an `[arith]` addition between calls (the §11 cache-soundness
   scenario: a goal that fails, then succeeds after the `[arith]`
   addition, proving stale failure entries don't block it).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; reducer and
  cache tests pass, including the `[arith]`-growth scenario.
- `.sig` now covers the full §12 freeze list for `linarithLib`.
- Style rules respected; commit the work.
