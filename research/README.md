# Research reports underlying ../PLAN.md and ../PLAN_phase_0.md

Two report sets, both containing finer-grained (line-level) analysis
than the plans themselves:

- four reports produced 2026-07-14 by parallel research agents, prior to
  the owner-decision round and the writing of `../PLAN.md`;
- four `phase0-*` reports produced 2026-07-15 during the Phase 0
  planning round, prior to the D11–D13 owner decisions and the writing
  of `../PLAN_phase_0.md`.

Isabelle citations in these reports refer to `mirror-isabelle @ master`
as of 2026-07-14, which is exactly the snapshot vendored at
`../sources/` (commit `f7e02b7e1f311d9c41ee075d22ff788b3e0de6db`), so
all `file.ML:line` references resolve there.  Papers cited are archived
at `../papers/` (see `../papers/README.md` for slugs).  HOL4 citations
refer to this repository (worktree `isabelle-tactics`, HEAD at the time
`af5d4a63f`).

| Report | Covers |
|---|---|
| [isabelle-classical-reasoner.md](isabelle-classical-reasoner.md) | claset architecture, safe/unsafe step tactics, fast/best/slow/deepen, blast (tableau + reconstruction), auto/force/fastforce/clarsimp, attributes/[iff], aesop comparison; file/line index |
| [isabelle-simplifier-vs-simplib.md](isabelle-simplifier-vs-simplib.md) | Isabelle raw_simplifier internals (rrules, congs, loopers/solvers/subgoaler, simprocs, ordered rewriting), splitter algorithm, HOL4 simpLib architecture, feature-by-feature gap-analysis table |
| [isabelle-arith-algebra.md](isabelle-arith-algebra.md) | linarith/arith (Fast_Lin_Arith, lin_arith preprocessing, arith registry), presburger (Cooper pipeline, reflection status), algebra (Groebner certificates), semiring normalizer, Decision_Procs, argo/smt/metis context; HOL4 counterparts and gap table; literature techniques |
| [hol4-automation-inventory.md](hol4-automation-inventory.md) | full HOL4 automation inventory: build sequence, MESON/METIS/TacticToe/HolyHammer, simpLib modules, bossLib surface, arithmetic (Boulton/Omega/Cooper/RealArith), Grobner/Normalizer, quantifier tools, ThmSetData/ThmAttribute, tactic combinators, testing conventions; gaps vs the Isabelle tactic list |
| [phase0-typebase-hook.md](phase0-typebase-hook.md) | `TypeBase.register_update_fn`/`elts()` API, reload/replay via AncestryData, all in-tree hook clients (BasicProvers ×2, computeLib, Encode), relevant tyinfo accessors, non-datatype caveats |
| [phase0-hol4-term-nets.md](phase0-hol4-term-nets.md) | lookup semantics of `src/0/Net` and `src/1/Ho_Net` (match-mode only; wildcard disciplines), `mlibTermnet.unify` as the repo's only unify-mode lookup, survey of all other net structures, build bands |
| [phase0-isabelle-claset-seed-rules.md](phase0-isabelle-claset-seed-rules.md) | full correspondence table `HOL.thy:819–935` base claset rules ↔ HOL4 heap theorems (exact statements, boolScript.sml lines); which ~15 rule forms must be proved fresh; quantification irregularities |
| [phase0-lazyseq-backtracking.md](phase0-lazyseq-backtracking.md) | portableML `seq`/`seqmonad`, simp's `Sequence` (Paulson 1988 port), `mlibStream`, meson's CPS backtracking, jrhTactics types, goal/tactic/validation types and `VALID`/`VALIDATE` plumbing |
