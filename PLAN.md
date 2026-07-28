# Plan: Isabelle/HOL-parity proof automation for HOL4

Date: 2026-07-14.  Branch: `isabelle-tactics` (off `origin/develop`).

## 0. Goal and ground rules

Implement HOL4 analogues of Isabelle/HOL's automation — `auto`, `blast`,
`force`, `fastforce`, `safe`, `clarify`, `clarsimp`, `fast`, `best`,
`deepen`, `simp` (upgrades), `arith`, `presburger`, `algebra`, `ring` —
that are **at least as strong** as the Isabelle originals.

- The target is parity in **automation strength**, not Isabelle-style proof
  texts.  Surface syntax stays idiomatic HOL4 (owner decision; see §2).
- All solutions must be general, principled and extensible — no pragmatic
  fixes.
- This plan is grounded in a reading of the Isabelle sources, the primary
  literature, and a full inventory of the HOL4 automation stack in this
  repository.  Key sources are cited inline; the bibliography is §13.
- **All cited Isabelle files are vendored verbatim under
  `.agent-files/sources/`** (commit `f7e02b7e1f311d9c41ee075d22ff788b3e0de6db`
  of `isabelle-prover/mirror-isabelle`, 2026-07-12; see
  `sources/README.md`).  Every `file.ML:line` reference in this plan
  resolves against those copies, e.g.
  `sources/src/Provers/classical.ML:241`.
- The four underlying research reports (line-level analysis beyond what
  this plan summarizes) are archived under `.agent-files/research/`
  (see `research/README.md`).

## 1. Research summary: what exists, what is missing

### 1.1 HOL4 assets (reusable as-is or as backends)

- **Simplifier (Isabelle-derived)**
  - Location: `src/simp/src/` (`simpLib`, `Traverse`, `Travrules`, `Cond_rewr`,
    `Opening`, `Unwind`, `Satisfy`, `Cache`)
  - Notes: Conditional + ordered/permutative rewriting, HO nets, congruence
    procs, preorder-parametric (an Isabelle-superset feature), dproc hooks,
    `Once`/`Ntimes` bounds
- **Stateful simpset + `[simp]` attribute**
  - Location: `src/basicProof/BasicProvers.sml` (`srw_ss`, `export_rewrites`),
    `src/1/ThmSetData.{sig,sml}`, `src/1/ThmAttribute.{sig,sml}`
  - Notes: `ThmSetData.export_with_ancestry` gives attribute registration +
    theory-delta persistence + ancestry merging — the plumbing for all new rule
    sets
- **FO provers**
  - Location: `src/meson/src/mesonLib.sml` (model elimination, iterative
    deepening), `src/metis/` (resolution + reconstruction)
  - Notes: Kept as-is; not the basis of BLAST (owner decision)
- **Nat linear arith**
  - Location: `src/num/arith/src/` (Boulton 1992: FM + Shostak SUP-INF),
    `numSimps.ARITH_ss` (cached simp dproc)
  - Notes: Incomplete (no integer-divisibility facts); remains a fast backend
- **Complete Presburger**
  - Location: `src/integer/`: `Omega*` (Pugh's Omega test), `Cooper*` (Cooper's
    QE), `IntDP_Munge` (normalization, nat→int lifting)
  - Notes: Norrish, TPHOLs 2003. Proof-producing, complete; currently unwired
    from `DECIDE`
- **Real arith**
  - Location: `src/real/RealArith{,0}.sml` (Positivstellensatz-certificate
    linear prover, HOL Light lineage), `RealField.sml`, `SOSLib.sml`
    (nonlinear, CSDP), `NLArith.sml`
- **Gröbner + normalizer**
  - Location: `src/num/reduce/src/Grobner.{sig,sml}`, `Normalizer.{sig,sml}`
    (Harrison ports, 2022)
  - Notes: Buchberger with Nullstellensatz cofactor certificates checked by
    `SEMIRING_NORMALIZERS_CONV`; Rabinowitsch trick; ideal membership. Wired
    only into `INT_RING`, `REAL_RING/FIELD`, `NUM_RING`, and abstract `Ring r`
    via `examples/algebra/ring/ringLib.sml`
- **Hypothesis substitution**
  - Location: `BasicProvers.VAR_EQ_TAC`
    (`src/basicProof/BasicProvers.sml:842`), `gvs` elimvars
  - Notes: The `hyp_subst_tac` analogue exists
- **Quantifier heuristics**
  - Location: `src/quantHeuristics/`, `Satisfy`/`SFY_ss`, `Unwind`
  - Notes: One-point rules, unification-based ∃ instantiation
- **Evaluation**
  - Location: `src/compute/src/computeLib.sml` (`EVAL`), plus `cv_compute`
  - Notes: Substrate for the later reflected-QE phase

### 1.2 Gaps (from the four research reports)

1. **Classical reasoner: absent entirely.**  No claset (safe/unsafe
   intro/elim/dest rule database), no matching-vs-resolution step tactics,
   no wrappers, no `safe`/`clarify`, no `auto`/`force`, no tableau prover.
   `ThmSetData` can host the rule sets but nothing consumes them.
2. **Simplifier extension points.**  simpLib lacks: a looper hook (hence no
   splitter-inside-simp — Isabelle installs `Provers/splitter.ML` as a
   looper); pluggable safe/unsafe solver stacks; a pluggable subgoaler;
   configurable side-condition depth (hard-coded `stack_limit = 4` in
   `Cond_rewr.sml:11` vs Isabelle's `simp_depth_limit` ≈ 40–100); settable
   term order; congprocs not exposable through `SSFRAG`; no in-engine
   mutual-fixpoint assumption simplification (Isabelle `mut_impc`,
   `raw_simplifier.ML:1315–1441`); no "safe simplifier" variant.
3. **Arithmetic packaging and generality.**  `bossLib.DECIDE` = Boulton
   nat arith + `TAUT_PROVE`; no escalation to the complete Omega/Cooper;
   no generic linear-arith engine over arbitrary ordered structures
   (Isabelle: `Fast_Lin_Arith` functor, `src/Provers/Arith/fast_lin_arith.ML`
   — proof-producing Fourier–Motzkin with Farkas-certificate justification
   trees); no systematic `min/max/abs/div/mod` pre-splitting
   (Isabelle: `src/HOL/Tools/lin_arith.ML`); no extensible `arith` registry
   (Isabelle: `src/HOL/Tools/arith_data.ML`); simp's arith solver is
   nat-only.
4. **`presburger` preprocessing/packaging** (engines already at parity or
   better): no subterm generalization / premise thinning / `dvd`-parity
   rule set / attribute-driven preprocessing à la
   `src/HOL/Tools/Qelim/cooper.ML` + `src/HOL/Presburger.thy`.
5. **`algebra`/`ring` genericity.**  Engine parity exists; missing is the
   uniform, declaration-driven access Isabelle gets from type classes via
   `Semiring_Normalizer` context data (`src/HOL/Tools/semiring_normalizer.ML`,
   `src/HOL/Tools/groebner.ML`), plus curated `algebra_simps`/`field_simps`
   collections.
6. **No general search combinators** (best-first/iterative-deepening with
   depth control) at the `Tactical` level; depth-bounded search exists only
   inside MESON/metis/TacticToe.

### 1.3 A structural constraint specific to HOL4: no goal metavariables

Isabelle's `fast`/`best`/`deepen` search directly on the kernel proof state,
instantiating schematic variables (`?x`) by resolution.  HOL4 goals cannot
contain metavariables.  Consequence for the design:

- **Safe steps** (matching only, never instantiating goal unknowns) map to
  genuine HOL4 tactics and can run directly on the goal state
  (`SAFE_TAC`, `CLARIFY_TAC`, the deterministic parts of `AUTO_TAC`).
- **Unsafe search** (which needs unknowns, e.g. applying `exI`-style intros
  with a yet-undetermined witness) runs on an **engine-internal proof-state
  representation with metavariables**, followed by kernel replay of the
  found proof — the same LCF pattern MESON, metis and Isabelle's own blast
  already use.  Both search drivers (the Isabelle-parity one and the
  aesop-style one, §4/§6) share this internal representation.

This is a faithful-semantics port (rule-directed search honoring the
claset), not a shortcut; Paulson's blast paper explicitly validates the
search-externally/replay-internally architecture (JUCS 1999, abstract and
§8.2).

## 2. Owner decisions (record)

All decided 2026-07-14, one-by-one, with alternatives presented:

- **D1:** **Scope**: phased full-parity program. Core phases planned in depth:
  classical family, simplifier upgrades, arith, presburger, algebra/ring. Later
  phases sketched: verified/reflected QE (Cooper, Ferrante–Rackoff, MIR),
  argo-style internal SMT, `approximation`.
- **D2:** **Classical architecture**: build BOTH a faithful port of Isabelle's
  claset design (`Provers/classical.ML`) AND a full aesop-style best-first
  engine (Limperg & From, CPP 2023), now, over ONE shared rule database whose
  schema carries both kinds of metadata from day one.
- **D3:** **blast**: faithful port of Paulson's `Provers/blast.ML` (untyped
  tableau + tactic-script reconstruction).
- **D4:** **Rule infrastructure**: mirror the simpset dual-track design —
  first-class claset/ruleset values with combinators, plus a global stateful
  claset persisted through the theory-ancestry machinery (see D11);
  per-invocation modifiers as theorem-list markers extending the existing
  `Cong`/`Excl`/`SF` convention. *Revised 2026-07-15 (D12)*: attribute surface
  is HOL4-native, not Isabelle-mimicking — `[intro]`/`[elim]`/`[dest]`
  (unsafe), `[sintro]`/`[selim]`/`[sdest]` (safe), plus `[iff]`, `[split]`,
  `[arith]` in later phases; removal via functions (`delrule`), not a del
  attribute.
- **D5:** **Simplifier**: extend simpLib in place (looper + splitter port,
  solver stacks, subgoaler, configurable limits/term order, congprocs in
  SSFRAG, fixpoint asm mode). Keep top-down traversal; adopt skeleton-style
  optimizations only where behavior-preserving.
- **D6:** **arith**: port `Fast_Lin_Arith` as a generic Farkas-certificate
  engine parametric over instance records; port the `lin_arith.ML`
  preprocessing layer; wire as type-generic simp solver; `ARITH_TAC` =
  extensible registry with escalation linarith → presburger → real backends.
- **D7:** **presburger**: Omega first, Cooper fallback, behind Isabelle-parity
  preprocessing and a `[presburger]` rule set.
- **D8:** **algebra/ring**: persistent instance registry (types and
  abstract-structure hypotheses → semiring/ring/field instance records) +
  goal-type dispatch; `ringLib` promoted from `examples/`; curated
  `algebra_simps`/`field_simps` collections.
- **D9:** **Naming**: HOL4 uppercase convention only — `AUTO_TAC`, `BLAST_TAC`,
  `FORCE_TAC`, `FASTFORCE_TAC`, `SAFE_TAC`, `CLARIFY_TAC`, `CLARSIMP_TAC`,
  `FAST_TAC`, `BEST_TAC`, `DEEPEN_TAC`, `AESOP_TAC`, `ARITH_TAC`,
  `PRESBURGER_TAC`, `ALGEBRA_TAC`, `RING_TAC`, `IDEAL_TAC`. No lowercase
  Isabelle-alias layer. (Collision handling: §11, "Resolved micro-decisions".)
- **D10:** **Integration**: portable opt-in layer — own subtree in the default
  build (after the core), integration-identical mechanisms, central seed
  theories for the rule corpus, TypeBase hook + catch-up; promotion to full
  core integration planned as an explicit final phase.
- **D11:** *(2026-07-15, Phase 0)* **Claset persistence substrate**: one
  `AncestryData.fullmake` instance (tag `"claset"`) with a rich custom delta
  type (kind, safety, optional priority) and explicitly registered attributes —
  not `ThmSetData.export_with_ancestry`, whose fixed `ADD/REMOVE` delta type
  cannot carry the D2 schema. Same mechanism family one level down; D10
  unaffected. Details: `PLAN_phase_0.md` §0.
- **D12:** *(2026-07-15, Phase 0)* **HOL4-native attribute syntax** (revises
  D4): `[intro]/[elim]/[dest]` unsafe, `[sintro]/[selim]/[sdest]` safe,
  mirroring the `Intro`/`SIntro`/… marker constructors; zero core-grammar
  changes; numeric aesop priorities as attribute arguments deferred to Phase 4
  (small additive lexer tweak then).
- **D13:** *(2026-07-15, Phase 0)* **Wrapper representation**: layer-level
  nondeterministic tactic type
  `ntactic = goal -> (goal list * validation) seq.seq` (`portableML/seq`),
  `wrapper = ntactic -> ntactic`; safe wrappers
  compose ORELSE-style, unsafe APPEND-style — one wrapper vocabulary for Phases
  1–4.
- **D14:** *(2026-07-16, Phase S)* **Loop hook surface**: all simpLib tactic
  entry points honor simpset loopers and final solvers; conversion/rule/prove
  entry points do not. Empty default lists preserve distribution behavior.
- **D15:** *(2026-07-16, Phase S)* **Solver architecture**: one
  conversion-level solver type serves both engine side conditions (always
  unsafe) and tactic-level residual goals (safe or unsafe by mode); simpsets
  carry named safe/unsafe lists and a separately settable subgoaler. The
  default subgoaler preserves the existing recursive traversal, context
  theorems are accumulated for solvers, tactics lift through
  `mk_tactic_solver`, and `REDUCER` stays unchanged.
- **D16:** *(2026-07-16, Phase S)* **Safe-simp mode**: an invocation-mode
  record on generic `GEN_SIMP_TAC`, not a simpset transformer or `SAFE_*`
  family. The flag selects only the safe final-solver list; side-condition
  solving remains unsafe and loopers still run.
- **D17:** *(2026-07-16, Phase S)* **`mut_impc` realization** (revises §5.7):
  tactic-level through `global_simp_tac`, with change counting/fixed-tail
  skipping and opt-in conclusion-fixpoint and implication-rebuild flags;
  existing entries retain their semantics. An in-engine port is deferred to the
  Phase 8 benchmark gate (§11).
- **D18:** *(2026-07-16, Phase S)* **Splitter congruence policy**: retain
  HOL4's strong congruences (`COND_CONG` and descent into case branches);
  `split_ss` adds only the splitter looper and the `cases_simp` analogue. This
  deliberate strength-first divergence from Isabelle's weak-congruence pairing
  may be retuned after Phase 8 benchmarks.
- **D19:** *(2026-07-16, Phase S)* **`[split]` placement**: all split machinery
  lives in `src/simp` (`splitLib`, the `split` ThmSetData settype/attribute,
  `Split` marker, TypeBase cache, and `split_ss`); no default simpset consumes
  it in Phase S.
- **D20:** *(2026-07-16, Phase S)* **Names**: own module `splitLib`;
  `SPLIT_TAC`, `split_ss`, `Split th`, and attribute/settype `split`.
  Collision-checked; the only shadow is an unaffected script-local `SPLIT_TAC`
  under `examples/`.
- **D21:** **Engine state representation and unifier**: the shared search
  engine (Phases 2 and 4; blast keeps its private untyped prototerm language
  per D3) uses typed metavariables represented as marked fresh free variables
  occurring as *leaves* (no Isabelle-style lifting), each carrying an explicit
  **allow-set** of eigenvariables it may mention (checked at bind time, plus
  occurs check); a **persistent** substitution store behind an abstract API (so
  the representation stays swappable); and a unifier = typed first-order core
  (modeled on `src/1/FullUnify`) **plus** the higher-order *pattern* case
  (`?m x1…xk ≟ t`, `xi` distinct eigenvariables ⇒ `?m := λx̄.t`) **plus**
  Lean-style
  first-order-approximation and η heuristics, single-solution and
  deterministic. Matching mode = the same algorithm rejecting bindings of
  pre-existing metavariables. Rationale: option-1 cost profile (no spines, no
  pervasive β-normalization — cheaper than Isabelle's own lifting) with
  Lean/Aesop-level capability; Lean's Aesop itself has no full HOU (CPP'23
  §3.1.1), and nothing in this space runs enumerative HOU in-search. The
  unifier is the hardest single component; it is concentrated, golden-testable,
  and can never cause unsoundness (kernel replay checks everything).
- **D22:** **One step cascade**: the classical step layer
  (safe/clarify/inst/unsafe/dup steps) is implemented **once**, over the
  engine's goal shape, with a mode flag (match vs unify) and per-step
  validation emission. Phase-1 `SAFE_TAC`/`CLARIFY_TAC` are the cascade's
  metavariable-free instantiation: on such nodes every step carries its kernel
  validation directly, so the exported tactics are genuine `ntactic`s per D13
  with no deferred replay, and wrappers apply as `ntactic` wrappers.
- **D23:** **Blast replay architecture**: `BLAST_TAC`'s recorded script replays
  left-to-right on the shared engine's states (initialized from the real goal):
  steps genuinely resolve and instantiate typed metavariables (Isabelle's
  division of labor — search finds the shape, replay re-finds first-order
  unifiers, cheap per Paulson §8.2); grounding happens once at the end via the
  engine's kernel replay. PROOF-FAILED-backtrack into the tableau is preserved.
  No untyped→typed back-translation, no Skolem↔variable registry. BLAST thereby
  depends on the engine (both are Phase 2; scheduling coupling only).
- **D24:** **Engine wrappers, day one**: engine nodes are materializable as
  HOL4 goals with metavariables rendered as reserved rigid free variables;
  claset safe/unsafe wrappers are honored at exactly Isabelle's application
  points (uwrappers around the inst+unsafe rung — but *not* around
  `depth_tac`'s `inst0` closers, matching upstream `classical.ML:718`;
  swrappers inside every safe step); a wrapper's `(goals, validation)` result
  is lifted back by re-abstracting the rendered metavariables, and its
  validation is recorded — wrapper steps replay for free. The documented rigid
  semantics mean that a wrapper can never instantiate engine metavariables
  (Isabelle's rewriter-level guarantee; Isabelle's *solver-level*
  instantiation is a recorded Phase-3 option,
  `phase12-classical-search-port.md` §4.3).
- **D25:** **Dynamic pruning** (supersedes the static `safe_depth_tac`
  DETERM-polarity question, where upstream Isabelle has carried an inverted
  branch since 2009 — see `phase12-classical-search-port.md` §8): the engine
  implements the real invariant — *when a subgoal's complete solve instantiated
  no metavariable visible in the remaining goals, discard its alternatives* —
  i.e. blast's `prune`/`clashVar` rule (`blast.ML:841–865`) applied to the
  classical drivers. This subsumes the corrected 2005 semantics (HOL4 entry
  goals are metavariable-free, so the outer solve is deterministic by the
  invariant) and prunes losslessly deep inside metavariable-laden states. No
  compatibility flags.
- **D26:** **Full driver surface**: export `FAST_TAC`, `SLOW_TAC`, `BEST_TAC`,
  `SLOW_BEST_TAC`, `FIRST_BEST_TAC`, `ASTAR_TAC`, `SLOW_ASTAR_TAC`,
  `DEEPEN_TAC`, plus the step tactics `SAFE_STEP_TAC`, `CLARIFY_STEP_TAC`,
  `STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC`. All are thin instantiations of
  the one engine; all names collision-checked free (2026-07-16, whole-tree
  grep).
- **D27:** **Failure semantics**: `SAFE_TAC` and `CLARIFY_TAC` fail exactly
  when they change nothing (`CHANGED_PROP` semantics — what Isabelle users
  actually experience of the `safe`/`clarify` *methods*,
  `classical.ML:834,843–844`). The raw never-fail behavior is reachable as
  `TRY SAFE_TAC`.
- **D28:** *(2026-07-19, Phase 3)* **Clasimpset**: the stateful clasimp tactics
  use a cached derived value of `srw_ss()` plus layer config (`cond_depth` 40,
  safe-solver stack, `split_ss`); lowercase claset+simpset-explicit forms
  throughout. Details: `PLAN_phase_3.md` §4. *Amended 2026-07-24 (D36)*: the
  claset+simpset-explicit forms are uppercase `CS_*`, not lowercase.
- **D29:** *(2026-07-19, Phase 3)* **`[iff]` persistence**: clasimp-owned
  `ThmSetData` settype `"iff"` whose delta carries only the source theorem;
  both derived views (claset rules, simpset rewrite) are recomputed by the
  apply hook on load. Declaration = source of truth; claset `cdelta` v1 and
  rules/⊥simp layering untouched; removal function writes RM.
- **D30:** *(2026-07-19, Phase 3)* **Uniform insertion semantics** (revises the
  Phase-2 plain-theorem convention): unmarked theorems in any `src/auto` tactic
  argument are inserted as assumptions (Isabelle's chained-fact channel; HOL4
  prover-family habit); explicit roles via markers only.
  `classicalLib`/`tableauLib` refactored accordingly; marker vocabulary gains
  `Simp`/`Iff` (Phase-0/2 freeze amendments).
- **D31:** *(2026-07-19, Phase 3)* **Safe asm-full-simp**:
  `GEN_GLOBAL_SIMP_TAC` takes `simp_mode` as first argument (uniform with D16's
  `GEN_SIMP_TAC` shape; Phase-S freeze amendment; existing entries keep
  signatures via `{safe=false}`). Clasimp's asm-full-simp = the D17
  mut_impc-parity configuration.
- **D32:** *(2026-07-19, Phase 3)*
  **`classicalLib.depth_solve_tac {dup} n cs`** additively exported (Phase-2
  freeze amendment): the one implementation
  of Isabelle's `depth_tac`/`nodup_depth_tac` recipe; internal uses refactored
  onto it. *Amended 2026-07-24 (D36)*: exported as `CS_DEPTH_SOLVE_TAC`.
- **D33:** *(2026-07-19, Phase 3)* **`tableauLib.blast_depth_tac`** additively
  exported (Phase-2 freeze amendment): raw claset-explicit fixed-depth tableau
  entry (no preprocessing, no deepening) for `AUTO_TAC`'s inner loop; public
  `BLAST_TAC` packaging unchanged. *Amended 2026-07-24 (D36)*: exported as
  `CS_BLAST_DEPTH_TAC` — the delivered module-private `blast_depth_tac`
  (`tableauLib.sml:183`) is the unrelated theorem-list entry behind
  `BLAST_DEPTH_TAC` and keeps its name.
- **D34:** *(2026-07-19, Phase 3)* **Names**: module `clasimpLib`; `AUTO_TAC`,
  `AUTO_DEPTH_TAC`, `FORCE_TAC`, `FASTFORCE_TAC`, `SLOWSIMP_TAC`,
  `BESTSIMP_TAC`, `CLARSIMP_TAC` (collision-checked). `AUTO`/`CLARSIMP` fail
  iff unchanged (D27 semantics); the FORCE family must close the goal.
- **D35:** *(2026-07-23, Phase 1/2 closure)* **M2 environmental closure**:
  close M2 once the complete benchmark suite and Halting II pass because
  `perf_event_paranoid` cannot be lowered on the available host.  Keep the
  unavailable kernel profiler as an explicit environmental limitation; do
  not invent samples or claim a lower setting.
- **D36:** *(2026-07-24, Phase 3)* **Context-explicit naming**: the `CS_`
  prefix denotes a context-explicit entry point across the whole layer,
  whether the context is a claset or a claset/simpset pair. Phase 3 exports
  `CS_AUTO_TAC`, `CS_FORCE_TAC`, `CS_FASTFORCE_TAC`, `CS_SLOWSIMP_TAC`,
  `CS_BESTSIMP_TAC`, `CS_CLARSIMP_TAC` (`… -> claset -> simpset -> tactic`),
  and D32/D33 export `CS_DEPTH_SOLVE_TAC`/`CS_BLAST_DEPTH_TAC`. Supersedes the
  lowercase forms of D28/D32/D33/D34; brings Phase 3 under the
  `src/auto/CLAUDE.md` naming rule and D38. Details: `PLAN_phase_3.md` §§3.2,
  3.3, 7.
- **D37:** *(2026-07-24, Phase 3)* **Simp-wrapper combinators**: Isabelle's
  `addss`/`addSss` are named `add_simp_wrapper`/`add_safe_simp_wrapper`,
  matching the delivered `clasetLib.add_unsafe_wrapper`/`add_safe_wrapper`
  pair. The wrapper slot *strings* stay Isabelle's (`"asm_full_simp_tac"`,
  `"safe_asm_full_simp_tac"`) so the port stays greppable against
  `clasimp.ML:44–54`. Details: `PLAN_phase_3.md` §5.
- **D38:** *(2026-07-24, Phase-1/2 review; = D-R1 of
  `PLAN_review_phase_1_2.md`)* **No lowercase alias layer**: the
  claset-explicit layer of `classicalLib` is uppercase `CS_*_TAC`
  (`CS_SAFE_TAC`, `CS_FAST_TAC`, …), types unchanged; module-private helpers
  keep lowercase — the rule governs the public API. Landed at `5a1dee9f9`
  with the 16 Docfiles renamed.
- **D39:** *(2026-07-24, Phase-1/2 review; = D-R2 of
  `PLAN_review_phase_1_2.md`)* **`Measured` twins**: unify the *cold-path*
  twins (per-invocation setup/translation) on a `checkpoint : unit -> unit`
  parameter, unmeasured callers passing `fn () => ()`; keep the *hot-path*
  twins (`blastTerm` term operations, `blastSearch` inner loop) and guard them
  with differential drift tests. Later phases add no new twins.
- **D40:** *(2026-07-27, Phase-3 refactor)* **`[iff]` simpset parity**:
  install each theory's declarations as one batch of named rewrites, and
  retract rewrites with `temp_delsimps`.  The theorem's `Thy.name` therefore
  works with `Excl`, `delsimps`, and `temp_delsimps`, exactly as for `[simp]`.
- **D41:** *(2026-07-27, Phase-3 refactor)* **Iff derivation belongs to the
  rules layer**: `clasetLib.iff_rules` derives both halves, including both
  safe constructor-injectivity rules contributed to the base claset.
  `clasimpLib` adds only the corresponding normalized simp rewrite.
- **D42:** *(2026-07-27, Phase-3 refactor)* **One simp-argument
  classifier**: `clasetLib.classify_simp_args` owns the traversal and marker
  vocabulary.  Simpset-less and simpset-carrying callers retain their
  distinct unwrap/reject policies.
- **D43:** *(2026-07-27, Phase-3 refactor)* **Simp wrappers carry controls**:
  `add_simp_wrapper` and `add_safe_simp_wrapper` take the simplifier-control
  theorem list explicitly; callers pass `[]` when no controls are wanted.

- **D44:** *(2026-07-28, Phase 4)* **Aesop architecture**: faithful
  CPP'23 AND/OR tree (goal/rapp/metavariable-cluster nodes, §4 copying
  algorithm) in new `src/auto/aesop/` modules, reusing `clasetMeta`/
  `clasetUnify`/`clasetNet`/`clasetGoal` single-goal nodes/`clasetReplay`/
  `searchHeap` — not best-first over whole proof states, not a Phase-2
  forest refactor.  Details: `PLAN_phase_4.md` §§0, 4.
- **D45:** *(2026-07-28, Phase 4)* **`clasetStep.rule_step`** additively
  exported (Phase-2 freeze amendment, D32/D33 precedent): per-theorem,
  wrapper-free, standard child policy, explicit unification mode; the
  amendment umbrella covers a non-consuming elim replay action if the
  forward builder needs it.
- **D46:** *(2026-07-28, Phase 4)* **Rule DB v2**: `rulespec.kind` gains
  `Forward`/`Norm`, persisted via `clasetADD2` alongside v1; the aesop
  index is a non-persisted by-target/by-hypothesis `clasetNet` pair on
  the `CS` record (as Phase 0 pre-authorized); simp-builder rewrites are
  an `aesop_simp` `ThmSetData` settype; tactic rules session-only.
- **D47:** *(2026-07-28, Phase 4)* **Attributes**: enact D12's
  `[intro=NN]`/`[elim=NN]`/`[dest=NN]` percent arguments (additive HolLex
  tweak); new `[norm]`/`[norm=k]`, `[forward]`/`[forward=NN]`,
  `[sforward]`, `[aesop_simp]`.  No safe integer-priority surface in
  Phase 4; pattern-cases declarations programmatic only.
- **D48:** *(2026-07-28, Phase 4)* **Default probability**: unsafe rules
  without explicit `prio` count as 50% for aesop; seeds annotate only
  where the paper's corpus differs.
- **D49:** *(2026-07-28, Phase 4)* **Surface**: `AESOP_TAC` is
  close-or-fail (safe goals reported via trace); `AESOP_SAFE_TAC` leaves
  the normalisation+safe frontier as subgoals with D27 semantics;
  `CS_AESOP_TAC`/`CS_AESOP_SAFE_TAC : aesop_config -> claset -> simpset
  -> tactic` per D36.
- **D50:** *(2026-07-28, Phase 4)* **Normalisation**: built-in norm rule
  = safe-mode mut_impc-parity global simp over an aesop-derived simpset
  cache (`srw_ss()` + `cond_depth` 40 + safe solvers + `aesop_simp`),
  **without** `split_ss`; case splits enter as low-priority safe rules
  from the `[split]` corpus (CPP'23 §3.4 parity; norm rules must yield
  ≤ 1 subgoal).
- **D51:** *(2026-07-28, Phase 4)* **`clasetMeta.absorb`** additively
  exported (second Phase-2 freeze amendment): domain-disjoint store
  extension merge, erroring on conflicts, required for winning-forest
  replay (sibling subtrees evolve incomparable store extensions).

Overarching (owner clarification): judge every design by resulting tactic
strength, not by resemblance to Isabelle's user syntax.

## 3. Layer architecture

The opt-in layer lives at `src/auto/`, with subdirectories mirroring the
phases:

```
src/auto/
  rules/       -- rule database, attributes, netpairs, seed theories (Phase 0)
  classical/   -- claset step tactics, SAFE/CLARIFY/FAST/BEST/DEEPEN
                 (Phase 1–2)
  blast/       -- tableau prover (Phase 2)
  clasimp/     -- AUTO/FORCE/FASTFORCE/CLARSIMP, [iff] (Phase 3)
  aesop/       -- best-first engine (Phase 4)
  linarith/    -- generic linear arith + ARITH_TAC registry (Phase 5)
  presburger/  -- PRESBURGER_TAC front end (Phase 6)
  algebra/     -- instance registry, ALGEBRA_TAC/RING_TAC (Phase 7)
```

Design constraints making the layer portable to full integration (D10):

1. **Integration-identical mechanisms**: everything uses
   `AncestryData`/`ThmSetData` / `ThmAttribute` / TypeBase hooks —
   nothing bespoke to "opt-in mode".
2. **Central seed theories**: `clasetSeedScript.sml` etc. declare rules
   *about ancestor theories' theorems* (theory-ancestry deltas live in the
   declaring theory).  Promotion = move each declaration into the theorem's
   home `*Script.sml` as an attribute; identical semantics.
3. **Stratified dependencies**: code depends only on libraries available
   before `src/boss` even though it is built after the core; moving it
   earlier in the build sequence is then a sequence edit only.
4. **TypeBase catch-up + hook**: a datatype hook registers rules for types
   defined after loading, plus a one-shot sweep over already-registered
   types.
5. Simplifier upgrades (Phase S) are the exception: they land **in
   `src/simp` itself** (D5), with defaults preserving current behavior
   (empty looper list, current solver behavior as default solver stack,
   `stack_limit` default unchanged for existing entry points; the layer's
   simpsets raise it — §5.5).

Build: new entry in the default build sequence (after the core band;
exercised by `bin/build -F` and by a `--seq` extension of
`upto-parallel` used during development).  Each directory ships
`selftest.sml` per repo convention.

## 4. Phase 0 — Rule database and attribute layer (`src/auto/rules/`)

The shared foundation for both search engines and BLAST (D2, D4).

**Status (2026-07-15): delivered.**  `src/auto/rules/` now provides the
persistent claset, attributes, markers, TypeBase contributions, seed theory,
and regression suite described in `PLAN_phase_0.md`.  The implementation
refined this initial sketch as follows: it has four classical netpairs
(`safe0`, `safep`, `unsafe`, and `dup`), not an `extra_netpair`; the aesop
in-memory index is deferred to Phase 4.  The persisted v1 schema reserves
only optional `prio` metadata; aesop builders and tactic-valued rules are
also Phase 4 work.  D12's HOL4-native attributes are
`[intro]`/`[elim]`/`[dest]` (unsafe) and
`[sintro]`/`[selim]`/`[sdest]` (safe), with function-based removal.  The
TypeBase hook seeds distinctness and injectivity only: constructor intros
await Phase 3's `[iff]` machinery and case splits await Phase S's `[split]`
set.  `help/Docfiles` entries are deferred to Phase 1, when user-facing
tactics exist.

**Rule kinds.**  {intro, elim, dest} × {safe, unsafe}, following
`Pure/bires.ML:113–142` (the `?`/extra kind is dropped: it exists only for
Isabelle's single-step `rule` method; revisit if a structured-rule tactic is
added later).  Additionally each rule carries optional aesop metadata:
priority (success probability, %), builder kind, or an arbitrary
tactic-valued rule (usable only by the aesop engine).

**Rule preprocessing** (port of `classical.ML:150–368`):
- dest → elim via a `make_elim` analogue (`A ⟹ B` ↦ `A ⟹ (B ⟹ R) ⟹ R`).
- **Weak-elim classical repair** (`classical_rule`, `classical.ML:150–169`):
  elims whose conclusion is not classically assumed get the negated
  conclusion added to side premises (without this, `fast` fails and blast
  reports PROOF FAILED on rules like `make_elim injD`).
- **Swapped intro variants** (`classical.ML:195–213`; HOL's
  `swap`: `¬P ⟹ (¬R ⟹ P) ⟹ R`): every intro also enters the nets in
  swapped form, applied to negated assumptions — the device that simulates
  multi-conclusion sequent calculus in natural deduction.
- **Duplicating variants** (`dup_intr = th RS classical`, `dup_elim`;
  `classical.ML:216–220`) for the complete `DEEPEN_TAC` search and blast's
  γ-rule retention.
- Premise flattening (atomize nested implications/conjunctions) so net
  indexing sees object structure.

**Indexing.**  Netpairs à la `Bires` (`bires.ML:251–303`): intro rules
indexed by conclusion, elim/dest by major premise, candidate ordering =
(fewer new subgoals, more recent declaration).  Five netpairs per claset:
`safe0` (0-subgoal), `safep` (branching safe), `unsafe`, `dup`, plus the
aesop index (discrimination trees over target/hypothesis patterns, CPP'23
§3.3).  Implementation reuses HOL4 term nets (`Ho_Net` as in simpLib);
matching (no goal instantiation) vs unification entry points are kept
strictly separate, since the safe/unsafe semantics depends on it
(`classical.ML:581–655`; isar-ref §"The Classical Reasoner").

**Claset values and state** (D4):
- `claset` abstract type with combinators (`add_safe_intro`, `++`-style
  merge, removal by name), mirroring simpset value ergonomics; merge
  preserves canonical declaration order (`Bires.merge_decls`).
- Global stateful claset (analogue of `srw_ss()`), persisted with a
  dedicated `AncestryData.fullmake` instance carrying rich deltas (D11),
  with explicitly registered attributes selecting the kind:
  `Theorem foo[intro]`, `[sintro]`, `[selim]`, `[dest]`, … (D12); aesop
  priority as a parameterized attribute argument (surface deferred to
  Phase 4).
- Per-invocation modifiers as theorem-list markers in the existing
  simpLib style (`process_tags`, `simpLib.sml:834`):
  `SIntro th`, `Intro th`, `SElim th`, `Elim th`, `SDest th`, `Dest th`,
  `Iff th`, `Split th`, `Del "name"`, alongside the existing
  `Cong`/`Excl`/`SF`/`Once` markers (grep confirms none of the new
  constructor names collide with existing signatures).  All new tactics
  accept the same marker vocabulary, as Isabelle's methods share
  `cla_modifiers`/`clasimp_modifiers` (`classical.ML:809`,
  `clasimp.ML:207`).

**Wrappers** (`classical.ML:513–574`): named safe-wrapper and
unsafe-wrapper lists on the claset (`type wrapper = (int -> tactic) ->
int -> tactic` adapted to HOL4 tactics); safe wrappers compose
deterministically (ORELSE), unsafe wrappers keep alternatives (APPEND).
This is the extension point through which the simplifier enters
(`AUTO_TAC`, §7) and through which users bolt on domain steps.

**TypeBase hook.**  For every datatype: distinctness and injectivity as
safe elims/dests, case-split theorems into the `[split]` set (§5),
constructors-as-intros where invertible — mirroring what Isabelle's
datatype package declares.  Catch-up sweep at load time (D10).

**Seed theories.**  `clasetSeedScript.sml` seeds the base logic exactly as
`HOL.thy:869–904` does: `iffI notI impI disjCI conjI TrueI refl` safe
intros; `iffCE FalseE impCE disjE conjE` safe elims; `allI` safe intro,
`exI ex1I` unsafe intros, `exE` safe elim, `allE` unsafe elim — using the
*classical* variants (`disjCI`, `impCE`, `iffCE`) that avoid quantifier
duplication.  Further seed theories per core theory (§10).

**Hypothesis substitution**: reuse `BasicProvers.VAR_EQ_TAC` as the
`hyp_subst_tacs` slot (occurs-check semantics matches
`hypsubst.ML:83–104`); extend if the blast reconstruction needs the
reordering variant (`blast_hyp_subst_tac`, see §6).

Deliverables: `clasetLib.{sig,sml}` (rule DB, values, state, attributes,
markers, wrappers), `clasetSeedScript.sml`, TypeBase hook, selftest.

## 5. Phase S — Simplifier upgrades (`src/simp/src/`, in place)

Concurrent with Phases 0–1 (needed by CLARSIMP/AUTO).

**Status (2026-07-16): delivered in `src/simp/src`.**  New loopers,
solver lists, splitting, and mutual-fixpoint flags default off, and no
distribution simpset consumes them.  Promotion remains pending §11; the
full-distribution regression gate is recorded there (D5).

1. **Looper hook**: named looper list on the simpset; tactic entry points
   call loopers when rewriting + dprocs are exhausted on a subgoal-shaped
   residue, restarting simplification on each result (semantics of
   `simplifier.ML:312–329`).  Conversion/rule/prove entry points do not run
   loopers or final solvers (D14).
2. **Splitter**: port of `Provers/splitter.ML` — split rules
   `?P (c args) = rhs` indexed by head constant; conclusion splits via the
   `meta_iffD`/lift-theorem contexting (`splitter.ML:101, 288–356`) adapted
   to HOL4 conversions (the lift theorem's job is done by careful
   `HO_PART_MATCH` context abstraction); assumption splits by contraposition
   + `disjE/conjE/exE` flattening (`splitter.ML:389`).  Installed as a
   looper; `[split]` rule set (ThmSetData-backed) + TypeBase-provided
   case-split theorems; `Split th` marker for per-invocation use.
   If-splitting parity with `RW_TAC`'s ad hoc `IF_CASES_TAC` handling.
3. **Solver stacks**: named safe/unsafe solver lists (pluggable).  Engine
   side conditions always use the unsafe list; **safe-simp mode** selects
   the safe list only for the final tactic-level residue (D15–D16), as
   required by `AUTO_TAC` and `CLARSIMP_TAC` (`simpdata.ML:127–151`,
   `clasimp.ML:44–54`).  Empty lists preserve existing behavior.  The
   generic linear-arith solver (§8) registers as unsafe, as HOL does
   (`lin_arith.ML:949`).
4. **Subgoaler hook and context**: the default subgoaler is the existing
   recursive traversal; accumulated context theorems are visible to
   solvers (D15).
5. **Configurable limits**: side-condition `cond_depth` is a simpset field.
   All existing entry points keep the current default 4 (zero distribution
   behavior change); the layer's simpsets set it to 40 (Isabelle's code
   default, `raw_simplifier.ML:433`) — Isabelle-parity conditional rule
   sets need ≫ 4.  Settable term order (`set_term_ord` analogue) controls
   ordered rewriting.
6. **Congprocs through SSFRAG**: expose `Opening`'s procedural congruence
   interface in the `SSFRAG` record (Isabelle's congprocs,
   `raw_simplifier.ML` `Congproc`).
7. **Fixpoint assumption simplification**: tactic-level mutual-fixpoint
   controls in `GEN_GLOBAL_SIMP_TAC` (semantics of `mut_impc`,
   `raw_simplifier.ML:1315–1441`): change counting with fixed-tail skipping,
   plus opt-in conclusion-fixpoint and implication-rebuild flags.  Existing
   `gvs`-family behavior is unchanged (D17); an in-engine port is subject to
   the Phase 8 benchmark gate in §11.

Delivered: backward-compatible extended `simpLib` API, own `splitLib`
module, `[split]` set and attribute, TypeBase cache, marker and fragment
integration, selftests including ported splitter cases, and user docs.

## 6. Phases 1–2 — Classical step tactics, search tactics, BLAST

### 6.1 Step layer (`src/auto/classical/`) — port of `classical.ML:578–732`

**Status (2026-07-19): delivered (Phase 1).**  The Phase-1 slice comprises
`searchHeap`, `clasetMeta`, `clasetUnify`, `clasetGoal`, `clasetStep`, and
`classicalLib`, with selftests and user documentation.  It exports
`SAFE_TAC`, `CLARIFY_TAC`, `SAFE_STEP_TAC`, and `CLARIFY_STEP_TAC`, plus
claset-explicit lowercase forms, with D27's change-or-fail semantics.  The
raw-goal sketch below was superseded by D22: safe reasoning runs through a
metavariable-free `clasetGoal.node` and retains direct validations.  The
shared cascade also includes assumption modus ponens, built-in `DISCH` and
`GEN`, and swapped handling for negated implication and universal
assumptions.

- `SAFE_STEP_TAC`: FIRST of assumption-matching, contradiction
  (`P`/`¬P`), 0-subgoal safe rules by matching, hyp-subst, branching safe
  rules by matching — wrapped by safe wrappers.
- `SAFE_TAC` = repeat-deterministically over all goals; `CLARIFY_STEP_TAC`
  / `CLARIFY_TAC`: the non-splitting restriction (only 1-subgoal safe
  rules; 2-subgoal only if one branch closes immediately;
  `classical.ML:599–625`).
- Runs directly on the HOL4 goal state (safe steps never instantiate goal
  unknowns, §1.3).

### 6.2 Search layer — internal engine with metavariables

**Status (2026-07-19): delivered (Phase 2).**  The complete classical module
list is `searchHeap`, `clasetMeta`, `clasetUnify`, `clasetReplay`,
`clasetGoal`, `clasetStep`, `clasetSearch`, and `classicalLib`.
`classicalLib` exports all of D26: `FAST_TAC`, `SLOW_TAC`, `BEST_TAC`,
`SLOW_BEST_TAC`, `FIRST_BEST_TAC`, `ASTAR_TAC`, `SLOW_ASTAR_TAC`,
`DEEPEN_TAC`, `STEP_TAC`, `SLOW_STEP_TAC`, and `INST_STEP_TAC`, plus the
claset-explicit forms.  The D21 persistent typed-metavariable store,
matching/unification, materialization, replay, wrappers, D25 pruning, heap,
and four search policies are implemented and regression-tested.

The delivered node is an ordered open-goal list with store, replay, ancestry,
and binding-mark bookkeeping; alternatives and frontiers live in
`clasetSearch`, rather than in an explicit exported AND/OR-forest type.
Its atoms-plus-abstractions size metric is fixed in `clasetGoal` and does not
call the otherwise corrected `claset_config.size_of`.  A-star's weight 5 and
`DEEPEN`'s increment 2 and ceiling 10 are fixed in `classicalLib`; only the
programmatic deepening start is configurable.  These are deviations from
the original pluggable/shared-forest sketch below.

`FAST_TAC`, `BEST_TAC`, `SLOW_TAC`, `DEEPEN_TAC` implement Isabelle's
step semantics (`inst_step` on safe nets by unification, then unsafe
steps; ORELSE vs APPEND distinction between fast and slow;
`deepen` = iterative deepening over `dup` rules with only unsafe steps
decrementing the bound, `classical.ML:700–732`) — but the search runs on
an engine-internal AND/OR proof forest supporting metavariables
(§1.3), with tactic-script recording and kernel replay on success (the
blast/MESON reconstruction pattern).  Best-first priority = proof-state
size (Isabelle's `sizef = size_of_thm`), pluggable.

This internal representation is designed **once** and shared with the
aesop engine (§6.4): nodes = goals (assumptions + conclusion +
metavariable store), edges = rule applications; safe-rule saturation is a
node-local deterministic phase; drivers differ only in frontier policy
(DFS / best-first / iterative deepening / aesop priorities).

### 6.3 BLAST (`src/auto/blast/`) — faithful port of `Provers/blast.ML` (D3)

**Status (2026-07-23): delivered; final phase gate and audit complete.**
The actual modules are `blastTerm`, `blastRule`,
`blastSearch`, `blastReconstruct`, and `tableauLib`, with selftests and user
documentation.  The extra `blastReconstruct` module, absent from the
original sketch, isolates D23's typed-engine reconstruction and PROOF-FAILED
tableau backtracking.  The public operations are `BLAST_TAC`,
`BLAST_DEPTH_TAC`, `depth_limit`, and `tryIt`.

The 2026-07-19 integrity review found a forbidden recognition incident.
Seven benchmark-statement seed theorems were used as rewrites, and a
separate Halting recognizer accepted an `aconv` match using a metis-proved
theorem.  Those preprocessors and instance theorems were removed.  This is
the incident record, not a current tactic description; no benchmark
recognition remains.

The later repairs are general replay/store repairs.  They preserve the exact
instantiated theorem, static premise prefixes, exact assumption provenance
and selected majors.  The tracked chronology includes exact assumption
selectors at `372c6e981`, provenance at `bcd957b3a`, the historical
all-suite state at `5bc674569`, static-prefix preservation at `e45dd0659`,
and final-store selected-major normalization at `d90554b5f`.  Reviewed
commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1` centralizes capture-safe
transitive persistent-metavariable expansion and exact replay across all 16
public stored-rule APIs.  It has no recognition or fallback shortcut.

Accepted committed-state attempt-04 records 48/48 Pelletier, 9/9 Table 1,
4/4 sets and a kernel-valid Halting II success.  Both expected-failure
lists are empty.  TASK_23 remains completed, TASK_24 is
completed/reclosed, and D35 closes M2 because its complete-suite and
Halting conditions pass.  The unavailable kernel profiler remains
disclosed rather than treated as an open blocker.

M1 is closed.  Its original explicit acceptance criterion required
behaviour preservation and measured wall-clock improvement on the six
listed workloads; it did not require remeasurement after every later patch.
The verified `5bc674569` public-production package has a 1,818-entry
manifest, six `>=30s` censored baselines, and all 18 exact kernel-valid
production runs below `3.544s`.  Attempt-04 contains no performance
measurement for the newer replay patch, so performance at `f4fc8be66` is
not claimed.  That transparent limitation is a non-blocking follow-up, not
an M1 or plan blocker.  Attempt-04 also supplies the committed-state
phase-boundary full build and final audit, so Phases 1/2 are complete.

Pipeline (per the source and Paulson JUCS 1999):
1. **Untyped translation**: private term datatype with destructive,
   trailed unification variables; types discarded except dynamic
   "typargs" on overloaded constants (paper §6) — in HOL4 the analogous
   ambiguity comes from polymorphic constants (e.g. `=` at bool vs other
   types); carry the relevant type instantiations dynamically.
2. **Rules from the claset**, converted lazily per node
   (`netMkRules`, `blast.ML:569–580`); elims require formula-variable
   conclusions (reject "weak" ones with a warning, as Isabelle does).
3. **Search**: branch = stack of levels (safe formulas / deferred unsafe),
   literals, variables, resource bound; cascade per formula: equality
   substitution → close against literals → safe rule → defer
   (`blast.ML:932–1176`); unsafe expansion decrements the bound,
   duplicates `md`-flagged formulas (γ-rules); instantiation penalty
   `1 + log₄ N` (paper §4); choice-point pruning of solved sibling goals
   (`prune`, `blast.ML:841–865`); iterative deepening
   `DEEPEN (1, depth_limit≈20)`.
4. **Reconstruction**: every step records the HOL4 tactic that replays it
   (match/resolve with the original theorem, assumption/contradiction
   closers, hyp-subst) plus assumption rotation to mimic the LIFO branch
   order (Isabelle needed `Thm.rotate_rule`; HOL4 assumption lists are
   plain lists, so rotation is a cheap assumption-reordering tactic); on
   success replay the whole script through the kernel; on replay failure
   print `PROOF FAILED` diagnostics and **backtrack into the tableau
   search** (`blast.ML:1254–1277`).

Known Isabelle limitations that carry over and are documented rather than
hidden: no higher-order unification in the search; wrappers ignored;
weak elims rejected.

Deliverables: `tableauLib` exporting `BLAST_TAC` + selftest including the
Pelletier problems 1–46 (Paulson's benchmark set, Table 1 of the paper)
and HOL4-native set-theoretic goals.

### 6.4 Phase 4 — Aesop-style best-first engine (`src/auto/aesop/`) (D2)

**Detailed implementation plan: `PLAN_phase_4.md` (2026-07-28; owner
decisions D44–D51; research: `research/phase4-aesop-engine.md`).**  It
refines this sketch against the delivered substrate: the "shared
forest" is realized as a new faithful AND/OR tree over the Phase-2
components (D44) rather than an exported Phase-2 forest type; case
splits are safe rules, not normalisation rules (D50); dropped
metavariables need no synthesis subgoals in HOL (grounded
deterministically); tactic-valued rules run on rendered goals and
cannot bind engine metavariables (D24 discipline).

Full implementation of Limperg & From, CPP 2023, over the shared rule DB
and the shared search forest of §6.2:

- **Rule builders**: apply/constructors/forward/destruct/cases/simp/tactic
  (CPP'23 §3.1) mapped to HOL4 (TypeBase for constructors/cases; simpLib
  for the simp builder; arbitrary `tactic`-valued rules).
- **Phases**: normalization (fixpoint of normalization rules including a
  built-in simpLib invocation over goal + assumptions), then best-first
  search over safe (100%) and unsafe (user-priority %) rules; goal
  priority = product of rule probabilities along the path (§2.3).
- **Metavariables**: the copying treatment of goals sharing metavariables
  (CPP'23 §4) — implemented in the shared forest; this is the
  highest-risk single component of the whole program and is scheduled
  after the parity tactics so nothing waits on it.
- **Residue reporting**: on failure, report the safe-rules-only frontier
  (the analogue of `safe`/`clarify` residue, §2.6).
- Entry point: `AESOP_TAC` (no collision; the name credits the
  algorithm's published design).

<h2 id="7-phase-3--clasimp-layer-autoforcefastforceclarsimp-srcautoclasimp">
7. Phase 3 — Clasimp layer: AUTO/FORCE/FASTFORCE/CLARSIMP
(<code>src/auto/clasimp/</code>)
</h2>

**Detailed implementation plan: `PLAN_phase_3.md` (2026-07-19; owner
decisions D28–D34).**  It corrects three details of the sketch below
against the source (`force`'s clarify phase sees only safe wrappers, so
`addss` is inert there; `[iff]` classifies safe/unsafe purely by premise
count and derives an intro+*dest* pair for equivalences, feeding the
simpset in every branch; `auto` has a `prune_params_tac` step, vacuous
in HOL4).

Port of `Provers/clasimp.ML` semantics, given §5 and §6:

- **Simp-as-wrapper**: `addss` (full simp as unsafe wrapper before every
  unsafe step) and `addSss` (safe-mode simp as safe wrapper after failing
  safe steps) — `clasimp.ML:44–54`.
- **`AUTO_TAC`** = the exact `mk_auto_tac` script (`clasimp.ML:147–161`):
  (1) full-simp every subgoal; (2) `SAFE_TAC`; (3) repeat-first-goal
  (depth-4 blast ORELSE CHANGED depth-2 claset search with simp inside,
  using the non-duplicating unsafe step, `nodup_depth_tac`); (4) final
  `SAFE_TAC` with safe-simp wrapper.  Acts on all goals, may leave
  simplified residue, idempotent up to blast instantiations.  Depth
  parameters exposed (`AUTO_TAC`, `auto_dtac (m,n)` -style; exact API in
  implementation review).
- **`FORCE_TAC`** (`clasimp.ML:167–173`): clarify → simp → best-first with
  simp wrapper; must close the goal.
- **`FASTFORCE_TAC`** = `FAST_TAC` + `addss`; `SLOWSIMP`/`BESTSIMP`
  analogues come free.
- **`CLARSIMP_TAC`** = safe-simp then clarify with safe-simp wrapper;
  never required to close.
- **`[iff]` attribute** (`clasimp.ML:87–112`): unconditional iffs → simpset
  + safe intro/dest pair via `iffD1/iffD2`; conditional → unsafe;
  `¬A` → safe elim; feeds *both* databases atomically.

All of these take the shared marker vocabulary (`Intro th`, `Simp th`
(≡ existing rewrite argument), `Split th`, `Cong th`, …), so
`AUTO_TAC [SIntro foo, Split listTheory.list_case_split]` plays the role
of `auto intro!: foo split: ...`.

<h2 id="8-phase-5--generic-linear-arithmetic-and-arith_tac-srcautolinarith-d6">
8. Phase 5 — Generic linear arithmetic and <code>ARITH_TAC</code>
(<code>src/auto/linarith/</code>) (D6)
</h2>

1. **Core engine**: port of the `Fast_Lin_Arith` functor
   (`fast_lin_arith.ML`): untrusted Fourier–Motzkin over integer-scaled
   `lineq` records with `injust` justification trees (Farkas multipliers:
   `Asm | Nat | LessD | NotLessD | Multiplied | Added`); kernel replay of
   the certificate (`mkthm`: monotone addition, scaling, simplification);
   `≠`-elimination by case split bounded by a `neq_limit`; discreteness
   flags for nat/int rounding (`<` ↦ `≤ −1`).
2. **Instance records** instead of type classes (the established HOL4
   idiom, cf. `Normalizer`): a record packaging the ordered-structure
   constants, literal handling, and the lemma kit `mkthm` needs; shipped
   instances: `num`, `int`, `real`, `rat`; user-registrable (persistent
   registry, ThmSetData-backed).
3. **Preprocessing layer**: port of `lin_arith.ML` — atom decomposition
   with coefficient extraction; `add_inj_const`-style handling of
   injections (`&` : num→int, `real_of_int`, …); bounded pre-splitting of
   `min/max/abs`, nat subtraction, `div/mod` (split-theorem driven, reuses
   the §5 splitter machinery where applicable).
4. **Simp integration**: the engine wrapped as (a) a type-generic reducer
   (`LINARITH_ss`, superseding nat-only `ARITH_ss` — swapped in as the
   `srw_ss` default only at promotion, D10) and (b) an unsafe solver for
   side conditions (§5.3), with the context-filtering + caching pattern of
   `numSimps.CTXT_ARITH`/`Cache`.
5. **`ARITH_TAC` registry** (port of `arith_data.ML`): ordered, extensible
   tactic registry + `[arith]` fact set inserted before running; default
   chain: generic linarith (full splitting) → `PRESBURGER_TAC` (§9) for
   nat/int goals → `REAL_ARITH` backends for real goals.  `DECIDE`'s
   behavior is unchanged until promotion; the layer's `ARITH_TAC` is the
   strength-parity entry point.

Certificate-checking stays LCF-style proof-producing (reflection deferred
to the later verified-QE phase, per D1/D6; cf. Chaieb & Nipkow JAR 2008 on
the trade-off).

## 9. Phase 6 — `PRESBURGER_TAC` (`src/auto/presburger/`) (D7)

Front end achieving `cooper.ML`-parity preprocessing over the existing
complete engines:

1. Normalization: strip/atomize; generalize non-Presburger subterms
   (extending `IntDP_Munge.non_presburger_subterms` handling); thin
   premises that cannot contribute; nat→int lifting
   (`IntDP_Munge.dealwith_nats`).
2. `[presburger]` rule set: `mod`/`div`/`abs`/`min`/`max` elimination via
   split theorems, `dvd`/parity idioms, power-of-constant handling —
   mirroring the rule corpus of `src/HOL/Presburger.thy`.
3. Engine escalation: **Omega first** (fast on the QF/low-alternation
   goals dominating practice), **Cooper fallback** (full quantifier
   structure) — both already proof-producing and complete (Norrish 2003).
4. Registered as the Presburger stage of the `ARITH_TAC` registry (§8.5).

Later phase (sketch, per D1): verified reflected Cooper executed by
`computeLib`/`cv_compute` (Chaieb & Nipkow LPAR 2005: ~200× over LCF
replay), as a third, optional engine — plus Ferrante–Rackoff and MIR for
linear real / mixed goals (Nipkow JAR 2010; Chaieb IJCAR 2006).

## 10. Phase 7 — `ALGEBRA_TAC` / `RING_TAC` (`src/auto/algebra/`) (D8)

1. **Instance registry**: persistent (ThmSetData-backed) map from
   (a) carrier types and (b) abstract-structure hypothesis patterns
   (e.g. `Ring r`) to semiring/ring/field instance records — exactly the
   data `Semiring_Normalizer` keeps as context data (`is_const`,
   `dest_const`, `mk_const`, `ring_eq_conv`, axiom theorems).  Shipped
   instances: `num`, `int`, `real`, `rat`, abstract `Ring r`
   (via `ringLib`), and words (`word n` as comm. ring; evaluate feasibility
   against `wordsLib` normalization early).  One-declaration registration
   for user structures.
2. **`RING_TAC`** = normalization + Gröbner refutation with cofactor
   certificates on universally quantified (in)equations;
   **`IDEAL_TAC`** = ideal-membership witness synthesis
   (`grobner_ideal`); **`ALGEBRA_TAC`** = `RING_TAC ORELSE IDEAL_TAC`
   (Isabelle's `algebra_tac`, `groebner.ML`; Chaieb & Wenzel 2007).
   Engine = the existing `Grobner`/`Normalizer` (no re-port; only the
   dispatch and instance plumbing are new).  Field division via the
   existing parsing-into-polynomial-form route; Rabinowitsch trick already
   present.
3. **`ringLib` promotion**: move the abstract-ring instance support from
   `examples/algebra/ring/` into the layer (and eventually `src/`),
   keeping its theory dependencies stratified.
4. **Simp collections**: named `algebra_simps` / `field_simps` sets
   (division elimination, ordered-field rearrangement) as ssfrags +
   ThmSetData sets across num/int/real/rat, mirroring the corpora of
   `Groups.thy`/`Fields.thy`.

## 11. Phase 8–9 — Seeding, benchmarking, promotion; resolved micro-decisions

### Seeding (Phase 8, continuous from Phase 1)

Theory-by-theory rule corpus in seed theories: `bool`, `pair`, `sum`,
`option`, `list`, `pred_set`, `finite_map`, `arithmetic`, `integer`,
`real`, `string`, `rich_list`, `sorting`, …  Method: (a) mine Isabelle's
declarations (`HOL.thy`, `Set.thy`, `List.thy`, `Map.thy`, …) as the
guide for *which shapes* of lemmas get which classification; (b) reuse
HOL4's existing `srw_ss`/`export_rewrites` corpus for `[simp]`;
(c) iterate against the benchmark suite.  Safe/unsafe classification
follows the invertibility criterion (`classical.ML:8–16`), reviewed
rule-by-rule — misclassified "safe" rules are the classic way clasets rot.

### Benchmarking (Phase 8)

- Parity suite: Pelletier problems (blast); Isabelle's `auto`/`force`
  regression goals translated to HOL4; `lin_arith`/Presburger example
  sets (incl. `src/integer/testing/` already in-repo); Gröbner examples
  (`NUM_RING`/`INT_RING` corpora + Isabelle `Groebner_Examples.thy`,
  vendored at `sources/src/HOL/Examples/Groebner_Examples.thy`).
- Strength metric: solved-goal counts + wall-clock, tracked in the layer's
  selftests (failing = regression); a comparison table vs Isabelle
  documented per release.
- Distribution impact: full `bin/build -F -t` green at every phase
  boundary (simp changes especially).

### Gate record

- **2026-07-15, Phase 0:** `bin/build -F -t` **green** (TASK_13 gate).
- **2026-07-16, Phase S:** per-task
  `bin/build -t --seq=tools/sequences/upto-parallel` gates **green**
  (TASK_01–TASK_13); full `bin/build -F -t` gate **green** at commit
  `3620dc729ef32204161ecf425362872ad1b3d317` (TASK_15).
- **2026-07-17, Phase 1:** `bin/build -F -t` reached the parallel core
  build, then failed in `src/probability` while proving
  `in_borel_measurable_inv` in `real_borelTheory`.  The same failure was
  reproduced with
  `Holmake HOLSELFTESTLEVEL=1 real_borelTheory.uo` at the Phase-1 branch
  base, commit `b0002151f63b0072922b8d30fa892de85ef5fed6`, proving it
  pre-existing; no Phase-1 fix was made.  The command
  `tools/h4pedant/h4pedant src/auto/classical/` was **clean** at commit
  `0642ba5540ab826f8e9c375d7b25f7c6ae033804` (TASK_09).
- **2026-07-19, Phase 2:** `bin/build -F -t` reached the parallel core
  build, then failed in `src/probability` while proving
  `in_borel_measurable_inv` in `real_borelTheory`.  This is the exact
  failure reproduced at the Phase-1 branch base
  (`b0002151f63b0072922b8d30fa892de85ef5fed6`) by the TASK_09 gate,
  proving it pre-existing; no Phase-2 fix was made.  The commands
  `tools/h4pedant/h4pedant src/auto/classical/` and
  `tools/h4pedant/h4pedant src/auto/blast/` were **clean** at commit
  `30b76dc93fbc772385919ae27a7b0cc00d82d379` (TASK_27).
- **2026-07-21, M5 at `7ea3b07fa`:** the rules, classical and blast
  directory gates passed with 77, 168 and 193 `OK` results, and the source
  recognition audit was clean.  The first clean
  `bin/build -t --seq=tools/sequences/upto-auto` integration gate passed.
  The following explicit `bin/build -F -t` failed reproducibly in
  `src/probability/real_borelTheory` while proving
  `in_borel_measurable_inv`.  This follows, rather than replaces, the
  historical 2026-07-19 Phase-2 probability failure above.
- **2026-07-22, principled simplifier repair:** commit
  `65250f8c38f59a46f4350cc33e837b3de2508bf3` (`Preserve global bounded
  rewrite lifetimes`) repaired the general defect without editing a
  probability proof, adding recognition, or changing a benchmark count or
  budget.  Invocation-shared bounded controls preserve global rewrite
  lifetimes across assumption and conclusion traversals; failing-first
  regressions cover the defect.
- **2026-07-22, final fresh M5 gates at `65250f8c3`:** a fresh detached
  worktree configured successfully in 18.17 s.  `upto-auto` passed in
  9m41.26s and explicit `bin/build -F -t` passed in 15m53.50s, both ending
  `Hol built successfully.`  The full gate reported `real_borelTheory` `OK`
  in 14 s and its direct artifacts record saving/exporting
  `in_borel_measurable_inv`.  The audited package's 45-entry rereview
  manifest verifies and hashes to
  `a6dde0623911ee486494b341ba9845c928f8fd1787c230b57134c95ae62e916b`.
  `upto-auto` contains expected `suspFastTheory ... F-CHEAT` and zero
  `CHEATED` results.  The full build contains the intentional pre-existing
  upstream `cv_compute/automation ... CHEATED` result with three
  `Saved CHEAT` entries and zero `F-CHEAT` results.  Both gates passed
  terminally.  Historical transcripts did not independently capture
  `TMPDIR`; the empty task `TMPDIR` postflight is corroboration only.
- **2026-07-22, historical final gates at `5bc674569`:** the wholly
  fresh v2 package
  `/tmp/isabelle-tactics-task7f-20260720-root/task23_final_clean_gates_fresh/`
  records configure 17.79 s,
  prerequisite setup 206.35 s, rules `Holmake`/selftest 15.54/12.08 s,
  classical `.19`/16.21 s, blast `.20`/20.69 s, level-2 blast 141.20 s,
  `upto-auto` 244.10 s and explicit full build 989.25 s.  Both integrated
  builds ended in terminal success.  The final reviewed live seal has 395
  entries and digest
  `2d66cab8b9db6c8a5e2c345a89c0ca2755b4a4d35cebc45cab9dedb2d507d3bc`;
  the 394-entry inventory has digest
  `786c8d9c2f763ee342eaaee8c5f79659be0433013cc00d4f43ccc4445b8b3812`.
  Recognition/shortcut audits, seed guard and h4pedant are green; known
  intentional CHEAT classifications remain disclosed.  No top-level v2
  driver was retained, so whole-schedule enforcement is not independently
  proven; named wrapper intervals do not overlap, but unrecorded activity in
  gaps is not excluded.  Process snapshots are scoped; copied
  probability/CHEAT direct artifacts are post-run corroboration, while the
  full log itself proves `real_borelTheory` `OK`.  The old first attempt is
  rejected for `0.497043743` s of setup overlap.  This evidence does not
  establish `/tmp/Holmakefile` nonmutation.
- **2026-07-23, historical accepted pre-commit patch evidence for
  `f4fc8be66`:** candidate 05 was collected from parent `d90554b5f` with
  the frozen patch that is exactly the reviewed source commit.  Fresh
  configure, exact `upto-auto`, direct Rules/Classical, Blast levels 1
  and 2, and h4pedant passed.  The suite counts were 48/48, 9/9 and 4/4,
  with one level-2 kernel-valid Halting II `OK`.  Manifest digest:
  `95be727c037229af3514a85d2e2f11ea56b76cdf19b84c1aa5e5372c58322d07`.
  Its exact integrated disclosure was one expected
  `suspFastTheory ... F-CHEAT`, zero `CHEATED` and zero `Saved CHEAT`.
  No full build ran in candidate 05.  It remains historical functional
  evidence and is superseded for current gate acceptance by attempt-04.
- **2026-07-23, authoritative committed-state Phase-2 gate at
  `f4fc8be66`:** accepted attempt-04 tested commit
  `f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`, tree
  `9f9dd4c4d5c4e3f303a7fa71605ae7b87ca9aa55`, with clean tracked state
  and index.  Its frozen 18-command plan has SHA-256
  `941435ac994a5dd43534b852c4f9508dce7161c2a0ecc96589fca3a92c403a00`.
  All 18 commands exited 0 in an aggregate 1799.992895 seconds, with no
  overlap and a passing post-run semantic audit.

  Fresh configure took 20.392579 s.  The exact
  `bin/build -t --seq=tools/sequences/upto-auto` took 527.781691 s and
  ended `Hol built successfully.`; it reported one expected
  `suspFastTheory ... F-CHEAT`, zero `CHEATED`, and zero `Saved CHEAT`.
  `bin/build -t --seq=tools/sequences/upto-parallel` took 8.399151 s.
  Rules `Holmake`/selftest took .057831/13.998101 s; Classical took
  .150386/18.075709 s; Blast `Holmake`/default/level-2 took
  .154177/28.799230/47.076659 s.  Both Blast runs record exactly 48/48
  unique Pelletier, 9/9 unique Table 1, and 4/4 unique set successes.
  Level 2 records exactly one kernel-valid Halting II `OK`; both expected
  lists are empty.

  H4pedant over Rules, Classical and Blast, `git diff --check`, the
  recognition/expected-list hygiene audit, and post-run identity checks
  passed.  The explicit `bin/build -F -t` was deliberately last among the
  build/test commands, took 1132.087214 s, and ended
  `Hol built successfully.`  Its separate classifications are zero
  `F-CHEAT`, one intentional pre-existing upstream
  `cv_compute/automation ... CHEATED`, and exactly three `Saved CHEAT`
  theorem names from the separately recorded .042298-second artifact
  command: `cv_exp_size_alt_ind`, `cv_exp_size_alt_def`, and
  `cv_exp_size_alt_thm`.

  The exact tested-tree inventory has 32,933 entries and SHA-256
  `21e331d3567063931f96bf897845cf131b252d3f7a80d08c8ffcde6ea678ae5e`.
  The exact package manifest has 47 entries and SHA-256
  `805cb6086f5fb65e0869dfd73722c9296cb0ec467fc150e8c410fe9d4e7e9c52`;
  its postseal lexical checker passes and all 28 independent retained
  adversaries are rejected.  The accepted package is:

  ```text
  /tmp/isabelle-tactics-task7f-20260720-root/
  task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
  ```

  Independent task34d review accepted the source and evidence.  Its
  transient package `__pycache__` was removed and descendant bytes, types
  and hashes restored; only the package-root mtime changed, which is outside
  the manifest schema.  No immutable-history, performance, profiler,
  resource, security, process or atomicity claim is made.  The
  requirement-by-requirement audit in `PLAN_phase_1_2_green.md` §6 closes
  TASK_27 and the Phases 1/2 Green plan.
- **2026-07-23, M1/M2 tower removal at `52a267058`:** a clean detached
  worktree at commit `52a267058` configured successfully.  The exact
  `bin/build -t --seq=tools/sequences/upto-auto` phase gate and the
  explicit `bin/build -F -t` full gate both exited 0 and ended
  `Hol built successfully.`  Targeted Classical and Blast
  `Holmake`/selftests, h4pedant over both directories, `git diff --check`,
  the removed-export search, and the production-API preservation audit
  also passed.  The fine-grained tower is retired; production cooperative
  interruption and coarse end-to-end wall-clock measurement remain.
- **2026-07-24, shared generic-marker predicate:** focused `Holmake` and
  `selftest.exe` gates passed in `src/marker`, `src/simp/src`, and
  `src/auto/rules`; h4pedant over all three directories and
  `git diff --check` were clean.  Both
  `bin/build -t --seq=tools/sequences/upto-parallel` and
  `bin/build -t --seq=tools/sequences/upto-auto` exited 0 and ended
  `Hol built successfully.`  The explicit `bin/build -F -t` also exited 0
  and ended `Hol built successfully.`; `real_borelTheory` was `OK` in
  14 seconds.  Its sole non-`OK` classification was the intentional
  pre-existing upstream `cv_compute/automation ... CHEATED` selftest.
  The supported documentation fallback reported that `pandoc` was absent,
  wrote the mdbook Markdown mirror, and did not affect the successful gate.
- **2026-07-24, Phase 3 at `2da4b3d64`:** `bin/build -F -t` exited 0
  and ended `Hol built successfully.` in 75.31 seconds wall-clock.  The
  full-build transcript contained zero `F-CHEAT`, zero `CHEATED`, and
  zero `Saved CHEAT` results.  `tools/h4pedant/h4pedant` was clean over
  every Phase-3-touched directory: `help/Docfiles`, `src/auto/blast`,
  `src/auto/clasimp`, `src/auto/classical`, `src/auto/rules`,
  `src/parallel_builds/core`, `src/simp/src`, and `tools/sequences`.

### Promotion (Phase 9, gated on the layer proving itself)

1. Move declarations from seed theories inline into home `*Script.sml`
   files (mechanical, per-theory PRs).
2. Move the subtree into the pre-`boss` band of the build sequence;
   `bossLib` re-exports the tactic surface.
3. Swap defaults where decided then (e.g. `LINARITH_ss` for `ARITH_ss`
   inside `srw_ss`; `DECIDE` escalation) — each its own owner decision at
   promotion time.

### Later phases (sketched per D1)

Verified/reflected QE (Cooper, Ferrante–Rackoff/Loos–Weispfenning, MIR)
on `cv_compute`; argo-style internal certificate-producing SMT
(CDCL + congruence closure + simplex, cf. Dutertre & de Moura CAV 2006,
Thiemann et al. FroCoS 2019); `approximation`-style verified interval
arithmetic.  Each gets its own plan when reached.

### Resolved micro-decisions (within the owner decisions above)

- **Directory**: the layer lives at `src/auto/`.
- **Tactic names** (collision check against all `src/**.sig` performed
  2026-07-14; `SAFE_TAC`, `FAST_TAC`, `BEST_TAC`, `AUTO_TAC`,
  `FORCE_TAC`, `CLARIFY_TAC`, `CLARSIMP_TAC`, `DEEPEN_TAC`, `BLAST_TAC`
  are all free):
  - `BLAST_TAC` is used as-is; its documentation cross-references
    `blastLib.BBLAST_TAC` (bit-blasting) to preempt confusion.
  - `ARITH_TAC`: the layer exports it, deliberately shadowing
    `numLib.ARITH_TAC`/`intLib.ARITH_TAC` when opened later — safe
    because the registry tactic strictly subsumes both (same goals
    solved and more); qualified names remain untouched.
  - `RING_TAC`: `ringLib.RING_TAC` (examples/) is absorbed into the
    layer as the abstract-ring instance of the generic `RING_TAC`
    (§10.3), so there is no lasting duplicate.
  - Best-first engine entry point: `AESOP_TAC`.
- **Marker constructors**: `SIntro`, `Intro`, `SElim`, `Elim`, `SDest`,
  `Dest`, `Iff`, `Split`, `Del` — reusing existing `Cong`, `Excl`, `SF`,
  `Once` unchanged (no signature collisions).
- **Phase S interface freeze**: the authoritative list is
  `PLAN_phase_S.md` §12; later changes to those interfaces require an owner
  decision.
- **Phase 1–2 amendments to the Phase-0 freeze list**: the unchanged
  `claset_config.size_of : goal -> int` interface now defaults to Isabelle's
  atoms-plus-abstractions metric instead of kernel `Term.term_size`, and
  `clasetRules` additively exports `REV_DUP_ELIM_RULE : thm -> thm`.  Both
  amendments are enacted and regression-tested; all other Phase-0
  freeze-list interfaces remain frozen.
- **Phase 1–2 interface freeze**: the current `clasetMeta` store API;
  `clasetGoal`'s node shape and search bookkeeping; `clasetStep`'s step and
  record contracts, depth-step parameterization, and wrapper application
  points; `clasetReplay`'s replay-step vocabulary used by blast; the full
  public `classicalLib` tactic signatures; and `tableauLib`'s complete
  surface are frozen at Phase-2 completion.  Changes require an owner
  decision; module internals remain private.
- **Phase 3 amendments to earlier freeze lists** (all owner-approved
  2026-07-19, D30–D33): marker vocabulary +`Simp`/`Iff` (Phase 0);
  layer-wide plain-theorem convention changed to insertion, affecting
  `classicalLib`/`tableauLib` behavior (Phase 2); additive exports
  `classicalLib.depth_solve_tac` and `tableauLib.blast_depth_tac`
  (Phase 2); `GEN_GLOBAL_SIMP_TAC` gains a leading `simp_mode`
  parameter (Phase S §12).
- **In-engine `mut_impc` revisit**: if Phase 8's Isabelle-translated
  benchmarks show gaps attributable to mutuality inside `SIMP_RULE`, under
  binders, or in nested implications, an engine port becomes its own
  planned item.  Otherwise the tactic-level D17 implementation stands.
- **Numeric defaults**: adopt Isabelle's — `AUTO_TAC` depths (4, 2),
  blast depth cap 20, linarith `neq_limit`/`split_limit` 9; simp
  side-condition `cond_depth` stays 4 for all existing entry points and is
  set to 40 in the layer's simpsets (§5.5).  All are configurable;
  benchmark results may retune the layer's values (a tuning matter, not
  an open design question).

## 12. Phasing, dependencies, risks

```
Phase 0  rules/          ──┐  (claset DB, attributes, seeds, TypeBase hook)
Phase S  simp upgrades   ──┤  (parallel; needed by Phases 3+)
Phase 1  SAFE/CLARIFY    ──┤  needs 0
Phase 2  FAST/BEST/DEEPEN + BLAST   needs 0,1 (shared search forest)
Phase 3  AUTO/FORCE/CLARSIMP/[iff]  needs S,1,2
Phase 4  aesop engine               needs 0, forest of 2
Phase 5  linarith + ARITH_TAC       needs S (solver slot); independent of 1–4
Phase 6  PRESBURGER_TAC             needs 5 (registry); engines exist
Phase 7  ALGEBRA/RING               independent (engines exist)
Phase 8  seeding + benchmarks       continuous, gates parity claims
Phase 9  promotion                  gated, per-item owner decisions
```

Top risks and mitigations:

1. **Aesop metavariable algorithm** (novel): scheduled last among core
   phases; nothing else depends on it; the shared forest isolates it.
2. **Blast reconstruction divergence** (known failure mode even in
   Isabelle, esp. around equality substitution reordering): implement the
   assumption-rotation and hyp-subst replay carefully first; Pelletier
   suite + PROOF FAILED telemetry in selftests.
3. **Simp regressions from new hooks**: empty-by-default hooks, full
   builds at each step, `src/simp/src/selftest.sml` extended before each
   feature lands.
4. **Seed corpus rot / misclassification**: benchmarks as regression
   tests; classification review checklist; promotion moves declarations
   next to theorems, eliminating drift long-term.
5. **Strength shortfall vs Isabelle** on specific goal classes: the
   benchmark suite is the arbiter; gaps feed back into rule corpus or
   engine tuning before parity is claimed.

## 13. Bibliography

All papers are archived locally under `.agent-files/papers/` —
agent-readable text at `papers/<slug>.txt`, original PDFs at
`papers/pdf/<slug>.pdf`, provenance (source URLs, download dates,
caveats) in `papers/README.md`.

- L. C. Paulson, *A Generic Tableau Prover and its Integration with
  Isabelle*, J. UCS 5(3), 1999.  [`paulson1999-blast`]
- J. Limperg, A. H. From, *Aesop: White-Box Best-First Proof Search for
  Lean*, CPP 2023.  [`limperg-from2023-aesop`]
- A. Chaieb, T. Nipkow, *Proof Synthesis and Reflection for Linear
  Arithmetic*, JAR 41, 2008 [`chaieb-nipkow2008-linarith`]; *Verifying
  and Reflecting Quantifier Elimination for Presburger Arithmetic*,
  LPAR 2005 [`chaieb-nipkow2005-presburger`].
- T. Nipkow, *Linear Quantifier Elimination*, JAR 45(2), 2010.
  [`nipkow2010-linqe`]
- A. Chaieb, M. Wenzel, *Context Aware Calculation and Deduction: Ring
  Equalities via Gröbner Bases in Isabelle*, Calculemus 2007.
  [`chaieb-wenzel2007-groebner`]
- A. Chaieb, *Verifying Mixed Real-Integer Quantifier Elimination*,
  IJCAR 2006.  (Closed access — no open copy exists; DOI
  10.1007/11814771_43.  The material is covered by §4.3.3 of Chaieb's
  PhD thesis, archived as [`chaieb2008-thesis`].)
- A. Chaieb, *Automated Methods for Formal Proofs in Simple Arithmetics
  and Algebra*, PhD thesis, TUM 2008.  [`chaieb2008-thesis`]
- J. Harrison, *Automating Elementary Number-Theoretic Proofs Using
  Gröbner Bases*, CADE-21, 2007 [`harrison2007-groebner`]; *Verifying
  Nonlinear Real Formulas via Sums of Squares*, TPHOLs 2007
  [`harrison2007-sos`].
- M. Norrish, *Complete Integer Decision Procedures as Derived Rules in
  HOL*, TPHOLs 2003 [`norrish2003-integer-dps`]; *Arithmetic Decision
  Procedures: a Simple Introduction* [`norrish-arithmetic-dps`].
- R. J. Boulton's arith library (HOL88 lineage; documented in
  `src/num/arith/` and `help/Docfiles/numLib.ARITH_CONV.smd`);
  R. E. Shostak, *On the SUP-INF Method for Proving Presburger
  Formulas*, JACM 24(4), 1977 [`shostak1977-supinf` — scanned original;
  text layer has minor OCR spacing noise].
- B. Dutertre, L. de Moura, *A Fast Linear-Arithmetic Solver for
  DPLL(T)*, CAV 2006 (extended version)
  [`dutertre-demoura2006-simplex`]; R. Bottesch, M. W. Haslbeck,
  R. Thiemann, *Verifying an Incremental Theory Solver for Linear
  Arithmetic in Isabelle/HOL*, FroCoS 2019 [`thiemann2019-simplex`].
- S. Böhme, T. Weber, *Fast LCF-Style Proof Reconstruction for Z3*,
  ITP 2010.  [`boehme-weber2010-z3`]
- Isabelle sources — vendored verbatim under `.agent-files/sources/`
  (mirror-isabelle commit `f7e02b7e1f31`, 2026-07-12; provenance and
  per-file purpose table in `sources/README.md`):
  `src/Provers/{classical,blast,clasimp,hypsubst,splitter}.ML`,
  `src/Provers/Arith/fast_lin_arith.ML`,
  `src/Pure/{raw_simplifier,simplifier,bires}.ML`,
  `src/Pure/Isar/context_rules.ML`,
  <code>src/HOL/Tools/{simpdata,lin_arith,arith_data,groebner,<!--
  --><wbr>semiring_normalizer}.ML</code>,
  `src/HOL/Tools/Qelim/cooper.ML`,
  `src/HOL/{HOL,Presburger,Fields,Groups}.thy`, isar-ref (`Generic.thy`).

## 14. Task 7m/7n M2 record and later Phase-2 outcomes

Task 7m's separately reviewed v10 P38@4 calibration is authoritative only
for its predeclared `mixed/indeterminate` result.  Its balanced schedule
completed 20 fresh children, five per mode, with no retry.  External medians
were A `9.189388257`, B `9.237345589`, C `11.027194246`, and D
`16.328066360` seconds.  Exact derived ratios were B/A `1.005219`, C/A
`1.199992`, D/C `1.480709`, and clock share `0.742557`; exact increments
were D-A `7.138678103`, C-A `1.837805989`, and D-C `5.300872114` seconds.

All rows had outcome `none`, 22 attempts, search counters
`2507169,624,140,210,233,4,322,5446`, and identical ordered 37-field
signatures.  Each C/D row had 61,486,260 clock reads, 22 terminal-summary
reads, and zero trace allocations and sequence-statistics reads.  B/A passed
the inclusive `[0.95,1.05]` sanity gate.  Clock-dominant required clock share
at least `.80` and D/C at least `1.50`; aggregation-material required C/A at
least `1.25`.  Neither predicate held, hence `mixed/indeterminate`.

This was a process-level ablation with no target.  It authorizes no target
run or target profile, projected speedup, optimization selection, capability
attribution, or M2 closure.  The external review-resolution erratum corrects
only cleanup chronology: the final live-artifacts compound command had no
`set -e`, ended with `! pgrep`, and regex-self-matched enclosing audit
payloads containing an earlier literal `/task7mcalibration.exe`.  Its status
cannot establish either preceding path-test status, and the original `.hol`
predicate attribution was wrong.  Cleanup authority instead rests on the
status-zero cleanup transaction, separate status-zero exact-argv endpoint,
and final/current absence of the live executable and `.hol` tree.  Future
cleanup checks must retain independent status-bearing path tests and a
separate exact-argv endpoint audit, with no regex `pgrep`.

At the time of Task 7m, the next M2 diagnostic was target-free,
low-frequency external statistical sampling.  Task 7n's reviewed
`benchmarks/m2-low-perturbation-diagnostic-final/` records the outcome.
The preferred fixed 9 Hz DWARF `perf` probe was permission-blocked by
`perf_event_paranoid=4`: `perf record` exited 255, leaving no usable or
readable sample data, and the synthetic report sentinel 125 was not a
`perf report` exit status.  No sampled P38 run, symbol/DSO attribution or
time-category result exists.

The predeclared standalone fallback completed a balanced ten-child schedule
with five fresh observations per mode and exactly 61,486,260 closure calls
per row.  Its net median was `5.579728519` seconds; against Task 7m's D-C
`5.300872114`, the ratio `1.052606` lies within the frozen
`[0.80,1.20]` consistency band.  This supports only limited standalone
consistency with Task 7m.  At that point M2 remained conditional and open:
further sampling required a host with `CAP_PERFMON` or lower
`perf_event_paranoid`, and no optimization, capability cause, projected
speedup or M2 closure was selected.  D35 and the current record below
supersede only that status, not the observation.

Later M3 work found no biconditional or gamma-accounting defect.  General
rule replay repairs preserved exact instantiated rules through all replay
paths, making P38, P41, P42 and P43 kernel-valid.  Commit `7ea3b07fa` then
added exact beta/eta transport back to the caller's target without changing
the historical 46/48 count.  M4's public depth-7 Halting-II attempt timed out
after `120.001251000` seconds under the unchanged 120-second budget.

The final M1 remeasurement at `5bc674569` uses public production
`Tactical.VALID (BLAST_TAC [])`, unchanged default maximum depth 20 and the
unchanged 30-second `Timeout.apply`.  Baseline `be308c56d` is right-censored
at `>=30s` for each of P34/P38/P41/P42/P43/P45.  Three exact kernel-valid
current samples are P34 `1.329700/1.320911/1.316835`, P38
`.099931/.100237/.100036`, P41 `.009163/.009141/.009075`, P42
`.010805/.010697/.010773`, P43 `.033935/.033627/.033786`, and P45
`3.543755/3.530560/3.470660` seconds.  Strict interval separation meets M1
on all six; no censored ratio is computed.  The reviewed package is in this
directory:

```text
/tmp/isabelle-tactics-task7f-20260720-root/task22_m1_final_measurement_fresh/
```

Its 1,818-entry final manifest digest
is `fa9bc5a1a98be7d09522f1c8d8c2100d18a73e4078987a5314a062784a161571`.

At `5bc674569`, the honest suites were 48/48 Pelletier with expected list
`[]`, 9/9 Table 1 with expected list `[]`, and 4/4 sets.  Historical M5
gates passed and TASK_23 was reclosed, while Halting II and M2 still
remained open.  That is now a historical status.

Reviewed commit `f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1` contains the
accepted replay repair.  Its centralized capture-safe persistent
metavariable expansion and exact replay have no recognition or fallback
shortcut.  Accepted committed-state attempt-04 records 48/48 Pelletier,
9/9 Table 1, 4/4 sets and one kernel-valid Halting II `OK`.  TASK_23
remains completed and TASK_24 is completed/reclosed.

D35 closes M2 because the complete suite and Halting II now pass.  The
kernel profiler is unavailable under the host setting and produced no
usable sample data; this is a disclosed environmental limitation, not an
open blocker.

M1 is closed under its original milestone-local acceptance criterion:
behaviour preservation and measured improvement on the six workloads, with
no requirement to rerun after every later patch.  The verified
`5bc674569` package has a 1,818-entry manifest, six `>=30s` censored
baselines, and all 18 exact kernel-valid public-production runs below
`3.544s`.  No performance run exists for `f4fc8be66`, so current-revision
performance is not claimed.  That transparent limitation remains a
non-blocking follow-up.

Attempt-04 supplies the committed-state `bin/build -F -t`, exact direct
suites, integrity checks and final semantic audit recorded in §11.  The
requirement audit in `PLAN_phase_1_2_green.md` §6 finds no unmet criterion.
Phases 1/2 and their Green closure plan are complete; no next task remains
for this phase.

On 2026-07-23, the owner accepted retiring the closed M1/M2
timing/diagnostic tower and its fine-grained current-revision
remeasurement capability.  The removal landed in commits `199dfe4cd`,
`f23a56183`, `45d1b6b01`, `03ee37955`, and `52a267058`; coarse
end-to-end wall-clock measurement remains available for Phase 8.  The
non-blocking statement that current-revision performance is not claimed
therefore remains historical rather than an outstanding tower
remeasurement task.
