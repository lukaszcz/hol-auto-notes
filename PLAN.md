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

| Asset | Location | Notes |
|---|---|---|
| Simplifier (Isabelle-derived) | `src/simp/src/` (`simpLib`, `Traverse`, `Travrules`, `Cond_rewr`, `Opening`, `Unwind`, `Satisfy`, `Cache`) | Conditional + ordered/permutative rewriting, HO nets, congruence procs, preorder-parametric (an Isabelle-superset feature), dproc hooks, `Once`/`Ntimes` bounds |
| Stateful simpset + `[simp]` attribute | `src/basicProof/BasicProvers.sml` (`srw_ss`, `export_rewrites`), `src/1/ThmSetData.{sig,sml}`, `src/1/ThmAttribute.{sig,sml}` | `ThmSetData.export_with_ancestry` gives attribute registration + theory-delta persistence + ancestry merging — the plumbing for all new rule sets |
| FO provers | `src/meson/src/mesonLib.sml` (model elimination, iterative deepening), `src/metis/` (resolution + reconstruction) | Kept as-is; not the basis of BLAST (owner decision) |
| Nat linear arith | `src/num/arith/src/` (Boulton 1992: FM + Shostak SUP-INF), `numSimps.ARITH_ss` (cached simp dproc) | Incomplete (no integer-divisibility facts); remains a fast backend |
| Complete Presburger | `src/integer/`: `Omega*` (Pugh's Omega test), `Cooper*` (Cooper's QE), `IntDP_Munge` (normalization, nat→int lifting) | Norrish, TPHOLs 2003.  Proof-producing, complete; currently unwired from `DECIDE` |
| Real arith | `src/real/RealArith{,0}.sml` (Positivstellensatz-certificate linear prover, HOL Light lineage), `RealField.sml`, `SOSLib.sml` (nonlinear, CSDP), `NLArith.sml` | |
| Gröbner + normalizer | `src/num/reduce/src/Grobner.{sig,sml}`, `Normalizer.{sig,sml}` (Harrison ports, 2022) | Buchberger with Nullstellensatz cofactor certificates checked by `SEMIRING_NORMALIZERS_CONV`; Rabinowitsch trick; ideal membership.  Wired only into `INT_RING`, `REAL_RING/FIELD`, `NUM_RING`, and abstract `Ring r` via `examples/algebra/ring/ringLib.sml` |
| Hypothesis substitution | `BasicProvers.VAR_EQ_TAC` (`src/basicProof/BasicProvers.sml:842`), `gvs` elimvars | The `hyp_subst_tac` analogue exists |
| Quantifier heuristics | `src/quantHeuristics/`, `Satisfy`/`SFY_ss`, `Unwind` | One-point rules, unification-based ∃ instantiation |
| Evaluation | `src/compute/src/computeLib.sml` (`EVAL`), plus `cv_compute` | Substrate for the later reflected-QE phase |

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

| # | Decision |
|---|---|
| D1 | **Scope**: phased full-parity program.  Core phases planned in depth: classical family, simplifier upgrades, arith, presburger, algebra/ring.  Later phases sketched: verified/reflected QE (Cooper, Ferrante–Rackoff, MIR), argo-style internal SMT, `approximation`. |
| D2 | **Classical architecture**: build BOTH a faithful port of Isabelle's claset design (`Provers/classical.ML`) AND a full aesop-style best-first engine (Limperg & From, CPP 2023), now, over ONE shared rule database whose schema carries both kinds of metadata from day one. |
| D3 | **blast**: faithful port of Paulson's `Provers/blast.ML` (untyped tableau + tactic-script reconstruction). |
| D4 | **Rule infrastructure**: mirror the simpset dual-track design — first-class claset/ruleset values with combinators, plus a global stateful claset persisted through the theory-ancestry machinery (see D11); per-invocation modifiers as theorem-list markers extending the existing `Cong`/`Excl`/`SF` convention.  *Revised 2026-07-15 (D12)*: attribute surface is HOL4-native, not Isabelle-mimicking — `[intro]`/`[elim]`/`[dest]` (unsafe), `[sintro]`/`[selim]`/`[sdest]` (safe), plus `[iff]`, `[split]`, `[arith]` in later phases; removal via functions (`delrule`), not a del attribute. |
| D5 | **Simplifier**: extend simpLib in place (looper + splitter port, solver stacks, subgoaler, configurable limits/term order, congprocs in SSFRAG, fixpoint asm mode).  Keep top-down traversal; adopt skeleton-style optimizations only where behavior-preserving. |
| D6 | **arith**: port `Fast_Lin_Arith` as a generic Farkas-certificate engine parametric over instance records; port the `lin_arith.ML` preprocessing layer; wire as type-generic simp solver; `ARITH_TAC` = extensible registry with escalation linarith → presburger → real backends. |
| D7 | **presburger**: Omega first, Cooper fallback, behind Isabelle-parity preprocessing and a `[presburger]` rule set. |
| D8 | **algebra/ring**: persistent instance registry (types and abstract-structure hypotheses → semiring/ring/field instance records) + goal-type dispatch; `ringLib` promoted from `examples/`; curated `algebra_simps`/`field_simps` collections. |
| D9 | **Naming**: HOL4 uppercase convention only — `AUTO_TAC`, `BLAST_TAC`, `FORCE_TAC`, `FASTFORCE_TAC`, `SAFE_TAC`, `CLARIFY_TAC`, `CLARSIMP_TAC`, `FAST_TAC`, `BEST_TAC`, `DEEPEN_TAC`, `AESOP_TAC`, `ARITH_TAC`, `PRESBURGER_TAC`, `ALGEBRA_TAC`, `RING_TAC`, `IDEAL_TAC`.  No lowercase Isabelle-alias layer.  (Collision handling: §11, "Resolved micro-decisions".) |
| D10 | **Integration**: portable opt-in layer — own subtree in the default build (after the core), integration-identical mechanisms, central seed theories for the rule corpus, TypeBase hook + catch-up; promotion to full core integration planned as an explicit final phase. |
| D11 | *(2026-07-15, Phase 0)* **Claset persistence substrate**: one `AncestryData.fullmake` instance (tag `"claset"`) with a rich custom delta type (kind, safety, optional priority) and explicitly registered attributes — not `ThmSetData.export_with_ancestry`, whose fixed `ADD/REMOVE` delta type cannot carry the D2 schema.  Same mechanism family one level down; D10 unaffected.  Details: `PLAN_phase_0.md` §0. |
| D12 | *(2026-07-15, Phase 0)* **HOL4-native attribute syntax** (revises D4): `[intro]/[elim]/[dest]` unsafe, `[sintro]/[selim]/[sdest]` safe, mirroring the `Intro`/`SIntro`/… marker constructors; zero core-grammar changes; numeric aesop priorities as attribute arguments deferred to Phase 4 (small additive lexer tweak then). |
| D13 | *(2026-07-15, Phase 0)* **Wrapper representation**: layer-level nondeterministic tactic type `ntactic = goal -> (goal list * validation) seq.seq` (`portableML/seq`), `wrapper = ntactic -> ntactic`; safe wrappers compose ORELSE-style, unsafe APPEND-style — one wrapper vocabulary for Phases 1–4. |
| D14 | *(2026-07-16, Phase S)* **Loop hook surface**: all simpLib tactic entry points honor simpset loopers and final solvers; conversion/rule/prove entry points do not.  Empty default lists preserve distribution behavior. |
| D15 | *(2026-07-16, Phase S)* **Solver architecture**: one conversion-level solver type serves both engine side conditions (always unsafe) and tactic-level residual goals (safe or unsafe by mode); simpsets carry named safe/unsafe lists and a separately settable subgoaler.  The default subgoaler preserves the existing recursive traversal, context theorems are accumulated for solvers, tactics lift through `mk_tactic_solver`, and `REDUCER` stays unchanged. |
| D16 | *(2026-07-16, Phase S)* **Safe-simp mode**: an invocation-mode record on generic `GEN_SIMP_TAC`, not a simpset transformer or `SAFE_*` family.  The flag selects only the safe final-solver list; side-condition solving remains unsafe and loopers still run. |
| D17 | *(2026-07-16, Phase S)* **`mut_impc` realization** (revises §5.7): tactic-level through `global_simp_tac`, with change counting/fixed-tail skipping and opt-in conclusion-fixpoint and implication-rebuild flags; existing entries retain their semantics.  An in-engine port is deferred to the Phase 8 benchmark gate (§11). |
| D18 | *(2026-07-16, Phase S)* **Splitter congruence policy**: retain HOL4's strong congruences (`COND_CONG` and descent into case branches); `split_ss` adds only the splitter looper and the `cases_simp` analogue.  This deliberate strength-first divergence from Isabelle's weak-congruence pairing may be retuned after Phase 8 benchmarks. |
| D19 | *(2026-07-16, Phase S)* **`[split]` placement**: all split machinery lives in `src/simp` (`splitLib`, the `split` ThmSetData settype/attribute, `Split` marker, TypeBase cache, and `split_ss`); no default simpset consumes it in Phase S. |
| D20 | *(2026-07-16, Phase S)* **Names**: own module `splitLib`; `SPLIT_TAC`, `split_ss`, `Split th`, and attribute/settype `split`.  Collision-checked; the only shadow is an unaffected script-local `SPLIT_TAC` under `examples/`. |
| D21 | **Engine state representation and unifier**: the shared search engine (Phases 2 and 4; blast keeps its private untyped prototerm language per D3) uses typed metavariables represented as marked fresh free variables occurring as *leaves* (no Isabelle-style lifting), each carrying an explicit **allow-set** of eigenvariables it may mention (checked at bind time, plus occurs check); a **persistent** substitution store behind an abstract API (so the representation stays swappable); and a unifier = typed first-order core (modeled on `src/1/FullUnify`) **plus** the higher-order *pattern* case (`?m x1…xk ≟ t`, `xi` distinct eigenvariables ⇒ `?m := λx̄.t`) **plus** Lean-style first-order-approximation and η heuristics, single-solution and deterministic.  Matching mode = the same algorithm rejecting bindings of pre-existing metavariables.  Rationale: option-1 cost profile (no spines, no pervasive β-normalization — cheaper than Isabelle's own lifting) with Lean/Aesop-level capability; Lean's Aesop itself has no full HOU (CPP'23 §3.1.1), and nothing in this space runs enumerative HOU in-search.  The unifier is the hardest single component; it is concentrated, golden-testable, and can never cause unsoundness (kernel replay checks everything). |
| D22 | **One step cascade**: the classical step layer (safe/clarify/inst/unsafe/dup steps) is implemented **once**, over the engine's goal shape, with a mode flag (match vs unify) and per-step validation emission.  Phase-1 `SAFE_TAC`/`CLARIFY_TAC` are the cascade's metavariable-free instantiation: on such nodes every step carries its kernel validation directly, so the exported tactics are genuine `ntactic`s per D13 with no deferred replay, and wrappers apply as `ntactic` wrappers. |
| D23 | **Blast replay architecture**: `BLAST_TAC`'s recorded script replays left-to-right on the shared engine's states (initialized from the real goal): steps genuinely resolve and instantiate typed metavariables (Isabelle's division of labor — search finds the shape, replay re-finds first-order unifiers, cheap per Paulson §8.2); grounding happens once at the end via the engine's kernel replay.  PROOF-FAILED-backtrack into the tableau is preserved.  No untyped→typed back-translation, no Skolem↔variable registry.  BLAST thereby depends on the engine (both are Phase 2; scheduling coupling only). |
| D24 | **Engine wrappers, day one**: engine nodes are materializable as HOL4 goals with metavariables rendered as reserved rigid free variables; claset safe/unsafe wrappers are honored at exactly Isabelle's application points (uwrappers around the inst+unsafe rung — but *not* around `depth_tac`'s `inst0` closers, matching upstream `classical.ML:718`; swrappers inside every safe step); a wrapper's `(goals, validation)` result is lifted back (re-abstracting the rendered metavariables) and the validation recorded — wrapper steps replay for free.  Rigid semantics documented: a wrapper can never instantiate engine metavariables (Isabelle's rewriter-level guarantee; Isabelle's *solver-level* instantiation is a recorded Phase-3 option, `phase12-classical-search-port.md` §4.3). |
| D25 | **Dynamic pruning** (supersedes the static `safe_depth_tac` DETERM-polarity question, where upstream Isabelle has carried an inverted branch since 2009 — see `phase12-classical-search-port.md` §8): the engine implements the real invariant — *when a subgoal's complete solve instantiated no metavariable visible in the remaining goals, discard its alternatives* — i.e. blast's `prune`/`clashVar` rule (`blast.ML:841–865`) applied to the classical drivers.  This subsumes the corrected 2005 semantics (HOL4 entry goals are metavariable-free, so the outer solve is deterministic by the invariant) and prunes losslessly deep inside metavariable-laden states.  No compatibility flags. |
| D26 | **Full driver surface**: export `FAST_TAC`, `SLOW_TAC`, `BEST_TAC`, `SLOW_BEST_TAC`, `FIRST_BEST_TAC`, `ASTAR_TAC`, `SLOW_ASTAR_TAC`, `DEEPEN_TAC`, plus the step tactics `SAFE_STEP_TAC`, `CLARIFY_STEP_TAC`, `STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC`.  All are thin instantiations of the one engine; all names collision-checked free (2026-07-16, whole-tree grep). |
| D27 | **Failure semantics**: `SAFE_TAC` and `CLARIFY_TAC` fail exactly when they change nothing (`CHANGED_PROP` semantics — what Isabelle users actually experience of the `safe`/`clarify` *methods*, `classical.ML:834,843–844`).  The raw never-fail behavior is reachable as `TRY SAFE_TAC`. |

Overarching (owner clarification): judge every design by resulting tactic
strength, not by resemblance to Isabelle's user syntax.

## 3. Layer architecture

The opt-in layer lives at `src/auto/`, with subdirectories mirroring the
phases:

```
src/auto/
  rules/       -- rule database, attributes, netpairs, seed theories (Phase 0)
  classical/   -- claset step tactics, SAFE/CLARIFY/FAST/BEST/DEEPEN (Phase 1–2)
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

**Status (2026-07-19): delivered (Phase 2).**  The actual modules are
`blastTerm`, `blastRule`, `blastSearch`, `blastReconstruct`, and
`tableauLib`, with selftests and user documentation.  The extra
`blastReconstruct` module, absent from the original sketch, isolates D23's
typed-engine reconstruction and PROOF-FAILED tableau backtracking.  The
public operations are `BLAST_TAC`, `BLAST_DEPTH_TAC`, `depth_limit`, and
`tryIt`.  Regressions cover Pelletier 1–46, 52, and 62, the nine Table-1
published bounds, four set-theory problems, robustness cases, and Halting II
at elevated `HOLSELFTESTLEVEL`.

The public tactics also add two local safe elimination rules and run fixed
preprocessing by nine helper rewrites; matching benchmark shapes can
therefore be discharged before tableau search.  In particular the Table-1
checks for problems 34, 38, 43, 46, and 52 do not measure raw tableau depth.
The exact Halting-II proposition is discharged directly by its proved
helper theorem, not by tableau search.  Thus the corpus records the strength
of the delivered public tactic, while those cases are deliberate deviations
from the unpreprocessed tableau pipeline described below.

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

## 7. Phase 3 — Clasimp layer: AUTO/FORCE/FASTFORCE/CLARSIMP (`src/auto/clasimp/`)

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

## 8. Phase 5 — Generic linear arithmetic and `ARITH_TAC` (`src/auto/linarith/`) (D6)

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
  `src/HOL/Tools/{simpdata,lin_arith,arith_data,groebner,semiring_normalizer}.ML`,
  `src/HOL/Tools/Qelim/cooper.ML`,
  `src/HOL/{HOL,Presburger,Fields,Groups}.thy`, isar-ref (`Generic.thy`).
