# HOL4 Proof-Automation Inventory (for Isabelle-style tactics)

> Research report, 2026-07-14.  One of four reports underlying
> `../PLAN.md`.  Produced by exploration of this repository
> (worktree `isabelle-tactics`, HEAD `af5d4a63f`).  See `README.md`
> for the report index.

Repo root: `/home/lukasz/dev/HOL/worktrees/isabelle-tactics`. All paths absolute-relative to that root.

## Build-sequence orientation (what's in the default build)

Default build driver: `tools/build/build-sequence` → `#include`s `sequences/kernel`, `sequences/core-theories`, `more-theories`, `large-theories`, `final-examples`.

- `tools/sequences/base-hol` (pulled in via `core-theories`) builds, in order: `src/compute/src`, `src/taut`, `src/refute`, `src/simp/src`, `src/metis`, `src/meson/src`, `src/basicProof`, `src/tfl/src`, `src/num/{theories,reduce,arith,termination}`, `src/unwind`, `src/pred_set/src`, `src/quantHeuristics`, `src/boss` → `bin/hol`.
- `tools/sequences/core-theories` (top of file) builds, all tagged `[poly]` (Poly/ML only): `src/AI`, `src/AI/sml_inspection`, `src/AI/proof_search`, `src/AI/machine_learning`, `src/tactictoe/src`, `src/tactictoe/selftest`, `src/holyhammer`. So **TacticToe and HolyHammer ARE in the default Poly/ML build** but are not part of `bossLib`; they are separate opt-in libraries.
- `integer`, `real`, `rational`, `algebra`, `transfer`, `coalgebras`, `res_quan` are built via `src/parallel_builds/core/Holmakefile` (`SRCRELNAMES`), reached from `final-examples`. So they are in the default build but downstream of `bossLib`.

---

## 1. First-order provers

**MESON** — `src/meson/src/`
- `mesonLib.{sig,sml}`: "Version of the MESON procedure a la PTTP" (model elimination). Tunable refs: `depth` (depth-vs-inference bound), `prefine`, `precheck`, `dcutin`, `skew`, `cache`, `chatting`, `max_depth` (default 30). Core: `GEN_MESON_TAC min max step thms`, `ASM_MESON_TAC = GEN_MESON_TAC 0 (!max_depth) 1`. **Iterative deepening** of inferences or depth (comment at `mesonLib.sml:583`; `solve_goal`, `SIMPLE_MESON_REFUTE`). Tries all support clauses each ID run.
- `Canon_Port.{sig,sml}`: CNF/prenex/skolemization canonicalization (`PREMESON_CANON_TAC`).
- `jrhTactics.{sig,sml}`: Harrison-style tactic state plumbing used by MESON.

**METIS** — `src/metis/`
- `metisTools.{sig,sml}`: HOL interface. `METIS_TAC`, `METIS_PROVE`, and typed/higher-order variants `{FO,FOT,HO,HOT,FULL}_METIS_TAC`; heuristic `METIS_TAC` auto-picks. Params record `{interface, solver, limit}`.
- `folTools`, `folMapping`: HOL↔first-order translation and **proof reconstruction** (README `src/metis/README`: 4-step pipeline — CNF, map to FOL, refute, translate back).
- `mlib*` (≈40 files): the standalone Metis prover — `mlibResolution`, `mlibMeson`, `mlibClause`, `mlibClauseset`, `mlibSubsume`, `mlibTermorder` (ordered paramodulation), `mlibSupport`, `mlibMeter` (limits). Combines model elimination + resolution.
- `normalForms.{sig,sml}` + `normalFormsScript.sml`: CNF/DNF/skolemization theory used by both metis and (indirectly) Grobner canonicalization.

**bossLib exposure** — `src/boss/bossLib.sml`: `METIS_TAC`/`metis_tac`=`metisLib.METIS_TAC`; `PROVE_TAC`/`prove_tac` and `PROVE` come from `BasicProvers` (`GEN_PROVE_TAC` wraps MESON — see `src/basicProof/BasicProvers.sig:13-16`).

**TacticToe** — `src/tactictoe/src/` (`tacticToe.{sig,sml}`, `tttLearn`, `tttEval`, `tttInfix`): learned tactic selection; search infra in `src/AI/proof_search/` (`psMCTS` Monte-Carlo tree search, `psBigSteps`, `psMinimize`, `psTermGen`) and `src/AI/machine_learning/` (`mlReinforce`, etc.). `src/AI/aiLib.{sig,sml}` general utilities.

**HolyHammer** — `src/holyhammer/`: exports to external ATPs (`hhExportFof/Tf0/Th0/...`), `hhReconstruct`, `holyHammer.{sig,sml}`, `provers/`. Depends on external ATP binaries.

---

## 2. Simplification — `src/simp/src/`

Self-documented in `src/simp/src/notes.md` and `MANIFEST` (read them; they define simpset/ssfrag/reducer/preorder/travrules/congproc precisely). Modules and roles:

- `simpLib.{sig,sml}`: the simpset/ssfrag data structures and the assembly. `SSFRAG {name, convs, rewrs, ac, filter, dprocs, congs}`. Simpset = `{mk_rewrs, net (HO term-net of conv), dprocs (reducers), travrules}`. Combinators: `++` (add frag), `&&` (add thms), `-*`/`remove_simps`, `merge_ss`, `mk_simpset`, `partition_ssfrags`, `add_weakener`, `add_relsimp`, `named_rewrites`, `register_frag`/`lookup_named_frag`. Simptac config record for `global_simp_tac` (elimvars/strip/droptrues → `gs`/`gvs`).
- `Traverse.{sig,sml}`: the traversal engine and the **reducer** interface (context via existential-type exceptions; `apply` gets context/solver/stack/conv/relation/term). Order: repeat high-priority equality rewrites, then descend, then decision procedures/weakeners bottom-up.
- `Travrules.{sig,sml}`: preorders (reflexive+transitive relations, `EQ_tr`), standard + weakening congprocs.
- `Opening.{sig,sml}`: `CONGPROC` — descent under congruence rules; reprocess flag for non-variable assumptions.
- `Cond_rewr.{sig,sml}`: rewriting-at-a-point (like `REWR_CONV`), **conditional/side-condition** rewriting, permutative (ordered) rewrites, and `mk_cond_rewr` (thm→rewrite normalization, e.g. `p/\q → [p,q]`).
- `Cache.{sig,sml}`: caching for context-aware decision procedures (`RCACHE`).
- `Unwind.{sig,sml}`: one-point quantifier eliminations (`?x. P x /\ x=4 → P 4`). **This is the closest existing thing to Isabelle's one-point rules.**
- `Satisfy.{sig,sml}` + `SatisfySimps.{sig,sml}`: existential-goal solving by unification against context → `SATISFY_ss`/`SFY_ss` (quantifier-instantiation reducer). `Sequence.sml` (lazy lists) and `Unify.sml` (FO unification) support it.
- `boolSimps.{sig,sml}`: bool rewrites + congruences (implication, COND, conjunction) — `bool_ss`, `BOOL_ss`, `CONJ_ss`, `DISJ_ss`, `DNF_ss`, `ETA_ss`.
- `combinSimps`, `pureSimps` (`pure_ss`, wraps in BOUNDED/UNBOUNDED tags), `congLib` (standalone congruence-rule rewriting), `Trace` (verbosity).

**Stateful simpset & registration** — `src/basicProof/BasicProvers.sml`:
- `srw_ss()` is the global stateful simpset. Built/merged via `ThmSetData.export_with_ancestry {settype="simp",...}` (`BasicProvers.sml:1206`), which auto-registers the **`[simp]` theorem attribute**. Deltas: `ADD_SSFRAG`/`REMOVE_RWT`; merging across theories handled by the ancestry mechanism (`merge_simpsets`, `apply_logged_updates`, `set_simpset_ancestry`).
- User API (`BasicProvers.sig`): `export_rewrites`, `augment_srw_ss`, `diminish_srw_ss`, `delsimps`/`temp_delsimps`, `thy_ssfrag`, `thy_simpset`, `SRW_TAC`, `RW_TAC`.
- `DefnBase` (`src/coretypes/DefnBase.{sig,sml}`) holds congruences (`add_cong`, `export_cong`) and `one_line_ify` (→ `oneline` in bossLib); `DefnBaseCore` (`src/1/`) registers defn/induction set data.

**Decision-procedure hook** = a `Traverse.reducer` packaged by `simpLib.dproc_ss`. Canonical example: `ARITH_ss` (§4).

---

## 3. bossLib surface — `src/boss/bossLib.{sig,sml}`

- Simp family: `simp = stateful asm_simp_tac`, `rw = stateful (PRIM_SRW_TAC ...)`, `fs = stateful full_simp_tac`, `rfs`=rev_full_simp, `gs`/`gvs`/`gns`/`gnvs`/`rgs` (via `global_simp_tac` config: `gvs` elimvars=true → **variable-eliminating simp**), `csimp`/`dsimp` (CONJ_ss/DNF_ss), `lrw`/`lfs`, `SRULE`/`SCONV`. Lower-level `SIMP_TAC`/`ASM_SIMP_TAC`/`FULL_SIMP_TAC` re-exported from simpLib.
- Provers: `METIS_TAC`/`metis_tac`, `PROVE_TAC`, `DECIDE`/`DECIDE_TAC`/`decide_tac` (= `numLib.DECIDE`, §4), `PROVE`/`METIS_PROVE`.
- Simpsets: `pure_ss`, `bool_ss`, `std_ss`, `arith_ss` (`= numLib.arith_ss ++ PMATCH_SIMP_ss`), `list_ss`, `srw_ss()`, `boss_ss` (srw+LET+ARITH). Frags: `ARITH_ss`, `CONJ_ss`, `DISJ_ss`, `DNF_ss`, `ETA_ss`, `QI_ss`, `SFY_ss`, `SQI_ss`.
- Case/induction: `Cases`, `Cases_on`, `Induct`, `Induct_on`, `recInduct`, `completeInduct_on`, `measureInduct_on`, `namedCases[_on]`, `PairCases[_on]`, `CASE_TAC`/`TOP_CASE_TAC`/`FULL_CASE_TAC`/`EVERY_CASE_TAC` — all from `BasicProvers`. `CaseEq`/`AllCaseEqs`/`CasePred` helpers.
- Eval: `EVAL`/`EVAL_TAC`/`EVAL_RULE`/`EVALn` (computeLib reflection).
- Definitions: `Define`/`xDefine`/`tDefine`/`Hol_defn`/`WF_REL_TAC`, `Datatype`, `Hol_reln`/`Hol_coreln` (inductive relations).
- Sets: `SET_TAC`/`ASM_SET_TAC`/`SET_RULE` (from `pred_setLib`). Quant: `QI_TAC`, `GEN_EXISTS_TAC`, and the whole `Q.*` quotation-tactic suite (`qexists`, `qspec_then`, `qpat_x_assum`, `qmatch_*`, `qabbrev_tac`...).
- intLib/realLib hooks are NOT auto-loaded by bossLib; `intLib`/`realLib` are separate opens.

---

## 4. Arithmetic

**Naturals** — `src/num/arith/src/` (Boulton's linear-arith `ARITH_CONV`):
- `Arith.{sig,sml}`: `ARITH_CONV`, `FORALL_ARITH_CONV`, `EXISTS_ARITH_CONV`, `is_presburger`, `non_presburger_subterms`, prenex/normalization drivers.
- Algorithm: `Sup_Inf.{sig,sml}` implements the **Sup-Inf / shadow-bound method** (`Bound`, `Max_bound`, `Min_bound`, `Pos_inf`, `Neg_inf`, `SUP_INF`); `Norm_arith`/`Norm_ineqs`/`Norm_bool`/`Prenex`/`Sub_and_cond` (normalization), `Solve`/`Solve_ineqs`/`Sol_ranges`, `Term_coeffs`, `Theorems`, `Rationals`. `GenPolyCanon`/`GenRelNorm`/`NumRelNorms` polynomial canonicalizers.
- `numSimps.{sig,sml}`: the **`ARITH_ss` reducer**. `CTXT_ARITH` (context-aware), `CACHED_ARITH` via `RCACHE{capacity=2000,per_key_cap=50}`, `ARITH_REDUCER` (a `Traverse.reducer`), `is_arith`/`is_arith_thm`/`is_arith_asm` predicates. `ARITH_ss = ARITH_RWTS_ss ++ ARITH_DP_ss`; also `old_ARITH_ss`. `SUC_FILTER_ss`, redc/ground reducers.
- `numLib.sml`: `DECIDE = ARITH_PROVE orelse TAUT_PROVE`; `DECIDE_TAC = (UNDISCH arith asms THEN ARITH_TAC) ORELSE TAUT_TAC`. `ARITH_CONV = Arith.ARITH_CONV`. So **`DECIDE` is the "cooperating" linear-nat + propositional prover**.

**Integers** — `src/integer/`:
- Two Presburger engines: **Omega** (`Omega.{sig,sml}`, `OmegaMLShadow`, `OmegaMath`, `OmegaSymbolic`, `OmegaSimple`, `OmegaShell` — the Omega test / omega shadow) and **Cooper** (`Cooper`, `CooperCore`, `CooperMath`, `CooperShell`, `CooperSyntax`, `CSimp` — Cooper's quantifier elimination). `jrhCore` (Harrison core), `DeepSyntaxScript`.
- **Unified entry** `IntDP_Munge.{sig,sml}`: `BASIC_CONV name conv` normalizes then applies a chosen DP; `conv_tac` pulls num/int assumptions and dispatches. `dealwith_nats` maps nat subgoals into int. `is_presburger`/`non_presburger_subterms`.
- `intLib.{sig,sml}`: user entry — `ARITH_CONV/TAC/PROVE = Omega.OMEGA_*` (default = Omega); `COOPER_CONV/TAC/PROVE` (Cooper); `INT_ARITH_ss`, `int_ss`, `prefer_int`. **Ring for integers**: `INT_POLY_CONV`, `INT_RING`, `INT_RING_TAC`, `int_ideal_cofactors`, `INTEGER_TAC`/`INTEGER_RULE` (ideal-membership via Grobner, §5). `intReduce`/`intSimps` ground reduction + simp frag.

**Reals** — `src/real/`:
- `RealArith.{sig,sml}` (+ `RealArith0`): **Positivstellensatz-based** linear real arith (`positivstellensatz` datatype, `REAL_LINEAR_PROVER`, `mk_real_arith_tac`), ported from HOL-Light. `NLArith.{sig,sml}` nonlinear, `SOSLib.{sig,sml}` sum-of-squares.
- `RealField.{sig,sml}`: rational-literal calculation (HOL-Light `calc_rat.ml`) — `REAL_RAT_*_CONV`.
- `realLib.{sig,sml}`: `REAL_ARITH`/`REAL_ARITH_TAC`/`REAL_ASM_ARITH_TAC`, `real_ss`.
- `realSimps` under `src/real/` (real simp frags); `bitArithLib`, `isqrtLib`.

Also `src/rational/` (ratLib), `src/HolSmt` (external SMT), `src/HolQbf`, `src/HolSat` (propositional/SAT) exist but are not in bossLib.

---

## 5. Algebra / ring / Gröbner

- **Gröbner basis: EXISTS.** `src/num/reduce/src/Grobner.{sig,sml}` — generic Buchberger algorithm ported from HOL-Light `grobner.ml` (Chun Tian, 2022). `grobner_basis`, `grobner_interreduce`, Buchberger's 2nd criterion, `grobner_refute`, `grobner_weak`, `grobner_ideal` (ideal membership), `grobner_strong`. Solves universal theory of commutative cancellation semirings char 0. Comment notes it does not handle "all rings."
- **Ring normalizer:** `src/num/reduce/src/Normalizer.{sig,sml}` — `SEMIRING_NORMALIZERS_CONV` (HOL-Light `normalizer.ml`): canonical polynomial form from semiring axiom theorem, gives `POLYNOMIAL_{ADD,MUL,NEG,SUB,POW}_CONV`, `NUM_NORMALIZE_CONV`. `normalizerScript.sml`/`normalizerTheory` provides the axiom schema. `Boolconv` supporting conversions.
- **Instantiations of the ring machinery:** `intLib.INT_RING`/`INT_POLY_CONV` (§4) and `RealField` use `Normalizer`+`Grobner`. `src/num/reduce/src/reduceLib` = `computeLib`-style ground arithmetic (`ADD_CONV`, `MULT_CONV`, etc.).
- **Abstract algebra theories:** `src/algebra/base/` (`monoidScript`, `groupScript`, `numberScript`, `primeScript`, `combinatoricsScript`) and `src/algebra/construction/` (`groupScript`, `monoidScript`, `ringScript`, `jcLib`). These are **theories, not decision procedures** — no `RING_TAC`/`ringLib` user tactic.
- **Reflection:** `src/compute/src/` — `computeLib.{sig,sml}` (`CBV_CONV`, compsets), `clauses`, `equations`, `groundEval`, `compute_rules`. `[compute]` attribute registered via `ThmSetData.new_exporter` at `computeLib.sml:393`. `EVAL`/`EVAL_TAC` in bossLib.

**GAP:** no general `RING_TAC`/`FIELD_TAC` exposed for arbitrary user-defined rings (only int/real/complex-style instances); Grobner is only wired into int/real, not a generic user-facing tactic like Isabelle's `algebra`/`ring`.

---

## 6. Quantifier / misc automation & hypothesis substitution

- `src/quantHeuristics/`: `quantHeuristicsLib` (+ `Base`, `Simple`, `Parameters`, `FunRemove`, `Abbrev`, `Tools`) — heuristic quantifier instantiation → `QI_ss`, `SQI_ss`, `QUANT_INST_ss`. `ConseqConv.{sig,sml}` — **consequence conversions** (strengthen/weaken `|- t' ==> t`), the nearest thing to directed intro/elim reasoning; `DEPTH_CONSEQ_CONV`.
- `src/unwind/`: `unwindLib` (hardware-style existential unfolding); note the simplifier's own `Unwind.sml` (§2) is the one used by `simp`.
- `src/pred_set/src/`: `pred_setLib` (`SET_TAC`/`ASM_SET_TAC` = MP all asms then MESON-backed set reasoning), `PGspec`/`PFset_conv`/`PSet_ins` conversions, `pred_setSimps`.
- **Hypothesis substitution (Isabelle `hyp_subst_tac` analogue): EXISTS.** `BasicProvers.VAR_EQ_TAC`/`var_eq_tac` (`src/basicProof/BasicProvers.sml:842-856`): uses `Tactic.eliminable` + `VSUBST_TAC` to eliminate an assumption `x = e`. `REPEAT VAR_EQ_TAC` is invoked inside `STP_TAC`/`RW_TAC`/`SRW_TAC` case handling (lines 1032-1079). `gvs`/`gnvs` (bossLib, elimvars=true) perform var-elimination during simp via `global_simp_tac`.
- `src/transfer/`: `transferLib`/`liftLib` (Isabelle-`transfer`-like relational transfer). `src/coalgebras/` present. `src/refute/` (`refuteLib`, `Canon`, `AC`) — refutation/CNF utilities. `src/res_quan` restricted quantifiers.

---

## 7. Rule/attribute infrastructure

- `src/1/ThmSetData.{sig,sml}`: named theorem-set persistence. `new_exporter {settype, efns}` and `export_with_ancestry {settype, delta_ops}` — the latter also **auto-registers a same-named `[attribute]`** (`ThmSetData.sml:228,294`). `setdelta = ADD (name,thm) | REMOVE`. Prebuilt shapes: `export_list`, `export_alist`, `export_simple_dictionary` (with `*_withflag_thms`). Deltas persisted through `Theory.LoadableThyData.t`.
- `src/1/ThmAttribute.{sig,sml}`: attribute registry. `register_attribute (name, {localf, storedf})`, `reserve_word`, `is_attribute`, `all_attributes`, `extract_attributes` (parses `name[attr1,attr2]` in `Theorem`/`Definition` syntax), `define_abbreviation`. Reserved: `induction`; boolLib reserves `local`, `unlisted`, `allow_rebind` (`src/1/boolLib.sml:227`).
- Existing attributes: `[simp]` (BasicProvers), `[compute]` (computeLib), `[defn]`/`[induction]`/congruence sets (DefnBaseCore, DefnBase), plus `local`/`unlisted`.
- **To add `[intro]`:** call `ThmSetData.export_with_ancestry {settype="intro", delta_ops=...}` in a new module (auto-gives the attribute + theory-delta persistence + ancestry merging). No existing consumer would use it — see gap below.

---

## 8. Tactic infrastructure & search combinators

- `src/1/Tactical.{sig,sml}`: core combinators `THEN`/`THENL`/`>>`/`>-`, `REPEAT`, `FIRST`, `FIRST_PROVE`, `MAP_EVERY`/`MAP_FIRST`, `FIRST_ASSUM`/`FIRST_X_ASSUM`, `CHANGED_TAC`, `TRY`, `VALID`, `REPEAT_LT`/`FIRST_LT` (list-tactic level), `gentactic` (`>~`, `>>~` selection-by-pattern in bossLib). Goal management in `src/proofman/`.
- **No built-in best-first / iterative-deepening tactic combinator with explicit depth control** exists at the `Tactical` level. Depth-bounded search lives only inside specific provers: MESON (`GEN_MESON_TAC min max step`, iterative deepening, `mesonLib.sml`), metis (`limit`), and the learned search in TacticToe (`src/AI/proof_search/psMCTS.sml` MCTS, `psBigSteps.sml`). General utility search: `src/portableML/` (portable ML lib), `src/AI/aiLib`.

---

## 9. Testing conventions

Each library ships a `selftest.sml` compiled to `selftest.exe` and run by `Holmake` (an executable that raises/`exit 1` on failure). Relevant exemplars for a new tactic:
- `src/simp/src/selftest.sml` (simplifier regression, incl. congruence/AC/looping cases).
- `src/meson/src/` tests + `src/meson/test` (sequence line `[poly]!!src/meson/test`); `src/metis/selftest.sml`.
- `src/integer/selftest.sml` and `src/integer/testing/` (Omega/Cooper problem sets); `src/num/arith/src/selftest.sml`.
- `src/basicProof/selftest.sml`, `src/boss/selftest.sml`, `src/quantHeuristics/selftest.sml`, `src/real/`, `src/transfer/selftest.sml`, `src/num/reduce/src/selftest.sml` (Grobner/Normalizer).
Pattern: build a term, run the tactic/conv, compare with expected via `testutils` helpers; theory-level tests use `*Script.sml` in `theory_tests/` subdirs.

---

## GAPS vs Isabelle tactic list (auto, blast, force, simp, arith, presburger, algebra, ring)

- **simp:** well covered (`simp`/`rw`/`fs`/`gvs`, stateful `srw_ss`, `[simp]` attribute, congruences, conditional/permutative rewriting, one-point/Unwind). Closest to Isabelle simp.
- **arith / presburger:** covered — nat linear arith (`DECIDE`, Sup-Inf) and integer Presburger (`intLib.ARITH_TAC` via Omega, `COOPER_TAC` via Cooper), real linear arith (`REAL_ARITH_TAC`, Positivstellensatz). No single unified `arith`/`presburger` front-end across num/int/real (`DECIDE` = nat+prop only; user must pick `intLib`/`realLib`). **Gap: no type-dispatching universal `arith`.**
- **ring / algebra:** Gröbner + semiring normalizer EXIST (`src/num/reduce/src/{Grobner,Normalizer}`) but are wired only into `intLib.INT_RING` and `RealField`. **Gap: no generic user-facing `ring_tac`/`algebra` over arbitrary user-defined ring/field structures; no automatic instance discovery.**
- **blast / auto / force (classical reasoner):** **Major gap.** HOL4 has MESON/METIS (FO model-elimination/resolution) and `PROVE_TAC`, but **no classical-reasoner rule database with intro/elim/dest rule classification, no `[intro]/[elim]/[dest]` attributes, no wrapper/safe-vs-unsafe step distinction, and no `auto`-style interleaving of simp + classical search.** `STP_TAC`/`RW_TAC` interleave stripping + simp + `VAR_EQ_TAC` but are not a configurable classical prover.
- **Splitter:** case-splitting exists (`FULL_CASE_TAC`, `CaseEq`, PMATCH, COND congruences) but **no simp-integrated "splitter as looper"** with a registrable split-rule set the way Isabelle's `split:` works; splits are separate tactics or fixed COND handling.
- **Search combinators:** **no general depth-controlled best-first/iterative-deepening tactic combinator** at `Tactical` level (only prover-internal in MESON/metis/TacticToe-MCTS).
- **Attribute infra to build on:** `ThmSetData.export_with_ancestry` cleanly supports adding `[intro]`/`[elim]` sets with theory persistence + ancestry merging — the plumbing for a classical reasoner's rule DB is available even though no reasoner consumes it yet.
