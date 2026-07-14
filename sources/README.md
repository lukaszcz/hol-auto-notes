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

Theory files (cited with line numbers or as rule-corpus guides):

| File | Cited for |
|---|---|
| `src/HOL/HOL.thy` | Classical/Blast instantiation, base claset seed corpus |
| `src/HOL/Presburger.thy` | [presburger] preprocessing rule corpus |
| `src/HOL/Fields.thy` | field_simps corpus |
| `src/HOL/Groups.thy` | algebra_simps corpus |
| `src/Doc/Isar_Ref/Generic.thy` | isar-ref chapters on the Simplifier and Classical Reasoner |
