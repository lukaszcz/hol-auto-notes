# Phase 4 research: the Aesop algorithm and its HOL4 substrate

Date: 2026-07-28.  Worktree `isabelle-tactics`, HEAD `3bac17ef5`.
Primary source: Limperg & From, *Aesop: White-Box Best-First Proof
Search for Lean*, CPP 2023 (`../papers/limperg-from2023-aesop.txt`,
read in full).  All HOL4 citations verified against this worktree;
`file:line` references resolve here.  Companion reports:
`phase12-classical-search-port.md` (engine design choices E1–E11),
`phase12-hol4-substrate.md`, `isabelle-classical-reasoner.md` §7
(aesop comparison).

## 1. The CPP'23 algorithm, precisely

### 1.1 Search tree (§2.2)

An AND/OR tree of alternating **goal nodes** and **rule-application
("rapp") nodes**.  Children of a goal are rapps (rules applied to it,
implicitly disjoint); children of a rapp are the subgoals it produced
(implicitly conjoined).  Node states: **proved** (goal: some child
rapp proved; rapp: all children proved), **stuck** (goal: all
applicable rules applied and every child rapp stuck; rapp: some child
stuck), **unknown**.  A node is **irrelevant** iff some ancestor-or-self
is proved or stuck; irrelevant nodes are never expanded.

### 1.2 Best-first loop and priorities (§2.3)

Loop: pick the highest-priority unknown goal, expand it along the
highest-priority not-yet-applied rule; exit when the root is proved or
stuck or a configurable limit (e.g. tree depth) is hit.  Each rule
carries a user-assigned **success probability** in (0,100%]; a
six-point scale suffices in practice (last resort 1%, low 25%, medium
50%, high 75%, almost-always 99%).  Goal priority = product of the
success probabilities of the rules on the path from the root (root =
100%).  Safe rules count as 100%, so safe subgoals inherit the parent
priority unchanged.

### 1.3 Safe/unsafe phases (§2.4)

Goal expansion is two-phase: try all **safe** rules first (in
user-assigned integer-priority order, which affects performance but not
provability); if one succeeds the goal is *never re-queued* — safe
rules are applied eagerly, without alternatives.  Only if no safe rule
applies are **unsafe** rules applied, and the goal is re-inserted into
the queue after each unsafe rapp so further unsafe rules can fire
later.  Safety is relative to the whole rule set (documented rule-set
design obligation, not a checked property).

### 1.4 Normalisation (§2.5)

A third phase running *before* safe/unsafe on every new goal: a
fixpoint loop over **normalisation rules** ordered by integer
priority; each iteration retries from the highest-priority rule, so
the order is respected on every intermediate goal.  Norm rules must
prove the goal or return exactly one subgoal.  One built-in norm rule
runs the **simplifier** on the whole goal (target + hypotheses) with
the default global simp set plus an aesop-specific simp set fed by a
`simp` rule builder (§3.2).  Local hypotheses are used by the
simplifier by default (both as rewrites and rewritten-to-truth-values);
per-invocation disable exists because badly oriented local equations
can loop (§3.2, §5.1).

### 1.5 Safe goals — the residue (§2.6)

On failure, Aesop reports the **safe goals**: what would remain after
running normalisation + safe rules only.  Since those are
non-branching, the safe goals are a well-defined single set.  Before
computing them all applicable safe rules must be expanded (the search
may have stopped early on a stuck branch).

### 1.6 Multi-rules (§2.7)

A rule may add several rapps at once (e.g. one per applicable
constructor).  Unsafe multi-rules are a plain generalisation.  Safe and
normalisation multi-rules are **forbidden dynamically**: registration
is allowed, but producing >1 rapp at run time fails the rule (so a
`constructors` rule for an inductive predicate where at most one
constructor ever applies can still be safe).

### 1.7 Rule builders (§3.1)

- **apply** — apply a lemma `∀x̄. P x̄` to a goal `Γ ⊢ P ȳ`; unresolved
  arguments become subgoals or metavariables.
- **constructors** — one multi-rule applying each constructor of an
  inductive type.
- **forward** — from hypotheses matching the rule's *immediate*
  premises, add the conclusion as a new hypothesis (non-immediate
  premises stay as an implication prefix / become subgoals).  Loop
  prevention: before adding hypothesis `h : T`, check whether an
  earlier forward rule *on this branch* already added a hypothesis of
  type `T`; if so, fail.
- **destruct** — forward + delete the matched hypotheses (no loop
  issue).
- **cases** — case analysis on a hypothesis of an inductive type
  (TypeBase analogue); optional **patterns** restrict applicability
  (e.g. `All _ (_ :: _)`) to break the recursive-type loop; multiple
  patterns allowed (disjunctive indexing).
- **tactic** — an arbitrary tactic as a rule; must change the goal or
  fail (no-ops forbidden).
- **simp** (§3.2) — adds a rewrite to the aesop-specific simp set used
  by the built-in normalisation simp call.

### 1.8 Indexing (§3.3)

A rule index maps a goal to a small candidate subset: **by-target**
(pattern unifies with the conclusion; used for apply/constructors),
**by-hypothesis** (pattern unifies with some hypothesis; used for
cases/forward — the pattern is the *last immediate* premise), and
**disjunction** of schemes (constructors: one target scheme per
constructor; cases: one hypothesis scheme per pattern).  Implemented
with discrimination trees; retrieval is unification-mode (both the
stored pattern and the query may contain variables/metavariables).
Matched rules are told their **match locations** (target or specific
hypotheses).  Retrieval is an over-approximation; the rule itself
re-checks on application.  `tactic` rules take a user-specified scheme
or are unindexed.

### 1.9 Default rule corpus (§3.4)

Norm: split conjunctive hypotheses; intro binders (`⊢ ∀x. P` →
params); rewrite/substitute equational hypotheses (with
hypothesis-deletion when one side is a local variable); split iff
goals into two implications, treat iff hypotheses as equalities.  Safe:
∧-intro (low integer priority), ∨-elim, refl-closing of definitionally
true equations, premise-free hypothesis application.  Unsafe:
∨-intros (50%), applying a universally quantified hypothesis (75%),
∃-intro creating a witness metavariable, safe-but-low-prio if/match
case splits.  (HOL4 mapping in §4.9 below.)

### 1.10 Metavariables (§4)

Rules may create and assign metavariables (∃-intro, transitivity).
Goals sharing a metavariable are **m-coupled**; the transitive closure
partitions each rapp's subgoals into **metavariable clusters**, which
become a third node layer between rapps and goals:

- cluster **proved** iff *one* of its goals is proved (a proof of one
  coupled goal must contain proofs of the others, see copying);
- cluster **stuck** iff *all* its goals are stuck;
- rapp proved iff all child clusters proved.

Cached per goal node: the set of metavariables it (transitively)
depends on.  Cached per rapp: metavariables it *created* and
metavariables it *assigned*.

**Copying (§4.3).**  When a rapp `R` applied to goal `G[?x₁…?xₙ]`
assigns some `?xᵢ`: walk from `G` up to the topmost rapp `Rₘ` that
created any assigned `?xᵢ`; every sibling `H` of a goal on that path
that depends on any assigned `?xᵢ` is **copied**: `H[?x̄ ≔ ā]` is added
as an *additional subgoal of `R`*.  Two skips: `H` already a copy of a
path goal; several copies of the same original (copy one).  Only the
goals are copied, not their subtrees (their rules re-apply — the known
inefficiency, §4.7).

**Safe rules that assign metavariables (§4.4)** do not stay safe:
run all safe rules; any whose application assigned a metavariable is
*not* added — its result is stored as a **postponed safe rapp**.  If
some safe rule succeeds without assignments, apply it and drop the
postponed list; otherwise enter the unsafe phase with the postponed
rapps offered as extra unsafe rules at **90%**, replayed from the
stored result rather than re-executed.

**Normalisation rules must not create or assign metavariables
(§4.5)** — there is no way to postpone inside the fixpoint.  (Lean
consequently cannot allow `cases` norm rules; see §4.5 for their
mvar-renaming problem — structurally impossible here, §4.6 below.)

**Dropped metavariables (§4.6).**  If a rapp on `G[?x]` neither
assigns `?x` nor has a subgoal containing `?x`, `?x` is *dropped*.
Lean must then (a) add a synthesis subgoal for `?x`'s type (types may
be uninhabited in DTT — the paper explicitly notes "the situation is
different for logics in which all types are inhabited, such as the
logic of Isabelle/HOL"), determined *after* copying, and (b) treat
dropped metavariables as assigned for the purposes of copying, so
coupled goals still get copied into the proof.

**Completeness (§4.7).**  Conjectured: with a fair strategy the
algorithm is as complete as the rule set allows; the tree only ever
grows (no rule application can disable another).

### 1.11 Evaluation (§5)

63% of 200 mathlib list lemmas outright, 94% given manual induction
(aesop deliberately does no induction); ~2.5× slowdown vs hand-written
proofs.  Failure classes: non-trivial existential witnesses (unification
-only instantiation), missing library lemmas, rule-set misfires.  Most
common local rule: low-priority unsafe `cases` on `List` hypotheses.

## 2. Delivered substrate (verified inventory)

### 2.1 Rule DB (`src/auto/rules/`, Phase 0 + 3)

- `rulespec = {kind : Intro|Elim|Dest, safe : bool, prio : int option}`
  (`clasetRules.sig`); **`prio` is fully plumbed** through the codec
  (`pair3_encode(kind, Bool, option_encode Int)`), deltas
  (`clasetADD1`/`clasetRM1`, `clasetRules.sml:798–838`), store and
  merge, and round-trips (selftest asserts `SOME 75`); **nothing reads
  it** — every current entry path passes `NONE`.  Intent recorded at
  `PLAN_phase_0.md:186`: "aesop success probability in percent; unsafe
  rules only; consumed in Phase 4".
- Schema evolution is by *versioned delta tags*: a `clasetADD2`
  decoder is added alongside v1 (`decode_delta = ThyDataSexp.first
  [...]`); v1 deltas keep decoding (`PLAN_phase_0.md` §10 risk 4).
- Attributes `intro/sintro/elim/selim/dest/sdest` **reject arguments**
  with "priorities arrive in a later phase"
  (`clasetLib.sml:823–843`; selftest locks it).  `ThmAttribute`
  supports `name=arg1 arg2` argument lists already; the blocker is the
  script lexer — `tools/parsing/HolLex:232–234` requires attribute
  *values* to start with a letter.  D12's planned enactment: additive
  HolLex tweak admitting digit-leading values, then `Int.fromString`
  parsing in `register_rule_attribute`.
- `clasetNet` (`clasetNet.sig`) is a **dual-mode first-order
  discrimination net**: `match : term -> 'a net -> 'a list` (rigid
  query) and `unify : {q, qvars : term HOLset.set} -> 'a net -> 'a
  list` (query-side variables) plus `unifyMeasured` (checkpoint
  callback), `vfilter` (deletion), persistent.  This is exactly the
  §1.8 retrieval shape (over-approximating unify-mode lookup keyed on
  stored patterns with `patvars`).
- The claset value `CS {decls, safe_wrappers, unsafe_wrappers, safe0/
  safep/unsafe/dup netpairs}` (`clasetLib.sml:15–27`);
  `PLAN_phase_0.md:319–320` records that "the aesop in-memory index is
  added to this record in Phase 4 — an internal, non-persisted
  change".
- Rule preprocessing available for reuse: canonicalisation
  (outer-∀ strip + premise currying), `MAKE_ELIM_RULE`,
  `CLASSICAL_RULE`, `SWAP_INTRO_RULE`, `DUP_*`; candidate order
  `(weight, recency)`; `rules_of : claset -> (rulespec * (string *
  thm)) list` preserves `prio`, but the netpair lookup entry points
  return `(tag * brl)` and drop it.
- TypeBase: `register_tyinfo_contribution : string *
  (tyinfo -> (rulespec * (string * thm)) list) -> unit` with
  reconciliation + one-shot catch-up (`clasetLib.sml:389–651`);
  currently seeds distinctness (safe elims) and injectivity (via
  `iff_rules`); clasimp adds constructor intros; **nchotomy/cases
  theorems are explicitly reserved for the Phase-4 cases builder**
  (`PLAN_phase_3.md:591`).
- `src/auto/CLAUDE.md:74–76`: wrappers and tactic-valued rules are
  **never persisted**; libraries re-establish them via
  `augment_claset`-style calls.
- Markers: the six rule markers + `Simp`/`Iff`/`Del`, built from
  generic `markerLib` helpers; `process_claset_tags` must keep passing
  unrecognized markers through unchanged (frozen observable
  behaviour).  `classify_simp_args` buckets Simp/Iff/generic-simp
  controls/rest (`clasetLib.sig:102–107`).

### 2.2 Engine (`src/auto/classical/`, Phase 2)

- `clasetMeta.store`: **persistent** typed-metavariable store —
  reserved-name frees (`%%claset_meta%%…`) and vartypes, per-meta
  eigenvariable **allow-sets** checked at bind time + occurs check;
  add-only bindings (never rebound) so `bindings` supports subtree
  diffs; `ground` = tymetas↦`bool` then metas↦`ARB`; `collapse` gives
  kernel substitutions.  Chosen persistent in Phase 2 *specifically*
  "enables sharing with the aesop forest" (design choice E3,
  `phase12-classical-search-port.md`).
- `clasetUnify`: store-threaded FO unification + Miller-pattern layer +
  positional first-order approximation for applied non-pattern metas;
  `mode = Match | Unify` (Match = only the rule's fresh metas
  flexible).
- `clasetGoal.node`: ordered `cgoal list` (each `{params, asl, w}`) +
  store + replay script + size cache + level + per-goal ancestry paths
  + binding marks; `create {goals, store, level}` builds arbitrary
  (e.g. **single-goal**) nodes; `children`/`elim_children` produce
  rule-application children; `render`/`unrender` materialise a goal as
  a HOL4 goal with **metavariables as rigid marked frees** and lift
  tactic results back, rejecting results that touch unknown markers —
  wrappers/tactics **cannot instantiate engine metavariables** (D24).
- `clasetStep`: `step = node * goalpos -> (step_record * node) seq.seq`;
  cascades (safe/clarify/inst/unsafe/dup/depth) are claset-shaped; the
  **per-theorem, wrapper-free** entry `blast_rule_step : claset ->
  {theorem, elim} -> step` exists but uses the blast-exact child
  policy (`ExactBlastPrefixes`).  There is **no** public per-theorem
  step with the standard `children` policy.
- `clasetReplay`: step-record vocabulary (11 kinds incl. `Wrapper` with
  `fixed_action`), script forest, `ground`, `REPLAY_TAC`; rule replay
  is by explicit instantiation from the grounded store (no re-search).
- `clasetSearch`: drivers `DEPTH_FIRST/DEPTH_SOLVE/BEST_FIRST/ASTAR/
  DEEPEN` over `expansion = node -> node seq.seq`; **priorities are
  hardwired** (`BEST_FIRST` uses `clasetGoal.compare` at
  `clasetSearch.sml:395`; `ASTAR` cost `size + 5*level` at
  `clasetSearch.sml:410–411`); D25 pruning lives in `DEPTH_SOLVE`.
  `node_limit` ref (default 100000).
- `searchHeap`: comparator-keyed min-heap with `delete_all_min`.
- `clasetNorm` (added post-review, commit `5a1dee9f9`): **beta/eta
  hygiene only** (`REDEPTH_CONV (BETA_CONV ORELSEC ETA_CONV)` +
  helpers), not a normalisation phase.
- **Freeze** (`PLAN_phase_1_2.md:1206–1212`): store API, step/record
  types "as consumed by … Phase 4 (node/forest shape, priority
  bookkeeping)", replay vocabulary, public tactic signatures frozen;
  additive exports have the D32/D33 precedent.

### 2.3 Clasimp/simp substrate (Phase S + 3)

- Derived-simpset cache: `clasimp_ss()` =
  `srw_ss() |> set_cond_depth 40 |> ++ split_ss |> set_safe_solvers
  [assumption/refl/TRUTH/contradiction]` via
  `BasicProvers.make_simpset_derived_value` (auto-invalidated when
  `srw_ss()` grows) — `clasimpLib.sml:8–27`.
- Modes: `GEN_SIMP_TAC {safe} ss thms`;
  `GEN_GLOBAL_SIMP_TAC {safe} {base, concl_in_fixpoint, imp_rebuild}`
  with clasimp's `asm_full_simp_config = {strip=true, elimvars=false,
  droptrues=true, oldestfirst=true, concl_in_fixpoint=true,
  imp_rebuild=true}` (D17/D31 mut_impc parity).
- Simp wrappers over claset wrapper slots: unsafe
  `"asm_full_simp_tac"` = `NAPPEND (NCHANGED (LIFT (asm_full_simp
  …)), step)`; safe `"safe_asm_full_simp_tac"` = `NORELSE (step,
  NCHANGED (LIFT (safe_asm_full_simp …)))` (`clasimpLib.sml:56–77`).
- `[iff]` is the complete template for a new theorem-fed set:
  `ThmSetData.export_with_ancestry` (auto-registers the attribute),
  value = Symtab of installed names, `apply_to_global` through public
  augmentation APIs only, per-theory batch finaliser, named-fragment
  discipline for `Excl`/`delsimps` interop.
- `splitLib` public surface: `SPLIT_CONV/SPLIT_TAC/SPLIT_ASM_TAC`,
  `type_split_of`, `split_thms()`, etc.

## 3. Component mapping and feasibility

### 3.1 Tree over the shared engine state

The natural realisation (details are Phase-4 plan material):

- tree **goal node** ↦ one `cgoal` + the store snapshot of its parent
  rapp (root: `clasetGoal.from_goal` of the user goal, store
  extracted);
- **rapp** ↦ one engine step applied to a single-goal
  `clasetGoal.create {goals = [g], store, level}` node, recording the
  resulting `step_record` (validation + store-parameterised replay
  action + created metas) and the child `cgoal`s and post-application
  store (persistent stores make per-rapp snapshots free — E3);
- **assigned-metas per rapp** = `clasetMeta.bindings` diff between
  parent and child stores (the same diff `clasetSearch.note_transition`
  computes privately); **created** comes from the `step_record`;
- **goal → mvar dependency set** = `clasetMeta.metas_of` over
  `asl @ [w]` (+ params' types), closed transitively through store
  residues (reimplementable from public `bindings`/`metas_of`;
  `clasetSearch.dependency_closure` is private);
- **copying** = instantiate the sibling `cgoal` under the assigning
  rapp's store (`clasetMeta.instantiate`/`norm` per term) — a pure
  term operation; add as extra subgoal of the rapp with a copy-of link;
- **clusters** = union-find over sibling goals' dependency sets;
- **normalisation/tactic/simp rules** = `render`/`unrender` on the
  single-goal node: rigid-mvar rendering *structurally enforces* the
  §4.5 no-assignment restriction, and `unrender` records a `Wrapper`
  step whose `fixed_action` replays the tactic's validation;
- **proof extraction** = when the root is proved, walk the winning
  subtree (per cluster: the one proved goal), ground the final store
  once, and replay the recorded actions bottom-up (each rapp's action
  targets position 1 of its single-goal node), composing validations;
  per E6, with fully recorded instantiations a replay failure is an
  engine bug — hard error, no silent fallback.

### 3.2 HOL4-specific simplifications (all justified by the paper)

- **Dropped metavariables need no synthesis subgoals**: every HOL type
  is inhabited and the final grounding maps unbound metas to `ARB`
  (deterministic; E5).  The *copying* half of §4.6 (treat dropped as
  assigned) still applies unchanged.  The paper itself flags the
  inhabited-logic case as different.
- **The §4.5 Lean `cases`-renames-mvars problem cannot arise**: HOL4
  case splits run through TypeBase theorems applied engine-side, or
  through rendered goals where metas are rigid frees no tactic can
  rename.
- **Hypotheses are not telescopes**: no hypothesis dependencies; a
  goal's mvar set is just the metas of its terms (plus types).

### 3.3 Genuine gaps (new machinery Phase 4 must build)

1. The AND/OR tree itself (nodes, states, irrelevance, queue keyed by
   priority products, limits) — nothing in `clasetSearch` is reusable
   for per-goal expansion (its drivers expand whole proof states and
   hardwire priorities).
2. A standard-policy **per-theorem rule step** (the `blast_rule_step`
   analogue without `ExactBlastPrefixes`) — currently private inside
   `clasetStep`'s cascades; needs an additive export (freeze
   amendment) or duplication.
3. **Forward/destruct application**: no existing step adds a derived
   hypothesis from matched premises (the cascades' MP rung is
   assumption-vs-assumption only); needs a new step built on
   `clasetUnify` + `cons_assumption`, with the branch-local
   added-hypothesis-type memory for loop prevention.
4. **Norm-phase fixpoint** and the builders/attribute/persistence
   layer for the new rule categories.
5. **Index**: by-target/by-hypothesis `clasetNet` pair for aesop
   candidate retrieval carrying `prio`+builder metadata (the classical
   netpairs drop `prio` and are keyed for the claset cascade shapes).

## 4. Constraints binding Phase 4

1. Phase-2 freeze: store API, step/record types, replay vocabulary,
   public tactic signatures — additive changes only, owner-approved
   (D32/D33 precedent).
2. Phase-0 freeze: `rulespec`/`cdelta` v1, attribute names, marker
   pass-through, lookup ordering contract; v2 codecs are the sanctioned
   evolution path; the aesop index on `CS` is pre-authorised as an
   internal non-persisted change.
3. `src/auto/CLAUDE.md`: tactic-valued rules and wrappers never
   persisted; dependency stratification (`rules/` must not depend on
   `src/simp` — so anything simp-flavoured lives in `aesop/` or
   `clasimp/`, not `rules/`); Moscow-ML-compatible SML; no
   benchmark-recognition shortcuts.
4. D9/D36 naming: uppercase drivers, `CS_` prefix for context-explicit
   forms; `AESOP_TAC` already reserved and collision-checked.
5. D30 insertion semantics: unmarked theorem arguments are inserted as
   assumptions; explicit roles via markers only.
6. Numeric defaults are tuning matters (parent plan §11), but new
   *surfaces* (attributes, tactics, schema) are owner decisions.

## 5. Open decisions identified (for the owner round)

1. Tree architecture: faithful CPP'23 AND/OR tree in `src/auto/aesop/`
   vs best-first over whole proof states vs refactoring Phase 2 onto an
   explicit shared forest.
2. Rapp execution: additive `clasetStep` per-theorem standard-policy
   step export vs reimplementation in `aesop/`.
3. Where aesop-only rule categories live: claset schema v2
   (`clasetADD2`) vs a separate aesop ancestry instance vs
   session-only; simp-builder as a ThmSetData settype; tactic rules
   session-only (mandated).
4. Attribute surface for the new categories + enactment of
   `[intro=NN]` (D12).
5. Default success probabilities for claset-derived unsafe rules
   consumed by aesop.
6. `AESOP_TAC` failure/residue semantics and the safe-goals companion.
7. Normalisation-phase composition (which simpset, simp mode, split
   participation, hypothesis usage).
