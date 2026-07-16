# Vendored Isabelle sources referenced by ../PLAN.md

Snapshot of the Isabelle source files that `.agent-files/PLAN.md` cites by
file and line number, so those references stay stable regardless of
upstream changes.

- Origin: https://github.com/isabelle-prover/mirror-isabelle
  (read-only mirror of https://isabelle.in.tum.de/repos/isabelle)
- Commit: `f7e02b7e1f311d9c41ee075d22ff788b3e0de6db`
  (master as of 2026-07-12; fetched 2026-07-14)
- Fetch URL pattern:
  `https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/f7e02b7e1f311d9c41ee075d22ff788b3e0de6db/<path>`
- License: Isabelle is distributed under a BSD-style license (see the
  `COPYRIGHT` file in the Isabelle distribution).  These files are kept
  verbatim, for reference only; no code from them is compiled into HOL4.

All line numbers cited in PLAN.md refer to these exact copies.
Verified anchors: `src/Provers/classical.ML:241` (`datatype claset`),
`src/Pure/raw_simplifier.ML:433` (`simp_depth_limit` = 40).

## Files

ML sources (paths as in the Isabelle repository):

| File | Cited for |
|---|---|
| `src/Provers/classical.ML` | claset, safe/unsafe steps, fast/best/slow/deepen, wrappers |
| `src/Provers/blast.ML` | tableau prover, reconstruction |
| `src/Provers/clasimp.ML` | auto/force/fastforce/clarsimp, addss/addSss, [iff] |
| `src/Provers/hypsubst.ML` | hypothesis substitution |
| `src/Provers/splitter.ML` | splitter-as-looper |
| `src/Provers/Arith/fast_lin_arith.ML` | generic linear arith engine (Farkas certificates) |
| `src/Pure/raw_simplifier.ML` | simplifier core (rrules, congs, loopers, solvers) |
| `src/Pure/simplifier.ML` | simplifier tactic layer, simprocs |
| `src/Pure/bires.ML` | rule kinds, netpairs, biresolution |
| `src/Pure/Isar/context_rules.ML` | intro/elim/dest attribute plumbing |
| `src/HOL/Tools/simpdata.ML` | HOL simplifier instantiation (mksimps, solvers) |
| `src/HOL/Tools/lin_arith.ML` | linarith preprocessing (min/max/abs/div/mod splitting) |
| `src/HOL/Tools/arith_data.ML` | extensible arith tactic registry |
| `src/HOL/Tools/groebner.ML` | algebra tactic (Groebner + certificates) |
| `src/HOL/Tools/semiring_normalizer.ML` | class-parametric ring normalization |
| `src/HOL/Tools/Qelim/cooper.ML` | presburger method (proof-producing Cooper) |

Added 2026-07-16 (same pinned commit; cited by
`../research/phase12-classical-search-port.md`):

| File | Cited for |
|---|---|
| `src/Pure/search.ML` | DEPTH_FIRST/DEPTH_SOLVE/BEST_FIRST/ASTAR/DEEPEN/ITER_DEEPEN |
| `src/Pure/tactical.ML` | ORELSE/APPEND/DETERM/REPEAT_DETERM1/FIRSTGOAL/COND semantics |
| `src/Pure/tactic.ML` | assume/eq_assume/biresolve/bimatch/make_elim tactics |
| `src/Pure/thm.ML` | Thm.biresolution/bicompose/lift_rule/(eq_)assumption |
| `src/Pure/drule.ML` | size_of_thm, revcut_rl, RSN/RS |
| `src/Pure/logic.ML` | lift_all/lift_abs, flatten_params, assum_problems |
| `src/Pure/term.ML` | size_of_term |
| `src/Pure/goal.ML` | SELECT_GOAL/restrict |
| `src/Pure/unify.ML` | HO unification, unify_search_bound |
| `src/Pure/pattern.ML` | pattern unification fast path |
| `src/Pure/library.ML` | make_order_list/untag_list (candidate ordering) |
| `src/Pure/General/alist.ML` | AList.update (wrapper list ordering) |
| `src/Pure/Isar/object_logic.ML` | atomize_prems_tac |

Theory files (cited with line numbers or as rule-corpus guides):

| File | Cited for |
|---|---|
| `src/HOL/HOL.thy` | Classical/Blast instantiation, base claset seed corpus |
| `src/HOL/Presburger.thy` | [presburger] preprocessing rule corpus |
| `src/HOL/Fields.thy` | field_simps corpus |
| `src/HOL/Groups.thy` | algebra_simps corpus |
| `src/Doc/Isar_Ref/Generic.thy` | isar-ref chapters on the Simplifier and Classical Reasoner |
| `src/HOL/Set.thy` | seeding-corpus guide (rule classifications to mine) |
| `src/HOL/List.thy` | seeding-corpus guide |
| `src/HOL/Map.thy` | seeding-corpus guide |
| `src/HOL/Examples/Groebner_Examples.thy` | ALGEBRA_TAC/RING_TAC benchmark corpus |
