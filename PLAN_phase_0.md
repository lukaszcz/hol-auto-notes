# Phase 0 implementation plan — rule database and attribute layer (`src/auto/rules/`)

Date: 2026-07-15.  Refines `PLAN.md` §4.  Branch `isabelle-tactics`.

All Isabelle citations resolve against `.agent-files/sources/` (commit
`f7e02b7e1f31`); HOL4 citations against this worktree (HEAD `af5d4a63f`).
Every infrastructure claim below was verified by reading the cited source.

## 0. Owner decisions taken for this phase (2026-07-15)

Asked and decided one-by-one, extending the §2 record of `PLAN.md`:

| # | Decision |
|---|---|
| D11 | **Claset persistence substrate**: one `AncestryData.fullmake` instance (tag `"claset"`) with a rich custom delta type (rule kind, safety, optional priority), own `ThyDataSexp` codec, and the attributes registered explicitly via `ThmAttribute.register_attribute`.  Not `ThmSetData.export_with_ancestry`: its delta type is hard-wired to `ADD(name,thm)/REMOVE(name)` (`src/1/ThmSetData.sig:8`) and its auto-registered attributes reject arguments (`ThmSetData.sml:216–219`), so it cannot carry the kind/priority schema D2 requires nor Isabelle's global canonical declaration order.  `AncestryData` is the exact mechanism `ThmSetData` itself wraps (`src/parse/AncestryData.sig`), so D10's "integration-identical mechanisms" holds. |
| D12 | **D4 revised — HOL4-native attribute syntax** (supersedes the `[intro!]`-style names in D4): plain names declare *unsafe* rules, `s`-prefixed names declare *safe* rules: `[intro] [elim] [dest]` (unsafe), `[sintro] [selim] [sdest]` (safe).  This mirrors the per-invocation marker constructors (`Intro th` / `SIntro th` / …) exactly, needs zero changes to the attribute grammar (`tools/parsing/HolLex:236–237` and `ThmAttribute.legal_attrsyntax`, `src/1/ThmAttribute.sml:86–90`, admit these names as-is), and is judged by strength parity, not resemblance to Isabelle's surface (owner's overarching rule).  Numeric aesop priorities as attribute arguments (`[intro=90]`) are deferred to Phase 4; they will need only an additive lexer tweak (attribute *values* currently must start with a letter, `HolLex:232–234`) — no name changes.  Rule *removal* is HOL4-native too: functions (`delrule`, `temp_delrule`), like `delsimps`; no `[rule del]` attribute. |
| D13 | **Wrapper representation**: Phase 0 defines a layer-level nondeterministic tactic type `ntactic = goal -> (goal list * validation) seq.seq` over `portableML/seq` with `LIFT`/`DETERM` and Isabelle-`Tactical`-semantics combinators; claset wrappers have type `ntactic -> ntactic`.  Safe wrappers compose with first-success choice (`ORELSE`), unsafe wrappers with alternatives-preserving choice (`APPEND`), reproducing `classical.ML:513–574` faithfully.  One wrapper vocabulary serves Phases 1–4. |

## 1. Scope

Phase 0 delivers the shared foundation of D2: the rule database both search
engines and BLAST read.  Concretely:

1. `NTactical` — nondeterministic tactic combinators (D13).
2. `clasetNet` — discrimination net over HOL terms with *match* and *unify*
   lookup modes.
3. `clasetRules` — rule canonical form + the five preprocessing derived
   rules (make-elim, classical repair, swap, dup-intro, dup-elim).
4. `clasetMarkerTheory` — marker constants for the per-invocation modifier
   vocabulary.
5. `clasetLib` — claset values (decls + four netpairs + wrappers),
   combinators, the persistent global claset, the six attributes, marker
   processing, TypeBase hook, printing/introspection.
6. `clasetSeedTheory` — the missing natural-deduction theorems + the
   HOL.thy-parity base declarations.
7. `selftest.sml` + `theory_tests/` — regression suite.
8. Build integration (Holmakefile, sequence entries).

Out of scope (explicitly): step tactics (Phase 1), the search engines
(Phases 2/4), `[iff]`/`[split]`/`[arith]` attributes (Phases 3/S/5), the
`?`-kind and the `extra_netpair` (dropped per PLAN §4 — no structured
`rule` method is planned), Isabelle's per-rule integer *weights* (they
order only the dropped extra netpair; our deltas carry an optional `prio`
field for the aesop engine instead), and the in-memory aesop
discrimination-tree index (Phase 4; only the *persisted schema* must be
right now, see §5.1).

## 2. Directory, build, portability

```
src/auto/rules/
  Holmakefile
  NTactical.{sig,sml}
  clasetNet.{sig,sml}
  clasetRules.{sig,sml}
  clasetMarkerScript.sml
  clasetLib.{sig,sml}
  clasetSeedScript.sml
  selftest.sml
  theory_tests/          -- persistence scenarios (own Holmakefile)
```

- **Dependency stratification** (PLAN §3.3): allowed dependencies are only
  libraries built before `src/boss` in `tools/sequences/base-hol`:
  `portableML` (seq), `src/1` (ThmAttribute, TypeBase, Tactical, Ho_Net if
  needed), `src/parse` (AncestryData, ThyDataSexp), `src/marker`,
  `src/simp/src` (not needed in Phase 0 — do **not** depend on it),
  `src/basicProof` (`VAR_EQ_TAC`, referenced by the config record §7 for
  Phase 1's benefit).  `boolTheory` for the seed script.
- **Build sequence**: add `auto/rules` to `SRCRELNAMES` in
  `src/parallel_builds/core/Holmakefile:4` (default build, exercised by
  `bin/build -F`).  Add a development sequence
  `tools/sequences/upto-auto`:
  ```
  #include sequences/kernel
  #include sequences/core-theories
  src/auto/rules
  ```
  Routine gate during development:
  `bin/build -t --seq=tools/sequences/upto-auto`.
- **Portability**: the entry is not `[poly]`-tagged, so all code must be
  Moscow-ML-compatible SML (no Poly/ML-isms).  `portableML/seq` is shared
  (verified).
- **Namespace**: sigobj is flat; the names `NTactical`, `clasetNet`,
  `clasetRules`, `clasetLib`, `clasetMarker*`, `clasetSeed*` were
  collision-checked against the tree (2026-07-15): all free.  Settype
  `"claset"` and attribute names `intro/sintro/elim/selim/dest/sdest` are
  unclaimed (checked against all `settype =` occurrences and
  `register_attribute` calls).

## 3. `NTactical` — nondeterministic tactics (D13)

Semantics ported from Isabelle `Pure/tactical.ML`; representation over
`portableML/seq` (`src/portableML/seq.sig` — lazy, memoizing; `append` lazy
in both arguments, verified `seq.sml:41–44`).

```sml
type nresult  = goal list * validation
type ntactic  = goal -> nresult seq.seq
type wrapper  = ntactic -> ntactic     (* claset wrapper type *)

val LIFT      : tactic -> ntactic      (* singleton seq; failure = empty *)
val DETERM    : ntactic -> tactic      (* first result; empty = fail *)
val NNO_TAC   : ntactic
val NALL_TAC  : ntactic
val NTHEN     : ntactic * ntactic -> ntactic   (* bind over all subgoals *)
val NORELSE   : ntactic * ntactic -> ntactic   (* t2 iff t1 empty *)
val NAPPEND   : ntactic * ntactic -> ntactic   (* lazy concatenation *)
val NTRY      : ntactic -> ntactic
val NREPEAT   : ntactic -> ntactic             (* REPEAT_DETERM semantics *)
val NCHANGED  : ntactic -> ntactic             (* filter: goal changed *)
val NFIRST    : ntactic list -> ntactic
val nEVERY    : ntactic list -> ntactic
```

Design notes:

- `NTHEN` is the one nontrivial combinator: for each result
  `(gs, v) ∈ t1 g`, enumerate result vectors of `t2` across `gs`
  (sequence-of-lists Cartesian product, lazy, depth-first — Isabelle's
  `Seq.THEN` semantics), composing validations.  Validation composition
  reuses the standard `mapshape`-style plumbing from `Tactical.THEN`
  (`src/1/Tactical.sml`); the composed validation for a chosen vector is a
  plain HOL4 `validation` — soundness is untouched (validations are only
  ever run by the kernel-checked route).
- Backtracking is *within* a `DETERM` boundary only; once `DETERM` picks
  the first result, alternatives are dropped — exactly Isabelle's method
  boundary behavior.
- `seqmonad` (`src/portableML/monads/seqmonad.sig`) is the shape template
  but is not reused directly: its state type has no validation pairing and
  the extra genericity buys nothing here.
- Selftest: algebraic laws (associativity of the choices, `NORELSE` vs
  `NAPPEND` distinguishability under later failure, laziness — a diverging
  second branch never forced when the first suffices), and validity of
  composed validations via `Tactical.VALID` on golden goals.

## 4. `clasetNet` — dual-mode discrimination net

Requirement (from `Pure/bires.ML:289–299`): candidate retrieval uses
Isabelle's `Net.unify_term` — an *over-approximation*; the strict
matching-vs-unification distinction is enforced at rule-application time,
not lookup time.  Verified state of HOL4 nets: `src/0/Net` and
`src/1/Ho_Net` implement only match-mode lookup (stored vars wild, query
vars rigid); no unify-mode lookup over HOL terms exists anywhere
(`mlibTermnet.unify`, `src/metis/mlibTermnet.sml:202–228`, is the only
in-repo implementation of the technique, over metis FO terms).  Phase 1
needs match-mode only (goals carry no pattern variables); Phase 2/blast
need unify-mode.  Both are provided now so the netpair module is stable
across phases.

```sml
type 'a net
val empty      : 'a net
val insert     : {pat : term, patvars : term HOLset.set} * 'a -> 'a net -> 'a net
val match      : term -> 'a net -> 'a list   (* query vars rigid  *)
val unify      : {q : term, qvars : term HOLset.set} -> 'a net -> 'a list
val vfilter    : ('a -> bool) -> 'a net -> 'a net    (* deletion *)
val listItems  : 'a net -> 'a list
```

- Label alphabet and traversal: first-order, Rator-first, as `src/0/Net.sml`
  (`V | Cmb | Lam | Cnst of string * string`); types ignored (sound:
  candidates are always re-checked by real matching/unification by the
  caller).  Insertion treats exactly the `patvars` (the rule's stripped
  outer universals) plus bound variables as wildcards; other frees are
  rigid — the `fvars` discipline of `Ho_Net`/simpLib
  (`src/simp/src/simpLib.sml:74`).
- `unify` walk: at a query position in `qvars`, harvest the whole subnet
  (skip-one-stored-subterm walk, following the structure of
  `mlibTermnet`'s `harvest`); at a stored-`V` edge, skip one query subterm
  as in `match`.  No substitution-consistency tracking (pure
  over-approximation; cheaper and sound).
- Selftest: soundness oracles — for random small term pairs, if `p`
  matches (resp. unifies with) `q` then the entry is retrieved; plus
  fixed regression cases for the Lam/Cmb corner cases.

## 5. Rule model, preprocessing (`clasetRules`)

### 5.1 Kinds, tags, decls, persisted schema

Port of `Pure/bires.ML:80–246` minus the `?` kinds:

```sml
datatype rulekind = Intro | Elim | Dest
type rulespec = {kind : rulekind, safe : bool, prio : int option}
    (* prio: aesop success probability in percent; unsafe rules only;
       carried in the schema from day one (D2), consumed in Phase 4 *)

type tag  = {weight : int, index : int}   (* weight = #new subgoals *)
type brl  = bool * thm                    (* elim-resolution flag, as Bires.rule *)
type rl   = thm * thm option              (* rule + swapped variant *)
type info = {rl : rl, dup_rl : rl}        (* plain form dropped with extra_netpair *)
type decl = {name : string, spec : rulespec, tag : tag, info : info, orig : thm}
```

- `decls` container: rules in canonical order via a decreasing `next`
  counter (`bires.ML:196–243`), keyed by *both* the theorem statement
  (duplicate detection, `Term.compare`-keyed dictionary on the normalized
  concl) and the declaration name (removal by name — our removal surface
  is name-based like `ThmSetData.REMOVE`).
- Candidate ordering: sort retrieved `(tag, brl)` by `(weight, index)`
  ascending — fewer new subgoals first, then later declarations
  (more-negative index) first (`bires.ML:97–110`, `classical.ML:268–273`:
  unswapped at `2k+1`, swapped at `2k`).
- `merge_decls` port (`bires.ML:230–231` with `decl_merge_ord`,
  `bires.ML:187–190`): returns the new decls to replay into the nets, so
  claset merge = incremental net insertion, as `merge_cs`
  (`classical.ML:400–422`).

Persisted delta (D11):

```sml
datatype cdelta = ADD of {name : thname, spec : rulespec} | RM of string
```

Codec via `ThyDataSexp` (`tag_encode "clasetADD1"` / `"clasetRM1"` — the
version suffix lets future schema variants decode with `first [dec1,dec2]`);
the theorem itself is *not* serialized: like `ThmSetData`
(`ThmSetData.sml:56–66`), load looks the name up (`lookup_exn`) and a
failed lookup degrades to a warning + dropped delta; `uptodate_delta`
prunes stale entries.

### 5.2 Canonical rule form

HOL4 rules are ordinary theorems, normalized on entry to

```
|- !x1 ... xk. P1 ==> P2 ==> ... ==> Pn ==> C
```

- outer `!`s stripped (the stripped variables are the net's `patvars`);
- top-level conjunctive premises curried with `AND_IMP_INTRO`
  (`boolTheory`, `boolScript.sml:2283`), recursively along the premise
  spine — the analogue of `flat_rule`/`atomize_prems`
  (`classical.ML:174–175`): net indexing and subgoal counting must see the
  object structure;
- premise-internal `!` and `==>` are left intact (they encode
  eigenvariable conditions and sub-derivations, e.g. `exE`'s
  `!x. P x ==> q` premise);
- intro rules index by `C`; elim/dest rules require `n ≥ 1`
  (`classical.ML:353,363`: premise-free elims are ill-formed) and index by
  the *major premise* `P1`.

### 5.3 The five preprocessing derived rules

Isabelle builds these with meta-level resolution (`RS`/`RSN` with
lifting).  HOL4 has no meta-level; each becomes a *derived rule*
implemented by primitive inference (UNDISCH/DISCH/SPEC/GEN/PROVE_HYP,
`CCONTR`, `EXCLUDED_MIDDLE` case split) — no tactic proofs, so per-rule
cost at declaration/load time is a fixed handful of kernel inferences.
Specifications (input in canonical form §5.2):

1. `MAKE_ELIM_RULE` (dest → elim; `Tactic.make_elim` analogue,
   `bires.ML:149`):
   `|- !xs. P1 ==> … ==> Pn ==> B`  ↦
   `|- !xs r. P1 ==> … ==> Pn ==> (B ==> r) ==> r`  (`r` fresh).
2. `CLASSICAL_RULE` (weak-elim repair, `classical.ML:150–169`): for an
   elim `|- !xs. M ==> Q1 ==> … ==> Qm ==> r` with variable conclusion
   `r`, replace every premise `Qi = ⟦qs⟧ ==> Ci` whose conclusion `Ci` is
   not `r` by `⟦~r; qs⟧ ==> Ci`; return the input unchanged if nothing
   changed (α-equivalence check, as Isabelle's `Thm.equiv_thm` guard).
   Derivation: case split on `r`.
3. `SWAP_INTRO_RULE` (`intr RSN (2, swap)`, `classical.ML:195–201`; swap =
   `¬P ⟹ (¬R ⟹ P) ⟹ R`):
   `|- !xs. A1 ==> … ==> An ==> C`  ↦
   `|- !xs r. ~C ==> (~r ==> A1) ==> … ==> (~r ==> An) ==> r`,
   an elim-form rule (major premise `~C`) applying the intro to a negated
   assumption — the multi-conclusion-sequent simulation.  Returns NONE
   when `C` is itself a negation-headed or variable-headed formula for
   which the swap adds nothing (mirror `maybe_swap_rule`'s single-unifier
   check by testing that `~C` is not an instance of `C`'s pattern class;
   exact guard fixed during implementation against Isabelle's behavior on
   the seed corpus).
4. `DUP_INTRO_RULE` (`dup_intr = th RS classical`, `classical.ML:216`):
   `|- !xs. A1 ==> … ==> An ==> C`  ↦
   `|- !xs. (~C ==> A1) ==> … ==> (~C ==> An) ==> C`
   (γ-retention: the negated conclusion stays available).
5. `DUP_ELIM_RULE` (`dup_elim`, `classical.ML:218–220`): for an elim with
   major premise `M`, add `M` back as a hypothesis of every non-major
   premise, so consuming the assumption does not lose it.

Kind-dispatched assembly = port of `ext_info` (`classical.ML:348–368`):

| declared as | stored `rl` | stored `dup_rl` |
|---|---|---|
| safe intro | flat + maybe-swapped | = rl |
| safe elim/dest | make-elim (dest) + classical-repair, no swap | = rl |
| unsafe intro | flat + maybe-swapped | DUP_INTRO + maybe-swapped |
| unsafe elim/dest | make-elim + classical-repair | DUP_ELIM |

Safe rules route to the `safe0` netpair iff they generate no new subgoals,
else `safep` (`classical.ML:323–327`); unsafe rules go to `unsafe` and (in
dup form) `dup` netpairs (`:329–334`).  Ill-formed inputs (premise-free
elims, un-duplicable intros) get the Isabelle error messages
(`err_thm_illformed`), duplicates a warning + no-op, cross-kind
re-declaration a warning (`classical.ML:286–314`).

Selftest: golden-example checks — e.g. an `injD`-analogue
(`|- inj f ==> f x = f y ==> x = y` over a locally defined `inj`) run
through dest-declaration must produce exactly the repaired elim of
`classical.ML:139–148`; swap/dup outputs for `AND_INTRO_THM`,
`DISJ_CINTRO_THM`, `EXISTS_INTRO_THM` compared against hand-proved
expected theorems.

## 6. `clasetLib` — claset values, state, attributes, markers, hook

### 6.1 The claset value

```sml
datatype claset = CS of {
  decls          : decls,
  safe_wrappers  : (string * wrapper) list,   (* compose: NORELSE *)
  unsafe_wrappers: (string * wrapper) list,   (* compose: NAPPEND *)
  safe0_netpair  : netpair,   safep_netpair : netpair,
  unsafe_netpair : netpair,   dup_netpair   : netpair
}
```

(no `extra_netpair`; the aesop in-memory index is added to this record in
Phase 4 — an internal, non-persisted change).

Value-level API (simpset-ergonomics, D4): `empty_cs`,
`add_rule : rulespec -> string * thm -> claset -> claset` plus convenience
`add_sintros/add_intros/add_selims/…`, `remove_rule : string -> claset ->
claset` (deletes all kinds, all four netpairs, via stored decl tags —
`delete_tagged_rule` port), `merge_cs`, `wrapper` operations
(`add_safe_wrapper`, `add_unsafe_wrapper`, `del_safe_wrapper`,
`del_unsafe_wrapper` — name-keyed alist update, `classical.ML:517–527`),
derived combinators with Isabelle's composition semantics
(`app_safe_wrappers`, `app_unsafe_wrappers` for Phase 1;
`classical.ML:529–530`), and introspection: `rules_of : claset ->
(rulespec * (string * thm)) list` in canonical order, `pp_claset`
(per-kind listing à la `Bires.pretty_decls`), netpair lookup entry points
for the later phases:

```sml
val match_intro_candidates : claset_part -> term(*concl*) -> (tag * brl) list
val match_elim_candidates  : claset_part -> term(*asm*)   -> (tag * brl) list
val unify_intro_candidates : ...    val unify_elim_candidates : ...
```

each returning tag-sorted candidates (§5.1 ordering); `claset_part`
selects safe0/safep/unsafe/dup.

### 6.2 Global state and persistence (D11)

Template: the `srw_ss` state machine (`BasicProvers.sml:1119–1253`),
ported field-for-field:

- `type cstate = claset * bool * pending list` — lazy initialisation: the
  TypeBase catch-up sweep and pending-delta replay run on first
  `the_claset()` demand (`init_state` pattern, `BasicProvers.sml:1141`).
- `AncestryData.fullmake` with `adinfo = {tag = "claset",
  initial_values = [("min", empty state)], apply_delta}`,
  `uptodate_delta` checking theorem liveness, `sexps` = §5.1 codec,
  `globinfo = {apply_to_global, thy_finaliser = SOME batch_finaliser,
  initial_value}` — the finaliser batches a theory's deltas into one
  decls/net extension per loaded theory.
- Public API (names follow the BasicProvers precedent):

```sml
val the_claset        : unit -> claset
val export_rule       : rulespec -> string -> unit     (* persistent; seed scripts *)
val temp_add_rule     : rulespec -> string * thm -> unit
val delrule           : string -> unit                 (* persistent RM *)
val temp_delrule      : string -> unit
val augment_claset    : (claset -> claset) -> unit     (* NOT persisted: wrappers,
                                                          programmatic/tactic rules *)
val claset_of_theory  : {thyname : string} -> claset option   (* DB *)
val merge_clasets     : string list -> claset option
val with_claset       : claset -> ('a -> 'b) -> ('a -> 'b)    (* with_temp_value *)
```

  Wrappers and (later) tactic-valued aesop rules are *not* persisted —
  they are closures; libraries re-establish them at load time via
  `augment_claset`, exactly as simpset dprocs/congprocs work today.

### 6.3 Attributes (D12)

Six calls to `ThmAttribute.register_attribute`
(`src/1/ThmAttribute.sig:15`): `intro`, `sintro`, `elim`, `selim`, `dest`,
`sdest`.  For each: `storedf` = `record_delta (ADD …)` + apply to the
global value; `localf` = apply to the global value only (the `Theorem
foo[intro,local]` path).  Non-empty argument lists raise a clear error
mentioning that priorities arrive in a later phase.  Usage:

```
Theorem MEM_SPLIT[sdest]: ...       (* safe destruction rule *)
Theorem SUBSET_ANTISYM[intro]: ...  (* unsafe introduction rule *)
```

### 6.4 Per-invocation markers

`clasetMarkerScript.sml` defines identity marker constants following
`markerTheory`/`markerLib` exactly (thm-carrying markers via `Cong_def`
pattern — `markerLib.sml:77`; string-carrying via the `Excl_t` tagged-term
pattern, `markerLib.sml:102`):

- `SIntro th`, `Intro th`, `SElim th`, `Elim th`, `SDest th`, `Dest th`
  (thm-carrying), `Del "name"` (string-carrying) — constructors and
  destructors exported from `clasetLib`;
- `process_claset_tags : thm list -> claset -> claset * thm list` — the
  `simpLib.process_tags` analogue (`simpLib.sml:834`): strips the claset
  markers, applies them as temporary claset modifications, and returns the
  remaining theorems untouched (so the same list can then flow into simp
  tag processing; `Cong`/`Excl`/`SF`/`Once` interoperation is preserved by
  construction because unrecognized markers pass through).  Consumed by
  every Phase 1–4 tactic.  `Iff`/`Split` markers are added by their owning
  phases into the same theory/module.

### 6.5 TypeBase hook

Extensible-by-design (later phases add contributions without a second
hook):

```sml
val register_tyinfo_contribution :
    string * (TypeBasePure.tyinfo -> (rulespec * (string * thm)) list) -> unit
```

Phase 0 registers one contribution and installs the plumbing:

- **distinctness** (`TypeBasePure.distinct_of`, option-valued): each
  conjunct `|- ~(C1 xs = C2 ys)` (and its `GSYM`) becomes a safe 0-subgoal
  elim `|- C1 xs = C2 ys ==> r` (notE composition) — closes any goal with
  a constructor-clash assumption;
- **injectivity** (`one_one_of`): `|- C xs = C ys <=> (x1 = y1) /\ …`
  becomes the safe dest `|- C xs = C ys ==> x1 = y1 /\ …` (iffD1
  direction; the conjunction is later split by the Phase 1 safe steps via
  the seeded `CONJ_ELIM_THM`).

Registration path: `TypeBase.register_update_fn (fn tyi => (add tyi; tyi))`
(`src/1/TypeBase.sig:23`; listener pattern of `BasicProvers.sml:1249`);
catch-up sweep over `TypeBase.elts()` inside `init_state` (D10);
non-datatype tyinfos handled with `Lib.total` (accessors raise on them).
Additions are idempotent (statement-keyed dedup, silent) because the hook
refires on theory reload (AncestryData delta replay,
`AncestryData.sml:277–279`).  These are value-level additions, not
persisted deltas — the hook re-derives them in every session, exactly like
`srw_ss`'s datatype simpls.

Refinement note vs PLAN §4: "constructors-as-intros where invertible" and
case-splits are *not* seeded here — invertibility is precisely the `[iff]`
criterion, so constructor handling lands with Phase 3's `[iff]` machinery,
and case-split theorems with Phase S's `[split]` set, both as further
`register_tyinfo_contribution` clients.

### 6.6 Config record (consumed by Phase 1)

The `CLASSICAL_DATA`-functor-argument analogue (`classical.ML:24–36`),
fixed (not per-claset), lives in `clasetLib`:

```sml
val claset_config : {
  hyp_subst_tac : tactic,          (* BasicProvers.VAR_EQ_TAC; occurs-check
                                      semantics matches hypsubst.ML:83-104 *)
  size_of : goal -> int            (* best-first heuristic default, Phase 2 *)
}
```

(`not_elim`/`imp_elim`-style closers are kernel ML rules in HOL4 and are
hard-coded in the Phase 1 step tactics; they need no configuration slot.)

## 7. `clasetSeedScript.sml` — seed theory

Base-logic parity with `HOL.thy:869–904`.  A full audit of the heap
(2026-07-15, DB.match sweep) established which Isabelle base rules exist
as HOL4 theorems.  Existing theorems are declared via
`clasetLib.export_rule`; missing ones are proved here (all are two-to-five
line tactic proofs) with the attribute directly on the `Theorem`.

**Existing theorems, declared by `export_rule`** (all `boolTheory`, lines
in `src/bool/boolScript.sml`):

| Isabelle rule | HOL4 theorem | declaration |
|---|---|---|
| refl | `EQ_REFL` (1154) | sintro |
| TrueI | `TRUTH` (432) | sintro |
| iffI | `IMP_ANTISYM_AX` (471; a proved thm) | sintro |
| notI | `IMP_F` (843) | sintro |
| conjI | `AND_INTRO_THM` (694) | sintro |
| FalseE | `FALSITY` (495) | selim |
| disjE | `OR_ELIM_THM` (820) | selim |
| ext | `EQ_EXT` (1188) | intro (unsafe) |

**Proved fresh** (verified absent from the default heap), with proposed
names and statements:

| name | statement | declaration |
|---|---|---|
| `DISJ_CINTRO_THM` | `!p q. (~q ==> p) ==> p \/ q` | sintro (classical disjCI — avoids quantifier duplication) |
| `CONJ_ELIM_THM` | `!p q r. p /\ q ==> (p ==> q ==> r) ==> r` | selim |
| `IMP_CELIM_THM` | `!p q r. (p ==> q) ==> (~p ==> r) ==> (q ==> r) ==> r` | selim (classical impCE) |
| `IFF_CELIM_THM` | `!p q r. (p <=> q) ==> (p ==> q ==> r) ==> (~p ==> ~q ==> r) ==> r` | selim (classical iffCE) |
| `EXISTS_ELIM_THM` | `!P q. (?x. P x) ==> (!x. P x ==> q) ==> q` | selim |
| `EX1_ELIM_THM` | `!P r. (?!x. P x) ==> (!x. P x /\ (!y z. P y /\ P z ==> y = z) ==> r) ==> r` | selim (alt_ex1E) |
| `EXISTS_INTRO_THM` | `!P x. P x ==> ?y. P y` | intro |
| `EX1_INTRO_THM` | `!P a. P a ==> (!x. P x ==> x = a) ==> ?!x. P x` | intro |
| `EX_EX1_INTRO_THM` | `!P. (?x. P x) ==> (!x y. P x /\ P y ==> x = y) ==> ?!x. P x` | sintro (ex_ex1I) |
| `FORALL_ELIM_THM` | `!P x r. (!y. P y) ==> (P x ==> r) ==> r` | elim (unsafe allE) |
| `NOT_ELIM_THM` | `!p r. ~p ==> p ==> r` | (support; used by preprocessing/tests, not declared) |

Isabelle's `impI`/`allI`/`exE`-eigenvariable handling are meta-level
mediation rules with no HOL4 theorem counterpart (kernel rules
`DISCH`/`GEN`/`CHOOSE`); goal-directed implication/universal introduction
are *built-in safe steps* of the Phase 1 step tactics.  This is a
faithful-semantics translation, not a gap: the theorem-backed part of the
claset covers exactly what Isabelle's netpairs cover, and the built-in
steps cover what Isabelle gets from meta-level resolution against
`impI`/`allI`.  `EXISTS_ELIM_THM`'s `!x.`-premise reproduces exE's
eigenvariable condition: applying it leaves a `!x. P x ==> q` subgoal
whose `GEN` step is again a built-in.

The seed theory also hosts nothing else: further per-theory corpora
(`pair`, `list`, `pred_set`, …) are Phase 8 (PLAN §11), and adding them
here would violate the stratification (§2).

## 8. Selftest and theory tests

`selftest.sml` (via `testutils`), grouped:

1. NTactical laws + validation validity (§3).
2. clasetNet match/unify soundness + ordering regressions (§4).
3. Preprocessing golden examples (§5.3), incl. rejection cases
   (premise-free elim errors, duplicate warnings).
4. Netpair routing: safe 0-subgoal vs branching classification; candidate
   order = (fewest-subgoals, recency) on a crafted 6-rule claset;
   swapped-variant retrieval on negated-assumption queries.
5. Claset value ops: add/remove/merge with canonical-order preservation
   (merge two clasets built in different orders; compare `rules_of`).
6. Attributes + markers: `Theorem foo[sintro]`-style declarations through
   `Theory`/`ThmAttribute` machinery in-process; `process_claset_tags`
   pass-through of `Cong`/`Excl` markers.
7. TypeBase hook: define a small datatype in-process, check
   distinct/inject rules appear; check catch-up on pre-existing types.

`theory_tests/` (own Holmakefile, modeled on `src/boss/theory_tests`):

- `declAScript.sml` declares rules (attribute + `export_rule` + `delrule`);
  `declBScript.sml` (child) checks `the_claset()` contents after load;
- diamond merge: two siblings extend/remove independently; a common child
  checks the ancestry-merged result (delta streams, not final values —
  the sibling-removal scenario of `AncestryData.sig:72–78`);
- reload idempotence: `Holmake` twice; hook refiring must not duplicate.

Gate for every task below: `bin/build -t --seq=tools/sequences/upto-auto`
green; full `bin/build -F -t` at phase completion (PLAN §11).

## 9. Task breakdown (dependency order)

| # | task | notes |
|---|---|---|
| T1 | `src/auto/rules/Holmakefile`, `tools/sequences/upto-auto`, `SRCRELNAMES` entry | skeleton builds empty |
| T2 | `clasetMarkerScript.sml` | no deps |
| T3 | `NTactical` + tests | §3 |
| T4 | `clasetNet` + tests | §4 |
| T5 | `clasetRules`: canonical form + 5 derived rules + tests | §5; the riskiest kernel-level code — golden tests first |
| T6 | `clasetLib` part 1: decls, netpairs, claset value + combinators | §6.1 |
| T7 | `clasetLib` part 2: AncestryData instance, attributes, API | §6.2–6.3 |
| T8 | markers + `process_claset_tags` | §6.4 |
| T9 | TypeBase hook + contribution registry | §6.5 |
| T10 | `clasetSeedScript.sml` | §7 |
| T11 | `theory_tests/` | §8 |
| T12 | `PLAN.md` §2/§4/§11 record updates + docs (`help/Docfiles` entries deferred to Phase 1 when tactics exist) | bookkeeping |

Estimated new code: ~2.5–3 kLoC SML + ~1 kLoC tests.

## 10. Phase-0-specific risks

1. **Derived-rule generality** (T5): rules whose premises contain nested
   quantifiers/implications stress `SWAP_INTRO_RULE`/`DUP_INTRO_RULE`
   (premise lifting under `~C`/`~r` must respect premise-internal
   binders).  Mitigation: implement on the canonical spine only (never
   descend into premises), golden tests over the seed corpus + every
   TypeBase-generated rule shape.
2. **Net wildcard discipline**: wrong `patvars` handling silently loses
   candidates (incompleteness invisible until Phase 1/2 tactics fail).
   Mitigation: the §4 soundness oracle tests; `match`/`unify` results
   cross-checked against brute-force list filtering on the seed claset.
3. **Load-time cost**: preprocessing re-runs per session per rule.
   Bounded: fixed primitive-inference count per rule, lazy init, per-theory
   batch finaliser; measure in selftest (fail if seed-claset init exceeds
   a generous budget).
4. **Schema evolution**: Phase 4 metadata beyond `prio` (builders,
   patterns, rule sets).  Mitigated by the versioned codec tags (§5.1) —
   new variants decode alongside v1; v1 deltas never break.
5. **Canonical-order merge fidelity**: subtle (`decl_merge_ord` reverses
   index order per kind-class).  Mitigated by test 5 in §8 replicating
   Bires merge scenarios.

## 11. Interfaces later phases rely on (freeze list)

Frozen at Phase 0 completion (changes require an owner decision):
`ntactic`/`wrapper` types and combinator semantics; `rulespec`/`cdelta`
schema (v1); attribute names; marker vocabulary; `add_rule`/`export_rule`/
`delrule`/`augment_claset`/`the_claset` signatures; candidate-lookup entry
points + ordering contract; `register_tyinfo_contribution`;
`claset_config`.  Everything else (`decls` internals, net implementation)
is private to `src/auto/rules`.

## 12. Completion notes (2026-07-15)

Phase 0 is complete.  The task completion log records no unplanned semantic
changes.  The agreed refinements are: the original parent-plan sketch's
`extra_netpair` is absent (the delivered claset has `safe0`, `safep`,
`unsafe`, and `dup`); the aesop in-memory index, builder metadata, and
tactic-valued rules are deferred to Phase 4, while v1 persists optional
`prio` only.  D12 superseded the original attribute spelling with the six
HOL4-native names `intro`/`sintro`, `elim`/`selim`, and `dest`/`sdest`;
removal is function-based.  The TypeBase hook deliberately seeds only
distinctness and injectivity; constructor intros and case splits remain for
Phase 3's `[iff]` and Phase S's `[split]` work respectively.

No `help/Docfiles` entries were added: they are deferred to Phase 1, when
user-facing tactics exist.  The §11 interface list is frozen as of
2026-07-15; changes require an owner decision.
