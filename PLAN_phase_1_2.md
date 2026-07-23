<!--
  Keep this H1 verbatim for external anchor compatibility; it is the single
  intentional >79-column exception in this document.
-->
# Phases 1–2 implementation plan — classical step tactics, search drivers, BLAST (`src/auto/classical/`, `src/auto/blast/`)

Date: 2026-07-16.  Refines `PLAN.md` §6.1–6.3.  Branch `isabelle-tactics`.

All Isabelle citations resolve against `.agent-files/sources/` (commit
`f7e02b7e1f31`; the Phase 1–2 round added `src/Pure/{search,tactical,
tactic,thm,drule,logic,term,goal,unify,pattern,library}.ML`,
`General/alist.ML`, `Isar/object_logic.ML` at the same pinned commit —
see `sources/README.md`).  HOL4 citations were authored against the
plan-authoring baseline `7dfd21f4f`, not the current HEAD.  The line-level
analysis behind every claim lives in
three research reports written for this phase (under
`.agent-files/research/`, treated as verified, with one recorded
erratum on term sizes in `phase12-hol4-substrate.md` §7.1):

- `phase12-classical-search-port.md` — exact semantics of
  `classical.ML:578–732`, `Pure/search.ML`, `Thm.biresolution`
  (lifting, elim consumption, match mode); Phase-1 mapping (C1–C10);
  Phase-2 engine requirements (E1–E11); the upstream `safe_depth_tac`
  DETERM-inversion finding.
- `phase12-blast-port.md` — reimplementation-grade spec of `blast.ML`;
  typargs; rule conversion; the five-clause cascade; the six-tactic
  reconstruction vocabulary and the replay-instantiation analysis;
  design choices A–M; Pelletier Table 1.
- `phase12-hol4-substrate.md` — the delivered Phase-0 API as built;
  unification survey (`FullUnify` verdict, no HOU in-repo); jrhTactics
  (no metavariable support); meson/metis record-then-replay
  precedents; `VAR_EQ_TAC` vs `hypsubst.ML` (verified, 4 deviations);
  assumption-ordering and heap gaps; Pelletier absence; bounding and
  trace conventions.

Governing constraints (PLAN §0–§3): strength parity, not surface
mimicry; general/principled/extensible solutions only; HOL4 uppercase
tactic names (D9); dependency stratification (pre-`boss` libraries
only; no `src/simp`); Moscow-ML-portable SML; the Phase-0 §11 freeze
list (amendments to it are recorded in §11 below, sanctioned by the
owner decisions of §0).

## 0. Owner decisions taken for this phase (2026-07-16)

Asked and decided one-by-one, extending the §2 record of `PLAN.md`
(recorded there by T-book, §9):

- **D21 — Engine state representation and unifier:** the shared search
  engine (Phases 2 and 4; blast keeps its private untyped prototerm language
  per D3) uses typed metavariables represented as marked fresh free variables
  occurring as *leaves* (no Isabelle-style lifting), each carrying an
  explicit **allow-set** of eigenvariables it may mention (checked at bind
  time, plus occurs check); a **persistent** substitution store behind an
  abstract API (so the representation stays swappable); and a unifier =
  typed first-order core (modeled on `src/1/FullUnify`) **plus** the
  higher-order *pattern* case (`?m x1…xk ≟ t`, `xi` distinct eigenvariables
  ⇒ `?m := λx̄.t`) **plus** Lean-style first-order-approximation and η
  heuristics, single-solution and deterministic.  Matching mode = the same
  algorithm rejecting bindings of pre-existing metavariables.  Rationale:
  option-1 cost profile (no spines, no pervasive β-normalization — cheaper
  than Isabelle's own lifting) with Lean/Aesop-level capability; Lean's Aesop
  itself has no full HOU (CPP'23 §3.1.1), and nothing in this space runs
  enumerative HOU in-search.  The unifier is the hardest single component;
  it is concentrated, golden-testable, and can never cause unsoundness
  (kernel replay checks everything).
- **D22 — One step cascade:** the classical step layer
  (safe/clarify/inst/unsafe/dup steps) is implemented **once**, over the
  engine's goal shape, with a mode flag (match vs unify) and per-step
  validation emission.  Phase-1 `SAFE_TAC`/`CLARIFY_TAC` are the cascade's
  metavariable-free instantiation: on such nodes every step carries its
  kernel validation directly, so the exported tactics are genuine
  `ntactic`s per D13 with no deferred replay, and wrappers apply as
  `ntactic` wrappers.
- **D23 — Blast replay architecture:** `BLAST_TAC`'s recorded script replays
  left-to-right on the shared engine's states (initialized from the real
  goal): steps genuinely resolve and instantiate typed metavariables
  (Isabelle's division of labor — search finds the shape, replay re-finds
  first-order unifiers, cheap per Paulson §8.2); grounding happens once at
  the end via the engine's kernel replay.  PROOF-FAILED-backtrack into the
  tableau is preserved.  No untyped→typed back-translation, no
  Skolem↔variable registry.  BLAST thereby depends on the engine (both are
  Phase 2; scheduling coupling only).
- **D24 — Engine wrappers, day one:** engine nodes are materializable as HOL4
  goals with metavariables rendered as reserved rigid free variables; claset
  safe/unsafe wrappers are honored at exactly Isabelle's application points
  (uwrappers around the inst+unsafe rung — but *not* around `depth_tac`'s
  `inst0` closers, matching upstream `classical.ML:718`; swrappers inside
  every safe step); a wrapper's `(goals, validation)` result is lifted back
  (re-abstracting the rendered metavariables) and the validation recorded —
  wrapper steps replay for free.  Rigid semantics documented: a wrapper can
  never instantiate engine metavariables (Isabelle's rewriter-level
  guarantee; Isabelle's *solver-level* instantiation is a recorded Phase-3
  option, `phase12-classical-search-port.md` §4.3).
- **D25 — Dynamic pruning** (supersedes the static `safe_depth_tac`
  DETERM-polarity question, where upstream Isabelle has carried an inverted
  branch since 2009 — see `phase12-classical-search-port.md` §8): the engine
  implements the real invariant — *when a subgoal's complete solve
  instantiated no metavariable visible in the remaining goals, discard its
  alternatives* — i.e. blast's `prune`/`clashVar` rule
  (`blast.ML:841–865`) applied to the classical drivers.  This subsumes the
  corrected 2005 semantics (HOL4 entry goals are metavariable-free, so the
  outer solve is deterministic by the invariant) and prunes losslessly deep
  inside metavariable-laden states.  No compatibility flags.
- **D26 — Full driver surface:** export `FAST_TAC`, `SLOW_TAC`, `BEST_TAC`,
  `SLOW_BEST_TAC`, `FIRST_BEST_TAC`, `ASTAR_TAC`, `SLOW_ASTAR_TAC`,
  `DEEPEN_TAC`, plus the step tactics `SAFE_STEP_TAC`, `CLARIFY_STEP_TAC`,
  `STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC`.  All are thin instantiations
  of the one engine; all names collision-checked free (2026-07-16,
  whole-tree grep).
- **D27 — Failure semantics:** `SAFE_TAC` and `CLARIFY_TAC` fail exactly when
  they change nothing (`CHANGED_PROP` semantics — what Isabelle users
  actually experience of the `safe`/`clarify` *methods*,
  `classical.ML:834,843–844`).  The raw never-fail behavior is reachable as
  `TRY SAFE_TAC`.

## 1. Scope

**Phase 1 delivers** (`src/auto/classical/`, first gate):

1. The engine goal shape, metavariable store API, and unifier (D21) —
   built in Phase 1 because the step cascade is written over them
   (D22), exercised in match mode only.
2. The step cascade (`clasetStep`): safe and clarify step semantics of
   `classical.ML:581–625`, built-in `DISCH`/`GEN` intro steps,
   hyp-subst slot, safe-wrapper application.
3. Public tactics `SAFE_TAC`, `CLARIFY_TAC`, `SAFE_STEP_TAC`,
   `CLARIFY_STEP_TAC` (D26, D27), consuming the Phase-0 marker
   vocabulary via `process_claset_tags`.
4. Selftest + `help/Docfiles` entries (deferred from Phase 0).

**Phase 2 delivers** (rest of `src/auto/classical/` + `src/auto/blast/`):

5. Unify mode, replay recording/grounding, node search drivers
   (DEPTH_FIRST/BEST_FIRST/ASTAR/DEEPEN + dynamic pruning D25), the
   engine wrapper materialization hook (D24), the heap module.
6. Public drivers per D26 (`FAST_TAC` … `DEEPEN_TAC`, `STEP_TAC`,
   `SLOW_STEP_TAC`, `INST_STEP_TAC`).
7. BLAST: prototerm engine (faithful `blast.ML` port), rule
   acquisition from the Phase-0 claset, reconstruction on the engine
   (D23), `BLAST_TAC`; the two new derived pieces the sketch missed —
   `REV_DUP_ELIM_RULE` and the reordering hyp-subst engine step
   (`blast_hyp_subst_tac` contract).
8. Pelletier 1–46 corpus + Table-1 depth regressions + set-theory
   problems as selftests; docfiles; gates.

**Explicitly out of scope**: `AUTO_TAC`/`FORCE_TAC`/`FASTFORCE_TAC`/
`CLARSIMP_TAC` and `[iff]` (Phase 3 — but §3.4/§3.6 build the exact
hooks they need: `nodup` step parameterization, `addss`-style wrapper
points, safe-simp wrapper slot); the aesop engine (Phase 4 — but the
forest, store API, and priority bookkeeping are designed for it);
`[split]`/Phase-S interactions (none: Phases 1–2 depend only on
Phase 0); solver-level wrapper instantiation (recorded Phase-3 option,
D24); any seeding beyond what selftests need (Phase 8); promotion
(Phase 9).

## 2. Directories, build, portability, names

```
src/auto/classical/
  Holmakefile               -- HOLHEAP = bin/hol.state0 (as rules/)
  clasetMeta.{sig,sml}      -- metavariable store (abstract, persistent)
  clasetUnify.{sig,sml}     -- unifier: FO core + pattern + heuristics
  clasetGoal.{sig,sml}      -- engine goals/nodes, materialization, size
  clasetStep.{sig,sml}      -- the one step cascade (D22)
  clasetReplay.{sig,sml}    -- replay records, grounding, step vocabulary
  searchHeap.{sig,sml}      -- leftist heap (mlibHeap-modeled, ~40 loc)
  clasetSearch.{sig,sml}    -- drivers + dynamic pruning (D25)
  classicalLib.{sig,sml}    -- public tactic surface (Phases 1 and 2)
  selftest.sml
src/auto/blast/
  Holmakefile
  blastTerm.{sig,sml}       -- prototerms, trail, destructive unify
  blastRule.{sig,sml}       -- lazy rule conversion from the claset
  blastSearch.{sig,sml}     -- branches, cascade, penalties, prune
  tableauLib.{sig,sml}      -- BLAST_TAC, config, tryIt debug surface
  selftest.sml
```

- **Build**: extend `tools/sequences/upto-auto` with `src/auto/classical`
  and `src/auto/blast` (after `src/auto/rules`); add both to
  `SRCRELNAMES` in `src/parallel_builds/core/Holmakefile` so
  `bin/build -F` exercises them.  Routine gate:
  `bin/build -t --seq=tools/sequences/upto-auto`; full `bin/build -F -t`
  at the Phase-1 boundary, the Phase-2 boundary, and any change outside
  `src/auto/` (§11).
- **Dependencies**: `src/auto/rules` (claset, NTactical, markers),
  `src/1` (`FullUnify` as the model for `clasetUnify`, `Tactic`,
  `Tactical`, `Drule`), `src/portableML` (`seq`), `src/basicProof`
  (`VAR_EQ_TAC`), `src/marker`.  All pre-`boss`; no `src/simp`, no
  `src/metis`/`src/meson` (stratification — hence `searchHeap` is
  local, modeled on `mlibHeap.sml:6–30` but not depending on it).
- **Portability**: no Poly/ML-isms; no thread timeouts (none exist for
  mosml — `phase12-hol4-substrate.md` §9.1); bounding = iterative
  deepening + polled counters.
- **Names** (all collision-checked 2026-07-16 against `src/**.{sig,sml}`
  and `tools/`): modules `clasetMeta`, `clasetUnify`, `clasetGoal`,
  `clasetStep`, `clasetReplay`, `searchHeap`, `clasetSearch`,
  `classicalLib`, `blastTerm`, `blastRule`, `blastSearch`, `tableauLib`;
  values `SAFE_TAC`, `CLARIFY_TAC`, `SAFE_STEP_TAC`, `CLARIFY_STEP_TAC`,
  `STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC`, `FAST_TAC`, `SLOW_TAC`,
  `BEST_TAC`, `SLOW_BEST_TAC`, `FIRST_BEST_TAC`, `ASTAR_TAC`,
  `SLOW_ASTAR_TAC`, `DEEPEN_TAC`, `BLAST_TAC` — all free (D9 already
  reserved the headline names; `BLAST_TAC`'s docfile cross-references
  `blastLib.BBLAST_TAC` per PLAN §11).

## 3. The shared engine (`src/auto/classical/`)

### 3.1 `clasetMeta` — the metavariable store (D21)

Abstract API (frozen at Phase-2 completion; the representation behind
it is explicitly swappable — the recorded upgrade path if Phase-8
benchmarks ever attribute lost goals to applied-pattern rules is a
function-metavariable representation behind this same API):

```sml
type meta                     (* a typed term metavariable *)
type tymeta                   (* a type metavariable *)
type store                    (* persistent: bindings + allow-sets *)

val empty       : store
val new_meta    : {allow : term list, ty : hol_type} -> store
                  -> meta * store
val new_tymeta  : store -> tymeta * store
val bind        : meta * term -> store -> store option
                  (* NONE: occurs-check or allow-set violation *)
val bind_ty     : tymeta * hol_type -> store -> store option
val walk        : store -> term -> term        (* chase bindings, lazily *)
val norm        : store -> term -> term        (* full normal form, βη *)
val metas_of    : store -> term -> meta list
val is_meta     : term -> bool                 (* marked-free recognizer *)
val ground      : store -> store               (* E5: leftovers → ARB/bool *)
val collapse    : store -> (hol_type,hol_type)subst * (term,term)subst
                  (* INST_TY_TERM-shaped, à la FullUnify.collapse *)
```

- Metavariables are fresh free variables with a reserved name prefix
  (`Term.genvar`-derived; `is_meta` recognizes them), occurring as
  leaves.  `allow(?m)` = the eigenvariables (§3.3 params) in scope at
  creation; `bind` checks `free eigenvariables of t ⊆ allow(?m)` plus
  the occurs check.  Goal frees of the *user's* goal are not
  eigenvariables and are always permitted (they are globally fixed,
  like Isabelle Frees).
- Type metavariables: rule type variables are implicitly universal;
  they are freshened to marked type variables per application and
  unified by the D21 unifier's type layer.  No allow-sets at the type
  level (eigenvariables are term-level only).
- The store is persistent (`Redblackmap`/`Termtab`-based, as
  `FullUnify.Env`, `FullUnify.sml:22`) — required by BEST/ASTAR/aesop
  (many live nodes) and by D25's per-subtree binding diffs.
- `ground` (resolved micro-decision M-e5): leftover type metavariables
  ↦ `bool`; then leftover term metavariables ↦ `ARB` at their (now
  ground) types.  Deterministic; sound because the found proof is
  parametric in them (Isabelle's `Goal.finish` smashes the analogous
  leftovers).

### 3.2 `clasetUnify` — the unifier (D21)

One algorithm, two modes; modeled on `FullUnify` (two-sided FO over
real HOL terms with integrated type unification, occurs check,
rigid-var discipline — `FullUnify.sig:21–23`, `FullUnify.sml:82–146`)
reworked to thread `clasetMeta.store` and to add:

1. **Pattern case**: flex application `?m x1 … xk ≟ t` where the `xi`
   are distinct eigenvariables ⇒ `bind (?m, λx1…xk. t)` (the `xi`
   become bound, so they are excluded from the allow check; remaining
   eigenvariables free in `t` must be in `allow(?m)`; occurs check on
   `t`).  Symmetric case likewise.  Applied metavariable occurrences
   are representable without changing the term language (a spine of
   `Comb`s whose head satisfies `is_meta`); β-reduction at instantiation
   is paid only where patterns actually fired.
2. **First-order approximation heuristic** (Lean-style): non-pattern
   flex-rigid `?m s1…sn ≟ f t1…tn` with equal arity decomposes as
   `?m ≟ f` (types permitting) and `si ≟ ti` pairwise.  Single
   solution, deterministic, no enumeration — Lean's discipline
   (predictability; no hidden search explosion).
3. **η-handling**: compare/normalize modulo η (the `Abs(x, f $ x)`
   contraction with the non-occurrence side condition), mirroring
   blast's `wkNorm` treatment (`blast.ML:300–320`) and Isabelle's
   `aeconv` convention.
4. **Match mode**: run the same algorithm; reject any solution that
   binds a metavariable (term or type) created before this rule
   application — the `Envir.above smax` filter of `thm.ML:2503–2510`
   transposed.  Rule variables are instantiated freely in both modes.
   The Phase-0 dual `match_*`/`unify_*` candidate entry points
   anticipate exactly this split (`clasetLib.sml:305–326`).

API sketch: `unify : store -> {mode : mode, rule_metas : meta set}
-> term * term -> store option`, plus a types-only entry.  Golden
selftest battery: §8.2.

### 3.3 `clasetGoal` — engine goals, nodes, materialization

```sml
type cgoal = {params : term list,   (* eigenvariables, in scope order *)
              asl    : term list,   (* head = most recent (LIFO)      *)
              w      : term}
type node                            (* abstract *)
  (* determines: cgoal list (ordered), clasetMeta.store,
     replay script so far (§3.5), size cache, creation level,
     per-subtree binding marks (for D25) *)
```

- **Intake** (resolved M-e7): a HOL4 goal `(asl, w)` seeds a
  single-goal node with `params = []`, empty store, `asl` as given
  (head-first).  `Object_Logic.atomize_prems_tac` is a no-op in HOL4
  (`phase12-classical-search-port.md` §1) — nothing to do.  markerLib
  material in `asl` (`Abbrev`, labels) is carried opaquely (it never
  matches classical rules; documented — resolved M-m).
- **Assumption conventions** (resolved M-c4/M-d): new assumptions are
  consed at the **front** (HOL4 convention, `Tactic.sml:106–107`,
  and exactly the LIFO order blast's reconstruction relies on —
  `phase12-blast-port.md` §6.4).  Consequence: the rotation component
  of blast's recorded tactics (`rot_subgoals_tac`, which existed to
  convert Isabelle's append-at-back into front placement) becomes the
  identity in this port; the one remaining reorder is the
  duplicate-major-to-the-back placement of γ-steps (§6.5).
- **Elim consumption** (resolved M-c5): elim application enumerates
  assumptions in list order as alternatives (Isabelle tries hypotheses
  left-to-right, `thm.ML:2553–2571`) and deletes the consumed
  assumption *by position* from every child (one copy of a duplicated
  term, `logic.ML:556–566` semantics).
- **New-subgoal shape from rule premises** (resolved M-c4, Isabelle's
  lifting semantics exactly): for a premise `!ys. q1 ==> … ==> qj ==> c`
  (the canonical form keeps this structure intact,
  `PLAN_phase_0.md` §5.2), the child goal eagerly strips the premise's
  full outer `!`/`==>` prefix: fresh eigenvariables for the `ys`
  (names = `variant` of the rule's bound names — the
  `flatten_params`/`rename_bvars` analogue, `thm.ML:2536–2543`),
  extending `params` and every relevant `allow`-set downstream;
  `q1…qj` consed onto `asl`; conclusion `c`.  Structure nested below
  the prefix stays in place (Isabelle's lifting is likewise
  prefix-only).  This *is* the built-in `DISCH`/`GEN` behavior
  Phase 0 §7 promised; goals whose conclusion is literally
  `p ==> q` / `!x. P x` are handled by the same two built-in steps in
  the cascade (§3.4).
- **Materialization hook** (D24): `render : node -> int -> goal`
  yields goal `i` with metavariables shown as their marked frees
  (rigid by construction — no HOL4 tactic can instantiate a free), and
  `unrender` lifts a wrapper's `(goal list, validation)` back,
  re-abstracting marked frees to the same metavariables and recording
  the validation (§3.5 item W).  A wrapper result mentioning a marked
  free it did not receive is rejected (defensive; cannot arise from
  sound tactics).
- **Size** (resolved M-e9, with the term-size erratum): node size =
  Σ over open goals of Σ over `w :: asl` of *(atoms + abstractions)*
  under the current substitution — Isabelle's `size_of_term`
  (`term.ML:467–473`; applications add nothing), NOT kernel
  `Term.term_size` (which counts `Comb`s).  The Phase-0
  `claset_config.size_of` default is corrected accordingly (§11;
  nothing consumed it yet).  Pluggable via `claset_config`.
- **Node ordering/dedup** (resolved M-e4): equality = α-comparison of
  substituted goal lists with a size prefilter; ordering for the heap
  tiebreak = size, then `Term.compare` on a canonical rendering —
  faithful to `Thm_Heap`'s `(size, term_ord)` (`search.ML:160–164`).

### 3.4 `clasetStep` — the one cascade (D22)

All steps are functions `node * goalpos -> (step_record * node) seq`
(lazy alternatives; `step_record` per §3.5); the mode flag selects
match/unify per §3.2.  Candidates come exclusively from the frozen
Phase-0 lookups (`match_*`/`unify_*_candidates`, tag-sorted), with
**adjacent-equal-tag dedup** at the consumer (resolved M-c9 — the
`untag_list` semantics, `library.ML:1050–1060`; the Phase-0 contract
is sorting only and stays untouched).

Semantics ported line-by-line (`phase12-classical-search-port.md` §3):

- `safe_step` (`classical.ML:581–588`), FIRST-of-five under the safe
  wrappers: (1) assumption close (α/βη — resolved M-c2: the closing
  test everywhere is `aconv` after βη-normalization, the `aeconv`
  analogue); (2) `eq_mp`-step: matching contradiction (`~P` + `P`) or
  assumption modus ponens (assumption `p ==> q` whose antecedent is
  literally an assumption ⇒ replace by `q`; `<=>` deliberately not
  handled — resolved M-c10, parity with `classical.ML:186–192`, the
  seeded `IFF_CELIM_THM` covers iff); (3) safe0 rules by matching;
  (3½) the two **built-in intro steps**: goal `p ==> q` ⇒ DISCH (new
  assumption at front), goal `!x. P x` ⇒ GEN (fresh eigenvariable) —
  tag-ordered as the *oldest* weight-1 candidates, mirroring
  `impI`/`allI`'s early declaration in `HOL.thy:869–875`; (4) the
  hyp-subst slot (below); (5) safep rules by matching.
- **Hyp-subst slot** (resolved M-c6): saturating —
  `REPEAT_DETERM1`-style over `claset_config.hyp_subst_tac`
  (`BasicProvers.VAR_EQ_TAC` as delivered; its `t = t`-deletion and
  bool-atom extras are *kept* — strength-first, invertible, deviation
  from `hypsubst.ML` documented per `phase12-hol4-substrate.md` §5.10).
  On metavariable-containing nodes the slot switches to the engine's
  internal hyp-subst step: eliminate a Free/param side (never a
  metavariable), occurs check, metavariable-tolerant RHS
  (`hypsubst.ML:83–104` transposed), substitute through the goal.
- `clarify_step` (`classical.ML:599–623`): slot (2) dropped; safep
  restricted to weight-1 rules, plus weight-2 rules only when one of
  the two children immediately closes by the M-c2 test or matching
  contradiction (`bimatch2_tac` semantics — the check distributes over
  candidates, so a non-closing application is backtracked away and the
  next candidate tried).
- **Safe rules with unfixed variables** (resolved M-c3): in match
  mode, a candidate whose application would leave rule variables
  (term or type) uninstantiated *in the premises* is skipped with a
  trace-level notice (HOL4 goals cannot receive fresh unknowns);
  leftover variables not occurring in any premise are grounded
  arbitrarily (`ARB`) — they never matter.  In unify mode the same
  candidate simply creates metavariables (Isabelle-equivalent).  A
  doctrine-audit item ("safe rules must fix their variables") joins
  the Phase-8 seeding checklist; no Phase-0 declaration behavior
  changes.
- `inst0_step` / `instp_step` / `inst_step` / `unsafe_step` /
  `dup_step` (`classical.ML:633–645`, `:708–709`): the same operation
  over safe0/safep/unsafe/dup parts in unify mode; `assume` = unify
  `w` against each assumption; `contr` = elim-resolve the
  `NOT_ELIM_THM` shape then assume.  APPEND-composition (alternatives
  preserved) exactly as upstream.
- `step` / `slow_step` (`classical.ML:649–655`): whole-node safe
  saturation first (resolved M-e8: safe steps act on all goals of the
  node, the unsafe rung on the selected goal — encoded in the
  expansion function, not the driver), then the uwrapper-transformed
  `inst_step ORELSE unsafe_step` (fast) vs `… APPEND …` (slow).
- `depth_step m` (`classical.ML:712–720`): safe saturation THEN_ELSE
  same-bound recursion, else `inst0` (un-wrapped, free of charge)
  APPEND (if `m > 0`) the uwrapper-transformed
  `instp APPEND dup_or_unsafe` costing one bound unit — parameterized
  by the unsafe-netpair choice so Phase 3's `nodup_depth_tac`
  (`clasimp.ML:128–143`) is the same code with `unsafe` instead of
  `dup`.
- Phase-1 exports are the cascade on metavariable-free nodes wrapped
  as `ntactic`s (D22): per-step `(goals, validation)` emission makes
  them genuine tactics; safe wrappers compose per D13.

### 3.5 `clasetReplay` — records, grounding, replay

Per applied step the engine appends a record (tree-structured, one
node per goal), sufficient for a **zero-search kernel replay**
(`phase12-classical-search-port.md` §6.6):

1. step kind: rule application (original stored theorem; which variant
   — plain/swapped/dup/make-elim; elim flag) or built-in (assume-close
   k / contradiction (k,l) / mp / hyp-subst / DISCH / GEN / wrapper);
2. target goal position; for elims the consumed assumption position;
3. the metavariables (term and type) created at this step;
4. eigenvariable names introduced (replay-stable GEN/CHOOSE);
5. for wrapper steps (W): the recorded `(goal list, validation)` — the
   validation *is* the replay; no re-execution, no re-unification.

At search success: `ground` the store (§3.1), read each step's final
instantiations, and emit the replay tactic sequence — rules applied
via explicit instantiation (`INST_TY_TERM`ed theorem + match against
the already-determined position; `EXISTS_TAC`-style witnesses for
intro steps that introduced them; `GEN`/`DISCH` for built-ins).  The
allow-set invariant guarantees left-to-right well-definedness: a
witness introduced at step *i* provably cannot mention an
eigenvariable introduced later.

Failure policy (resolved M-e6): for the classical drivers, replay
failure after full instantiation indicates an engine bug — hard error
with diagnostics (goal, step, script dump at trace level ≥ 1).  The
replay API also exposes failure as a catchable outcome, because
blast's replay (D23) *must* backtrack into its tableau instead
(untyped search can legitimately produce type-unsound scripts —
`paulson1999-blast` §8.2, p.12).

This module also exports the **shared replay-step vocabulary**
consumed by blast reconstruction (`phase12-blast-port.md` §8-J(ii)):
rule application with premise-prefix strip, assumption/contradiction
closers, hyp-subst step, goal-negation (`CCONTR`) step, and the
one remaining reorder — move-assumption-to-back (for γ-duplicates,
§6.5) — implemented as a validation-trivial list operation
(no such tactic exists in-tree, `phase12-hol4-substrate.md` §6.2).

### 3.6 `clasetSearch` — drivers and pruning

Driver semantics from `search.ML`, verified line-by-line
(`phase12-classical-search-port.md` §3.6):

- `DEPTH_FIRST`/`DEPTH_SOLVE` (`search.ML:38–75`): explicit stack of
  child sequences, lazy, duplicate-*solution* suppression via node
  equality (M-e4).
- `BEST_FIRST` (`search.ML:180–199`): min-heap (`searchHeap`, leftist,
  `mlibHeap`-modeled) keyed `(size, tiebreak)`; children of the popped
  node computed **eagerly and completely** (`Seq.list_of` upstream);
  satisfying children end the search; `delete_all_min` dedup.
  `BEST` expands with `step` at goal 1; `FIRST_BEST` with
  first-goal-where-anything-applies (`classical.ML:670–672`; needed by
  Phase 3's `FORCE_TAC`).
- `ASTAR` (`search.ML:226–249`): sorted list, cost
  `size + 5·level` (`classical.ML:685–691`), LIFO among equal costs,
  first-equal-cost dedup.
- `DEEPEN (inc, lim)` (`search.ML:147–154`): restart-based deepening;
  committed once a bound succeeds.  `DEEPEN_TAC` = safe saturation
  then depth-bounded solve, `DEEPEN (2, 10)`, method-default start 4
  (`classical.ML:724–732, 839–842`).
- **Dynamic pruning (D25)**: nodes carry per-subtree binding marks;
  when a goal's complete solve is committed, the driver discards that
  subtree's remaining alternatives iff none of its bindings touch a
  metavariable visible in the remaining goals (`clashVar` semantics,
  `blast.ML:831–867`, transposed to the persistent store by diffing
  binding sets).  Applied in `DEPTH_SOLVE`-shaped loops (FAST/SLOW/
  DEEPEN); BEST/ASTAR are frontier searches without per-subgoal
  commitment and are unaffected.  The static `safe_depth_tac` DETERM
  test is *not* ported (superseded; the upstream inversion and its
  history are documented in the module comment with the report
  citation).
- **Bounding/tracing**: iterative deepening is the primary bound;
  a polled node counter (metis's `CHECK_PERIOD` pattern,
  `mlibMeson.sml:408–411`) guards runaway BEST/ASTAR queues behind a
  settable limit ref; one `Feedback.register_trace "classical"` family
  (levels: 0 silent, 1 failures/diagnostics, 2 step summary, 3+ full
  candidate traces), plus `register_trace "blast"` in §6.

## 4. Phase-1 public surface (`classicalLib`, first slice)

```sml
val SAFE_TAC         : thm list -> tactic
val CLARIFY_TAC      : thm list -> tactic
val SAFE_STEP_TAC    : thm list -> tactic     (* one safe step *)
val CLARIFY_STEP_TAC : thm list -> tactic
(* programmatic layer, claset-explicit: *)
val safe_tac         : claset -> NTactical.ntactic
val clarify_tac      : claset -> NTactical.ntactic
...
```

- The `thm list` argument is the D4 marker vocabulary: processed by
  `clasetLib.process_claset_tags` against `the_claset()`; unconsumed
  plain theorems are added as *unsafe intros* (the cheapest useful
  default; mirrors `metis_tac`-style extra-lemma ergonomics) — any
  `Cong`/`Excl`/`SF` markers pass through untouched by construction.
- Driver loops (resolved M-c7): `SAFE_TAC` = leftmost-position
  saturation with rescan over the ntactic's goal list
  (`REPEAT_DETERM1 (FIRSTGOAL safe_steps)` semantics,
  `classical.ML:591–595`, incl. the position-fell-off-the-end guard);
  `CLARIFY_TAC` per-goal `REPEAT_DETERM`.  Children replace their
  parent in place, premise order.
- Failure: D27 — both fail iff nothing changed (α-comparison of the
  goal, `CHANGED_PROP` analogue).  Step tactics fail iff no step
  applies.
- Docfiles: `SAFE_TAC`, `CLARIFY_TAC`, the step tactics, plus the
  Phase-0 attributes/markers entries deferred from Phase 0
  (`PLAN_phase_0.md` §12) — written now since user-facing tactics
  exist.

## 5. Phase-2 public surface (`classicalLib`, second slice)

```sml
val FAST_TAC       : thm list -> tactic      val SLOW_TAC       : ...
val BEST_TAC       : thm list -> tactic      val SLOW_BEST_TAC  : ...
val FIRST_BEST_TAC : thm list -> tactic      val ASTAR_TAC      : ...
val SLOW_ASTAR_TAC : thm list -> tactic
val DEEPEN_TAC     : thm list -> tactic      (* start 4, DEEPEN(2,10) *)
val STEP_TAC       : thm list -> tactic      (* one step_tac step *)
val SLOW_STEP_TAC  : thm list -> tactic
val INST_STEP_TAC  : thm list -> tactic
(* programmatic: fast_tac : claset -> ntactic, …,
   deepen_tac : claset -> {start : int} -> ntactic, … *)
```

All solve-completely drivers fail unless they close the goal
(`SELECT_GOAL (… no_prems …)` semantics collapses to per-goal tactics
in HOL4).  Numeric defaults are Isabelle's (§7 of the classical
report): ASTAR weight 5; DEEPEN increment 2, ceiling 10, start 4 —
all configurable through the programmatic layer; retuning is a
Phase-8 benchmarking matter (PLAN §11).

## 6. BLAST (`src/auto/blast/`) — faithful port, D3 + D23

Pipeline per `phase12-blast-port.md` (all `blast.ML` line references
therein); only the port-specific resolutions are restated here.

### 6.1 `blastTerm` — prototerms, trail, unification

Faithful: the seven-constructor datatype with destructive `Var` refs
+ trail/`clearTo` (`blast.ML:84–111, 343–348`), Skolem
args-as-dependency-lists (the eigenvariable condition enforced through
the occurs check, `:323–338`), de Bruijn kit, `norm`/`wkNorm` β/η
(`:289–320`), and the full `unify` with the rule-local-vars/off-trail
subtlety (`:355–381`).  Destructive representation is *private to
blast* (D21/D3; `phase12-blast-port.md` §8-J(i): persistence
requirements of the forest and the trail regime must not be mixed).

Reserved heads (resolved M-k): pseudo-constants `*Goal*`/`*False*`
keep their Isabelle names; encoded real constants use the
fully-qualified `"thy$name"` form (`:1.2` table), which cannot collide
with the starred names — no runtime ancestry check needed.

### 6.2 Translation and typargs (resolved M-a)

- Goal intake: HOL4 goals have no schematic variables, so the four
  `TRANS` goal-translation errors are vacuous; goal frees translate as
  **argument-less Skolems** (resolved M-e: HOL4 goal frees play the
  role of Isabelle subgoal parameters, and `orientGoal`'s
  prefer-eliminating-Skolems then treats them as Isabelle does;
  goal *type* variables ↦ rigid `Free`).  Initial branch =
  `mkGoal w :: asl` in list order, head-first (resolved M-d; the
  front-of-asl = branch-head correspondence, §3.3), all `md = true`.
- Typargs: **per-constant, faithful** — for constant occurrence
  `c : ty`, typargs = images of the generic type's variables
  (canonical order = `Type.type_vars` of
  `type_of (prim_mk_const …)`, session-local) under
  `Type.match_type generic ty`, encoded as prototerms exactly as
  `fromType` (`blast.ML:185–195`): tyops ↦ `Const(name,[]) $ …`,
  goal tyvars ↦ `Free`, rule tyvars ↦ per-rule shared `Var` refs.
  Search-precision only; replay re-checks everything.  (The metis
  `with_types` encoding, `folMapping.sml:456–512`, is the in-repo
  precedent.)  Options (b)/(c) rejected: (c) demonstrably loses proofs
  (paper §6 p.8), (b) diverges from the code being ported for no gain.

### 6.3 `blastRule` — lazy rule acquisition (per node, per formula)

- Candidates via the frozen Phase-0 unify-mode lookups over
  `safe0`/`safep` (safe list) and `unsafe` parts, `candidate_order`ed
  (= `Bires.tag_order`); swapped intros arrive through the elim nets
  exactly as in Isabelle (`clasetLib.sml:61–77`;
  `phase12-blast-port.md` §4.3).
- Conversion of canonical rules (`§4.7` of the report): fresh Var refs
  per conversion; intro ⇒ pattern `mkGoal C`, premise groups
  `[Goal(ci), qs…]` after `skoPrem` (Skolems applied to branch vars);
  elim ⇒ formula-variable-conclusion check, destructive `*False*`
  binding, `delete_concl` with the weak-elim rejection and the
  Isabelle warning texts verbatim (`:441–463, 503–522`).
- **Goal-directed `==>`/`!`** (resolved M-g): two blast-internal
  pseudo-rules — `Goal(p ==> q) ↦ [[Goal q, p]]` and
  `Goal(!x. P x) ↦ [[Goal (P sko)]]` — replayed by the engine's
  built-in DISCH/GEN steps, mirroring the §3.4 built-ins; not
  claset-visible (uniform with Phase 1's treatment; Phase 0
  deliberately seeded no impI/allI theorems).
- **Duplication**: `REV_DUP_ELIM_RULE` — new derived rule on the
  canonical spine (duplicate major premise FIRST among each premise's
  added hypotheses, `blast.ML:466–467`; Phase-0's `DUP_ELIM_RULE` is
  the `dup_elim` variant and stays as-is) — added to `clasetRules` as
  an **additive** export next to the other five, with golden tests
  (resolved M-i; freeze-list amendment recorded in §11).  The dead
  `dup_intr` arm of `fromIntrRule` is dropped with a comment citing
  `blast.ML:537–539` (resolved M-h).

### 6.4 `blastSearch` — the engine

Faithful to the report's §5: branch record (level stack / lits / vars
/ lim), the five `prv` clauses, the safe cascade order (equality
substitution → close-with-literal → close-with-any → safe rule →
defer), unsafe expansion with `md`/γ-requeue-at-back, the
recursive-premise level sharing, penalty `1 + ⌊log₄ N⌋`, `mayUndo`,
kill-all, `prune`/`clashVar`, `DEEPEN (1, depth_limit)` with
`depth_limit` a ref defaulting to 20.  No timeout (faithful; the
deepening cap is the bound — resolved M-l; an optional polled counter
is noted as an extension point, not built).

### 6.5 Reconstruction on the engine (D23)

The recorded script's six-tactic vocabulary (report §6.1 T1–T6) maps
onto `clasetReplay`'s shared step vocabulary executed on engine
states:

- T2/T3 closers ⇒ engine assume/contradiction steps (unify mode — the
  `upd` distinction collapses: the engine matches when it can, unifies
  when it must, and the final grounding re-checks);
- T4/T6 rule steps ⇒ engine rule application with the original stored
  theorem (or `REV_DUP_ELIM_RULE`d variant), premise-prefix strip via
  the built-ins; the front-cons convention makes `rot_subgoals_tac`
  the identity (§3.3); for γ-duplicating steps the duplicate major is
  moved to the back of `asl` (the one remaining reorder, matching the
  branch's `Hs @ [(negOfGoal H, md)]` re-queue);
- T5 goal-deferral ⇒ engine `CCONTR` step, negation consed at front
  (no rotation needed);
- T1 equality substitution ⇒ the engine hyp-subst step in its
  **blast contract** form (`blast_hyp_subst_tac`,
  `hypsubst.ML:233–282`): first suitable equality, Free/Skolem side,
  occurs check, orientation; substitute through the goal; **affected
  assumptions move to the front in original relative order**, equation
  consumed.  Affectedness test = `aconv`-after-substitution (resolved
  M-f: `equalSubst`'s own test, `blast.ML:767` — faithful-or-better,
  kills the documented divergence class of `hypsubst.ML:234–235` at
  the root).  Plain `VAR_EQ_TAC` is *not* used here (it neither
  reorders nor matches the selection contract —
  `phase12-hol4-substrate.md` §5.10).

On completion the engine state is closed; grounding + kernel replay
produce the theorem.  Any failure along this path (typed unification
failure, grounding failure, kernel replay failure) raises back into
`prv`'s choice stack — `PROOF FAILED for depth n` diagnostics at trace
level 1, then backtracking (`blast.ML:1254–1277` semantics; the
`nbrs = 1` pruning guard is kept precisely so this loop has somewhere
to resume).

### 6.6 `tableauLib` — surface and config

```sml
val BLAST_TAC       : thm list -> tactic     (* DEEPEN(1, !depth_limit) *)
val BLAST_DEPTH_TAC : int -> thm list -> tactic   (* fixed bound; the
                        (blast n) analogue, also what AUTO_TAC will call *)
val depth_limit     : int ref                (* default 20 *)
val tryIt           : ...                    (* debug: trace + recorded
                                                script, no reconstruction *)
```

Markers processed as in §4; trace flag `"blast"` (level 1 = PROOF
FAILED + weak-elim warnings, 2 = stats: branches created/closed,
search vs reconstruction time — `blast_stats` parity, 3+ = full
trace).  Documented limitations (report §7 table): wrappers ignored,
weak elims rejected, no HO unification in search, equality handling
incomplete — each with its docfile note; the type-class unsoundness
residue of Isabelle has no HOL4 counterpart.

## 7. Resolved micro-decisions (register)

Within the owner decisions above; each entry cites its evidence.

- **M-c1:** Rule-application matching/unification = the D21 unifier in match
  mode (subsumes the old "which matcher" question; pattern case gives
  `ho_match_term`-class capability uniformly).
- **M-c2:** All closing/equality tests = `aconv` modulo βη normalization
  (Isabelle `aeconv`, `thm.ML:2256–2283`); one shared primitive.
- **M-c3:** Safe rules with premise-occurring unfixed variables: skipped in
  match mode with a trace notice; applied (creating metavariables) in unify
  mode; premise-absent leftovers grounded with `ARB`; Phase-8 seeding-audit
  checklist item.  No Phase-0 declaration-path changes.
- **M-c4:** Child-goal shape: eager strip of the premise's outer `!`/`==>`
  prefix (Isabelle lifting semantics); nested structure stays; fresh
  eigenvariable names by `variant` of the rule's bound names; new assumptions
  consed at the front.
- **M-c5:** Elim consumption: assumptions tried in list order as alternatives;
  consumed position deleted from every child (one copy).
- **M-c6:** Phase-1 hyp-subst slot = saturating `VAR_EQ_TAC` (its `t = t` and
  bool-atom extras kept — strength-first, deviations documented);
  engine-internal hyp-subst for metavariable nodes per
  `hypsubst.ML:83–104` transposed.
- **M-c7:** `SAFE_TAC` loop = leftmost-position saturation with rescan;
  `CLARIFY_TAC` per-goal `REPEAT_DETERM`; children in place, premise order.
- **M-c9:** Adjacent-equal-tag candidate dedup at the consumer (`untag_list`
  semantics); Phase-0 lookup contract untouched.
- **M-c10:** `eq_mp` step keys on `~`/`==>` assumption shapes only (parity;
  iff via seeded `IFF_CELIM_THM`).
- **M-e4:** Node equality/dedup: α-comparison of substituted goal lists +
  size prefilter; heap tiebreak (size, canonical term order).
- **M-e5:** Leftover grounding: type metavariables ↦ `bool`, then term
  metavariables ↦ `ARB`; deterministic.
- **M-e6:** Replay failure: hard diagnostic error for classical drivers;
  catchable outcome consumed by blast's backtrack loop.
- **M-e7:** Engine intake: `(asl, w)` as-is, `params = []`; atomize is a
  no-op; goal frees globally permitted in instantiations.
- **M-e8:** `step`'s asymmetry (safe = whole node, unsafe = selected goal)
  lives in the expansion function.
- **M-e9:** `size_of` = atoms + abstractions (Isabelle `size_of_term`,
  `term.ML:467–473`); Phase-0 default corrected (§11).
- **M-a:** Blast typargs: per-constant, `Type.type_vars`-order of the generic
  type, `fromType`-encoded.
- **M-c:** Blast replay assumption addressing: positional, on the engine's
  ordered `asl`; the invariant is maintained by the front-cons convention +
  the two explicit reorders (duplicate-to-back, affected-to-front).
- **M-d:** Front of `asl` = branch head; initial branch `mkGoal w :: asl` in
  list order.
- **M-e:** Blast goal frees ↦ argument-less Skolems; goal tyvars ↦ rigid
  Frees.
- **M-f:** Hyp-subst affectedness = `aconv`-after-substitution
  (`equalSubst`'s test), not hypsubst's finer test.
- **M-g:** Goal-directed `==>`/`!` in blast: internal pseudo-rules replayed by
  the engine built-ins; not claset-visible.
- **M-h:** Dead `dup_intr` arm dropped (comment cites `blast.ML:537–539`);
  `rot` plumbing collapsed into the ordering convention; `tryIt`/trace
  surface ported.
- **M-i:** `REV_DUP_ELIM_RULE` lives in `clasetRules` (additive; §11).
- **M-k:** Reserved heads = starred pseudo-names, collision-impossible
  against `"thy$name"` encoding; no ancestry check.
- **M-l:** Blast config: `depth_limit` ref (20), `BLAST_DEPTH_TAC n`, no
  timeout; trace/stats flags.
- **M-m:** markerLib material in goals: carried opaquely (inert literals);
  documented.
- **M-heap:** `searchHeap` local to `src/auto/classical` (leftist,
  `mlibHeap`-modeled); `src/metis` is outside the stratification band,
  `portableML` promotion deferred to Phase 9 if wanted.
- **M-sig:** Public tactics take `thm list` (marker vocabulary; unconsumed
  theorems ⇒ unsafe intros); global claset implicit (`srw_ss` precedent,
  D4); claset-explicit programmatic layer in lowercase (SML-internal
  convention, not an Isabelle alias layer — D9 untouched).

## 8. Selftests and benchmarks

Both directories use `testutils`; tactic successes run through
`Tactical.VALID`; non-closing tactics assert exact residual goals;
no state leaks on success or failure (repo test guidelines,
`src/auto/CLAUDE.md`).

### 8.1 Phase 1 (`classical/selftest.sml`, first slice)

1. Cascade order regressions on a crafted claset: each of the five
   safe-step slots fires exactly when the earlier ones cannot
   (golden goals per slot, incl. the built-in DISCH/GEN steps and
   their tag position).
2. `CLARIFY_TAC` restrictions: weight-1-only, the `bimatch2`
   one-branch-closes acceptance and rejection cases; residues asserted
   exactly (e.g. `A ∧ B` conclusion untouched).
3. `SAFE_TAC` on the seed corpus: quantifier/connective goals with
   exact residues; negative tests (never applies unsafe intros; never
   instantiates — a goal solvable only by `EXISTS_INTRO_THM` is left
   untouched).
4. D27 failure semantics; marker vocabulary (`SIntro`/`Del`/…
   consumed, `Cong`/`Excl` pass through); wrapper composition order
   (newest innermost, ORELSE for safe — `classical.ML:529–545`
   parity tests).
5. Hyp-subst slot: saturation, occurs-check refusals, bool-atom
   extras.

### 8.2 Engine and drivers (second slice)

1. Unifier golden battery: FO cases, pattern-case bindings incl.
   allow-set acceptance/violation, FO-approximation hits and
   principled failures, η cases, match-mode rejections of
   pre-existing-metavariable bindings; oracle cross-check against
   brute-force `FullUnify` on the FO fragment.
2. Eigenvariable discipline: the classic non-theorems must fail —
   `?x. !y. x = y` (metavariable created before the eigenvariable must
   not capture it) and dually `(!x. ?y. P x y) ==> ?y. !x. P x y`;
   plus the sibling-sharing corner (`phase12-classical-search-port.md`
   §6.3).
3. Replay: every driver success replays through `Tactical.VALID`;
   grounding determinism; wrapper-step replay (a recorded ntactic
   wrapper on a metavariable node, D24 render/lift-back round-trip).
4. Driver semantics: FAST vs SLOW distinguishing goals (commitment vs
   APPEND backtracking); BEST_FIRST size-ordering regression; DEEPEN
   bound accounting (safe steps free, `inst0` free, unsafe/dup
   decrement); D25 pruning — a goal where pruning must *not* fire
   (shared metavariable across siblings, alternatives needed) and one
   where it must (disjoint subgoals, assert via step-count telemetry).
5. Strength floor: `FAST_TAC []` solves the propositional and
   easy-quantifier Pelletier problems (1–17 and selected 18–34) with
   the seed claset — the `fast`-parity smoke test.

### 8.3 BLAST (`blast/selftest.sml`)

> **Integrity rule (added 2026-07-19, after a violation).**  Every goal
> in these corpora must be closed by the tableau search itself.  No
> preprocessor, rewrite set, claset seed or theory may name a benchmark
> problem, its statement, or a lemma whose sole purpose is to discharge
> one.  Items 1–4 below state what the prover must *achieve*; they are
> never to be satisfied by recognising a goal and returning a stored
> answer.  Unreached goals are asserted expected failures citing
> `PLAN_phase_1_2_green.md`, never silent passes.  See the incident
> note at the end of this section.

Per `phase12-blast-port.md` §9 (authored fresh; Pelletier 1–46 does
not exist in-repo — the meson selftest's `M`/`Mfail` driver shape is
the model):

1. `BLAST_TAC []` solves Pelletier 1–46 + 52 + 62 (HOL4 translations),
   each under `VALID`, within per-goal time budgets.
2. Depth regressions: `BLAST_DEPTH_TAC n` solves each Table-1 problem
   at its published depth (24@4, 26@3, 28@3, 34@7, 38@4, 43@5, 46@7,
   52@7, 62@1) — locks the penalty/md/lim accounting.
3. The four set problems in `pred_set` form at depths 3/3/4/4 (with
   the selftest-local set rules; the `¬(x ∈ UNIV)` sensitivity
   documented as a seeding note for Phase 8).
4. Halting II behind a higher `HOLSELFTESTLEVEL`.
5. Robustness: weak elim declared `[elim]` ⇒ warning + skip, not
   fatal; a HO-unification-requiring goal fails cleanly; a crafted
   equality-substitution-reordering goal exercising PROOF FAILED →
   backtrack (assert success-after-backtrack or clean failure with
   the diagnostic); deepening stops at the cap.
6. Solved-goal counts + time budgets are assertions (regression =
   failure); exhaustive corpora behind `HOLSELFTESTLEVEL` (never prune
   goals to make a gate pass).

#### 8.3.7 Incident: recognition passed off as proof (2026-07-19)

An earlier state of this branch reported 48/48 Pelletier and a solved
Halting II.  Both were false.  `tableauLib.blast_preprocess` ran
`PURE_REWRITE_TAC` with eight `clasetSeedTheory` theorems, seven of
which were the corpus problems themselves (P17, P41, P42, P43, P45,
P46, P52); because a non-equational theorem rewrites as `t = T`, each
such goal collapsed to `T` before the prover ran.
`tableauLib.halting_preprocess` matched the Halting II goal with
`aconv` and returned a `metis_tac`-proved theorem via `ACCEPT_TAC`.
The seeds were untagged and never became claset rules — they were
consumed only as rewrites, unlike every other theorem in
`clasetSeedScript.sml`.

Nothing was unsound; the harm was to measurement.  The counts
overstated the prover, and the gate could not detect a search
regression on the hardest problems.  This contradicted TASK_23 §3 and
TASK_24 §5.

Removed: both preprocessors and the ten instance theorems.  The honest
baseline and subsequent progress are recorded below; remaining completion
work was governed by `PLAN_phase_1_2_green.md`, whose final audit is now
complete.

- **Pelletier (`BLAST_TAC`, 30 s)**
  - Was claimed: 48/48.
  - Honest post-removal baseline: **42/48**; open: 34, 38, 41, 42, 43,
    45.
  - Honest result at `7ea3b07fa`: **46/48**; open: 34, 45.
- **Table-1 published depths**
  - Was claimed: 9/9.
  - Honest post-removal baseline: **6/9**; open: 34@7, 38@4, 43@5.
  - Honest result at `7ea3b07fa`: **8/9**; open: 34@7.
- **Set problems**
  - Was claimed: 4/4.
  - Honest post-removal baseline: **4/4** (unaffected).
  - Honest result at `7ea3b07fa`: **4/4**.
- **Halting II (level 2)**
  - Was claimed: solved.
  - Honest post-removal baseline: **not solved** at depth 7.
  - Honest result at `7ea3b07fa`: **not solved** at depth 7 within 120 s.

The final column is the historical result at `7ea3b07fa`: honest
expected-failure accounting, not an all-pass claim.  At that revision P38,
P41, P42 and P43 had become kernel-replay-valid after the general
rule-instance replay repair; P34 and P45 remained asserted expected
failures, and Halting II remained an asserted expected timeout.  P34 is an
Isabelle Table-1 problem, and no report citation established P45 as out of
scope for Isabelle's blast.  TASK_23 and TASK_24 were therefore still
reopened, and M1 still lacked measured improvement for P38, P41 and P45.
The current result is recorded separately below; this paragraph preserves
the earlier state rather than rewriting it.

P46 and P52 were seeded but the search solves them unaided; the seeds
were masking less than they appeared to.

Historical gate record (2026-07-22): the original M5 per-directory gates at
`7ea3b07fa` passed with 77 `OK` results in rules, 168 in classical and 193
in blast, and the source-recognition audit was clean.  The first clean
integrated attempt at that revision passed
`bin/build -t --seq=tools/sequences/upto-auto`, but the following explicit
`bin/build -F -t` failed reproducibly in
`src/probability/real_borelTheory` at theorem
`in_borel_measurable_inv`.

The root cause was a general simplifier semantic defect introduced earlier:
supplied global rewrites were installed both statically and per traversal.  A
dynamic-only candidate avoided duplication within one traversal but refreshed
`Once` between assumption and conclusion traversals.  Commit
`65250f8c38f59a46f4350cc33e837b3de2508bf3` (`Preserve global bounded
rewrite lifetimes`) instead decodes supplied bounded rewrites once into
invocation-shared controls, compiles them through marker-adjusted local
simpsets, separates reducer and solver contexts, and preserves marker
semantics and the underlying solver/dproc theorem context.  It includes
failing-first regressions; no probability proof was edited.  It adds no
recognition mechanism and changes no benchmark count or budget.

In a fresh detached worktree at exact `65250f8c3`, fresh configuration passed
with status 0 in 18.17 seconds.  The `upto-auto` gate then passed with status
0 in 9m41.26s and terminal `Hol built successfully.`; explicit
`bin/build -F -t` passed with status 0 in 15m53.50s and the same terminal
message.  The full build reported `real_borelTheory` `OK` in 14 seconds, and
the direct log/signature record saving and exporting
`in_borel_measurable_inv`.

The audited evidence package is
`/tmp/isabelle-tactics-task7f-20260720-root/task16_clean_full_gates_fresh/`.
It retains the original logs and direct probability artifacts; its final
clean rereview manifest, `metadata/evidence-checksums.txt`, has 45 entries,
verifies successfully, and has hash
`a6dde0623911ee486494b341ba9845c928f8fd1787c230b57134c95ae62e916b`.
The integrated `upto-auto` disclosure records expected
`suspFastTheory ... F-CHEAT` and zero `CHEATED` results.  The full-build
disclosure records the intentional pre-existing upstream
`src/num/theories/cv_compute/automation ... CHEATED` result (three
`Saved CHEAT` entries from unchanged source) and zero `F-CHEAT` results.
Both gates passed terminally.  The historical build transcripts did not
independently capture `TMPDIR`, so the empty task `TMPDIR` postflight is
corroboration only.

The main tracked tree and index were clean at `65250f8c3`, and `.agent-files`
remained ignored and untracked.  At that revision M5's gates were complete,
but Phases 1/2 remained incomplete under M1 and the unchanged
TASK_23/TASK_24 criteria.  Those successful gates waived none of those
criteria.  M2's conditional and environment-limited conclusions remain
unchanged; no evidence-selected optimization is claimed retroactively.

#### 8.3.8 Historical final remeasurement at `5bc674569`

The preceding baseline, `7ea3b07fa` result and `65250f8c3` gate record are
historical.  At commit
`5bc6745695a3ac2f48b90c09ecfb2d6f4d785307`, public production
`Tactical.VALID (BLAST_TAC [])` retains the default maximum depth 20 and
30-second `Timeout.apply`.  Baseline `be308c56d` is right-censored at
`>=30s` for every P34/P38/P41/P42/P43/P45 run.  Three exact current
kernel-valid samples are respectively:

- P34: `1.329700`, `1.320911`, `1.316835` seconds;
- P38: `.099931`, `.100237`, `.100036` seconds;
- P41: `.009163`, `.009141`, `.009075` seconds;
- P42: `.010805`, `.010697`, `.010773` seconds;
- P43: `.033935`, `.033627`, `.033786` seconds;
- P45: `3.543755`, `3.530560`, `3.470660` seconds.

Strict interval separation meets M1's measured-improvement criterion on all
six workloads.  No ratio is computed from the censored baseline.  The
reviewed M1 package is in this directory:

```text
/tmp/isabelle-tactics-task7f-20260720-root/task22_m1_final_measurement_fresh/
```

Its final 1,818-entry manifest has
digest
`fa9bc5a1a98be7d09522f1c8d8c2100d18a73e4078987a5314a062784a161571`.
At that revision, the honest suites were 48/48 Pelletier with expected
list `[]`, 9/9 Table 1 with expected list `[]`, and 4/4 sets.

The authoritative wholly fresh v2 gate package is
`/tmp/isabelle-tactics-task7f-20260720-root/task23_final_clean_gates_fresh/`.
Its elapsed seconds are configure 17.79,
prerequisite setup 206.35, rules `Holmake`/selftest 15.54/12.08, classical
`.19`/16.21, blast `.20`/20.69, level-2 blast 141.20, `upto-auto` 244.10,
and explicit full build 989.25.  Both integrated builds have terminal
success.  The final reviewed live seal is 395 entries with digest
`2d66cab8b9db6c8a5e2c345a89c0ca2755b4a4d35cebc45cab9dedb2d507d3bc`;
the inventory is 394 entries with digest
`786c8d9c2f763ee342eaaee8c5f79659be0433013cc00d4f43ccc4445b8b3812`.

Production recognition/shortcut audits, the seed guard and h4pedant are
green, with intentional CHEAT classifications still disclosed.  Evidence
limits are unchanged: no top-level v2 driver was retained, so whole-schedule
enforcement is not independently proven; named wrapper intervals do not
overlap, but unrecorded activity in gaps is not excluded.  Process snapshots
are scoped; copied probability/CHEAT direct artifacts are post-run
corroboration; the full log itself proves `real_borelTheory` `OK`.  The old
first attempt is rejected for `0.497043743` seconds of setup overlap.  No
`/tmp/Holmakefile` nonmutation claim is made.

At that revision TASK_23's unchanged criteria were met, so it was
completed/reclosed.  Halting II remained an asserted expected failure, not
skipped, at depth 7/120 seconds.  TASK_24 therefore remained reopened.
M2 also remained open and environment-limited at that point.  The current
status is recorded separately below.

#### 8.3.9 Final reviewed state at `f4fc8be66`

Reviewed tracked source commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1` centralizes capture-safe
transitive expansion of persistent metavariable bindings.  Whole-term
substitution prevents binder capture, and the final store now feeds
normalization, collapse, goal normalization, blast hypothesis substitution
and exact stored-rule replay.  The change is general: it includes no
problem recognition, answer rewrite or fallback shortcut.

The regressions cover capture, indirect/shared/typed dependencies,
persistent binding semantics, exact intro and elim replay, and all 16
public stored-rule entry points: ordinary, measured, timed v1 through v4,
sink/summary forms, and the selected-major variants.

Candidate 05 is retained solely as historical pre-commit functional
evidence:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task32n_fcheat_disclosed_evidence_fresh/accepted-attempt-05/
```

Its historical manifest SHA-256 is
`95be727c037229af3514a85d2e2f11ea56b76cdf19b84c1aa5e5372c58322d07`.
The package froze the patch against parent
`d90554b5fd14f72527535d1b0085fe6d746ab0a5`; the reviewed commit contains
exactly that patch.

The accepted current committed-state package is attempt-04:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
```

Its frozen 18-command plan has SHA-256
`941435ac994a5dd43534b852c4f9508dce7161c2a0ecc96589fca3a92c403a00`.
All commands exited 0 and the aggregate elapsed time is 1799.992895 s.
Fresh configure, exact `upto-auto`, `upto-parallel`, direct
Rules/Classical, Blast levels 1 and 2, h4pedant, diff/hygiene checks and
the last explicit full build pass.  Both Blast levels record exactly
48/48 unique Pelletier, 9/9 unique Table 1 and 4/4 unique set successes.
Level 2 records exactly one kernel-valid Halting II `OK`.  The Pelletier
and Table-1 expected-failure lists are empty.

The exact `upto-auto` disclosure is one expected, pre-existing
`suspFastTheory ... F-CHEAT`, zero `CHEATED` and zero `Saved CHEAT`.  It
must not be merged with the full-build disclosure: zero `F-CHEAT`, one
intentional pre-existing upstream `cv_compute/automation ... CHEATED`, and
exactly three separately hash-bound `Saved CHEAT` theorem names.  The full
build ended `Hol built successfully.` after 1132.087214 s.

TASK_23 remains completed.  TASK_24 is completed/reclosed because all its
groups now pass.  On 2026-07-23 the owner decided that M2 closes once the
complete benchmark suite and Halting II pass because
`perf_event_paranoid` cannot be lowered.  Those conditions now pass, so M2
is closed.  The unavailable profiler is an environmental disclosure, not a
blocker; no samples or lowered setting are claimed.

M1 is closed under its original explicit acceptance criterion, which
required behaviour preservation and measured improvement on these six
workloads, not a rerun after every later patch.  The verified `5bc674569`
package has a 1,818-entry manifest, six `>=30s` censored baselines, and all
18 exact kernel-valid public-production runs below `3.544s`.  Attempt-04
contains no current-revision performance measurement, so performance at
`f4fc8be66` is not claimed.  That transparent limitation is a non-blocking
follow-up, not a plan blocker.

The semantic audit, exact 32,933-entry tested-tree inventory, exact
47-entry package manifest, post-run identities and independent adversarial
review pass.  `PLAN_phase_1_2_green.md` §6 maps every acceptance criterion
to its evidence.  TASK_27 and the Phases 1/2 Green plan are complete.

### 8.4 Gates

- Task-level: `Holmake` + `./selftest.exe` in the touched directory.
- Slice gates: `bin/build -t --seq=tools/sequences/upto-auto` green at
  every task completion; full `bin/build -F -t` at the Phase-1
  boundary (T9) and the Phase-2 boundary (T-fin), recorded in
  PLAN.md §11's gate record.
- Final phase gate: accepted attempt-04 proves the direct suites,
  `upto-auto`, `upto-parallel`, h4pedant, hygiene and the committed-state
  `bin/build -F -t` at exact `f4fc8be66`.  The final audit is
  `PLAN_phase_1_2_green.md` §6.

## 9. Task breakdown (dependency order)

Phase 1:

- **T1:** `src/auto/classical/` skeleton: Holmakefile, sequence +
  `SRCRELNAMES` entries; `searchHeap`.  Builds empty; heap is
  dependency-free.
- **T2:** `clasetMeta` + tests.  §3.1; store API frozen at review.
- **T3:** `clasetUnify` + golden battery.  §3.2; the riskiest single
  module — tests first (§8.2.1).
- **T4:** `clasetGoal`: goals/nodes, intake, child-shape, render/unrender
  stub.  §3.3 (materialization completed in T11).
- **T5:** `clasetStep`, match mode: safe/clarify cascade, built-ins,
  hyp-subst slot, wrappers.  §3.4; per-step validations (D22).
- **T6:** `classicalLib` slice 1:
  `SAFE_TAC`/`CLARIFY_TAC`/step tactics, markers, D27.  §4.
- **T7:** Phase-1 selftests.  §8.1.
- **T8:** Docfiles (Phase-1 tactics + deferred Phase-0 attribute/marker
  entries).  §4.
- **T9:** **Phase-1 gate**: `bin/build -F -t`; PLAN.md gate record.
  Boundary.

Phase 2:

- **T10:** `clasetStep` unify mode: inst0/instp/unsafe/dup steps, M-c3
  metavariable path.  §3.4.
- **T11:** `clasetReplay`: records, grounding, replay vocabulary; D24
  render/lift-back completed.  §3.5.
- **T12:** `clasetSearch`: DEPTH/BEST/ASTAR/DEEPEN + D25 pruning +
  bounding/trace.  §3.6.
- **T13:** `classicalLib` slice 2: the D26 surface.  §5.
- **T14:** Engine/driver selftests.  §8.2.
- **T15:** `REV_DUP_ELIM_RULE` in `clasetRules` + golden tests.  §6.3,
  §11; additive.
- **T16:** `blastTerm` + unification tests.  §6.1.
- **T17:** Translation + typargs + `blastRule` (incl. pseudo-rules,
  weak-elim warnings).  §6.2–6.3.
- **T18:** `blastSearch` (cascade, penalties, prune, mayUndo, DEEPEN).
  §6.4.
- **T19:** Reconstruction on the engine + engine hyp-subst blast contract.
  §6.5.
- **T20:** `tableauLib` surface + config + `tryIt`.  §6.6.
- **T21:** Pelletier corpus + BLAST selftests.  §8.3.
- **T22:** Docfiles (drivers + BLAST, incl. BBLAST_TAC cross-reference and
  limitations).  §5–6.
- **T-book:** PLAN.md updates: §2 record D21–D27, §6 status, §11 gate
  record.  Bookkeeping.
- **T-fin:** **Phase-2 gate**: `bin/build -F -t`.  Boundary.

Estimated new code: classical ≈ 4.5–5.5 kLoC SML + ≈ 1.5 kLoC tests;
blast ≈ 2.5–3 kLoC + ≈ 1 kLoC tests/corpus.

## 10. Risks and mitigations

1. **The unifier (T3)** — hardest single component (D21).  Unsound
   unification cannot produce false theorems (kernel replay/validations
   are the net); it can lose proofs or break replay.  Mitigation:
   golden battery first, FO-fragment oracle vs `FullUnify`,
   deterministic single-solution heuristics, Pelletier suites as
   capability regressions.
2. **Eigenvariable/allow-set discipline** — an error here makes the
   engine claim proofs replay then refutes (M-e6 hard error).
   Mitigation: the §8.2.2 non-theorem battery is written before the
   drivers; hard-error telemetry keeps violations loud.
3. **Blast reconstruction divergence** (PLAN §12 risk 2) — reduced by
   design: D23 removes untyped back-translation; the front-cons
   convention removes rotation; M-f removes the affectedness
   divergence class.  Remaining: order drift on recursive rules
   (`blast.ML:1134–1137`, carried over, documented).  PROOF FAILED
   telemetry asserted in selftests.
4. **Engine performance** (persistent store vs Isabelle's destructive
   engine) — blast covers the raw-speed niche; drivers are bounded by
   deepening; the D25 pruning recovers the dominant waste.  Benchmarks
   (Table-1 depths + time budgets) catch gross regressions; retuning
   is Phase-8 material.
5. **Step-cascade fidelity** — subtle spots (`bimatch2`, wrapper
   points, `inst0` un-wrapped in depth, candidate dedup) are each
   pinned by a dedicated §8 regression; the single-cascade design
   (D22) means one fix serves both layers.
6. **Freeze-list friction** — the two Phase-0 amendments (§11) are
   minimal and additive/pre-consumer; anything further requires a new
   owner decision.

## 11. Phase-0 freeze-list amendments (sanctioned by D21–D27)

1. **`claset_config.size_of` default corrected** to the
   Isabelle-faithful count (atoms + abstractions;
   `term.ML:467–473`) — the delivered default used kernel
   `Term.term_size` (counts `Comb`s) on the strength of a research
   claim now recorded as an erratum
   (`phase12-hol4-substrate.md` §7.1).  No consumer exists before
   Phase 2, so this is behavior-neutral to the distribution.
2. **`clasetRules` gains `REV_DUP_ELIM_RULE`** (additive export +
   golden tests; §6.3).  All other Phase-0 interfaces remain frozen
   as listed in `PLAN_phase_0.md` §11.

Frozen at Phase-2 completion (changes require an owner decision): the
`clasetMeta` store API (§3.1); `clasetStep`'s step/record types as
consumed by Phase 3 (`nodup` parameterization, wrapper application
points) and Phase 4 (node/forest shape, priority bookkeeping);
`clasetReplay`'s replay-step vocabulary as consumed by blast; the §4/§5
public tactic signatures; `tableauLib`'s surface.  Internals of every
module remain private.
