# Research reports underlying ../PLAN.md

Four reports produced 2026-07-14 by parallel research agents, prior to
the owner-decision round and the writing of `../PLAN.md`.  They contain
finer-grained (line-level) analysis than the plan itself.

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
