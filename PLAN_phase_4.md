# Phase 4 implementation plan — aesop engine (`src/auto/aesop/`)

Date: 2026-07-28.  Basis: parent plan `PLAN.md` §6.4 (D2: full
aesop-style best-first engine over the shared rule DB), Limperg & From,
*Aesop: White-Box Best-First Proof Search for Lean*, CPP 2023
(`papers/limperg-from2023-aesop.txt`, read in full; cited as "§n"
below), and the verified substrate inventory in
`research/phase4-aesop-engine.md` (2026-07-28, HEAD `3bac17ef5`).
Companion reports: `research/phase12-classical-search-port.md`
(E3/E5/E6), `research/phase12-hol4-substrate.md`,
`research/isabelle-classical-reasoner.md` §7.

All eight decisions below were taken by the owner on 2026-07-28,
one-by-one, with alternatives presented; they continue the parent
register as D44–D51.

## 0. Owner decisions

- **D44 — Architecture: faithful AND/OR tree.**  New modules in
  `src/auto/aesop/` implement the CPP'23 tree exactly: goal nodes (one
  `cgoal` + the parent rapp's persistent store snapshot), rapp nodes
  (step record(s) + child cgoals + post-application store),
  metavariable-cluster nodes, proved/stuck/unknown states, and a
  priority queue over goals.  Reuses `clasetMeta`, `clasetUnify`,
  `clasetNet`, `clasetGoal` single-goal nodes (incl. D24
  `render`/`unrender`), the `clasetReplay` vocabulary, and
  `searchHeap`.  Rejected: best-first over whole proof states (not the
  paper's algorithm; cross-goal alternative multiplication); refactoring
  Phase 2 onto an exported forest (freeze-breaking churn, no strength
  gain).
- **D45 — Rapp substrate: additive `clasetStep` export** (Phase-2
  freeze amendment, D32/D33 precedent): a per-theorem, wrapper-free
  step with the *standard* child policy and explicit unification mode —
  the `blast_rule_step` analogue minus `ExactBlastPrefixes` — consumed
  by aesop on single-goal nodes.  The amendment umbrella included, if
  implementation required it, an additive *non-consuming* elim replay
  action in `clasetReplay` for forward rules (§5.3).  **Closed unused by
  D52 (2026-07-30, `PLAN_phase_4_simplify.md`)**: the forward path ships
  through `FORWARD_RULE_TAC`, so `NONCONSUMING_ELIM_RULE_TAC`,
  `nonconsuming_elim_rule_action` and the `retain_major` parameter are
  removed.  Rejected:
  reimplementation in `aesop/` (duplicates the centralized
  canonicalisation/meta-creation/replay logic); using
  `blast_rule_step` as-is (blast-exact prefix policy is a semantic
  misfit).
- **D46 — Rule DB: claset schema v2 + aesop-simp settype.**  One DB
  (D2): `rulespec` v2 extends `kind` with `Forward` and `Norm`,
  persisted via a new `clasetADD2` delta alongside v1 (the
  pre-authorized versioned-codec path); the aesop in-memory index (a
  by-target/by-hypothesis `clasetNet` pair carrying `rulespec`) becomes
  a non-persisted `CS` field built incrementally, exactly as
  `PLAN_phase_0.md` §6.1 pre-authorized.  Simp-builder rewrites get
  their own `ThmSetData` settype (`[iff]` template) feeding an
  aesop-derived simpset; tactic rules are session-only via an
  `augment_claset`-style API (`src/auto/CLAUDE.md` mandate).
  Pattern-carrying user `cases` declarations may join the codec in a
  later phase.  Rejected: a separate aesop ancestry instance (two rule
  stores, against D2); session-only new categories (seed corpus
  impossible).
- **D47 — Attributes.**  Enact D12: `[intro=NN]`, `[elim=NN]`,
  `[dest=NN]` percent arguments on the three unsafe attributes
  (additive HolLex tweak for digit-leading attribute values).  New:
  `[norm]` / `[norm=k]` (normalisation rule, integer penalty; built-in
  simp at penalty 0, negative penalties run before it); `[forward]` /
  `[forward=NN]` (unsafe forward, percent) and `[sforward]` (safe
  forward); settype+attribute `aesop_simp`.  Safe intro/elim/dest
  ordering stays the claset candidate order — no safe integer-priority
  surface in Phase 4 (`[sintro=k]` remains an additive option later);
  the three safe attributes keep rejecting arguments.  User
  cases-with-pattern declarations are programmatic in Phase 4.
  Rejected: an umbrella `[aesop=...]` attribute (sub-language in
  attribute args, non-HOL4-native); priorities-only minimalism
  (breaks the attribute-driven promotion story).
- **D48 — Default probability.**  Unsafe rules with `prio = NONE` get
  a single documented default of **50%** (medium on the paper's
  six-point scale).  Seed declarations add explicit percentages where
  the paper's default corpus does.  Rejected: invented kind-based
  defaults; excluding undeclared rules (guts the shared DB).
- **D49 — Surface: close-or-fail + safe companion.**
  `AESOP_TAC : thm list -> tactic` must close the goal; on failure it
  fails, reporting the safe goals through the trace machinery (§2.6).
  `AESOP_SAFE_TAC : thm list -> tactic` runs normalisation + safe
  rules only and leaves the safe frontier as subgoals with D27
  change-or-fail semantics.  Context-explicit `CS_AESOP_TAC` /
  `CS_AESOP_SAFE_TAC : aesop_config -> claset -> simpset -> tactic`
  per D36, with the limits record on the `CS_` forms.  Rejected: a
  residue-leaving `AESOP_TAC` (silently degrades an expensive failed
  search into a clarify-strength step); close-or-fail without the
  companion (breaks the §2.6 workflow).
- **D50 — Normalisation composition.**  Built-in norm rule =
  `GEN_GLOBAL_SIMP_TAC {safe = true}` with clasimp's
  mut_impc-parity `asm_full_simp_config`, over an aesop-derived
  simpset cache (from `srw_ss()`: `cond_depth` 40, clasimp's
  safe-solver stack, plus the `aesop_simp` set and per-invocation
  `Simp` args/controls) — **without** `split_ss`: norm rules must
  produce at most one subgoal (§2.5), and the paper maps if/case
  splitting to **low-priority safe rules** (§3.4), which is where the
  `[split]` corpus enters (conclusion splits low, hypothesis splits
  lower).  Assumptions are used by the simp call by default; disable
  via the existing generic controls.  Safe mode is deliberate:
  normalisation must stay provability-preserving and
  metavariable-clean (§4.5) even if the recorded solver-level
  instantiation option (Phase-3 note, `clasetGoal.sig:88–92`) is ever
  taken up for unsafe solvers.  Rejected: `clasimp_ss` verbatim with a
  dynamic branching-promotion special case; unsafe-mode norm simp.
- **D51 — Store merge: additive `clasetMeta` export** (second Phase-2
  freeze amendment): a domain-disjoint extension merge, e.g.
  `absorb : {base : store, extensions : store list} -> store`,
  implemented inside `clasetMeta` as a keyed-map union that **errors
  on any conflicting key** (an aesop engine bug, never silently
  resolved).  Needed at proof extraction: sibling subtrees under one
  rapp evolve incomparable store extensions with provably disjoint
  new-binding domains (shared metavariables force goals into one
  cluster, proved by a single subtree), but replay needs one covering
  store (the dropped-then-copied case makes independent per-subtree
  grounding inconsistent).  Rejected: aesop-local parallel store
  bookkeeping (drift risk the freeze exists to prevent); linear
  re-replay extraction (a second execution engine for a 30-line
  union).

Numeric values introduced in this plan (rapp/depth limits, the 90%
postponement percentage, fixed builtin orderings) follow the parent
plan §11 rule: configurable, benchmark-tunable, not design questions.

## 1. Scope

In scope: the AND/OR search tree with the full §4 metavariable
algorithm; the seven rule builders (§3.1: apply, constructors,
forward, destruct, cases, simp, tactic); the aesop index; schema v2 +
attributes + `aesop_simp` settype; the normalisation phase with the
built-in simp rule; `AESOP_TAC` / `AESOP_SAFE_TAC` (+ `CS_` forms);
selftests, Docfiles, build integration.

Out of scope (recorded non-goals):

- **Named rule sets** (Lean's activatable rule-set collections): the
  single global claset + per-invocation markers is the D2/D4 design.
- **Declarative pattern-`cases` attributes** (patterns don't fit
  attribute values); programmatic registration only.
- **Safe integer-priority surface** (`[sintro=k]`): claset candidate
  order suffices; additive later.
- **Induction**: aesop by design performs none (§5.1).
- Changes to `AUTO_TAC`/classical/blast behaviour; promotion items.

## 2. Grounding: what exists and is used as-is

Verified in `research/phase4-aesop-engine.md` §2:

- `clasetMeta.store` (persistent, allow-sets, add-only bindings,
  deterministic `ground`: tymetas→`bool`, metas→`ARB`), `bindings`,
  `instantiate`/`norm`, `collapse`, `metas_of`.
- `clasetUnify` (`Match`/`Unify`, Miller patterns, FO approximation).
- `clasetGoal`: `create {goals, store, level}` (single-goal nodes),
  `children`/`elim_children` (with `consumed : int option`),
  `record_step`, `render`/`unrender` (rigid metavariable rendering —
  wrappers/tactics cannot instantiate engine metas), `from_goal`.
- `clasetStep` public built-ins: `blast_disch_step`, `blast_gen_step`,
  `blast_hyp_subst_step` (wrapper-free; reused for built-in norm
  rules), `step_record` accessors.
- `clasetReplay`: step records with store-parameterised `action`s,
  `ground`, `REPLAY_TAC`-style replay; `Wrapper`/`fixed_action` for
  rendered-goal tactic results.
- `searchHeap` (comparator min-heap, `delete_all_min`).
- `clasetNet` dual-mode net (`match`, `unify {q, qvars}`,
  `unifyMeasured`, `vfilter`).
- `clasetRules`: canonical forms, `MAKE_ELIM_RULE`, `CLASSICAL_RULE`,
  swapped/dup variants, `rules_of` (carries `rulespec`), decls
  container, versioned delta codec.
- `clasetLib`: claset value/state, attributes, markers,
  `classify_simp_args`, `invocation_claset`, `INSERT_FACTS_TAC` (D30),
  `register_tyinfo_contribution`, wrapper lists.
- clasimp: `make_simpset_derived_value` cache pattern, safe-solver
  stack, `GEN_GLOBAL_SIMP_TAC` modes/configs, the `[iff]` settype
  recipe, `add_simp_wrapper`/`add_safe_simp_wrapper`.
- `splitLib`: `type_split_rules`, `split_thms`, `mk_asm_split`.

## 3. Cross-module amendments (land first, each with its own gate)

Ordered so every step keeps `bin/build -t --seq=tools/sequences/
upto-auto` green.

### 3.1 Attribute arguments (D47; enacts D12)

1. `tools/parsing/HolLex`: extend `attributeValue` to admit
   digit-leading tokens (additive; regenerate the lexer; existing
   scripts unaffected).
2. `clasetLib.register_rule_attribute`: for `intro`/`elim`/`dest`,
   parse `args` as one optional integer in `[1,100]`
   (`Int.fromString`; anything else is a clean error naming the
   attribute); build `{kind, safe = false, prio = SOME n}`.
   `sintro`/`selim`/`sdest` keep rejecting arguments, message updated
   to say safe-rule priorities are not supported (drop the "later
   phase" wording).
3. `temp_add_rule`/`export_rule` paths already accept full
   `rulespec`s; no change.
4. Selftests: replace the args-rejection lock for unsafe attributes
   with round-trip tests (`Theorem foo[intro=75]` ⇒ delta carries
   `SOME 75`); keep the rejection lock for the safe three.

### 3.2 `clasetStep.rule_step` (D45)

Additive export, wrapper-free, standard child policy:

```sml
val rule_step :
  {theorem : thm, elim : bool, mode : clasetUnify.mode} -> step
```

Internals: the existing cascade rule-application path (canonical form,
fresh metas for rule variables, conclusion/major-premise unification
per `mode`, `clasetGoal.children`/`elim_children`, per-alternative
`step_record` with instantiated-replay `action`) — re-exported, not
re-implemented.  Each alternative in the returned seq is one candidate
rapp.  (The companion non-consuming `clasetReplay` action that the D45
umbrella held open for the forward builder was not required and is
closed by D52.)  Differential tests against
`blast_rule_step` on intro/elim examples where the policies agree.

### 3.3 `clasetRules` schema v2 (D46, D47)

1. `datatype rulekind = Intro | Elim | Dest | Forward | Norm`.
   `prio` semantics by kind (documented in the sig): unsafe
   Intro/Elim/Dest/Forward — success percent in `[1,100]`; Norm —
   integer penalty (any int; simp sits at 0); safe rules — reserved,
   ignored in Phase 4.
2. Codec: `clasetADD2`/`clasetRM1` — v2 encoder used **only** when the
   delta needs it (kind ∈ {Forward, Norm}); Intro/Elim/Dest deltas
   keep emitting v1, so theories not using the new kinds stay loadable
   by older code.  `decode_delta = ThyDataSexp.first [v1-add, v2-add,
   rm]`.
3. Routing: Forward/Norm rules never enter the four classical
   netpairs (`safe_class_of` extended; the classical cascades are
   untouched and observable claset behaviour for existing kinds is
   preserved — locked by existing selftests).  They live in `decls`
   and the aesop index only.
4. `ext_info` for the new kinds: Forward stores the `MAKE_ELIM_RULE`
   form (safe and unsafe; no swapped/dup variants); Norm stores the
   canonical rule unchanged.
5. `dest_decls`/`rules_of` ordering: existing kind groups unchanged;
   Forward and Norm appended as new groups (order within groups by
   the existing tag order).

### 3.4 Aesop index in `CS` (D46)

Non-persisted field on the claset record (pre-authorized):

```sml
type aesop_index =
  {target : aentry clasetNet.net,   (* keyed by conclusion *)
   hyp    : aentry clasetNet.net}   (* keyed by major premise /
                                       last immediate premise *)
```

where `aentry` carries `{name, spec : rulespec, tag, thm}`.  Intro
rules (safe+unsafe) index by conclusion; Elim/Dest/Forward by major
premise.  **Amended by D52–D54 (2026-07-30, `PLAN_phase_4_simplify.md`):
Norm rules are not indexed at all.**  The normalisation phase takes the
whole Norm list rather than retrieving by goal shape, so the claset
precomputes it as `norm_decls` and exposes `clasetLib.norm_rules_of :
claset -> (rulespec * (string * thm)) list`, held in `rules_of` order.
`aesop_target_candidates` therefore comprises Intro rules only.  Built
incrementally in `add_decl`, rebuilt by `vfilter` on removal, merged
by replaying `decl_merge_order` (same discipline as the netpairs).
New lookup entry points (additive, `rulespec`-carrying):

```sml
val aesop_target_candidates :
  claset -> {q : term, qvars : term HOLset.set} ->
  (rulespec * (string * thm)) list
val aesop_hyp_candidates : (* same type *)
```

unify-mode (`clasetNet.unify`), candidate order = `(prio-derived
rank, weight, recency)` for unsafe, claset candidate order for safe;
safe precedes unsafe (the Norm class is gone per D54).
Match locations (§3.3 of the paper) are recovered by the caller: the
hyp-side query is per assumption, so the assumption index is known.

### 3.5 `clasetMeta.absorb` (D51)

```sml
val absorb : {base : store, extensions : store list} -> store
```

Union of the six keyed maps; any key present twice with unequal
values raises a diagnostic `HOL_ERR` (engine-bug invariant check).
Selftest: golden merges incl. allow-set and eigen tables; conflict
detection.

### 3.6 Markers (freeze-list amendment, additive)

`clasetMarkerScript.sml` + `clasetLib`: constructors `Norm : thm ->
thm`, `Forward : thm -> thm`, `SForward : thm -> thm` (grep 2026-07-28:
no collisions in `src/**.sig`; `AESOP` names likewise free).
`process_claset_tags`'s pass-through contract for unrecognized markers
is preserved; the new markers are consumed only by aesop's argument
pipeline (§7).  Percent/penalty arguments do not ride markers;
per-invocation priorities use the programmatic `CS_` path.

### 3.7 Build integration

`src/auto/aesop` added to `tools/sequences/upto-auto` (after
`clasimp`) and to `SRCRELNAMES` in
`src/parallel_builds/core/Holmakefile`; `theory_tests` subdirectory
listed with `!` like the rules/clasimp ones if needed.

## 4. The engine (`src/auto/aesop/`)

Modules: `aesopData` (settype + derived simpset), `aesopRule`,
`aesopTree`, `aesopNorm`, `aesopSearch`, `aesopLib`.  All
Moscow-ML-compatible SML; `Feedback` trace `"aesop"` (levels: 1
outcome/safe-goals, 2 expansions/copying, 3 full nodes).

### 4.1 `aesopData`: the `aesop_simp` settype and derived simpset

`[iff]`-template registration (`ThmSetData.export_with_ancestry`,
settype `"aesop_simp"`; collision-checked free) whose value is the
rewrite list; `apply_to_global` marks the derived cache stale.
Derived cache (per D50):

```sml
val aesop_ss : unit -> simpLib.simpset
(* srw_ss() |> set_cond_depth 40
            |> set_safe_solvers [clasimp safe stack]
            |> ++ (rewrites (aesop_simp set))   — NO split_ss *)
```

via `BasicProvers.make_simpset_derived_value`, additionally
invalidated by `aesop_simp` deltas.

### 4.2 `aesopRule`: the rule model

```sml
datatype rphase = RNorm of int          (* penalty *)
                | RSafe                 (* claset order *)
                | RUnsafe of int        (* percent, 1..100 *)
datatype rapply =
    EngineStep of clasetStep.step       (* per-alternative rapps *)
  | RenderedTactic of NTactical.ntactic (* via render/unrender *)
  | MultiStep of clasetStep.step list   (* constructors multi-rule *)
type rule = {name : string, phase : rphase, apply : rapply,
             once : bool (* forward-style hyp-dedup check *) }
```

Rule sources, assembled per invocation from the invocation claset:

1. Claset Intro/Elim/Dest: safe → `RSafe` in claset candidate order;
   unsafe → `RUnsafe (prio | 50)` (D48); application =
   `clasetStep.rule_step` with `mode` per §4.4 below.  Swapped/dup
   variants are **not** used by aesop (γ-duplication is the classical
   engine's device; aesop re-derives applicability through copies and
   new goals).
2. Forward decls: §5.3.
3. Norm decls: §6.
4. Split corpus: for each `[split]` theorem, a low-order safe rule
   (conclusion split; assumption split lower still) built on
   `splitLib` conversions applied as `RenderedTactic` (D50).
5. Built-ins: assumption/contradiction closers (safe, first),
   `blast_disch_step`/`blast_gen_step` and hyp-subst as norm built-ins
   (§6), the built-in simp norm rule.
6. Session tactic rules (`aesopLib.augment_aesop`-registered) and
   per-invocation rules from markers.
7. Postponed safe rapps re-offered at `RUnsafe 90` (§4.5).

Fixed safe order in Phase 4 (safe integer priorities deferred):
closers, safe0 claset rules, safe forward, safep claset rules,
conclusion splits, assumption splits.

### 4.3 `aesopTree`: nodes, states, copying

One search-state record threaded functionally (id-keyed
`Redblackmap`s + counters; no global refs):

```sml
type gid = int  type rid = int  type cid = int
goal:  {id, cgoal, store, level, prio : real (* sum of ln(p) *),
        deps : meta set * tymeta set (* transitive, cached *),
        copy_of : gid option, parent : rid option, cluster : cid,
        norm : norm_state, safe_done : bool,
        unsafe_cursor : rule queue, postponed : rapp_data list,
        state : Unknown | Proved | Stuck}
rapp:  {id, parent : gid, rule : string, prob, records :
        step_record list (* norm-chain-free; one per installed step *),
        store, created, assigned, clusters : cid list, state}
cluster: {id, parent : rid, goals : gid list, state}
```

- **Priorities**: `prio` = Σ ln(percent/100) along the path (root 0.0;
  `RSafe` adds 0).  Queue = `searchHeap` keyed by
  (higher `prio` first, then insertion counter FIFO) — deterministic
  and fair among equals.
- **States** (§2.2/§4.2): goal proved iff some child rapp proved; rapp
  proved iff all child *clusters* proved; cluster proved iff *some*
  member goal proved.  Goal stuck iff normalised, safe phase done,
  unsafe candidates exhausted, and all child rapps stuck; rapp stuck
  iff some cluster stuck; cluster stuck iff all members stuck.
  Irrelevance = any ancestor-or-self proved or stuck; checked lazily
  on queue pop.
- **Metavariable bookkeeping**: `deps` from `clasetMeta.metas_of`
  over `asl @ [w]` and param types, closed transitively through
  `bindings` residues; per-rapp `created` from the `step_record`,
  `assigned` = `bindings`-diff parent→child store.
- **Clusters**: partition of a rapp's child goals (incl. copies) by
  transitive overlap of `deps` (union-find at rapp installation).
- **Copying (§4.3/§4.6)**: on installing a rapp `R` under `G` with
  `assigned ≠ ∅` *or* dropped metas (created-by-ancestors metas in
  `G.deps` that appear in no child's `deps` and are unassigned —
  treated as assigned for copying): walk parents from `G` to the
  topmost rapp creating any such meta; every sibling goal of a
  path goal whose `deps` meets the assigned/dropped set is copied —
  `cgoal` instantiated under `R.store`
  (`clasetMeta.instantiate` + `norm`), added as an extra child goal
  of `R` with `copy_of` set.  Skips: siblings that are copies of path
  goals; duplicate copies of one original.  Subtrees are not copied
  (§4.3; rules re-apply).  **No synthesis subgoals for dropped
  metas**: every HOL type is inhabited and grounding is deterministic
  (`ARB`), per the paper's own inhabited-logic remark (§4.6) and E5.

### 4.4 `aesopSearch`: the loop and phases

Loop (§2.3): pop the best unknown, still-relevant goal; ensure
normalised (§6, on first expansion); then:

- **Safe phase** (§2.4/§4.4): try safe rules in the fixed order.  On
  a goal whose `deps` is empty, rules run in `Match` mode; first
  successful alternative is committed (classical `SAFE_TAC`
  discipline), the rapp installed, the goal never re-queued.  On a
  goal with metavariables, safe rules run in `Unify` mode: a result
  whose `assigned` is empty installs as safe; a result that assigned
  metas is **postponed** (stored, not installed).  If no safe rule
  installs, the postponed list is carried into the unsafe phase as
  extra `RUnsafe 90` pseudo-rules whose application just installs the
  stored result (§4.4); if some safe rule installs, postponed results
  are dropped.
- **Unsafe phase**: apply the single best remaining unsafe candidate
  (rule percent order, then claset order); **all** unification
  alternatives of that rule become sibling rapps (the multi-rule
  generalisation, §2.7); re-queue the goal if candidates remain.
- **Multi-rule prohibition** (§2.7): a `MultiStep`/multi-alternative
  application in the safe phase or a branching result in the norm
  phase fails that rule *dynamically* (rule treated as inapplicable),
  so effectively-deterministic constructors rules may still be safe.
- **Limits**: `{max_rapps : int, max_depth : int}` in `aesop_config`,
  defaults 200 and 30 (tunable numerics per parent §11); hitting a
  limit stops expansion of the offending branch (depth) or the search
  (rapps), leading to failure with the safe-goals report.
- **Termination**: root proved → extraction; root stuck or limits →
  failure path: complete all applicable safe expansions on the
  relevant frontier, then compute and report the **safe goals**
  (§2.6) at trace level 1.

### 4.5 Proof extraction and replay

On root proved: select the winning forest (per cluster, its proved
goal; per goal, its proved rapp).  Compute the covering store =
`clasetMeta.absorb` of the root store with all winning-branch final
stores (domain-disjointness argued at D51; conflicts are hard
errors), then `clasetMeta.ground` once.  Replay bottom-up: each
goal's norm-chain records, then its rapp's record `action grounded`,
children composed positionally (each action targets position 1 of its
single-goal node); `RenderedTactic`/wrapper records replay their
recorded `fixed_action`.  Per E6(a): with fully recorded
instantiations a replay failure is an engine bug — hard diagnostic
error, no backtrack-into-search (unlike blast, whose search is
untyped).  The final result is a standard `(goal list, validation)`
with the empty goal list, delivered through `Tactical.VALID`.

## 5. Rule builders (§3.1 mapping)

### 5.1 apply

`[intro]`/`[intro=NN]` claset rules; engine application =
`rule_step {theorem, elim = false, mode}`.  Unification-only witness
finding, exactly the paper's caveat set (HO limitations as per D21's
unifier: FO + patterns + approximation).

### 5.2 constructors

A `MultiStep` bundling `rule_step` intro applications of a list of
theorems — for inductive relations, the `X_rules` conjuncts
(programmatic registration; seeding common relations is Phase-8
corpus work).  Datatype "constructors" in Lean's sense (goal *is* the
inductive type) has no HOL4 analogue (goals are props) — documented
divergence.  Unsafe by default; safe registration allowed, guarded by
the dynamic §2.7 check.

### 5.3 forward / destruct

Declared `[forward]`/`[forward=NN]`/`[sforward]` (kind `Forward`,
`safe` flag) or per-invocation via `Forward`/`SForward` markers.
Operationally: apply `MAKE_ELIM_RULE thm` via `rule_step` with
`elim = true` against a matching assumption, **without consuming
it** (`children` with `consumed = NONE`; replay is `FORWARD_RULE_TAC`,
so the D45 non-consuming replay action was never needed — D52).
Phase-4 default =
all-immediate: after the major premise matches, every remaining
premise subgoal must close immediately by assumption
(match/unify per goal mode); the conclusion lands as the new head
assumption of the single surviving child.  Programmatic registration
accepts `{immediate : int}` to leave a premise suffix as an
implication in the added hypothesis (documented, additive).
**destruct** = the existing claset Dest kind (consuming) — no new
machinery; aesop simply applies Dest rules with consumption.
**Loop prevention** (§3.1): before installing, walk the branch's
forward-added hypothesis list (tracked per goal node, inherited by
children and copies) and fail if an `aconv`-equal hypothesis (under
`instantiate` of the current store) was already added by a forward
rule on this branch.

### 5.4 cases

Case analysis via elim application of a cases/nchotomy-shaped theorem
(`rule_step` with `elim = true`, consuming for
inductive-relation cases; nchotomy-based datatype splits via the
split-rule route of D50 when they concern `if`/`case` *subterms*).
TypeBase supplies the theorems (`nchotomy_of`/`case_def`-derived —
the material reserved for Phase 4 by `PLAN_phase_3.md` §9);
registration is per-invocation or programmatic, **not** a global
default (the paper's own guidance: global recursive-type cases rules
loop; its List case split is a local rule, §5.1).  Optional
**patterns** (§3.1.4): programmatic registration takes a pattern term
list; applicability requires some assumption to match a pattern
(checked by `match_term` after index retrieval).

### 5.5 simp

`[aesop_simp]` settype → `aesop_ss()` (§4.1); per-invocation `Simp th`
args join the invocation simpset (existing `classify_simp_args`
machinery).

### 5.6 tactic

`aesopLib.augment_aesop {name, phase, tactic : NTactical.ntactic}`
(session-only, never persisted).  Applied through
`render`/`unrender` on the goal's single-goal engine node: rigid
rendering means tactic rules **cannot create or assign engine
metavariables** (documented divergence from Lean, structurally
enforced; the D24 wrapper guarantee).  No-op results are rejected
(§3.1.5): `unrender` result must differ from the input goal.
Indexing: optional user-supplied target/hyp pattern; unindexed
otherwise.

## 6. Normalisation phase (§2.5, D50)

Per goal, on first expansion: fixpoint over norm rules ordered by
penalty, restarting from the lowest penalty after every success;
each rule must prove the goal or yield exactly one subgoal; results
accumulate as the goal's `norm_state` chain (records + final cgoal +
store — no rapp/alternative structure).

Fixed built-in chain at penalty 0 (relative order within 0 fixed and
documented): `blast_disch_step`-style assumption introduction,
`blast_gen_step` ∀-introduction, hyp-subst
(`blast_hyp_subst_step`; the paper's equational-hypothesis
substitution incl. variable elimination), then the built-in simp rule
(safe-mode `GEN_GLOBAL_SIMP_TAC` over `aesop_ss()` + invocation
additions, run through `render`/`unrender`).  User `[norm]` rules
(engine `Match`-mode apply-style application, ≤1 subgoal enforced
dynamically) run before (negative penalty) or after (positive) the
built-ins.  Rigid rendering + `Match` mode structurally enforce the
§4.5 no-metavariable rule for the whole phase.  A norm application
that branches or that binds a metavariable fails that rule
dynamically.

The user `[norm]` rule list is fetched **once** per goal expansion
(from `clasetLib.norm_rules_of`, D54) and reused across the whole
fixpoint while the goal is rewritten — it is deliberately *not*
retrieved from the aesop index by goal shape, since a rule indexed
against the initial conclusion is not the set applicable at iteration
*k*.  Moving retrieval inside the fixpoint (one query per iteration)
is sound and possibly stronger, but needs its own benchmark evidence;
it is a Phase-5 item, not part of D54.

## 7. Surface (`aesopLib`, D49)

```sml
type aesop_config = {max_rapps : int, max_depth : int}
val default_config : aesop_config
val AESOP_TAC       : thm list -> tactic
val AESOP_SAFE_TAC  : thm list -> tactic
val CS_AESOP_TAC      : aesop_config -> clasetLib.claset ->
                        simpLib.simpset -> tactic
val CS_AESOP_SAFE_TAC : aesop_config -> clasetLib.claset ->
                        simpLib.simpset -> tactic
val augment_aesop : {name : string, phase : ..., tactic : ...} -> unit
```

- Argument processing mirrors clasimp (`process_clasimp_args`
  pattern): `markerLib.ABBRS_THEN`; `classify_simp_args`; `Simp` args
  → invocation simpset; `Iff` args → `iff_declaration` (claset rules +
  rewrite); claset markers via `process_claset_tags`; new
  `Norm`/`Forward`/`SForward` markers consumed into invocation rules
  (default penalties/percentages); plain theorems **inserted** (D30,
  `INSERT_FACTS_TAC`); generic simp controls forwarded to the simp
  calls.
- `AESOP_TAC` = `Tactical.VALID`-wrapped close-or-fail; safe goals
  reported at trace ≥ 1 on failure (computed per §4.4).
- `AESOP_SAFE_TAC` = normalisation + safe rules only, run to
  saturation (deterministic; on the metavariable-free entry goal the
  whole safe fragment stays metavariable-free, since `Match`-mode
  applications ground stray rule metas — so the frontier is a genuine
  goal list); leaves the frontier as subgoals; fails iff it changes
  nothing (D27 semantics via `NCHANGED` around insertion + engine, as
  in `classicalLib`).
- Public entries use `the_claset()` + `aesop_ss()` +
  `default_config`; `CS_` forms are the explicit-context spine (D36).

## 8. Seeds and TypeBase

- No new seed theory is required for engine correctness (built-ins +
  existing claset seeds suffice).  Percent annotations mirroring the
  paper's default corpus (§3.4: ∨-intros 50, universal-hypothesis
  application 75) are applied where the existing seed rules diverge
  from the D48 default — i.e. only rules whose intended percent is
  not 50 get explicit `prio` in `clasetSeedScript.sml` (re-recorded
  deltas; theory rebuild).
- TypeBase: a `"aesop-cases"` tyinfo contribution is **not**
  registered globally (D50/§5.4 rationale); instead `aesopLib`
  exposes `cases_rule_for : hol_type -> rule` (nchotomy/cases-theorem
  backed) for per-invocation/programmatic use.  Constructor intros and
  case splits continue to arrive via `[iff]` (Phase 3) and `[split]`
  (Phase S) respectively.

## 9. Selftests (`src/auto/aesop/selftest.sml`)

Per `src/auto/CLAUDE.md`: successes through `Tactical.VALID`, exact
residues asserted for `AESOP_SAFE_TAC`, negative cases, no state
leaks, expected failures asserted as failures, no benchmark
recognition.

1. Unit: index retrieval (target/hyp, mvar-containing queries);
   priority arithmetic (log-domain products, FIFO ties); schema-v2
   codec round-trips (Forward/Norm, percents, penalties); attribute
   parsing incl. rejection cases; `absorb` merges + conflict error.
2. Tree goldens: Fig. 1/Fig. 2 scenarios (m-coupling, cluster
   partition, copying incl. transitive coupling `G1–G2–G3`);
   postponed safe rapps (assumption-close under metavariables);
   dropped-metavariable case (the §4.6 `RingHom`-style goal expressed
   in HOL4: `?f. homo f` with a hypothesis supplying a
   witness-independent proof) — proved, with `ARB`-grounding
   verified kernel-side.
3. Phases: norm fixpoint order (penalty ordering, restart semantics,
   ≤1-subgoal enforcement, simp-at-0 with a negative-penalty user
   rule before it); dynamic multi-rule prohibition; tactic-rule no-op
   rejection; forward loop prevention.
4. Search: transitivity chains (`x ≤ z` via `≤`-trans with both
   reflexivity and hypothesis instantiations — the §4 motivating
   example); limits (max_rapps, max_depth) trigger cleanly.
5. Strength smoke set: a listTheory mini-corpus (append/length/
   reverse/membership lemmas solvable without induction) run under
   `AESOP_TAC []`; Pelletier propositional subset for sanity; exact
   `AESOP_SAFE_TAC` residues on representative goals.
6. Replay honesty: every success re-checked by the kernel via
   `Tactical.VALID`; a deliberately corrupted-store test asserting the
   hard-error (not silent) replay policy.

## 10. Documentation

`help/Docfiles` entries: `aesopLib.AESOP_TAC`,
`aesopLib.AESOP_SAFE_TAC`, `aesopLib.CS_AESOP_TAC`,
`aesopLib.CS_AESOP_SAFE_TAC`, `aesopLib.augment_aesop`, the
`[norm]`/`[forward]`/`[sforward]`/`[aesop_simp]` attributes (in the
attribute documentation alongside `[intro]` etc.), and the numeric
attribute-argument syntax.  `AESOP_TAC`'s entry credits the published
design (Limperg & From, CPP 2023) and documents divergences: tactic
rules cannot bind metavariables; no induction; no named rule sets;
dropped metavariables grounded to `ARB`.

## 11. Task breakdown

Each task gates on: focused `Holmake` + `selftest.exe` in the touched
directories, `tools/h4pedant` over them, `git diff --check`, and
`bin/build -t --seq=tools/sequences/upto-auto`; the phase closes with
an explicit full `bin/build -F -t`.

1. **T01** HolLex attribute-value tweak + `clasetLib` percent parsing
   (+ selftest updates).  [§3.1]
2. **T02** `clasetRules` v2: kinds, codec `clasetADD2`, routing,
   `ext_info`, ordering; attribute registrations `[norm]`,
   `[forward]`, `[sforward]`.  [§3.3]
3. **T03** Aesop index in `CS` + candidate entry points.  [§3.4]
4. **T04** `clasetStep.rule_step` (+ optional non-consuming replay
   action); differential tests.  [§3.2]
5. **T05** `clasetMeta.absorb` + tests.  [§3.5]
6. **T06** Markers `Norm`/`Forward`/`SForward`.  [§3.6]
7. **T07** `aesopData`: settype + derived simpset.  [§4.1]
8. **T08** `aesopRule` + builders (apply/constructors/forward/
   destruct/cases/simp/tactic).  [§4.2, §5]
9. **T09** `aesopTree`: nodes, states, clusters, copying (golden
   tests first).  [§4.3]
10. **T10** `aesopNorm`: fixpoint + built-in chain + simp rule.  [§6]
11. **T11** `aesopSearch`: loop, phases, postponement, limits,
    safe-goals computation.  [§4.4]
12. **T12** Extraction/replay (absorb + ground + bottom-up
    validation composition); replay-honesty tests.  [§4.5]
13. **T13** `aesopLib` surface + argument pipeline + seeds percent
    pass.  [§7, §8]
14. **T14** Selftest completion (strength smoke set), Docfiles,
    build-sequence integration.  [§9, §10, §3.7]
15. **T15** Phase gate: full `bin/build -F -t`; freeze-list record
    (§13); parent-plan register update (D44–D51, gate record).

Dependency spine: T01–T06 are independently gateable; T08 needs
T02–T04; T09 needs T05; T11 needs T08–T10; T12 needs T05, T09;
T13 needs T07, T11, T12.

## 12. Risks

1. **Copying algorithm correctness** (the parent plan's declared
   highest-risk component): mitigated by golden tree tests written
   *before* the search loop (T09), the paper's worked figures as test
   vectors, and the `absorb` conflict check turning bookkeeping bugs
   into hard errors instead of unsound replays (replay itself is
   kernel-checked regardless — soundness is never at stake, only
   completeness/failure).
2. **Freeze amendments** (D45, D51, markers): all additive; each
   lands with differential/golden tests and its own gate before any
   consumer exists.
3. **Priority underflow/fairness**: log-domain sums avoid float
   underflow; FIFO tie-breaking keeps equal-priority exploration
   deterministic; documented.
4. **Norm-phase loops** (badly oriented `aesop_simp` rewrites, §3.2
   caveat): the simp call inherits simpLib's bounded machinery
   (`cond_depth` 40); the fixpoint counts iterations against
   `max_depth`-derived bound; disable-hypotheses control available.
5. **Strength shortfall vs Lean's aesop** on metavariable-heavy goals
   (tactic rules can't bind metas; unification-only witnesses): the
   engine-native builders cover the paper's own default corpus; gaps
   feed Phase-8 benchmarks, as for every other phase.
6. **Schema-v2 compatibility**: v1 deltas continue to decode; new
   kinds emit v2 only; theory_tests cover cross-version reload
   (ancestor with v1-only deltas loaded by v2 code).

## 13. Interfaces later phases rely on (freeze list)

Frozen at Phase-4 completion on 2026-07-29, against source revision
`406b4efd67e1` (changes require an owner decision):
`rulespec`/`cdelta` v2 schema and per-kind `prio` semantics; the
attribute surface incl. numeric-argument syntax; the `aesop_simp`
settype; `clasetStep.rule_step` and `clasetMeta.absorb` signatures;
the marker vocabulary incl. `Norm`/`Forward`/`SForward`; the public
`aesopLib` signatures (`aesop_config`, the four tactics,
`augment_aesop`, `cases_rule_for`).  Engine internals (`aesopTree`/
`aesopSearch`/`aesopNorm` shapes) remain private.
