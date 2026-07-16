# Phase 1–2 substrate research: the HOL4 side

Deep research for planning Phases 1–2 (SAFE_TAC/CLARIFY_TAC, FAST/BEST/
SLOW/DEEPEN over an internal metavariable engine with kernel replay,
BLAST_TAC).  All paths relative to the worktree root
(`/home/lukasz/dev/HOL/worktrees/isabelle-tactics`) unless absolute.
Isabelle sources cited from the in-repo snapshot
`.agent-files/sources/src/`.

Organized by the nine assigned topics.  Non-existence findings are
flagged explicitly with **DOES NOT EXIST**.

---

## 1. Delivered Phase-0 modules (`src/auto/rules/`) — the actual API

Phase 0 is complete (`PLAN_phase_0.md:602–616`); the §11 freeze list
(`PLAN_phase_0.md:591–599`) freezes: `ntactic`/`wrapper` types and
combinator semantics, `rulespec`/`cdelta` schema v1, attribute names,
marker vocabulary, `add_rule`/`export_rule`/`delrule`/`augment_claset`/
`the_claset` signatures, candidate-lookup entry points + ordering
contract, `register_tyinfo_contribution`, `claset_config`.  `decls`
internals and the net implementation are private.

### 1.1 `NTactical` — nondeterministic tactic layer (D13)

Types (`src/auto/rules/NTactical.sig:5–7`, mirrored in
`NTactical.sml:7–9`):

```sml
type nresult = goal list * validation
type ntactic = goal -> nresult seq.seq   (* portableML seq *)
type wrapper = ntactic -> ntactic
```

Exact combinator semantics (all in `src/auto/rules/NTactical.sml`):

- `LIFT tac` (`:11–14`): wraps a plain `tactic` into a one-element
  lazy sequence; a `HOL_ERR` from the tactic becomes `seq.empty`
  (failure = empty sequence).  Only `Feedback.HOL_ERR` is caught.
- `DETERM ntac` (`:16–19`): takes the FIRST result of the sequence and
  returns it as a plain tactic result; empty sequence → `NO_TAC`.
  Alternatives beyond the first are discarded (commit point).
- `NNO_TAC` (`:21`) = `fn _ => seq.empty`; `NALL_TAC` (`:22`) =
  `LIFT ALL_TAC`.
- `NTHEN (t1, t2)` (`:24–47`): full backtracking sequencing — `t2` is
  applied to EVERY subgoal of each `t1` result, and the cross product
  of alternative outcomes across subgoals is enumerated (via
  `seq.bind`); validations are composed with
  `v o Lib.mapshape lengths vs` (`:45`).  All laziness through
  `seq.delay`.
- `NORELSE (t1, t2)` (`:49–54`): committed choice — if `t1` yields at
  least one result, the whole `t1` sequence is used and `t2` is never
  consulted; only if `t1` is empty does `t2` run.  (This is Isabelle's
  `ORELSE` on tactic sequences, not `APPEND`.)
- `NAPPEND (t1, t2)` (`:56–57`): full alternation — `t1`'s results
  followed lazily by `t2`'s (Isabelle's `APPEND`).  The safe/unsafe
  wrapper distinction of D13 is exactly NORELSE- vs NAPPEND-style
  composition.
- `NTRY t` (`:59`) = `NORELSE (t, NALL_TAC)`.
- `NREPEAT t` (`:61`) = `LIFT (REPEAT (DETERM t))` — NOTE: repetition
  is DETERMINISTIC (commits to first alternative each round, single
  result); it is not a backtracking repeat.  Phase 1's `SAFE_TAC`
  repetition gets determinism for free; Phase 2's search must NOT use
  `NREPEAT` where backtracking across iterations is needed.
- `NCHANGED t` (`:63–71`): filters out results that returned exactly
  one subgoal alpha-equal to the input goal (`boolSyntax.goal_eq`);
  0-subgoal or multi-subgoal results always count as "changed".
- `NFIRST` (`:73–74`) folds `NORELSE`; `nEVERY` (`:76–77`) folds
  `NTHEN`.

### 1.2 `clasetNet` — dual-mode discrimination net

Signature (`src/auto/rules/clasetNet.sig:6–12`): `empty`,
`insert {pat, patvars} value`, `match tm net`, `unify {q, qvars} net`,
`vfilter`, `listItems`.

Implementation (`src/auto/rules/clasetNet.sml`):

- Labels `V | Cmb | Lam | Cnst of string * string` (`:23`); one node
  per application (uniform `Cmb` labelling, unlike `Ho_Net` which
  folds argument counts into labels — the header comment `:1–14`
  explains why a separate net was needed and pins `match` to Ho_Net
  semantics).
- Stored patterns: variables in `patvars` and locally bound vars
  become wildcards `V` (`stored_label`, `:42–48`); other free vars get
  a name-prefixed constant label (`fvar_label`, `:35–38`).
- `match tm net` (`:131–137`): stored-side wildcards only — the query
  is rigid; any stored `V` matches a whole query subterm.  Standard
  match-direction net (approximates matching, superset of true
  matches).
- `unify {q, qvars} net` (`:139–150`): ALSO treats the query's own
  free vars in `qvars` as wildcards — when the query walk hits such a
  var, `skip_one` (`:98–107`) steps over one whole stored subterm.
  This approximates full first-order UNIFICATION candidate retrieval,
  the direction Isabelle's `inst_step`/`biresolve` needs for Phase 2.
- Both return candidates in unspecified net order; ordering is imposed
  by the caller (see §1.4).  `vfilter` (`:152–170`) supports deletion
  by predicate on values.

### 1.3 `clasetRules` — canonical form, derived rules, decls, deltas

Key types (`src/auto/rules/clasetRules.sig:7–17` /
`clasetRules.sml:10–20`):

```sml
datatype rulekind = Intro | Elim | Dest
type rulespec = {kind : rulekind, safe : bool, prio : int option}
type tag = {weight : int, index : int}
type brl = bool * thm          (* Isabelle's (is_elim, rule) pair *)
type rl = thm * thm option     (* rule + optional swapped variant *)
type info = {rl : rl, dup_rl : rl}
type canonical = {thm : thm, patvars : term HOLset.set,
                  prems : term list, concl : term}
```

**Canonical form** (`clasetRules.sml:22–88`): `canonical_rule`
converts the outer spine `!xs. P1 /\ P2 ==> ... ==> C` so no premise
on the spine is a top-level conjunction — `curry_conj_premises`
(`:26–39`) currifies via `AND_IMP_INTRO` (as an EQ_MP, kernel-cheap),
recursing under each premise with `undisch`/`DISCH`.  `dest_imp_only`
is used throughout, so `~P` is NOT treated as `P ==> F` (`:22–24`
comment).  `is_canonical` (`:45–53`) short-circuits already-canonical
theorems.  `fresh_forall_vars` (`:59–67`) freshens outer binders that
shadow hypothesis frees so GENL succeeds.  `canonical_form` (`:80–88`)
returns the canonical thm, the outer `!`-vars as `patvars`, the
premise list, and the conclusion.  A premise like `!x. P x ==> q` is
ONE premise — derived rules operate on the outer spine only
(`:109–110` comment).

**Indexing** (`:101–107`): intros index on the conclusion
(`rule_index_of Intro = #concl`); elims/dests index on the FIRST
premise (major premise); missing premise ⇒ "Ill-formed … rule" error.

**The five derived rules** (all pure kernel forward proofs over
`rule_spine`, `:111–120`):

- `MAKE_ELIM_RULE` (`:136–145`): Isabelle's `make_elim` /
  `Tactic.make_elim` analogue — from `!xs. P1 ==> … ==> C` builds
  `!xs r. P1 ==> … ==> (C ==> r) ==> r` (fresh boolean `r`,
  `fresh_bool` `:131–132`).  Turns a Dest rule into an Elim.
- `CLASSICAL_RULE` (`:147–182`): Isabelle's `classical_rule`
  (`.agent-files/sources/src/Pure/drule.ML`) analogue — for an elim
  with variable conclusion `r`, each minor premise not already
  concluding `r` is strengthened to `~r ==> prem`, justified by
  `EXCLUDED_MIDDLE` + `DISJ_CASES`.  No-op if the conclusion is not a
  variable or no premise needs repair (`:158–164`).
- `SWAP_INTRO_RULE` (`:199–220`): the "swapped" intro used for
  contradiction-style elimination from a negated assumption —
  from `!xs. P1 ==> … ==> C` builds
  `!xs r. ~C ==> (~r ==> P1) ==> … ==> r` (via `CCONTR`).  Returns
  `NONE` when the conclusion is negation-headed or unifiable with its
  own negation (`negation_headed`/`is_instance` guards, `:186–205`) —
  Isabelle's `swapify` restriction.
- `DUP_INTRO_RULE` (`:222–233`): γ-duplication for unsafe intros —
  premises lifted to `~C ==> Pi`, conclusion re-derived by `CCONTR`;
  net effect: applying it keeps `~C` available so the intro can be
  re-tried (Isabelle's `dup_intr = th RS classical`).
- `DUP_ELIM_RULE` (`:235–251`): γ-duplication for unsafe elims —
  minor premises lifted to `major ==> premi`, so the major premise
  survives the elimination (Isabelle's `dup_elim`).

**`ext_info spec th`** (`:253–297`) assembles the persisted `info`:
- Intro: `rl = (canonical, SWAP_INTRO_RULE canonical)`; unsafe intros
  also get `dup_rl = (DUP_INTRO_RULE, SWAP_INTRO_RULE dup)`; safe
  rules reuse `rl` as `dup_rl`.
- Elim/Dest: `elim = CLASSICAL_RULE (MAKE_ELIM_RULE th')` for Dest,
  `CLASSICAL_RULE th'` for Elim; `rl = (elim, NONE)` (no swapped
  variant for elims); unsafe get `dup_rl = (DUP_ELIM_RULE elim, NONE)`.
  Premise-less elims are rejected (`:258–260`).

**brl/tag semantics**: `brl = (is_elim, thm)` mirrors Isabelle's
`Bires.rule`.  `subgoals_of (is_elim, th)` (`:301–303`) = #premises,
minus 1 for elims (the major premise is consumed).  `tag.weight` =
subgoal count of the primary rule (set in
`clasetLib.make_rule_decl`, `clasetLib.sml:114–121`); `tag.index` is a
per-net insertion sequence number: decl indices decrease from −1
(`empty_decls`, `:371–372`; `extend_decl` assigns `index = next` and
decrements, `:419–429`), and each decl's net entries use
`2*index + 1` for the primary rule and `2*index` for the swapped rule
(`clasetLib.insert_rl`, `clasetLib.sml:61–78`) — so the swapped
variant sorts immediately BEFORE its parent among same-weight entries,
and more recently added rules sort before older ones (smaller = more
recent since indices go negative).  `compare_tag` (`:310–314`) orders
by weight then index; `candidate_order` (`:316–318`) sorts candidate
lists with it — fewer subgoals first, then recency.  This reproduces
Isabelle's `Bires.tag` ordering.

**Safety classes** (`:299–308`): `safe_class_of` = `NONE` for unsafe,
`Safe0` for safe rules with 0 subgoals, `SafeP` otherwise — the
claset's `safe0`/`safep` net split (Isabelle's `safe0_netpair` /
`safep_netpair`).

**decls** (`:367–459`): keyed by canonical conclusion (`Termtab`) and
by name (`Symtab`); duplicate (same kind+safety for same canonical
thm) adds are warned and ignored (`:398–409`); cross-kind
re-declaration warns but proceeds (`:411–418`); `dest_decls` sorts by
`decl_order` (`:333–351`: safe before unsafe, then Intro < Elim <
Dest, then tag) and `merge_decls` (`:449–459`) replays the incoming
side in `decl_merge_order` (`:353–363`, Bires.decl_merge_ord: intros
first, then decreasing tag = original insertion order) so merged
clasets get fresh decreasing indices in canonical relative order.

**Persistence deltas** (`:461–519`): `cdelta = ADD {name : thname,
spec} | RM string`; encode/decode via `ThyDataSexp` tags
`clasetADD1`/`clasetRM1`; `load_delta` fetches the theorem by kernel
name via `DB.fetch_knm`, warning-and-dropping stale names.

### 1.4 `clasetLib` — claset value, lookup entry points, state,
attributes, markers, config

**Claset value** (`src/auto/rules/clasetLib.sml:18–25`): decls + named
safe/unsafe wrapper alists + FOUR netpairs — `safe0_netpair`,
`safep_netpair`, `unsafe_netpair`, `dup_netpair`, each an
`(intro net, elim net)` pair of `(tag * brl)` entries (`:15–16`).
There is NO `extra_netpair` (confirmed deviation from Isabelle's
claset, recorded in `PLAN_phase_0.md:604–608`).  Unsafe decls are
inserted into BOTH `unsafe_netpair` (with `#rl info`) and
`dup_netpair` (with `#dup_rl info`) (`add_decl`, `:92–112`); safe
decls go to exactly one of safe0/safep by `safe_class_of` (`:98–107`).
Elim-kind entries go in the elim net, intro entries in the intro net;
a SWAPPED intro variant is inserted as an ELIM entry (`insert_rl`,
`:61–78`, note `insert_brl true tag' th'` for the swapped rule) —
matching Isabelle, where swapped intros live on the elim side of the
netpair.

**Candidate lookup entry points** (`:305–326`) — what Phase 1–2
actually calls:

```sml
claset_part : part -> claset -> claset_part   (* netpair accessor *)
match_intro_candidates : claset_part -> term -> (tag * brl) list
match_elim_candidates  : claset_part -> term -> (tag * brl) list
unify_intro_candidates : claset_part -> term -> (tag * brl) list
unify_elim_candidates  : claset_part -> term -> (tag * brl) list
```

- `match_*` uses `clasetNet.match` (stored patvars wild, query rigid)
  — the SAFE-step direction.  Query term: the goal conclusion for
  intros, an assumption for elims.
- `unify_*` uses `clasetNet.unify` with `qvars = FVLset [tm]`
  (`free_var_set`, `:320`) — ALL free variables of the query act as
  unifiable.  This is the `inst_step` direction for the Phase-2
  engine, where engine metavariables appear as free vars in the query.
- ALL four return `candidate_order`-sorted `(tag * brl)` lists:
  ascending weight (subgoal count), then ascending index (most
  recently added first, swapped variant before parent).  This ordering
  is part of the frozen contract.

**Global state** (`:328–590`): one `AncestryData.fullmake` instance,
tag `"claset"` (`:544–553`), with lazy replay (`pending` list until
first `the_claset()` demand — `init_state`, `:524–532`) and batched
theory-load application (`batch_finaliser`, `:540–542`; removal in a
batch triggers full net rebuild, `batch_apply`, `:416–421`).  Public
mutators: `export_rule spec name` (persistent, `:668–675`),
`temp_add_rule` (`:565`), `delrule`/`temp_delrule` (`:677–682`,
`:567–568`), `augment_claset : (claset -> claset) -> unit` (`:570`;
this is how libraries re-establish wrappers at load — wrappers are
closures and never persisted).  Readers: `the_claset ()` (`:561–563`),
`claset_of_theory`, `merge_clasets`, `with_claset` (`:686–690`).

**TypeBase hook** (`:428–590`): `register_tyinfo_contribution`
(`:576–584`) with catch-up + `TypeBase.register_update_fn` listener
(`:586–590`).  Phase 0 registers two contributions: distinctness
(safe elims `c1 x = c2 y ==> r`, both orientations, `:633–647`) and
injectivity (safe dests from one_one via `iff_dest_rule`, `:649–660`).
Contribution rule names are stems like
`__claset_tyinfo_<thy>_<tyop>_distinct_<n>` (`:625–628`).

**Wrappers** (`:244–256`): named alists; `app_safe_wrappers` /
`app_unsafe_wrappers` fold-apply them over an `ntactic` (last-added
applied outermost — `List.foldl` over the alist, `:249–250`).

**Attributes** (`:692–712`): `[intro]/[sintro]/[elim]/[selim]/[dest]/
[sdest]` registered via `ThmAttribute.register_attribute`; arguments
rejected until Phase 4 priorities (`attribute_error`, `:692–695`).

**Per-invocation markers** (`:724–791`): marker constants in theory
`clasetMarker` (`clasetMarkerScript.sml:1–13`); `SIntro …
Dest : thm -> thm` wrap via `markerLib.genCong`; `Del =
markerLib.Excl` (`:749`).  `process_claset_tags thms cs` (`:777–791`)
peels marked theorems off a theorem list, applying adds (with
generated names `__claset_marker_<n>`, `:752–764`) and Del-removals,
returning the augmented claset and the unconsumed theorems — Phase 1
tactics take `thm list` arguments and route them through this.

**Config record** (`:714–720`):

```sml
val claset_config =
  {hyp_subst_tac = BasicProvers.VAR_EQ_TAC,
   size_of = default_goal_size}
```

`default_goal_size` = sum of `Term.term_size` over assumptions +
conclusion (`:714–716`) — the `sizef` seed for BEST_TAC (§7).

### 1.5 Seed theory (`src/auto/rules/clasetSeedScript.sml`)

Declared via `export_rule` on existing bool theorems (`:15–22`):
- safe intros: `EQ_REFL`, `TRUTH`, `IMP_ANTISYM_AX` (iffI analogue),
  `IMP_F` (notI: `(P ==> F) ==> ~P`), `AND_INTRO_THM` (conjI).
- safe elims: `FALSITY` (FalseE), `OR_ELIM_THM` (disjE).
- unsafe intro: `EQ_EXT`.

Proved-in-place seed rules with attributes (`:24–89`), mirroring
Isabelle's default claset (`HOL.thy` / Paulson's rules):
- `DISJ_CINTRO_THM[sintro]` `(~q ==> p) ==> p \/ q` — classical disjI.
- `CONJ_ELIM_THM[selim]` (conjE), `IMP_CELIM_THM[selim]` (impCE),
  `IFF_CELIM_THM[selim]` (iffCE), `EXISTS_ELIM_THM[selim]` (exE),
  `EX1_ELIM_THM[selim]` (ex1E).
- `EXISTS_INTRO_THM[intro]` (exI — unsafe, needs a witness),
  `EX1_INTRO_THM[intro]` (ex1I), `EX_EX1_INTRO_THM[sintro]`.
- `FORALL_ELIM_THM[elim]` (allE — unsafe), and `NOT_ELIM_THM` proved
  but NOT declared (available for Phase 1 contradiction handling).

Notably ABSENT from the seed (Phase 1 must handle these as built-in
steps or add them): no disjI1/disjI2 pair (replaced by the classical
`DISJ_CINTRO_THM`), no impI (`==>`-intro is a built-in safe step via
DISCH in Isabelle's `safe_step` too), no allI (`!`-intro likewise a
built-in via GEN), no notE as declared elim (NOT_ELIM_THM undeclared),
no conjunction-of-conclusion splitting beyond `AND_INTRO_THM`.

### 1.6 Build/deps

`src/auto/rules/Holmakefile:1–11` pins `HOLHEAP = bin/hol.state0`
(pre-boss band); dependency stratification rule: nothing from
`src/simp` (enforced by review, `src/auto/CLAUDE.md:58–64`).
`clasetLib` depends on `src/basicProof` (BasicProvers) and
`src/marker` (markerLib) — both pre-boss.

---

## 2. Unification over HOL terms

Summary verdict first: **a restricted first-order unifier over real
HOL terms exists in two forms** — `Unify` (simp) and `FullUnify`
(src/1) — plus one-sided matchers (`match_term`, `ho_match_term`) and
metis's own-FO-syntax unifier.  **No higher-order unification over HOL
terms exists anywhere in the repo.**  Note the stratification
constraint: `src/auto/rules` (and hence classical/) must not depend on
`src/simp` (`src/auto/CLAUDE.md:58–64`), which rules out `Unify`/
`Satisfy` for the engine and leaves `FullUnify` (src/1) as the
in-bounds unifier.

### 2.1 `src/1/Unify.*` — **DOES NOT EXIST**

There is no `src/1/Unify.sig/.sml`.  The module named `Unify` lives at
`src/simp/src/Unify.{sig,sml}`.

### 2.2 `Unify` (src/simp/src) — restricted FO unification, no types

"First order unification restricted to specified 'scheme' variables"
(`src/simp/src/Unify.sig:1–4`).  API (`Unify.sig:12–22`):
`simp_unify_terms_in_env : term list -> term -> term ->
(term,term)subst -> (term,term)subst`, `simp_unify_terms`,
`deref_tmenv`, `restrict_tmenv`.

- Variable designation is an EXCLUSION list: first argument `consts`
  = rigid vars; every other free var is unifiable
  (`Unify.sml:47–53`).
- Occurs check: yes — `occ`/`bind` fail with "occurs"
  (`Unify.sml:25–33`).
- Types: NOT unified — "these don't do type unification"
  (`Unify.sig:10`); leaves compared by `aconv`, so metavariable types
  must already be correct.
- Lambdas handled by descending with bound vars removed from `consts`
  and env restriction (`Unify.sml:61–67`); comment warns it "assumes
  things have been renamed" (`Unify.sml:39–41`).
- First-order only (COMB/COMB structural recursion,
  `Unify.sml:58–60`).

Callers: `Satisfy` (below), `quantHeuristics`
(`src/quantHeuristics/quantHeuristicsLibBase.sml:2011–2015`), HolSmt
(`src/HolSmt/Library.sml:391`), pattern_matches
(`src/pattern_matches/patternMatchesLib.sml:423`).

### 2.3 `Satisfy` (src/simp/src) — existential witness search

`src/simp/src/Satisfy.sig:40–52`: `type factdb = term list * thm
list`; `satisfy`, `SATISFY : factdb -> term -> thm`, `SATISFY_CONV`,
`SATISFY_TAC`, `add_facts`.  Strips outer existentials, replaces
ex-vars by `genvar`s, unifies conjunct goals against `!`-stripped
facts using `simp_unify_terms_in_env` (`Satisfy.sml:4,27–39,56–68`);
unsolved witnesses default to `mk_select(v,T)` (`Satisfy.sml:63`).
Depth-1 only ("depth-1 prolog unification", `Satisfy.sig:1–8`).
Instructive precedent for witness handling, but simp-band (out of
bounds for `src/auto`) and far weaker than the planned engine.

### 2.4 `FullUnify` (src/1) — the recommended engine unifier

`src/1/FullUnify.{sig,sml}`.  Two-sided first-order unification over
real HOL terms WITH integrated type unification, in an
optmonad-over-environment style:

```sml
val unify_types : hol_type list -> hol_type * hol_type -> unit Env.EM
val unify : hol_type list -> term list -> term * term -> unit Env.EM
val collapse : ((hol_type,hol_type)subst * (term,term)subst) Env.EM
```
(`FullUnify.sig:21–23`.)

- Rigid-variable designation by TWO exclusion lists: `ctys` (rigid
  tyvars) and `ctms` (rigid term vars); everything else is a
  metavariable (`FullUnify.sml:118–121` terms, `:82–84` types).
- Occurs check on both levels: type `Lib.mem ty1 (type_vars ty2)`
  (`:83`); term `free_in tm1 tm2` (`:122–126`).
- Type unification integrated: `unify` first unifies `type_of t1`
  with `type_of t2` (`:145`); COMB nodes unify argument types
  (`:128–130`); header comment (`:8–21`) documents the invariant that
  term bindings respect the induced type instantiation.
- Capture-avoiding under binders (fresh genvar pushed on a bound-var
  list; metavariables may not be bound to bound vars, `:114–116`,
  `:131–137`).
- First-order: heterogeneous shapes fail (`:138`); an applied
  metavariable `F x` is not solved.
- `Env.t` is triangular (`hol_type Symtab.table * term Termtab.table`,
  `FullUnify.sml:22`); `collapse` (`:149–211`) flattens to
  `(tyS, tmS)` ready for `Drule.INST_TY_TERM`.

Existing search client: `src/1/resolve_then.sml:135–137`
(`FullUnify.Env.fromEmpty (FullUnify.unify fixed_tyl fixed_tml (t,
concl th1_ud) >> FullUnify.collapse)`) — i.e. `drule`-family
resolution already uses exactly the pattern the Phase-2 engine needs.
Caveat for the engine: it returns at most ONE unifier (deterministic;
FO unification has unique mgus so this is fine), and it allocates a
fresh env per call — per-node incremental use is by threading `Env.t`
through the monad rather than `fromEmpty` each time.

### 2.5 Matching (one-sided)

- `Term.raw_match : hol_type list -> term set -> term -> term ->
  (tmS * tyS) -> ((tmS * term set) * (tyS * hol_type list))`
  (`src/prekernel/FinalTerm-sig.sml:68–72`; impl
  `src/0/Term.sml:931–932`, worker `RM` `:894–929`).  `tyfixed` =
  rigid tyvars, `tmfixed` = rigid term vars; simultaneous type
  matching via `Type.raw_match_type` (`Term.sml:891,905,919–922`);
  double-bind rejection (`:902–904`); scope-capture rejection
  (`:896–897`).
- `match_terml = norm_subst o raw_match` (`Term.sml:944–945`);
  `match_term = match_terml [] empty_varset` (`:947`).
- `Type.match_type` family: `src/0/Type.sml:272–293`
  (`raw_match_type`, `match_type_restr`, `match_type_in_context`,
  `match_type`).
- Higher-order MATCHING (not unification): `HolKernel.ho_match_term
  : hol_type list -> term set -> term -> term -> tmS * tyS`
  (`src/postkernel/HolKernelDoc.sig:24–31`, impl
  `src/postkernel/HolKernel.sml:759–771` with `term_pmatch`/
  `term_homatch` in the surrounding local block, projection under
  fresh genvars `:698–737`).  Used by Ho_Rewrite
  (`src/1/Ho_Rewrite.sml:177,224–259`), `PAT_ASSUM`
  (`src/1/Tactical.sml:833`), Q, markerLib.  There is no
  `src/1/HoMatch.sml`.

### 2.6 metis FO unifier (own syntax, not HOL terms)

`mlibTerm.term = Var of string | Fn of string * term list`
(`src/metis/mlibTerm.sig:15–17`).  Unification lives in `mlibMatch`
(there is NO `mlibUnify` module): `unify/unifyl/unify_literals`
(`src/metis/mlibMatch.sig:20–24`), occurs check at
`src/metis/mlibMatch.sml:62,69` ("unify: occurs check"), core solve
loop `:64–78`, substitutions from `mlibSubst`
(`src/metis/mlibSubst.sig`).  Untyped; unusable on `Term.term` without
the folMapping translation (§4).

### 2.7 genvar and instantiation utilities

- `Term.genvar : hol_type -> term` (`src/0/Term.sml:312–316`, prefix
  `%%genvar%%`), `genvars` (`:318–321`), `is_genvar` (`:323–324`);
  `variant`/`prim_variant`/`gen_variant` (`:339–354`), `numvariant`
  (`:356–367`).  Standard mint-fresh-metavariable facility; note
  Phase-0 code deliberately uses `variant` (readable names) for rule
  freshening (`clasetRules.sml:59–67`) and `genvar` appears in
  `Satisfy`, `gvarify` (`src/1/Tactic.sml:1138–1147`), FullUnify
  binder descent.
- `Thm.INST : (term,term)subst -> thm -> thm`
  (`src/prekernel/FinalThm-sig.sml:57`); `Thm.INST_TYPE` (`:33`);
  `Drule.INST_TY_TERM (Stm,Sty) = INST Stm o INST_TYPE Sty`
  (`src/1/Drule.sml:1257`; sig `src/1/Drule.sig:79`); `Term.subst`
  (`src/0/Term.sml:589`), `Term.inst` (`:615`).

---

## 3. jrhTactics — HOL-Light-style tactic system

Located at `src/meson/src/jrhTactics.{sig,sml}`.  It is a compact HOL
Light-lineage tactic engine used ONLY by mesonLib, and — the critical
finding — **it has NO metavariable support**.

- Types (`src/meson/src/jrhTactics.sml:5–10`):
  `type Goal = (thm list * term)` (assumptions held as THEOREMS, not
  terms), `type Goalstate = Goal list * validation`,
  `type Tactic = Goal -> Goalstate`,
  `type refinement = Goalstate -> Goalstate`.
  HOL Light's goalstate is `instantiation * goal list * justification`
  — the `instantiation` component (metavariable bindings) was DROPPED
  in this port.
- No `META_EXISTS_TAC` / `X_META_EXISTS_TAC` / `UNIFY_ACCEPT_TAC`
  anywhere in the repo (whole-tree greps return nothing).
- Refinement composition `by` threads validations only
  (`jrhTactics.sml:17–28`); no instantiation is applied at extraction.
- Bridge back to real tactics: `convert : Tactic -> tactic`
  (`jrhTactics.sml:74–78`).
- Sole client: `mesonLib` (`src/meson/src/mesonLib.sml:762–987`,
  e.g. `POLY_ASSUME_TAC : thm list -> jrhTactics.Tactic` at `:877`).
  Nothing else in src/ or examples/ references it.
- Build status: in the core build (`tools/sequences/base-hol:16`
  includes `src/meson/src`).

Assessment: reusable as a small functional tactic-combinator engine
whose goals carry thm-assumptions, but for metavariables it is merely
instructive — the instantiation-carrying goalstate and unifying leaf
tactics would have to be added, i.e. re-deriving what the port
deliberately removed.  The only in-repo metavariable machinery is
metis-internal and first-order (`src/metis/mlibMeson.sml:418–419`,
`mk_mvars`/`mlibSubst` over FO literals).  **No goal-metavariable
tactic system over HOL terms exists in the repo** — consistent with
the plan's §1.3 constraint and `src/auto/CLAUDE.md:65–70`.

---

## 4. Search + replay precedents (mesonLib, metis/mlib, folTools/folMapping)

### 4.1 mesonLib (`src/meson/src/mesonLib.sml`)

- Internal FO representation (`:118–126`): `fol_term = Var of int |
  Fnapp of int * fol_term list`; `fol_atom = int * fol_term list`;
  negation = negated predicate code (`:113–115`, `:217–223`).  Types
  FULLY ERASED; polymorphic constants distinguished because the
  constant store is keyed by `Term.compare` (type-inclusive), so each
  type instance of a constant gets its own integer code
  (`fol_of_const`, `:181–195`).  Polymorphism handled by HOL-level
  pre-instantiation: `POLY_ASSUME_TAC` (`:877–933`) instantiates
  polymorphic lemmas at the types of matching goal constants before
  translation.  Higher-order subterms rejected
  (`fol_of_term`, `:201–209`, "higher order" failure at `:205`).
- Rules from theorems: goal negated by `REFUTE_THEN`
  (`Canon_Port.sml:216–219`, used `mesonLib.sml:985`); HOL-level CNF
  pipeline `PREMESON_CANON_TAC` (`:771–785`) = PRESIMP / DELAMB /
  NNFC / SKOLEM conversions + `ASM_FOL_TAC` arity-uniformization
  (`Canon_Port.sml:86–102`) + prop-CNF (`Canon_Port.sml:201–205`);
  then FO-level contrapositives `mk_contraposes` /
  `fol_of_hol_clauses` (`:625–660`), bucketed per head predicate and
  sorted by hypothesis count (`optimize_rules`, `:666–673`).
  Equality handled by synthesized congruence axioms
  (`create_equality_axioms`, `:794–871`).
- Proof recording: search builds a pure tree `fol_goal = Subgoal of
  fol_atom * fol_goal list * (int * thm) * int * (fol_term * int)
  list` (`:458–462`), assembled in the success continuation (`:531`).
  No kernel inference during search.
- Replay: `meson_to_hol` (`:735–757`) walks the tree bottom-up,
  materializing HOL contrapositives on demand (cached
  `make_hol_contrapos`, `:698–722`) and combining with
  `Drule.MATCH_MP`/`Thm.CONJ`/`HO_PART_MATCH` (`:743–756`).  The
  jrhTactics engine only manages the assumption list around this
  (`PURE_MESON_TAC`, `:964–969`).
- Bounds: iterative deepening in `solve_goal` (`:604–617`) from `min`
  by `step` up to `max` ("solve_goal: Too deep"); per-node depth guard
  (`:521–522`); size budget decremented per expansion (`:480`);
  inference counter (`:479`); continuation cache keyed on
  `(insts,size)` (`:408–419`); divide-and-conquer splitting with
  `skew` (`:545–562`).  Top level: `max_depth = ref 30` (`:994`),
  `ASM_MESON_TAC = GEN_MESON_TAC 0 (!max_depth) 1` (`:995`).  NO
  wall-clock timeout at all.

### 4.2 metis (`src/metis/`) — folTools/folMapping DO exist

- FO syntax: `mlibTerm` (§2.6).  HOL↔FO bridge: `folMapping.sml`
  (term/type/thm translation + proof replay), `folTools.sml`
  (problem assembly, axiom injection, solver driving),
  `metisTools.sml` (entry points, limits, auto-classification).
- **Types-as-terms encoding** (the blast typargs precedent):
  `folMapping.parameters = {higher_order : bool, with_types : bool}`
  (`folMapping.sml:43–49`).  With `with_types = true`, EVERY subterm
  is wrapped `Fn(":", [tm2fol tm, hol_type_to_fol tyV (type_of tm)])`
  (`hol_term_to_fol`, `:488–512`, wrapper at `:493`).  Types reified
  as FO terms by `hol_type_to_fol` (`:456–468`): tyop → `Fn("Thy$Tyop",
  args)` (`:442–445`); tyvar → FO `Var` if in the "floppy" set `tyV`,
  else a nullary constant (`:459–461`).  Floppy tyvars (tagged
  `XXfolXX`, `new_tyvar`/`is_new_tyvar`, `:133–175`) are the dynamic
  typeargs: FO unification instantiates them, and replay lifts them
  back via `fol_type_to_hol` (`:470–473`).  In HO mode applications
  become `Fn("%",[a,b])` and atoms wrapped with `Fn("$",...)`
  (`:499–501,520`); equality special-cased to `Fn("=",...)` and outer
  type tags stripped from atoms in FO mode (`remove_type`, `:127`,
  `:521`).  The prover core tolerates the `":"` tags
  (`mlibClause.sml:313–314,414–415`); the finite-model evaluator maps
  `":"` to `fst` to ignore types (`metisTools.sml:59`).
  Untyped-first strategy: `metisTools` tries `with_types = false` and
  retries WITH types when replay fails with "proof translation error"
  (`trap`, `metisTools.sml:213–221`, used `:303,318`).
- **Proof objects + re-checking**: mlib has an LCF-style FO kernel —
  `mlibKernel.sig:14–28` (`eqtype thm`, inferences Axiom/Refl/Assume/
  Inst/Factor/Resolve/Equality); `mlibThm.proof : thm -> (thm *
  inference') list` reconstructs the annotated DAG
  (`mlibThm.sig:14–29`).  HOL replay is `folMapping.fol_thms_to_hol`
  (`:870–874`) driving `proof_step` (`:699–818`): each FO inference is
  re-run as HOL kernel inference (Inst' → `PINST` `:722–729`;
  Resolve' → `MP (SPEC … RESOLUTION) (CONJ …)` `:742–780`; Equality'
  → path-walk `fol_path_to_hol` `:646–684` + `EQUAL_STEP`
  `:783–815`), with worker lemmas proved once (`:235–261`) and
  literals carried on the HOL hyp list (`:293–324`).  Search is
  untrusted; only the recorded proof is replayed.
- **Rules from theorems / polymorphism**: `folTools.mk_vthm/
  mk_vthm_ty` (`folTools.sml:154–168`) compute generalizable tyvars;
  `build_map` Skolemizes, GSPECs term vars to genvars, records floppy
  tyvars (`:258–291`); `add_thm` → `hol_thm_to_fol` + fresh renaming
  `mlibThm.FRESH_VARS` (`:221–230`); all tyvars freshened on entry
  (`all_new_tyvars`, `folMapping.sml:148–149,344–350`).  Equality/
  combinator/boolean axioms injected on demand
  (`folTools.sml:378–456`).
- Limits: see §9.

---

## 5. Rule-application tactic vocabulary

Core types (`src/1/Abbrev.sml:8–14`): `goal = term list * term`,
`validation = thm list -> thm`, `tactic = goal -> goal list *
validation`, `thm_tactic`, `thm_tactical`, plus `list_tactic` /
`list_validation`.

### 5.1 `MATCH_MP_TAC` (`src/1/Tactic.sml:855–887`)

`thm -> tactic`.  For `|- !xs. A ==> !ys. B`: matches `B` against the
goal FIRST-ORDER (`match_terml`, `:875`), freezing vars shared with
the theorem's hypotheses (`lconsts`, `:861–862`) and hypothesis
tyvars (`:863`); requires a top-level implication (`:868–869`);
quantified vars free in `A` but not `B` become EXISTENTIALLY
quantified in the single new subgoal `?zs. A` (`evs` partition +
`efn`, `:856–873`); goal-side leading `!` stripped and re-generalized
(`GENL vs`, `:874–880`; fails "Generalized var(s)." if a stripped var
got instantiated).  Validation: `MP (DISCH ant gth) o hd` (`:883`).

### 5.2 `irule` / `IRULE_TAC` / `prim_irule`
(`src/1/Tactic.sml:824–914`)

- `prim_irule` (`:824–827`): matches the WHOLE conclusion
  (`match_term`), instantiates theorem + hypotheses (`INST_TT_HYPS`),
  closes the goal and adds the instantiated HYPOTHESES as subgoals
  (`ADD_SGS_TAC`).  No implication handling.
- `irule` (`:898–904`, `IRULE_TAC = irule` `:914`): first
  canonicalizes with `Drule.IRULE_CANON`
  (`src/1/Drule.sml:2229–2247`) — GEN_ALL, move antecedents to hyps,
  regroup hyps sharing variables absent from the conclusion and
  existentially quantify them, reconjoin into one antecedent — then
  `MATCH_MP_TAC` if the canonical conclusion is an implication, else
  `MATCH_ACCEPT_TAC` (`:901–903`).  Handles multi-`==>` rules,
  negated conclusions (via canonization), theorem hypotheses.
  `irule_at pos` (`:905–913`) resolves into an existential via
  `resolve_then` (which is the FullUnify client, §2.4).

### 5.3 `HO_MATCH_MP_TAC` / `ho_match_mp_tac`
(`src/1/Tactic.sml:1055–1084`)

Same shape as MATCH_MP_TAC but matches the consequent HIGHER-ORDER
via `HO_PART_MATCH (snd o dest_imp_only)` (`:1072–1076`);
antecedent-only vars existentially closed with `SIMPLE_CHOOSE`
(`:1064–1066`).  Companions: `HO_BACKCHAIN_TAC` (`:1042–1053`),
`HO_MATCH_ACCEPT_TAC` (`:1029–1036`).

### 5.4 `MATCH_ACCEPT_TAC` (`src/1/Tactic.sml:809–816`)

`REPEAT GEN_TAC` then close the goal with `PART_MATCH Lib.I thm`
(first-order whole-conclusion match, zero subgoals).

### 5.5 drule family (`src/1/Tactic.sml:1276–1316`, engine
`src/1/mp_then.sml:16–78`)

`fun dGEN sel pos k = sel o mp_then pos k` (`:1277`);
`drule = dGEN first_assum (Pos hd) mp_tac` (`:1278`), `dxrule` uses
`first_x_assum` (`:1280`), `rev_*` use `last(_x)_assum`
(`:1279,1281`); `_then` variants take the continuation (`:1284–1288`);
`drule_at`/`match_position` select which antecedent conjunct to
resolve (`:1290–1300`); `drule_all`/`dxrule_all` resolve repeatedly
through all antecedents via `REPEAT_GTCL` (`:1302–1316`).  Selection:
FIRST assumption (front-to-back = most-recent-first) for which the
resolution succeeds; `x` variants REMOVE it, plain variants keep it.
`mp_then` canonicalizes the rule with `MP_CANON (GEN_ALL …)`
(`mp_then.sml:18`) and matches the chosen antecedent against the
assumption (`PART_MATCH'`).

### 5.6 Assumption tacticals (`src/1/Tactical.sml`)

- `find` helper (`:792–794`) recurses over `asl` FRONT-TO-BACK; the
  front is the most recently added assumption (§6).
- `FIRST_ASSUM` (`:796–797`) / `first_assum` (`:800`); `LAST_ASSUM`
  reverses first (`:798–799`).
- `FIRST_X_ASSUM = FIRST_ASSUM o (fn ttac => fn th => UNDISCH_THEN
  (concl th) ttac)` (`:814–823`) — same order, matched assumption
  plucked out (`Lib.pluck (aconv tm)`, `:815–816`).
- `PAT_ASSUM = gen FIRST_ASSUM`, `PAT_X_ASSUM = gen FIRST_X_ASSUM`
  (`:863–864`); `gen` (`:853–861`) filters by HIGHER-ORDER match of
  the pattern with goal/assumption frees fixed
  (`can_match_with_constants`, `:831–851`).  `qpat_x_assum` =
  `Q.PAT_X_ASSUM` (`src/q/QLib.sml:23`, `src/q/Q.sml:333–340`).

### 5.7 `EXISTS_TAC` / `Q.EXISTS_TAC`

`Tactic.sml:333–341`: substitutes the given witness for the bound var,
validation `EXISTS (w, t)`.  `Q.EXISTS_TAC` (`src/q/Q.sml:231–237`)
parses the quotation at the bound variable's type.  `ID_EX_TAC`
(`Tactic.sml:343–345`) uses the bound var itself.

### 5.8 `IMP_RES_TAC` / `RES_TAC` (`src/1/Tactic.sml:980–993`,
`src/1/Thm_cont.sml:461–520`)

`IMP_RES_THEN ttac th`: `RES_CANON` the theorem into
`!vars. ante ==> concl` clauses (`Thm_cont.sml:487–488`), resolve each
clause against EVERY assumption by first-order `MATCH_MP`
(`:462–471`, `match_terml` with hyp vars/tyvars frozen), apply `ttac`
to every resolvent (`:491–501`).  `RES_THEN` does the same with the
goal's own implicative assumptions as rules (`:509–519`).
`IMP_RES_TAC` / `RES_TAC` wrap these with
`REPEAT_GTCL IMP_RES_THEN STRIP_ASSUME_TAC` — TRANSITIVE resolution
to a fixpoint, results stripped and ASSUMED (`Tactic.sml:983–989`);
both fall back to `ALL_TAC` instead of failing.  Known combinatorial
blowup: every rule × every assumption, iterated.

### 5.9 `CCONTR_TAC` / `CONTR_TAC` (`src/1/Tactic.sml:57–94`)

`CONTR_TAC : thm_tactic` (`:57–64`) closes a goal from a falsity
theorem (`CONTR w cth`).  `CCONTR_TAC : tactic` (`:94`) =
`([(mk_neg w :: asl, F)], sing (CCONTR w))` — assume `~w`, goal
becomes `F`.  This is the classical entry step for the Phase-2
engine/blast (goal ↦ refutation of `~w`).

### 5.10 `BasicProvers.VAR_EQ_TAC` — exact semantics, verified

Definition chain:

- `BasicProvers.VAR_EQ_TAC` (`src/basicProof/BasicProvers.sml:849–855`)
  = `ASSUM_TAC VSUBST_TAC var_eq THEN tidy` where
  `ASSUM_TAC f P = first_x_assum (f o assert (P o concl))` (`:843`),
  `var_eq = Tactic.eliminable` (`:842`), and `tidy =
  markerLib.TIDY_ABBREVS` unless trace `"BasicProvers.var_eq_old"` = 1
  (`:845–852`).
- Selection predicate `Tactic.eliminable`
  (`src/1/Tactic.sml:1098–1104`):

  ```sml
  fun eliminable tm =
      let val (lhs,rhs) = dest_eq tm
      in
        aconv lhs rhs orelse
        (is_var lhs andalso not (free_in lhs rhs)) orelse
        (is_var rhs andalso not (free_in rhs lhs))
      end handle HOL_ERR _ => is_bool_atom tm
  ```

  So it accepts: (a) trivial `t = t`; (b) `x = t` with x a var NOT
  free in t (occurs check present); (c) `t = x` symmetrically; (d) a
  boolean atom — `is_bool_atom` (`src/1/boolSyntax.sml:188–190`) means
  a boolean VARIABLE `v` or `~v`.
- Assumption choice: `first_x_assum` scans the assumption list from
  the head (most recent first) and PICKS THE FIRST assumption whose
  conclusion satisfies `eliminable`, removing it from the list.
- Action `Tactic.VSUBST_TAC` (`src/1/Tactic.sml:1127–1131`): if the
  equation is a bool atom or `l !~ r` (`eliminable_eqvar`,
  `:1124–1125`), then `SUBST_ALL_TAC (orient thm)`; a pure `t = t`
  becomes `ALL_TAC` — i.e. the reflexive assumption is simply deleted
  (it was already removed by `first_x_assum`).
- Orientation `Tactic.orient` (`src/1/Tactic.sml:1106–1122`): bool
  atom `v` → `EQT_INTRO` (v = T), `~v` → `EQF_INTRO` (v = F);
  `var = var` → canonical direction by `Term.compare` (if lhs < rhs
  then SYM, so the Term.compare-larger variable is eliminated);
  `var = t` kept as-is; `t = var` → SYM.  The var being eliminated
  always ends on the LHS.
- Substitution scope: `SUBST_ALL_TAC rth = SUBST1_TAC rth THEN
  RULE_ASSUM_TAC (SUBS [rth])` (`src/1/Tactic.sml:462`) — substitutes
  in the CONCLUSION and in ALL remaining assumptions.  The equation
  itself is gone (consumed by `first_x_assum`).

**Comparison with Isabelle `hypsubst.ML` (in-repo snapshot
`.agent-files/sources/src/Provers/hypsubst.ML`), verifying the Phase-0
claim (`PLAN_phase_0.md:455–456`, `PLAN.md:260–262`)**:

Isabelle's `inspect_pair` (`hypsubst.ML:83–104`) accepts an assumption
equation when one side is a Bound/Free variable with (i) an occurs
check `Logic.occs (t', u)` (`:97,101`) and (ii) orientation flag
(reorient when the var is on the right, `:95,103`); `eq_var`
(`:108–123`) walks the premises left-to-right and returns the FIRST
suitable equation; `gen_hyp_subst_tac` (`:144–155`) then substitutes
throughout the subgoal (asm_lr_simp with just that equation) and
deletes the equality (`thin_rl`), restoring assumption order with
`rotate_tac ~k`.

Verdict: the CORE semantics match — first suitable assumption
equation, var-on-either-side with occurs check, orient so the variable
is eliminated, substitute into conclusion + all assumptions, delete
the equation.  Genuine differences to record for Phase 1/blast:

1. **Scan order**: hypsubst scans premises in their given order
   (oldest-first in Isabelle's list); `first_x_assum` scans HOL4's
   assumption list head-first, i.e. MOST-RECENT-first (§6).  Same
   "first hit wins" policy, opposite traversal direction.
2. **Extras in HOL4**: `eliminable` also fires on `t = t` (deletes it)
   and on boolean atoms `v`/`~v` (rewrites v ↦ T/F everywhere).
   hypsubst has neither (Isabelle deletes `x = x` via `thin_refl` in
   its own loop, and bool-atom rewriting is simp's job).
3. **Missing vs hypsubst**: (a) hypsubst's Bound-variable preference
   (`:88–95`) has no HOL4 analogue — HOL4 goals have no loose bounds;
   free variables play the role of Isabelle's parameters, so the Free
   case (`:96–103`) is the right comparison; (b) the `novars`
   schematic-var guards (`:84–85,89,93`) are vacuous in HOL4 (no
   schematic vars in goals); (c) hypsubst's `check_frees`/
   `thin_free_eq_tac` subtleties (`:108–132`) — refusing to substitute
   a Free that occurs in no other premise, or thinning instead — are
   NOT mirrored; VAR_EQ_TAC always substitutes; (d) hypsubst restores
   the assumption position (`rotate_tac (~k)`, `:153`); VAR_EQ_TAC
   changes assumption order (RULE_ASSUM_TAC re-assumes).
4. **Var-var orientation**: hypsubst eliminates the LEFT one
   (`:88–91` Bound case first come); VAR_EQ_TAC eliminates the
   `Term.compare`-larger one (`orient`, `Tactic.sml:1116–1118`) —
   deterministic but a different canonical choice.

So "occurs-check semantics matches hypsubst.ML:83–104"
(`PLAN_phase_0.md:455–456`) is TRUE for the occurs check and
orientation core; the claim should not be read as full behavioral
equality (differences 1–4 above).  For blast's reconstruction
(`PLAN.md §6.3` step 4), difference 1 (scan order) and 3(d)
(assumption-order disturbance) are the ones that can break replay
scripts and must be pinned down in the Phase-2 design.

### 5.11 `VALID` / `VALIDATE` / `GEN_VALIDATE`
(`src/1/Tactical.sml:406–541`)

- `VALID tac` (`:438–446`): runs the tactic, manufactures oracle
  theorems for the subgoals (`masquerade = Thm.mk_oracle_thm
  "ValidityCheck"`, `:408`), applies the validation, and checks via
  `bad_prf` (`:416–425`) that the produced theorem's conclusion is
  alpha-equal to the goal and every hypothesis is (alpha-equal to) an
  original assumption; else fails "Invalid tactic".  This is the
  replay check the selftest guidelines require for tactic tests
  (`src/auto/CLAUDE.md:82–86`), and the model for Phase-2's own
  replay validation.
- `GEN_VALIDATE flag tac` (`:499–513`), `VALIDATE = GEN_VALIDATE
  true` (`:540`): instead of failing on extra hypotheses, turns them
  into ADDITIONAL subgoals discharged by `PROVE_HYP` in the composed
  justification (`:506–512`).  Useful pattern if replay produces
  side conditions.
- List-tactic analogues `VALID_LT` / `GEN_VALIDATE_LT`
  (`:448–465`, `:523–541`).

---

## 6. Assumption manipulation

### 6.1 Ordering: new assumptions go to the FRONT

- `Tactic.ASSUME_TAC` (`src/1/Tactic.sml:106–107`):
  `fn bth => fn (asl, w) => ([(concl bth :: asl, w)],
  sing (PROVE_HYP bth))` — cons.  The HEAD of `asl` is the most
  recent assumption.
- `LAST_ASSUME_TAC` (`:111–112`) appends at the end (`asl @ [t]`).
- `STRIP_ASSUME_TAC` bottoms out in `CHECK_ASSUME_TAC` →
  `ASSUME_TAC`, so stripped components also land at the front
  (`src/1/Tactic.sml:464–469`); note components of a conjunction are
  assumed in order, each consed, so the LAST conjunct ends up
  frontmost.
- `POP_ASSUM` pattern-matches `(a :: asl, w)`
  (`src/1/Tactical.sml:606–608`); `POP_LAST_ASSUM` takes the tail
  element (`:614–620`).

Consequence for blast reconstruction: HOL4's "most recent first" is
the natural LIFO order the tableau wants, but tactics like
`VAR_EQ_TAC` (via `RULE_ASSUM_TAC`) and `STRIP_ASSUME_TAC` reshuffle;
replay scripts must address assumptions by content or re-establish
order explicitly.

### 6.2 Reordering / addressing — what exists

- **No numeric-index assumption addressing exists** and **no
  assumption-rotation tactic exists**: `ROTATE_LT`
  (`src/1/Tactical.sml:291–304`) rotates the GOAL list, not
  assumptions; there is no `rotate_tac` analogue for hypotheses (the
  blast plan's "cheap assumption-reordering tactic", `PLAN.md
  §6.3(4)`, must be written — it is a trivial
  `(asl,w) -> ([(rotated asl, w)], sing I)`-style valid tactic, but
  it does not exist today).
- Dropping: `WEAKEN_TAC : (term -> bool) -> tactic`
  (`src/1/Tactic.sml:793–803`, first assumption satisfying the
  predicate via `Lib.pluck`); idiom `pop_assum kall_tac`
  (`kall_tac = K all_tac`, `src/boss/bossLib.sml:139`).
- Content-based selection: `FIRST(_X)_ASSUM`, `LAST(_X)_ASSUM`,
  `PAT(_X)_ASSUM`, `PRED_ASSUM`, `hdtm(_x)_assum`, `goal_assum`
  (`src/1/Tactical.sml:633–634, 792–874, 926`).
- Labels: markerLib provides labelled assumptions —
  `MK_LABEL`/`L`/`DEST_LABEL` (`src/marker/markerLib.sig:71–76`,
  impl `src/marker/markerLib.sml:375`), `ASSUME_NAMED_TAC` (inserts
  AFTER existing labels rather than plain cons,
  `markerLib.sml:389–396`), `LABEL_ASSUM`/`LABEL_X_ASSUM`/
  `find_labelled_assumption` (`markerLib.sig:79–91`), and
  hide/unhide (`markerLib.sig:97–110`).  A stable-naming substrate if
  the Phase-2 replay wants to address assumptions robustly.

---

## 7. Term size and best-first ingredients

### 7.1 Term size — TWO different functions, mind the shadowing

- Kernel `Term.term_size` (`src/0/Term.sml:997–1008`, sig
  `src/prekernel/FinalTerm-sig.sml:88`): counts EVERY node — `+1` per
  Comb, per Abs, per leaf.
- `HolKernel.term_size` (`src/postkernel/HolKernel.sml:412–431`):
  does NOT count Comb nodes (only leaves and LAMB); the comment says
  "There's no logical significance to this number".  Since most code
  `open HolKernel`, THIS one shadows `Term.term_size` in typical
  scope.  Phase-0's `default_goal_size`
  (`src/auto/rules/clasetLib.sml:714–716`) is written
  `Term.term_size` explicitly — the qualified kernel version, i.e.
  application nodes count.
  **ERRATUM (2026-07-16, verified against `sources/src/Pure/term.ML:
  467–473`)**: this report originally claimed Isabelle's
  `size_of_term` "counts abstractions, applications and leaves —
  matching the KERNEL `Term.term_size` convention".  That is wrong:
  `size_of_term` adds 1 per Abs and per atom and **nothing per
  application** (`add_size (t $ u) n = add_size t (add_size u n)`),
  agreeing with `phase12-classical-search-port.md` §2.6.  Neither
  in-repo `term_size` matches it exactly; the faithful `sizef` is a
  small bespoke count (atoms + abstractions).  `PLAN_phase_1_2.md`
  corrects the `claset_config.size_of` default accordingly (nothing
  consumes it before Phase 2).
- Other precedents: simpLib's `size_of_term`
  (`src/simp/src/Cond_rewr.sml:32–35`, orientation heuristic for
  permutative rewrites, comparisons at `:61,112`); metis
  `mlibTerm.term_size` (`src/metis/mlibTerm.sml:430`).  No term_size
  in boolSyntax or Ho_Rewrite.

### 7.2 Priority queues

- **portableML has NO heap/priority queue** (full listing checked:
  maps/sets only — Redblackmap/set, Table/Symtab/Inttab, PIntMap,
  HOLset; `seq` for lazy sequences; `Uref`).
- The ONLY functional priority queue in the repo is
  `mlibHeap` (`src/metis/mlibHeap.{sig,sml}`): Okasaki leftist heap
  (`mlibHeap.sml:6–30`), signature `empty : ('a*'a->order) -> 'a
  heap`, `add`, `is_empty`, `top`, `remove`, `size`, `app`,
  `to_stream`, `pp` (`mlibHeap.sig:6–21`).  Used as metis's
  set-of-support queue keyed by real-valued clause weight
  (`src/metis/mlibSupport.sml:193,216–217,276,299–301`).  It is built
  in the standard build (`tools/sequences/base-hol:15` includes
  `src/metis`), but it is `mlib`-namespaced and metis-internal by
  intent — AND `src/metis` builds AFTER the pre-boss band, so the
  stratification constraint (`src/auto/CLAUDE.md:58–64`) forbids
  depending on it.  Consequence: **BEST_TAC/aesop need their own
  small leftist heap** (≈40 lines; `mlibHeap.sml` is the obvious
  model) either in `src/auto/` or proposed for `portableML` — an
  owner decision to record in the Phase-2 plan.

---

## 8. Pelletier problems in-repo

- The only FOL benchmark collection is the meson selftest,
  `src/meson/test/selftest.sml` (3440 lines).  It does NOT contain
  Pelletier 1–46; it has a SPARSE HIGH-NUMBERED SUBSET as named vals
  of quoted terms: `P50` (`:60,194`), `P55` Agatha in two variants
  (`:94–106`, `:175–187`), `P47` Steamroller (`:113–130`, driven
  expecting FAILURE via `Mfail`), `P48` (`:137`), `P49` (`:148`,
  `Mfail`), `P51` (`:151`), `P52` (`:155`); `P53`/`P54` commented out
  "Too slow" (`:161–169`); plus `ERIC` (`:67`) and `LOS` (`:81–87`).
- It also contains ~100 TPTP problems ("100 problems selected from
  the TPTP library", banner `:198–311`) as named vals (`BOO003_1`
  etc., `:356,370`), whose comment table cross-references Pelletier
  numbers (e.g. `:259` LCL230-2 = Pelletier 5, `:300–303` SET046-5/
  SET047-5/SYN071-1 = Pelletier 42/43/48).
- Drivers: local `M nm tm` = `require is_result TAC_PROOF (([], tm),
  MESON_TAC[])` and `Mfail` = `require (check_HOL_ERR …)`
  (`src/meson/test/selftest.sml:7–19`), over `testutils`.
- `src/metis/selftest.sml` (116 lines) tests normal-form conversions
  and two failure paths only — no problem sets.
- The literal string "pelletier" appears nowhere else in the repo
  (only `src/auto/CLAUDE.md` and the TPTP comment table).

**Conclusion**: the planned BLAST selftest (Pelletier 1–46, Paulson's
Table 1) **must be authored fresh** — there is no reusable in-repo
encoding of the full set.  The meson selftest's `M`/`Mfail` driver
shape and its P47–P55/TPTP statements are directly reusable as form
and as extra corpus; Paulson's numbering can be cross-checked against
the TPTP table comments above.

---

## 9. Timing, limits, and trace conventions

### 9.1 How existing provers bound effort

- mesonLib: NO wall clock.  Iterative deepening `solve_goal`
  (`src/meson/src/mesonLib.sml:604–617`) from `min` step `step` up to
  `max` ("solve_goal: Too deep"); depth- vs inference-bound selected
  by the `depth` flag (`:90`, applied `:608–609`); `max_depth = ref
  30` (`:994`); `ASM_MESON_TAC = GEN_MESON_TAC 0 (!max_depth) 1`
  (`:995`).
- metis: `type limit = {time : real option, infs : int option}`
  (`src/metis/mlibMeter.sig:12`); `unlimited`/`expired`
  (`mlibMeter.sml:24–26`).  Time is a POLLED CPU timer
  (`Timer.startCPUTimer`/`checkCPUTimer`, `mlibMeter.sml:76–83`;
  `check_meter` `:115–117`), polled every `CHECK_PERIOD = 100`
  inferences (`src/metis/mlibMeson.sml:408–411`; also
  `mlibResolution.sml:266`, `mlibSolver.sml:261,339`).  Default
  unlimited (`metisTools.sml:173`); user-settable global
  `metisTools.limit` ref (`:281,287–288`).  Solver combination is
  cost-sliced: `cost_fn = Time of real | Infs of real`,
  `SLICE : real ref` (`src/metis/mlibSolver.sig:53–62`).
- holyhammer/AI: thread-based wall-clock timeout `smlTimeout`
  (`src/AI/sml_inspection/smlTimeout.sml:11–82`,
  `Thread`/`ConditionVar.waitUntil`/`Thread.interrupt`) — Poly/ML
  only.
- `Portable.realtime` (`src/portableML/Portable.sig:225`,
  `Portable.sml:694–704`) only REPORTS wall time.  Isabelle-imported
  `Timeout.apply` exists at
  `src/portableML/poly/concurrent/Timeout.sml` (Event_Timer + thread
  interrupt) — Poly/ML only; there is NO mosml counterpart
  (`src/portableML/mosml/` has none).

**Constraint**: `src/auto` must stay Moscow-ML-compatible
(`src/auto/CLAUDE.md:55–57` portability rule).  Therefore Phase-2
CANNOT use `smlTimeout`/`Timeout` (Poly/ML threads).  The portable
pattern is the metis one: an inference/node counter plus an optional
polled `Timer` check at expansion points (raise on expiry), and
Isabelle-parity iterative deepening (`DEEPEN`) as the primary bound —
which is also exactly what blast.ML itself does (`DEEPEN (1,20)`,
`.agent-files/sources/src/Provers/blast.ML`).

### 9.2 Trace flags

- API: `Feedback.register_trace : string * int ref * int -> unit`
  (`src/prekernel/Feedback.sig:74`), plus `register_btrace` (`:81`),
  `register_ftrace` (`:79`), `set_trace` (`:87`), scoped
  `Feedback.trace ("name", n) f x` / `with_traces` (`:90–91`).
- Precedents: `register_trace("meson", chatting, 2)`
  (`src/meson/src/mesonLib.sml:108`); simplifier trace
  `register_trace("simplifier", trace_level, 7)`
  (`src/simp/src/Trace.sml:31`); Phase-0 itself registers the btrace
  `"BasicProvers.var_eq_old"` precedent
  (`src/basicProof/BasicProvers.sml:845–848`).
- Convention for Phase 1–2: one `int ref` per tactic family
  registered at load time (e.g. `"blast"`, max level covering the
  PROOF-FAILED diagnostics of `blast.ML:1254–1277`), settable via
  `set_trace`, plus counters printed at higher levels (meson's
  `inform` pattern, `mesonLib.sml:972–980`).

---

## 10. Cross-cutting conclusions for the Phase 1–2 design

1. **Unifier**: use `FullUnify` (src/1, in-bounds for the
   stratification rule) as the engine's unification core; it already
   provides rigid-var exclusion sets, occurs check, integrated type
   unification, and `collapse` output shaped for
   `Drule.INST_TY_TERM`.  `resolve_then` (src/1) shows the intended
   usage.  No HO unification exists; the blast port's documented
   "no higher-order unification in search" limitation carries over
   naturally.
2. **Nothing to reuse for goal metavariables**: jrhTactics dropped
   HOL Light's instantiation component; the engine-internal
   proof-state representation of PLAN §6.2 must be designed fresh
   (as planned).  meson's `fol_goal` recording tree and metis's
   inference-DAG + `folMapping.proof_step` replay are the two
   in-repo blueprints for record-then-replay.
3. **Typargs precedent**: metis's `with_types` `Fn(":", [tm, ty])`
   wrapping with floppy tyvars (`folMapping.sml:456–512`) is the
   proven HOL mechanism for blast's dynamic typargs; the
   untyped-first-retry-typed strategy (`metisTools.sml:213–221`) is
   also worth copying.
4. **Candidate retrieval is done**: Phase-0's `match_*` /`unify_*`
   candidate entry points with the frozen weight-then-recency
   ordering directly implement the netpair queries of
   `classical.ML`'s step tactics and `inst_step`.
5. **Assumption rotation and a shared heap do not exist** — both are
   small new pieces (valid-by-construction rotation tactic; leftist
   heap after `mlibHeap`), to be planned explicitly.
6. **Bounding**: iterative deepening + polled counters (portable);
   no thread timeouts in `src/auto`.
7. **VAR_EQ_TAC matches hypsubst's core** (occurs check,
   orientation, substitute-everywhere, delete equation) with four
   documented deviations (§5.10) — scan direction, t=t/bool-atom
   extras, no thin_free_eq refinements, assumption-order
   disturbance.  Phase 1 can adopt it as `claset_config.hyp_subst_tac`
   as delivered; blast replay must not assume hypsubst-identical
   assumption ordering.
