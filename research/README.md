# Research reports underlying the plans in `..`

Report sets, all containing finer-grained (line-level) analysis than
the plans themselves:

- four reports produced 2026-07-14 by parallel research agents, prior to
  the owner-decision round and the writing of `../PLAN.md`;
- four `phase0-*` reports produced 2026-07-15 during the Phase 0
  planning round, prior to the D11–D13 owner decisions and the writing
  of `../PLAN_phase_0.md`;
- four `phaseS-*` reports produced 2026-07-16 during the Phase S
  planning round, prior to the D14–D20 owner decisions and the writing
  of `../PLAN_phase_S.md`;
- three `phase12-*` reports produced 2026-07-16 during the Phase 1–2
  planning round, prior to the writing of `../PLAN_phase_1_2.md`;
- one `phase4-*` report produced 2026-07-28 during the Phase 4
  planning round, prior to the owner-decision round and the writing of
  `../PLAN_phase_4.md` (HOL4 citations refer to worktree HEAD
  `3bac17ef5`);
- three `phase5-*` reports produced 2026-07-30 during the Phase 5
  planning round, prior to the D59–D62 owner decisions and the writing
  of `../PLAN_phase_5.md` (HOL4 citations refer to worktree HEAD
  `7a8a286b5`).

Isabelle citations in these reports refer to `mirror-isabelle @ master`
as of 2026-07-14, which is exactly the snapshot vendored at
`../sources/` (commit `f7e02b7e1f311d9c41ee075d22ff788b3e0de6db`), so
all `file.ML:line` references resolve there.  (The `phase12-*` round
added further `src/Pure` files to the snapshot, fetched at the same
pinned commit; see `../sources/README.md`.)  Papers cited are archived
at `../papers/` (see `../papers/README.md` for slugs).  HOL4 citations
refer to this repository (worktree `isabelle-tactics`; HEAD `af5d4a63f`
for the 07-14/07-15 sets, `7dfd21f4f` for the 07-16 sets).

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
| [phaseS-isabelle-splitter.md](phaseS-isabelle-splitter.md) | `Provers/splitter.ML` algorithm (conclusion/assumption splits, lift theorem) + HOL4 mapping |
| [phaseS-isabelle-simploop.md](phaseS-isabelle-simploop.md) | subgoaler/solver/looper wiring in raw_simplifier/simplifier, safe-simp mode, `mut_impc` |
| [phaseS-simplib-compat.md](phaseS-simplib-compat.md) | repo-wide simpLib/Traverse/Cond_rewr compatibility survey (frozen records, call sites) |
| [phaseS-hol4-splitting-idioms.md](phaseS-hol4-splitting-idioms.md) | existing HOL4 split theorems and case-splitting idioms (RW_TAC, TypeBase, if-splitting) |
| [phase12-classical-search-port.md](phase12-classical-search-port.md) | exact semantics of classical.ML:578–732 + Pure/search.ML combinators + Thm.biresolution (lifting, elim consumption, match mode); Phase 1 goal-level mapping (design choices C1–C10); Phase 2 metavariable-engine requirements (E1–E11); wrapper-on-Vars analysis; numeric constants; upstream `safe_depth_tac` DETERM-inversion finding |
| [phase12-blast-port.md](phase12-blast-port.md) | reimplementation-grade spec of blast.ML: prototerm language/trail/unification, typargs + HOL4 encoding options, netMkRules/rule conversion, five-clause search cascade (penalties, md flags, prune, mayUndo), six-tactic reconstruction vocabulary + replay-instantiation analysis, limitations table, design choices A–M, Pelletier Table 1 + selftest spec |
| [phase4-aesop-engine.md](phase4-aesop-engine.md) | precise CPP'23 Aesop spec (tree/states/priorities, phases, safe goals, multi-rules, seven builders, discrimination-tree indexing, §4 metavariable algorithm: clusters/copying/postponed safe rapps/dropped mvars); verified inventory of the delivered Phase-0/2/3 substrate it maps onto (prio reservation, clasetNet dual-mode net, clasetMeta/clasetUnify/clasetGoal render-unrender, clasimp derived-simpset + [iff] template); feasibility mapping, HOL4-specific simplifications, gap list, freeze constraints, open decisions |
| [phase5-simp-substrate.md](phase5-simp-substrate.md) | delivered Phase-S extension points as-built: ssolver/subgoaler types and invocation sites (side conditions vs final residue), mk_tactic_solver semantics, looper hook, cond_depth plumbing, full splitLib API + programmatic-reuse verdict for linarith pre-splitting, extended SSFRAG/REDUCER records, the numSimps CTXT_ARITH/RCACHE pattern with a transposition recipe |
| [phase5-arith-theorem-inventory.md](phase5-arith-theorem-inventory.md) | verified per-type lemma inventory for the Fast_Lin_Arith kits (num/int/real/rat): add/mult monotonicity, discreteness, neqE sources, min/max/abs and sub/div/mod split material, injection homomorphisms, literal-evaluation conversions, the existing RealArith0 FM-with-Positivstellensatz machinery, rat build position, and the explicit to-prove gap list |
| [phase5-auto-layer-substrate.md](phase5-auto-layer-substrate.md) | src/auto substrate for Phase 5: D28 clasimp cache and D50 aesop_ss internals with exact linarith insertion points and invalidation caveats, ThmSetData settype/attribute pattern (aesop_simp vs split vs iff shapes), build/Holmakefile/selftest integration template, marker vocabulary and classify_simp_args, Docfiles format, and the verified stratification verdict forcing the two-directory layout |
| [phase12-hol4-substrate.md](phase12-hol4-substrate.md) | delivered Phase-0 API as-built; HOL4 unification survey (`FullUnify` verdict, no HOU anywhere); jrhTactics (no metavariable support); meson/metis search-then-replay pipelines incl. types-as-terms typargs precedent; rule-application tactic vocabulary; `VAR_EQ_TAC` vs hypsubst verified (4 deviations); assumption ordering/rotation gaps; term_size/heap findings; Pelletier absence; bounding/trace conventions |
