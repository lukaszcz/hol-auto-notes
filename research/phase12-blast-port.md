# Phase 2 BLAST_TAC: port design report for `Provers/blast.ML`

> Research report, 2026-07-16.  Input to the Phase 2 implementation plan
> (PLAN.md §6.3, decision D3: faithful port of Paulson's untyped tableau
> prover with tactic-script reconstruction, reading the Phase-0 claset).
>
> Primary sources, read line-by-line and in full:
> `../sources/src/Provers/blast.ML` (1321 lines, cited as `blast.ML:n`),
> `../sources/src/Provers/hypsubst.ML` (306 lines),
> `../sources/src/HOL/HOL.thy` (BLAST_DATA instantiation at 923–935),
> L. C. Paulson, *A Generic Tableau Prover and its Integration with
> Isabelle*, J.UCS 5(3) 1999 (`../papers/paulson1999-blast.txt`, cited
> by §/page).  Supporting: `../sources/src/Provers/classical.ML`,
> `../sources/src/Pure/bires.ML`, `research/isabelle-classical-reasoner.md`
> §3, `PLAN_phase_0.md` §5–6, and the delivered Phase-0 code under
> `src/auto/rules/` (HEAD `7dfd21f4f`).
>
> Convention: "prototerm" = blast's internal `term` datatype; "Var" =
> a prototerm unification variable (`term option ref`); "HOL4 term" =
> a kernel term.  §8 collects every genuine design choice; nothing in
> this report decides them.

---

## 1. BLAST_DATA and every external dependency of the functor

### 1.1 The functor signature (blast.ML:38–47)

```sml
signature BLAST_DATA =
sig
  structure Classical: CLASSICAL
  val Trueprop_const: string * typ
  val equality_name: string
  val not_name: string
  val notE: thm           (* [| ~P;  P |] ==> R *)
  val ccontr: thm
  val hyp_subst_tac: Proof.context -> bool -> int -> tactic
end;
```

HOL instantiates it at HOL.thy:923–935:

| field | HOL value | statement / definition | used in blast at |
|---|---|---|---|
| `Classical` | the HOL `Classical` structure (HOL.thy:840–852) | claset access | netpairs 936–937; `dup_intr` 546; `cla_modifiers` 1316 |
| `Trueprop_const` | `dest_Const ⟨Trueprop⟩` (HOL.thy:927) | the object-truth judgment | `mk_Trueprop` 174 (net queries 572, 578), `strip_Trueprop` 176–177 |
| `equality_name` | `"HOL.eq"` (HOL.thy:928) | | `dest_eq` 740–743 (equality substitution) |
| `not_name` | `"HOL.Not"` (HOL.thy:929) | | `negate` 162, `isNot` 164, `delete_concl` 445, `addLit` 880–888, `match` 906–907 |
| `notE` | HOL.thy:399 `⟦¬P; P⟧ ⟹ R` | | `contr_tac` 798–799, trace label 805 |
| `ccontr` | HOL.thy:562 `ccontr = FalseE [THEN classical]`, i.e. `(¬P ⟹ False) ⟹ P` | | `negOfGoal_tac` 640–641 |
| `hyp_subst_tac` | `Hypsubst.blast_hyp_subst_tac` (HOL.thy:932; hypsubst.ML:266–282) | equality-assumption substitution with affected-hyps-to-front reordering | recorded as replay tactic at 1036 |

From `Classical`, blast uses exactly: `safe0_netpair_of`,
`safep_netpair_of` (blast.ML:936, classical.ML:478–479),
`unsafe_netpair_of` (blast.ML:937, classical.ML:480), `dup_intr`
(blast.ML:546; classical.ML:216 `dup_intr th = zero_var_indexes (th RS
Data.classical)`), and `cla_modifiers` (method setup, blast.ML:1316).
Blast never reads `dup_netpair` or the wrappers — dup forms are derived
on the fly from the plain rule (see §4.5), wrappers are ignored by
design (blast.ML:16).

Pure-level dependencies (the "hidden" part of the interface):
`revcut_rl` + `Thm.assumption` (rev_dup_elim, 467), `Thm.rotate_rule`
(rot_tac 479 — the primitive Paulson added for reconstruction, paper
§8.2 p.11), `rotate_tac` (641), `eresolve_tac`/`ematch_tac`/
`resolve_tac`/`match_tac` (494–498), `eq_assume_tac`/`assume_tac`
(799, 806), `Object_Logic.atomize_prems_tac` (1281, 1290),
`SELECT_GOAL` (1280, 1289), `DEEPEN` (1291), `Net.unify_term` +
`Bires.tag_order` (573–580; bires.ML:106 sorts by (weight, index)
ascending), `Sign.const_typargs` (195), `Sign.const_instance` (607,
tracing only), `Name.variant` (gensym, 133–134), `Variable.names_of`
(125), the configs `blast_depth_limit` (=20), `blast_trace`,
`blast_stats` (79–81), and the reserved-constant check that the theory
must not declare constants named `*Goal*` or `*False*` (113–121).

### 1.2 The HOL4 analogue of each field

| Isabelle field | HOL4 analogue |
|---|---|
| `Classical` netpairs | `clasetLib.the_claset()` + `unify_intro_candidates` / `unify_elim_candidates` over `safe0_part`/`safep_part`/`unsafe_part` (clasetLib.sig:47–55; the lookups exist since Phase 0, clasetLib.sml:315–326).  Candidate ordering contract = `candidate_order` (weight, then index) matches `Bires.tag_order`. |
| `Trueprop_const` | **vanishes**.  HOL4 has no meta/object split; branch formulas and net keys are plain boolean terms.  `strip_Trueprop` = identity; the `mk_Trueprop` wrapping before net queries (572, 578) is dropped. |
| `equality_name` | `{Thy="min", Name="="}`; prototerm constant name e.g. `"min$="`.  Fully-qualified names avoid theory ambiguity (HOL4 constant names are only unique per theory). |
| `not_name` | `{Thy="bool", Name="~"}`. |
| `notE` | `NOT_ELIM_THM : !p r. ~p ==> p ==> r` (already specified as a Phase-0 support theorem, PLAN_phase_0.md §7) — used only to build the replay contradiction-closer (§6.2). |
| `ccontr` | kernel `Thm.CCONTR` / `Tactic.CCONTR_TAC` semantics: goal `(asl, G)` ↦ `(asl ∪ {~G}, F)`.  Used by the `negOfGoal_tac` analogue (§6.2); position of the new assumption must satisfy the ordering invariant (§6.4, design choice §8-D). |
| `hyp_subst_tac` | a reordering variant of `BasicProvers.VAR_EQ_TAC` (see §6.5); the plain `VAR_EQ_TAC` does not reorder and does not satisfy `blast_hyp_subst_tac`'s contract. |
| `dup_intr` | `clasetRules.DUP_INTRO_RULE` — but note this arm is dead code in blast's current flow (§4.4). |
| `rev_dup_elim` | a **new** derived rule `REV_DUP_ELIM_RULE` (§4.5): Phase-0's `DUP_ELIM_RULE` is the `dup_elim` analogue, *not* the rev variant blast needs. |
| `Thm.rotate_rule` / `rotate_tac` | an assumption-list rotation tactic.  In HOL4 this is pure bookkeeping on `asl` — a validation that re-orders nothing kernel-visible (a theorem's hyp set is unordered), so it is cheaper than Isabelle's primitive.  It must exist as a real tactic so the recorded script composes. |
| `atomize_prems_tac` | vacuous for assumptions (no meta-level).  The Phase-0 canonical-form currying (`AND_IMP_INTRO`) plays the corresponding role on *rules*, at declaration time. |
| `DEEPEN` | a simple iterative-deepening driver (bounded retry loop); HOL4 has none at `Tactical` level (PLAN §1.2 item 6) — small local code. |
| configs | `Feedback.register_btrace`-style trace flags plus a depth-limit reference (default 20). |
| reserved consts | check at `BLAST_TAC` entry that no ancestor theory declares constants with the chosen reserved names, or (simpler) choose internal names outside the legal constant namespace and skip the check — design choice §8-K. |

---

## 2. The internal term language, translation, normalization, unification

### 2.1 The datatype (blast.ML:84–91)

```sml
datatype term =
    Const  of string * term list  (*typargs constant--as a term!*)
  | Skolem of string * term option Unsynchronized.ref list
  | Free   of string
  | Var    of term option Unsynchronized.ref
  | Bound  of int
  | Abs    of string*term
  | op $   of term*term;
```

- `Var` is a **destructive** unification variable: `ref NONE` =
  unassigned, `ref (SOME t)` = instantiated.  All traversals chase
  assignments (`aconv` 202–204, `norm` 293, `wkNorm` 302–304,
  `add_term_vars` 229–230, …).  Identity is ref-equality (204).
- `Skolem (name, args)`: a Skolem *function application*, args being
  precisely a list of Var **refs** (not terms).  The args record which
  branch variables the Skolem term may depend on; they are consulted by
  the occurs check (`varOccur` 332: `occ lev (Skolem(_,args)) = occL lev
  (map Var args)`) and by the substitution-safety check (`substOccur`
  726–731).  `norm` prunes assigned refs out of the arg list
  (290: `Skolem (a, vars_in_vars args)`).
- `Free`: a rigid name — Isabelle Frees and TFrees (185–186).
- `Bound`: de Bruijn index (paper §7 p.8).  `incr_bv`/`incr_boundvars`
  (254–263), `loose_bnos` (266–275), `subst_bound` (277–285) are the
  standard de Bruijn kit, copied in miniature.
- `Abs (name, body)`: name is decoration only.
- `Const (name, typargs)`: §3.

`aconv` (198–211): alpha-conv chasing instantiations; `Skolem(a,_)
aconv Skolem(b,_) = a=b` — "arglists must then be equal" (200) because
Skolem names are gensym-fresh.  Unassigned Vars compare by ref (204).

### 2.2 Translation: fromType / fromConst / fromTerm

`fromType alist` (185–192): an Isabelle type becomes a prototerm —
`Type(a,Ts)` ↦ `Const(a,[]) $ … $` (curried via `list_comb`),
`TFree a` ↦ `Free a`, `TVar ixn` ↦ a Var ref shared through the
mutable `alist` so equal TVars map to the *same* ref ("We need to
unify the TVars faithfully in order to track overloading", 183–184).
`fromConst thy alist (a, T) = Const (a, map (fromType alist)
(Sign.const_typargs thy (a, T)))` (194–195): §3.

`fromTerm thy t` (386–405) — used for **rules** (via `Thm.prop_of`,
507, 544) and by the debug goal reader (1301).  Per call it allocates
fresh `alistVar`/`alistTVar`, so every rule conversion gets fresh Vars
(the Prolog-style clause-copying; freshness per *application* comes
from `netMkRules` re-converting per node, §4.1).  Cases: Const ↦
`fromConst`; Free ↦ `Free`; Bound ↦ `Bound`; `Var (ixn,_)` ↦ shared
fresh ref via alistVar (392–397); `Abs (a,_,u)` ↦ translate the body
and **eta-contract** if it has the shape `f $ Bound 0` with `Bound 0`
not loose in `f` (398–403); application ↦ `$`.

### 2.3 Translation of the goal: fromSubgoal / skoSubgoal (1205–1248)

`fromSubgoal` translates one Isabelle subgoal
`⋀params. A1 ⟹ … ⟹ An ⟹ C`:

1. `discard_foralls` (1192–1193) strips the outer `⋀params`, leaving
   loose Bounds referring to them.
2. `from lev t` walks the term.  The head cases mirror `fromTerm`,
   with two extra restrictions on schematic Vars in the proof state:
   - Every argument of a function Var must be a bound variable
     (`bounds`, 1213–1219), else
     `raise TRANS "Function unknown's argument not a bound variable"`
     (or "… not a parameter" if bound too deep, 1215–1216).  A Var is
     recorded in `alistVar` as `(ix, (ref NONE, is))` where `is` is
     the list of parameter indices it was applied to (1226–1229);
     a second occurrence with a *different* argument list raises
     `TRANS "Discrepancy among occurrences of ?x"` (1230–1233).
     The Var *application* collapses to just `Var ref` — the bound
     arguments are erased from the term and remembered only in `is`.
   - An `Abs` applied to arguments raises
     `TRANS "argument not in normal form"` (1234–1236).
3. `skoSubgoal i t` (1241–1246): for each of the `npars` parameters,
   substitute `Skolem (gensym "T", getVars (!alistVar) i)` for the
   corresponding loose Bound.  `getVars alist i` (1197–1200) returns
   the Vars that were **not** applied to parameter `i` — i.e. the
   Skolem term for a parameter depends exactly on those unknowns that
   are *forbidden* from mentioning it.  This encodes the eigenvariable
   condition: `varOccur v (Skolem(_,args))` is true iff `v` is (or is
   instantiated to something containing) one of `args`, so unifying
   `?v := …sko…` is *rejected by the occurs check* precisely when the
   proof state said `?v` may not depend on that parameter.

**HOL4 mapping.**  HOL4 goals contain no schematic variables, so at
goal-translation time `alistVar` is always empty: the Var cases and
all three TRANS errors are vacuous, and every "parameter" Skolem has
an empty dependency list, i.e. is a Skolem constant.  HOL4 goals also
have no `⋀params` — their role is played by the goal's free variables.
So the HOL4 `fromSubgoal` is simply: translate `w` and each member of
`asl` with frees ↦ `Free` (equivalently `Skolem(name,[])`; the two are
interchangeable for closed goals — design choice §8-E), constants ↦
`Const` with typargs (§3), λ ↦ `Abs` with the same eta-contraction,
type variables of the goal ↦ `Free` (rigid).  The initial branch is
`initBranch (mkGoal concl :: hyps, lim)` (blast.ML:1274, 1179–1184)
with every formula flagged `md = true`.

### 2.4 Skolemization of rule premises: skoPrem (449–451)

```sml
fun skoPrem state vars (Const ("Pure.all", _) $ Abs (_, P)) =
        skoPrem state vars (subst_bound (Skolem (gensym state "S", vars), P))
  | skoPrem _ _ P = P;
```

A rule premise's outer meta-quantifiers (eigenvariable conditions,
δ-rules) are replaced by Skolem terms applied to **the branch's current
variables** (`vars` is the branch's `vars` field passed through
`netMkRules`, 951/1080).  This is the *standard* (non-liberalized)
δ-rule; the paper §5 (pp.6–7) records that liberalized δ-rules were
measured and rejected because reconstruction would require ε-term
manipulation ("prohibitively inefficient"), while the standard rule
"corresponds … to the standard ∃-elimination rule" and reconstructs
cheaply.  HOL4: the canonical rule form keeps premise-internal `!x. …`
intact (PLAN_phase_0.md §5.2), and those are what the HOL4 `skoPrem`
consumes; replay introduces the eigenvariable by a kernel GEN-style
step (§6.3).

### 2.5 Normalization: norm and wkNormAux (289–320)

`norm` (289–297): full normalization *except under unmodified
abstractions* — chases Var assignments, normalizes Const typargs,
prunes Skolem arg lists, and β-reduces (`norm f` yielding `Abs` ⇒
`norm (subst_bound (u, body))`).  Applied to the head formula before
rule search (949, 1078) and for tracing.

`wkNorm`/`wkNormAux` (300–320): head normalization for unification —
chase the head's Var assignments; β-reduce head redexes;
**eta-contract** `Abs(a, f $ Bound 0)` to `f` when `Bound 0` is not
loose in `f` and the argument weak-head-normalizes to `Bound 0`
(308–314).  `wkNorm` (316–320) short-circuits when the head is already
rigid (Const/Skolem/Free).

### 2.6 The trail and clearTo (104–111, 343–348)

Global mutable search state (`datatype state`, 104–111): `trail : term
option ref list ref` and `ntrail : int ref` record every Var
assignment made against the *branch* (not rule-local ones); `nclosed`,
`ntried` are statistics counters; `names` feeds gensym; `fullTrace`
is debug-only.  Backtracking restores by:

```sml
(*Restore the trail to some previous state: for backtracking*)
fun clearTo (State {ntrail, trail, ...}) n =
    while !ntrail<>n do
        (hd(!trail) := NONE;
         trail := tl (!trail);
         ntrail := !ntrail - 1);
```

(blast.ML:343–348.)  Every choice point captures `!ntrail` and undoes
to it (980, 1002, 1024, 1153, 1158; also on failed unification 380 and
on kill-all 993/1143).

### 2.7 Unification (355–381)

```sml
fun unify state (vars,t,u) =
    let val State {ntrail, trail, ...} = state
        val n = !ntrail
        fun update (t as Var v, u) =
            if t aconv u then ()
            else if varOccur v u then raise UNIFY
            else if mem_var(v, vars) then v := SOME u
                 else (*avoid updating Vars in the branch if possible!*)
                      if is_Var u andalso mem_var(dest_Var u, vars)
                      then dest_Var u := SOME t
                      else (v := SOME u;
                            trail := v :: !trail;  ntrail := !ntrail + 1)
        fun unifyAux (t,u) =
            case (wkNorm t,  wkNorm u) of
                (nt as Var v,  nu) => update(nt,nu)
              | (nu,  nt as Var v) => update(nt,nu)
              | (Const(a,ats), Const(b,bts)) => if a=b then unifysAux(ats,bts)
                                                else raise UNIFY
              | (Abs(_,t'),  Abs(_,u')) => unifyAux(t',u')
                    (*NB: can yield unifiers having dangling Bound vars!*)
              | (f$t',  g$u') => (unifyAux(f,g); unifyAux(t',u'))
              | (nt,  nu)    => if nt aconv nu then () else raise UNIFY
        and unifysAux ([], []) = ()
          | unifysAux (t :: ts, u :: us) = (unifyAux (t, u); unifysAux (ts, us))
          | unifysAux _ = raise UNIFY;
    in  (unifyAux(t,u); true) handle UNIFY => (clearTo state n; false)
    end;
```

(blast.ML:355–381, quoted in full; header comment 351–354.)  Points
that must be reproduced
exactly:

- **First-order with bound variables** (paper §7 p.8): decomposition
  is rigid on `$`; a Var unifies with any term passing the occurs
  check; `Abs` unifies with `Abs` by body (which can create dangling
  Bounds — deliberate, flagged in the comment at 374); a Bound unifies
  only with the same Bound (final `aconv` case); β/η via `wkNorm`.
  There is **no** higher-order (pattern) unification — a Var-headed
  application `?f $ x` decomposes first-order against `g $ u`.
- **Occurs check** `varOccur` (323–338): forbids `v` in `u`, *including
  through Skolem argument lists* (332) — this is where eigenvariable
  conditions bite — and forbids capturable dangling Bounds
  (`occ lev (Bound i) = lev <= i`, 334).  It does **not** descend into
  Const typargs (comment 333: "term variables can't occur in types").
- **The `vars` parameter**: Vars local to the rule being applied.
  Assignments to them are *not trailed* (they are garbage after this
  application; 352–354, 361), and `update` prefers to assign the
  rule-local Var rather than a branch Var when both sides are Vars
  (362–365) — minimizing trail growth and branch damage.  Callers pass
  `add_term_vars(P,[])` — the Vars of the rule pattern (972, 1103) —
  or `[]` for literal closing (807).
- On failure the trail is restored to `n` and `false` returned; on
  success partial assignments *stay* (they are the unifier).

---

## 3. Typargs: types in the untyped prover, and the HOL4 encoding

### 3.1 What Isabelle records and where it is used

`Const of string * term list` (85): every constant carries its
**typargs** — `Sign.const_typargs thy (a, T)` returns the list of
types instantiating the constant's *declared* type variables at this
occurrence, in declaration order.  For a monomorphic constant the list
is empty; for `HOL.eq : 'a ⇒ 'a ⇒ bool` at instance `nat ⇒ nat ⇒ bool`
it is `[nat]`.  So the modern code records typargs for **all**
polymorphic constants automatically (the paper §6 pp.7–8 describes an
earlier directive-based version: "The prover can be directed to record
the types of certain constants"; the shipped code needs no directive).
Types are encoded **as prototerms** (`fromType`, §2.2): type
constructors become Consts applied with `$`, TFrees become Frees, and
TVars become shared Var refs — "it represents Isabelle types using its
data structure for terms; unification propagates type constraints"
(paper §6 p.8).

Typargs participate in:

- **unification**: `(Const(a,ats), Const(b,bts)) => if a=b then
  unifysAux(ats,bts)` (371–372) — same constant name, then unify the
  typarg lists pairwise.  This is what stops the iff-rule from firing
  on a `nat` equality and lets a rule instantiate a type variable.
- `aconv` (199), the recursion-detector `match` (905–908, `matchs tas
  tbs`), `add_term_vars` (231 — typarg Vars count as branch vars!),
  `norm` (291).

They do **not** participate in: the occurs check (333), equality
substitution (`substOccur` 721–735 and `subst_atomic` 693–698 treat
`Const` atomically), or the net-lookup keys (`toTerm` drops them, 556:
"no need to convert typargs").  Display-only reconstruction of types:
`showType`/`topType` (599–610).

Soundness role: **none — search precision only.**  The whole design
rests on reconstruction re-checking everything through the kernel
(paper abstract p.1: "Because Isabelle verifies the proof, the prover
can cut corners for efficiency's sake without compromising soundness.
For example, the prover can use type information to guide the search
without storing type information in full"; §8.2 p.12: reconstruction
"occasionally fails because the tableau proof is unsound; almost
certainly, because it has used a rule that involves overloading …
except for uses of axiomatic type classes" — the residual gap being
sort constraints, which typargs do not encode).

### 3.2 The example that motivates dynamic typargs (paper §6 pp.7–8)

The equality `t = u` has three rule families — transitivity (any
type), iff-introduction (bool), extensionality (sets) — and static
analysis cannot resolve which applies after unification instantiates a
polymorphic rule (the `insert` example, paper p.8: after applying the
`x ∈ insert y A` rule, `x = y`'s type is whatever `insert`'s typarg
says *now*).  Recording `insert`'s typarg and unifying it during rule
application makes the set-equality rule reachable exactly when the
typarg has been forced to a set type.

### 3.3 HOL4 adaptation

HOL4's ambiguity source is the same: polymorphic constants.  A HOL4
constant occurrence is a name plus a type instance of the constant's
generic type; the analogue of `const_typargs` is:

```
generic = type_of (Term.prim_mk_const {Thy,Name})   (* FinalTerm-sig.sml:36 *)
theta   = Type.match_type generic ty_occurrence
typargs = map (Type.type_subst theta) (canonical tyvar order of generic)
```

with "canonical order" fixed once (e.g. `Type.type_vars` order of the
generic type; typargs are never persisted, so any deterministic
per-session order is sound).  Encoding, mirroring `fromType`: type
operator `(thy$tyop)` ↦ `Const("thy$tyop",[])` applied to encoded args
via `$`; **goal-side** type variables ↦ `Free` (rigid — a goal's type
variables are fixed, exactly like Isabelle TFrees); **rule-side** type
variables ↦ Var refs shared through the per-rule alist (a claset rule's
type variables are implicitly universal and must unify).

Faithful encoding options (decision deferred, §8-A):

- (a) **per-constant typargs** exactly as above — the faithful port;
  cost proportional to polymorphic-constant density;
- (b) a single typarg = the constant's full instance type as one
  encoded term — simpler, strictly coarser sharing (loses nothing
  semantically, slightly more unification work, and diverges from the
  code being ported);
- (c) no typargs — maximally fast search, but the §3.2 phenomenon
  returns as replay-time PROOF FAILED and lost proofs (the iff/set
  ambiguity is *more* acute in HOL4, below).  The paper explicitly
  tried the static variant and found it "cannot find proofs involving
  such inferences" (p.8).

Soundness is unaffected in all three: HOL4 replay re-proves every step
through the kernel; a type-unsound tableau proof surfaces as replay
failure → backtrack (§6.6).  Unlike Isabelle there are no type
classes, so the one residual unsoundness class Paulson documents
(axiomatic sort constraints, p.12) has **no HOL4 counterpart**;
type-correctness of a HOL4 rule instance is fully determined by
first-order type matching, which the typarg encoding models exactly.

HOL4-specific concerns:

- **bool-vs-other equality.**  `min$= : 'a -> 'a -> bool`.  Typarg
  `bool` selects iff-style rules (`IMP_ANTISYM_AX` as safe intro,
  `IFF_CELIM_THM` as safe elim); typarg `'a` matches generic equality
  rules; typarg an instance of `'b -> bool` (or, at seeding time,
  whatever pred_set uses) selects set-extensionality-style rules.
  Note HOL4 sets are literally functions (`'a -> bool`), so "set
  equality" is equality at a function type — the typarg mechanism
  handles this with no special case, but seed-rule design must accept
  that `f = g` at `'a -> bool` matches both function-extensionality
  and set rules (that is a Phase-8 seeding question, not an engine
  question).
- **set membership.**  `bool$IN : 'a -> ('a -> bool) -> bool`
  (pred_set idiom).  Rules like `IN_UNION`, `IN_INTER`, `IN_INSERT`
  are keyed on the `IN`/`UNION` head constants, so discrimination-net
  indexing does the real work; `IN`'s typarg matters for the same
  reason `insert`'s does in the paper's example — it is what makes a
  later `x = y` goal know its elements are sets.
- **λ-abstractions in goals.**  Handled: `fromTerm` keeps `Abs`
  (eta-contracting the `f $ Bound 0` shape, 398–403); `toTerm` maps
  `Abs` to a wildcard in net queries (561); `unify` handles Abs–Abs.
  Since HOL4 goals carry no schematic variables, the two `fromSubgoal`
  restrictions ("Function unknown's argument not a bound variable",
  1215–1219; "argument not in normal form", 1236) can never fire on
  goal translation — they concern only the Isabelle proof-state shape.
  The *search-time* limitation stands: rules whose applicability needs
  genuine higher-order unification (Var-headed patterns applied to
  non-Var arguments) will unify first-order or not at all (§7).

---

## 4. Rule acquisition: netMkRules and the conversions

### 4.1 netMkRules (569–580)

```sml
fun netMkRules state P vars (nps: Bires.netpair list) =
  case P of
      (Const ("*Goal*", _) $ G) =>
        let val pG = mk_Trueprop (toTerm 2 G)
            val intrs = maps (fn (inet,_) => Net.unify_term inet pG) nps
        in  map (fromIntrRule state vars o #2) (Bires.tag_order intrs)  end
    | _ =>
        if isVarForm P then [] (*The formula is too flexible, reject*)
        else
        let val pP = mk_Trueprop (toTerm 3 P)
            val elims = maps (fn (_,enet) => Net.unify_term enet pP) nps
        in  map_filter (fromRule state vars o #2) (Bires.tag_order elims)  end;
```

- Rules are fetched **lazily, per node, per formula**: a `*Goal*`
  formula consults only the **intro** nets; any other formula consults
  only the **elim** nets.  `nps` is `safeList = [safe0, safep]` in the
  safe cascade (936, 951) and `unsafeList = [unsafe]` for deferral
  probing and unsafe expansion (937, 1046, 1080).
- `toTerm d` (555–562) converts the prototerm back to a dummy-typed
  Isabelle term for net lookup, replacing Vars/Abs by a wildcard Var
  and cutting at depth `d` (2 for goals, 3 for elims — the extra level
  because the elim key is a whole formula, not a conclusion) — a pure
  over-approximation; real applicability is decided by `unify` later.
  HOL4: query `clasetNet.unify` directly with a converted HOL4 term
  whose Var positions become fresh frees listed in `qvars`
  (clasetNet.sig:156; the existing `unify_intro_candidates` takes all
  frees of the query as flexible, clasetLib.sml:320–326 — an even
  coarser over-approximation, sound for the same reason).
- `isVarForm` (564–567): a formula that is a bare Var or `¬(Var)` is
  rejected ("Too flexible assertions or goals", motivated by
  `(⋀P. ¬P) ⟹ 0=1`, 564) — no rules returned, so it is deferred and
  eventually parked as a literal.
- `Bires.tag_order` sorts candidates by (fewer new subgoals, more
  recent declaration) — bires.ML:97–110; HOL4 `candidate_order` has
  the identical contract (clasetRules.sig:49, PLAN_phase_0.md §5.1).
- Every conversion allocates **fresh Vars** (fromTerm's fresh alists),
  so each candidate is an independently instantiable copy, and gets
  the *current branch vars* for `skoPrem` dependency recording.

### 4.2 Intro conversion: fromIntrRule (527–548)

```sml
fun convertIntrPrem t = mkGoal (strip_imp_concl t) :: strip_imp_prems t;

fun convertIntrRule state vars t =
  let val Ps = strip_imp_prems t
      val P  = strip_imp_concl t
  in  (mkGoal P, map (convertIntrPrem o skoPrem state vars) Ps)  end;
```

A rule `⟦A1; …; An⟧ ⟹ C` becomes pattern `*Goal*(C)` with, per premise
`Ai = ⟦qs⟧ ⟹ Ci` (after `skoPrem`), the new-branch formula group
`[Goal(Ci), qs…]` — the premise's conclusion is the new goal, its
hypotheses become branch formulas.  The attached replay tactic
(545–547) is `rmtac ctxt upd (if dup then Classical.dup_intr rl else
rl) i THEN rot_subgoals_tac (rot, #2 trl) i`.  Comment 537–539: "Since
unsafe rules are now delayed, dup is always FALSE for introduction
rules" — the `dup_intr` arm is **dead** in the current engine, because
unsafe formulas are always stored goal-negated and expand through the
elim nets (§5.4); γ-duplication of goals rides on *swapped intros*
found in the elim net.  A faithful HOL4 port may keep or drop the arm
(§8-H).

### 4.3 Elim conversion: fromRule / convertRule / delete_concl (434–522)

```sml
fun delete_concl [] = raise ElimBadPrem
  | delete_concl (P :: Ps) =
      (case P of
        Const (c, _) $ Var (Unsynchronized.ref (SOME (Const ("*False*", _)))) =>
          if c = "*Goal*" orelse c = Data.not_name then Ps
          else P :: delete_concl Ps
      | _ => P :: delete_concl Ps);

fun convertPrem t =
    delete_concl (mkGoal (strip_imp_concl t) :: strip_imp_prems t);

(*Expects elimination rules to have a formula variable as conclusion*)
fun convertRule state vars t =
  let val (P::Ps) = strip_imp_prems t
      val Var v   = strip_imp_concl t
  in  v := SOME (Const ("*False*", []));
      (P, map (convertPrem o skoPrem state vars) Ps)
  end
  handle Bind => raise ElimBadConcl;
```

(blast.ML:441–463.)  Mechanism: the elim's conclusion must be a bare
schematic variable `R`; that Var ref is **destructively bound to the
pseudo-constant `*False*`** (a permanent binding, off-trail — safe
because the refs are private to this conversion).  Then, in each
remaining premise `⟦qs⟧ ⟹ Ci`, `delete_concl` removes the **first**
formula of the form `*Goal*(→*False*)` (the premise concludes `R`) or
`¬(→*False*)` (the premise hypothesizes `¬R` — the classical-repair
shape): on the tableau side, that occurrence *is* the branch's current
goal/negated goal, already present, so it must not be re-added.  If a
premise contains **no** such occurrence, `ElimBadPrem` propagates and
`fromRule` (503–522) rejects the rule with the user-visible warning
"Ignoring weak elimination rule" (513–517) — such rules lose the
conclusion and "could cause PROOF FAILED" (439–440).  A non-variable
conclusion (or a premise-free elim — the `(P::Ps)` Bind) raises
`ElimBadConcl`, dropped with a trace-only message "conclusion should
be a variable" (518–522).  Result: pattern = the major premise `P`
(unified against the branch formula), plus new-branch groups from the
remaining premises.  Replay tactic (508–510): `emtac ctxt upd (if dup
then rev_dup_elim ctxt rl else rl) i THEN rot_subgoals_tac (rot, #2
trl) i`.

**Swapped intros arrive here for free**: classical.ML stores each
intro also as `intr RSN (2, swap)` — an elim-format rule with major
premise `¬C` and variable conclusion (classical.ML:195–213; HOL.thy
`swap` at 819) — in the elim nets.  Blast's non-Goal lookup finds
them, `convertRule` accepts them (conclusion `R` is a Var; every
premise `¬R ⟹ Ai` contains the `¬(→*False*)` occurrence), and this is
how goals deferred as negated assumptions get expanded by intro logic
(§5.4).  The Phase-0 claset stores swapped variants in the elim nets
the same way (clasetLib.sml:61–77), so the HOL4 lookup surface is
already right.

### 4.4 emtac / rmtac and the upd flag (486–498)

```sml
fun emtac ctxt upd rl =
  TRACE ctxt rl (if upd then eresolve_tac ctxt [rl] else ematch_tac ctxt [rl]);
fun rmtac ctxt upd rl =
  TRACE ctxt rl (if upd then resolve_tac ctxt [rl] else match_tac ctxt [rl]);
```

`upd` = "this application instantiated branch variables" (detected as
`ntrl < !ntrail`, 974/1105).  If not, the recorded tactic uses
**matching** (no proof-state Vars instantiated) — "Matching makes the
tactics more deterministic in the presence of Vars" (492–493); if yes,
genuine resolution, letting Isabelle's engine re-find the unifier
(paper §8.2 p.11: delivering the search's instantiations "yielded no
speed-up; the tableau prover only finds first-order unifiers, which
Isabelle can reconstruct easily").  The HOL4 consequence of *not*
having this option is the central §6 problem.

### 4.5 Duplication: rev_dup_elim (466–467) and dup_intr

```sml
(*Like dup_elim, but puts the duplicated major premise FIRST*)
fun rev_dup_elim ctxt th = (th RSN (2, revcut_rl)) |> Thm.assumption (SOME ctxt) 2 |> Seq.hd;
```

vs `dup_elim` (classical.ML:218–220) which additionally cuts the
duplicate back behind the other premises.  The "FIRST" placement is
load-bearing: after the elim consumes the assumption, each new subgoal
gets `[dupMajor, new1 … newk]` appended; `rot_subgoals_tac` rotates by
`k` (counted from the **plain** rule's premises — `#2 trl` excludes
the duplicate), yielding assumption order `[new1 … newk, old…,
dupMajor]` — the duplicate lands at the very **back**, exactly
matching the branch's `Hs @ [(negOfGoal H, md)]` re-queue (1084).
HOL4 needs a new derived rule `REV_DUP_ELIM_RULE` with this placement
(Phase-0's `DUP_ELIM_RULE` matches `dup_elim`, not this); specified on
the canonical spine: for elim `|- !xs r. M ==> Q1 ==> … ==> Qm ==> r`,
produce the variant in which each `Qi = ⟦qs⟧ ==> Ci` becomes
`⟦M; qs⟧ ==> Ci` with `M` **first** among the added hypotheses.
`dup_intr = th RS classical` (classical.ML:216) = Phase-0
`DUP_INTRO_RULE`; dead in blast's flow (§4.2) but trivially available.

### 4.6 rot_subgoals_tac (470–483)

```sml
local
  fun nNewHyps []                         = 0
    | nNewHyps (Const ("*Goal*", _) $ _ :: Ps) = nNewHyps Ps
    | nNewHyps (P::Ps)                    = 1 + nNewHyps Ps;
  fun rot_tac [] i st      = Seq.single st
    | rot_tac (0::ks) i st = rot_tac ks (i+1) st
    | rot_tac (k::ks) i st = rot_tac ks (i+1) (Thm.rotate_rule (~k) i st);
in
fun rot_subgoals_tac (rot, rl) = rot_tac (if rot then map nNewHyps rl else [])
end;
```

Semantics: for each new subgoal `j` produced by the rule application
(subgoal numbers `i, i+1, …`), rotate its assumption list by minus the
number of new *hypothesis* formulas that premise contributed
(`*Goal*`-marked entries are conclusions, not hypotheses — skipped).
Isabelle appends new hypotheses at the back; rotating by `~k` brings
them to the **front**, restoring the branch's LIFO discipline ("Rotate
the assumptions in all new subgoals for the LIFO discipline", 470;
paper §8.2 p.11).  The `rot` flag is always `true` at both call sites
(981, 1133); the comment at 1134–1137 records the known imperfection
for recursive rules ("that's WRONG if the new formulae are Goals…").

### 4.7 HOL4 rule conversion, precisely

Candidates arrive from the Phase-0 netpairs as `(tag, brl)` with
`brl = (is_elim, thm)` and `thm` in canonical form
`|- !x1…xk. P1 ==> … ==> Pn ==> C` (PLAN_phase_0.md §5.2).  The HOL4
`fromRule`/`fromIntrRule` must:

1. Strip the outer `!xs`; map each `xi` to a fresh prototerm Var ref
   (one alist per conversion).  Map the rule's type variables to fresh
   shared Var refs (§3.3).  Translate body with constants carrying
   typargs.
2. **Intro** (`is_elim = false`, from the intro net): pattern
   `mkGoal C'`; premises: for each `Pi`, `skoPrem` its outer `!`s
   (fresh Skolems applied to the branch vars), then
   `[Goal(concl_of Pi'), hyps_of Pi'…]` where hyps/concl split `Pi'`
   along its `==>` spine.
3. **Elim** (`is_elim = true`, from the elim net, includes swapped
   intros, make-elim'd dests, classical-repaired elims): require
   `n ≥ 1` and `C'` to be (after chasing) an unassigned Var that came
   from an `xi` of type `bool` — the **formula-variable conclusion
   check**.  Destructively bind it to `*False*`.  Pattern = `P1'`;
   premises `P2 … Pn` via skoPrem + convertPrem with `delete_concl`;
   `ElimBadPrem` ⇒ reject with the weak-elim warning (same text),
   `ElimBadConcl` ⇒ trace-only skip.  Note the Phase-0 preprocessing
   (`MAKE_ELIM_RULE`, `CLASSICAL_RULE`) produces variable conclusions
   by construction, so rejections should be rare and confined to
   directly-declared exotic elims — same as Isabelle.
4. Attach the replay tactic: the emtac/rmtac analogue with the
   *original stored theorem* (or its rev-dup/dup variant when
   `dup = true`), followed by the premise-structure strip and rotation
   (§6.3), driven by the `(upd, dup, rot)` triple exactly as at
   508–510 / 545–547.

What plays the role of the formula-variable check is therefore: *the
canonical elim's conclusion must be one of its own outermost
universally quantified boolean variables, not occurring free in a
non-conclusion position that would survive deletion* — operationally
just steps 3's Var + delete_concl tests, which need no extra analysis.

---

## 5. The search engine

### 5.1 Branch representation and invariants (93–99, 1179–1184)

```sml
type branch =
    {pairs: ((term*bool) list *        (*safe formulae on this level*)
               (term*bool) list) list, (*unsafe formulae on this level*)
     lits:   term list,                (*literals: irreducible formulae*)
     vars:   term option Unsynchronized.ref list,
     lim:    int};
```

- `pairs` is a **stack of levels** ("stack frames", 770): each rule
  application pushes a new level holding the premise's formulas; the
  head level's first list is the unexpanded *safe* queue, its second
  the *deferred unsafe* queue of that level.  This realizes the LIFO
  discipline (paper §3 p.4: formulas derived from `A` are expanded
  before anything older) while γ-deferral stays level-local ("The
  deferred γ-formula does not go to the end of a global queue but
  merely after all other formulæ in the present group", paper §3 p.4).
- Every pending formula carries an `md` ("may duplicate") flag.
  Initial formulas: `md = true` (initBranch 1181).  Safe expansions:
  children get `hasSkolem G orelse md` (joinMd 823–826, hasSkolem
  817–821) — md is inherited, and *regained* by any formula containing
  a Skolem term.  Unsafe expansions: children get `md = false`
  (1082–1083: "new premises of unsafe rules may NOT be duplicated").
  Together these implement the paper's γ-retention optimization (§3
  p.5): the outer γ-formula is retained (re-queued when expanded, §5.4)
  while inner γ-formulas are discarded — except when δ-generated
  Skolem terms make instances genuinely different (the `∀x ∃z ∀y A`
  example), which `hasSkolem` detects.
- `lits`: formulas no rule applies to — literal is *rule-relative*
  (paper §7 p.9).  `addLit` (876–894) maintains the goal bookkeeping:
  when a `*Goal*` literal is added and complementary/duplicate goal
  or negation literals exist, older goals are rewritten to negations.
- **Goal invariant**: a branch holds at most one `*Goal*`-marked
  formula among its pending formulas — the Isabelle subgoal's
  conclusion; all other formulas are assumptions.  Maintained by
  `negOfGoals`/`negOfGoal` conversions whenever a new Goal enters
  (newBr 955–960; newPrem 1085–1087; addLit) — matching the
  natural-deduction constraint "If a rule is to generate multiple goal
  formulæ, then all but one of them must be negative" (paper §8.1
  p.11).
- `vars`: all Var refs occurring in the branch (kept deduplicated and
  assignment-chased via `vars_in_vars`/`add_terms_vars`, 246–247,
  978–979, 1106–1107); consumed by `skoPrem` (δ-dependencies) and
  `prune`/`nextVars` (§5.6).
- `lim`: the resource bound; decremented by unsafe expansions and by
  instantiating inferences (§5.5).

The engine state is `brs : branch list` — the list of open branches
(= open Isabelle subgoals), depth-first, head active.

### 5.2 prove's five clauses (932–1176)

`prv (tacs, trs, choices, brs)` where `tacs` = recorded replay tactics
(newest first), `trs` = trace, `choices` = backtrack stack of
`(ntrail_mark, #branches, exn)`:

1. `brs = []` (938–940): all branches closed — print stats, call the
   continuation `cont (tacs, trs, choices)` (reconstruction, §6.6).
2. Head branch's head level has a head **safe** formula `G`
   (941–1064): the cascade below.
3. Head level exhausted (`([], unsafe)`) and a lower level exists
   (1065–1072): merge — `(Gs, unsafe@unsafe')` — deferred unsafe
   formulas sink to their level boundary in order.
4. Exactly one level, no safe formulas, head **unsafe** formula `H`
   (1073–1174): unsafe expansion, §5.4.
5. Anything else — i.e. a branch with only literals left (1175):
   `backtrack trace choices`.

`backtrack` (870–874) raises the exception of the newest choice point
(each choice point carries its own locally declared `PRV` exception —
one per `deeper`/`closeF` recursion, 946/1077 — so control returns to
*precisely* that frame); with no choices left it raises `PROVE`,
turning `raw_blast` into `Seq.empty` (1276).

### 5.3 The safe cascade (1032–1063), exact conditions

For head formula `G` (normed, 950), with `rules = netMkRules … G vars
safeList` (951):

0. `if lim<0 then … backtrack` (1034).
1. **Equality substitution** (1036–1041): record
   `Data.hyp_subst_tac ctxt trace`; replace the branch by
   `equalSubst ctxt (G, rest-of-branch)`.  `equalSubst` (757–790)
   raises `DEST_EQ` unless `G` is an equality (`dest_eq`, 739–743,
   eta-contracting both sides via `eta_contract_atom` 700–708) with a
   substitutable orientation: `orientGoal` (748–755) prefers
   eliminating a Skolem, then a Free — never a Var or a compound —
   and `check`/`substOccur` (721–746) rejects `t = u` if `t` occurs in
   `u` *or* `u` contains any Var outside `t`'s Skolem-argument list
   ("For example, x=?a is rejected because ?a could be instantiated to
   Suc(x)", 723–725; reflexive: `x=x` rejected because
   `hyp_subst_tac` fails on it, 720).  On success: substitute
   throughout pairs and lits (`subst_atomic`); every **affected**
   formula is pulled out and pushed as a brand-new head level
   `(changed', []) :: pairs'` (786) — affected *literals* rejoin the
   pending queue with `md = true` (779); the equation itself is
   deleted.  The header (31–35) and paper §7 (p.9) flag this
   re-ordering as the classic reconstruction-divergence source.
2. `handle DEST_EQ =>` **close with a literal**: `closeF lits`
   (1008–1025).  `tryClose` (802–815) unifies (with empty rule-var
   list) goal-vs-literal or literal-vs-goal complementary pairs:
   `Goal(G)` against `L` or `G` against `Goal(L)` — replay
   `eq_assume_tac ORELSE' assume_tac` (806); `¬G` against `L` or `G`
   against `¬L` — replay `contr_tac` = `ematch_tac [notE] THEN'
   (eq_assume_tac ORELSE' assume_tac)` (798–799; the comment notes
   trying `eq_contr_tac` first was a net slowdown, 797).  On close:
   bump `nclosed`, prune (§5.6), push choice `(ntrl, nbrs, PRV)`;
   backtracking into it (`PRV`) resets the trail and tries the next
   literal (1021–1024).
3. `handle CLOSEF =>` **close with any queued formula**: `closeFl
   ((br,unsafe)::pairs)` (1027–1031) — same `closeF` over every level's
   safe then unsafe queues.
4. `handle CLOSEF => deeper rules` — **apply a safe rule** (970–1006):
   first candidate whose pattern `P` unifies with `G`
   (`unify state (add_term_vars(P,[]), P, G)`, 972):
   - `updated = ntrl < !ntrail`; if updated,
     `lim' = lim - (1 + log(length rules))` else `lim` (974–977) —
     the instantiation penalty, §5.5.
   - New branches via `newBr` (953–967): each premise group `prem`
     becomes a branch with `(joinMd md prem, [])` pushed as a new
     level; if `prem` contains a Goal, all other Goals in the branch
     (pairs and lits) are negated (`negOfGoals`, `negOfGoal`,
     955–960) — the conclusion changed, so the old conclusion becomes
     a negated assumption (matches what the swapped rule does on the
     Isabelle side).
   - Record `tac (updated, false, true)` (981) — no duplication for
     safe rules, always rotate.
   - If `prems = []`: branch **closed by rule** (the paper §3 p.5
     "Rules that Close Branches"): `nclosed++`, prune, recurse (985–989).
   - If `lim' < 0`: "Excessive branching: KILLED" — reset trail and
     raise `NEWBRANCHES`, abandoning *all* remaining candidates
     (991–993; faster than trying siblings).
   - Otherwise recurse with the new branches (995–997).
   - `handle PRV`: if `updated`, reset trail and try the next
     candidate (1002); if not, `backtrack` further — an
     uninstantiating safe-rule application never needs a sibling rule
     (1003–1004): this is the α/β-rule determinism.
5. `handle NEWBRANCHES =>` **defer** (1045–1063): probe
   `netMkRules … unsafeList`:
   - no unsafe rule could ever apply ⇒ `G` is a literal: move to
     `lits` via `addLit`; no tactic recorded (1047–1053).
   - some unsafe rule applies ⇒ move `negOfGoal G` (with its `md`) to
     the **end** of the current level's unsafe queue (1060); if `G`
     was a Goal, record `negOfGoal_tac` = `resolve_tac [ccontr] THEN
     rotate_tac ~1` (1056, 639–641) — on the Isabelle side the
     conclusion becomes the negated assumption, rotated to the front.

### 5.4 Unsafe expansion (1073–1174)

Precondition: `pairs = [([], (H,md)::Hs)]` — every safe formula at
every level is consumed.  With `rules = netMkRules state H vars
unsafeList` (`H` normed; `H` is never a Goal — goals were negated on
deferral, so lookup is in the **elim** nets):

0. `if lim<1 then … backtrack` (1165).
1. `deeper rules` (1101–1162): first unifiable candidate:
   - `updated` as before; `dup = md` (1109 — earlier builds also
     required new vars; comment 1109–1110); `recur = exists (exists
     (match P)) prems` (1113 — tracing only at this point).
   - `lim' = if updated then lim - (1+log(length rules)) else lim - 1`
     (1114–1116); the comment (1117–1120) records that *not* charging
     non-dup non-recur steps found proofs shallower but looped.
   - `newPrem` (1082–1097): each premise group becomes
     `Gs' = map (fn Q => (Q,false)) prem` — children non-duplicable —
     and `Hs' = if dup then Hs @ [(negOfGoal H, md)] else Hs` — the
     γ-formula re-queued at the **back** of the unsafe queue, md
     preserved.  **Recursive-premise special case** (1088–1093,
     quoted):

     ```sml
     {pairs = if exists (match P) prem then [(Gs',Hs')]
              (*Recursive in this premise.  Don't make new
                "stack frame".  New unsafe premises will end up
                at the BACK of the queue, preventing
                exclusion of others*)
           else [(Gs',[]), ([],Hs')],
      ...}
     ```

     `match` (902–915) is one-way pattern matching (Var in the
     pattern matches anything; `*Goal*`/¬ identified, 906–907): if the
     rule's own pattern matches a premise formula (transitivity
     shape), the premise shares the level with the pending unsafe
     queue instead of stacking above it — so the recursive offspring
     go behind the old γ-formulas rather than starving them (paper §7
     "Transitivity" pp.9–10; header 24–29).
   - `lits' = map negOfGoal lits` if the premise introduces a Goal
     (1085–1087).
   - Kill-all when `lim' < 0` and the rule branches (1140–1143).
   - Record `tac' = tac (updated, dup, true)` (1133); push choice
     `(ntrl, length brs0, PRV)`; recurse (1151–1154).
   - `handle PRV`: retry next candidate only if `mayUndo`
     (1155–1160), quoted:

     ```sml
     val mayUndo =
         (*Allowing backtracking from a rule application
           if other matching rules exist, if the rule
           updated variables, or if the rule did not
           introduce new variables.  This latter condition
           means it is not a standard "gamma-rule" but
           some other form of unsafe rule.  Aim is to
           emulate Fast_tac, which allows all unsafe steps
           to be undone.*)
         not(null grls)   (*other rules to try?*)
         orelse updated
         orelse vars=vars'   (*no new Vars?*)
     ```

     (blast.ML:1121–1132; cf. paper §7 "Undoable rules" p.9: undo "if
     other unifiable rules exist, if it instantiates variables, or if
     the inference does not introduce new variables".)  A pure γ-rule
     that was the only candidate and instantiated nothing is *not*
     re-tried — its re-queued copy will supply further instances.
2. `handle NEWBRANCHES =>` no unsafe rule unified: `H` moves to
   `lits` (1167–1173); no tactic.

### 5.5 The instantiation penalty (897–899)

```sml
fun log n = if n<4 then 0 else 1 + log(n div 4);
```

so the charge for an instantiating inference is `1 + ⌊log₄ N⌋` where
`N` = number of *candidate* rules for the formula (975–976,
1114–1115); a non-instantiating unsafe step costs exactly 1, a
non-instantiating safe step 0.  Paper §4 (pp.5–6): the γ-bound also
controls variable instantiation; a penalty of 1 lets `t ∈ ?X` swamp
the search, so the penalty grows with the local branching factor N —
"log₄ N … a compromise between banning instantiation altogether and
allowing it freely", tuned experimentally (the code's `1 +` is the
baseline unsafe cost on top).

### 5.6 Pruning (829–867)

```sml
(*nbrs = # of branches just prior to closing this one.  Delete choice points
  for goals proved by the latest inference, provided NO variables in the
  next branch have been updated.*)
fun prune _ (1, nxtVars, choices) = choices  (*DON'T prune at very end: allow
                                             backtracking over bad proofs*)
  | prune (State {ctxt, ntrail, trail, ...}) (nbrs: int, nxtVars, choices) =
      let fun traceIt last = ...
          fun pruneAux (last, _, _, []) = last
            | pruneAux (last, ntrl, trl, (ntrl',nbrs',exn) :: choices) =
                if nbrs' < nbrs
                then last  (*don't backtrack beyond first solution of goal*)
                else if nbrs' > nbrs then pruneAux (last, ntrl, trl, choices)
                else (* nbrs'=nbrs *)
                     if clashVar nxtVars (ntrl-ntrl', trl) then last
                     else (*no clashes: can go back at least this far!*)
                          pruneAux(choices, ntrl', List.drop(trl, ntrl-ntrl'),
                                   choices)
  in  traceIt (pruneAux (choices, !ntrail, !trail, choices))  end;
```

(blast.ML:841–865; `clashVar` 831–838 tests whether any of the last
`n` trail entries occurs in `nxtVars` = the Vars of the *next* open
branch, `nextVars` 867.)  Reading: when a branch closes with `nbrs`
branches open, choice points recorded while `nbrs` was unchanged
belong to the *just-solved* subproblem; they can be discarded —
backtracking would only re-derive another proof of an already-closed
goal — **unless** the solved goal's proof instantiated variables
visible in the remaining branches (then alternatives may matter).
Choice points with `nbrs' < nbrs` are older than this goal's creation
and survive; the scan never prunes past the first of those.  Skipping
`nbrs' > nbrs` entries steps over choices of already-closed inner
subproofs.  The `nbrs = 1` guard keeps the final choice points so a
failed *reconstruction* can still backtrack (844–845 — directly
serving §6.6).  Paper §3 "Search-Space Pruning" (p.5) and p.12:
pruning "reduces the chances of finding alternative proofs" after a
PROOF FAILED — accepted cost.

### 5.7 Iterative deepening, statistics, no timeout

- `blast_tac` (1284–1292): `SELECT_GOAL (atomize_prems_tac 1 THEN
  DEEPEN (1, depth_limit) (fn m => fn _ => raw_blast start ctxt m) 0 1)`
  — bounds 0, 1, 2, … up to `blast_depth_limit` (default 20, line 79).
  `depth_tac` (1279–1282) runs one fixed bound (the `(blast n)` method,
  1313–1319; also what `auto` calls with m=4).
- Statistics (`blast_stats`): search time + `nclosed` (branches
  closed) + `ntried` (branches created, from 1) + tactic count at
  every `prv` completion (`printStats`, 918–924); reconstruction time
  separately (1267–1268).  **There is no timeout in blast.ML** — the
  paper's position is that the user interrupts (§1 p.2); any HOL4
  time-limit is optional new surface (design choice §8-L).
- `tryIt` (1296–1307) exposes the raw engine on a parsed goal for
  debugging; worth porting for selftests (it returns the full trace
  and the recorded tactic list without running reconstruction).

---

## 6. Reconstruction

### 6.1 The recorded vocabulary

Search steps cons tactics onto `tacs`; reconstruction runs
`EVERY' (rev tacs) 1` on the original (SELECT_GOAL'd, atomized) state
(1264).  The complete vocabulary:

| # | recorded at | tactic | replays |
|---|---|---|---|
| T1 | 1036 | `Data.hyp_subst_tac ctxt trace` = `blast_hyp_subst_tac` | equality-assumption substitution + reorder (§6.5) |
| T2 | 810–811 via 806 | `eq_assume_tac ORELSE' assume_tac` | close: conclusion equals/unifies-with an assumption |
| T3 | 812–813 via 798–799, 805 | `ematch_tac [notE] THEN' (eq_assume_tac ORELSE' assume_tac)` | close: complementary assumptions ¬P, P |
| T4 | 981 | `rmtac upd rl THEN rot_subgoals_tac` or `emtac upd rl THEN rot_subgoals_tac` | safe rule (intro on the conclusion / elim on first matching assumption) + rotation |
| T5 | 1056 via 640–641 | `resolve_tac [ccontr] THEN rotate_tac ~1` | goal deferral: conclusion becomes front negated assumption |
| T6 | 1133/1151 | `emtac upd (rev_dup_elim rl \| rl) THEN rot_subgoals_tac` | unsafe (elim-form) rule, optionally duplicating |

No tactic is recorded for: moving a formula to `lits` (1047–1053,
1167–1173), level transfer (1065–1072), or the goal-negation
bookkeeping inside `newBr`/`newPrem`/`addLit` (the corresponding
Isabelle-side change is produced by the same rule application T4/T6 —
the swapped rule's `¬r` premises carry it).

### 6.2 What each must do on a HOL4 goal

Correspondence: an open branch = an open HOL4 goal `(asl, w)`; the
branch's unique `*Goal*` formula = `w`; every other pending formula
and literal = a member of `asl`; branch order (head-first) = `asl`
order (front-first).

- **T2**: close `(asl, w)` where some `a ∈ asl` closes `w`.  The
  `eq_assume_tac` half is `FIRST_ASSUM ACCEPT_TAC`-style with plain
  α-conversion — directly portable.  The `assume_tac` half *unifies*,
  instantiating proof-state Vars — meaningless on a HOL4 goal; see
  §6.3.
- **T3**: find the first assumption of the form `~P` such that `P`
  closes against a (later) assumption; HOL4 shape:
  `FIRST_X_ASSUM (fn nth => …CONTR… )` built from `NOT_ELIM_THM`, with
  the same first-match-in-order discipline as `ematch_tac` so the
  divergence behavior is faithful.
- **T4/T6**: apply the stored theorem — intro against `w`
  (match-mode: `PART_MATCH`-style against the conclusion), elim
  against the first assumption its major premise matches, consuming
  it; then, per new subgoal, *strip the premise structure*: for a
  premise `!ys. q1 ==> … ==> qj ==> c`, the new HOL4 goal must end up
  as `(qs' @ old_asl_minus_major, c')` with fresh frees for `ys` —
  i.e. GEN-introduce each skolemized `!y` (matching the search-side
  `skoPrem`) and DISCH-move each `qi` into the assumption list.  In
  Isabelle all of this is implicit in lifted resolution; in HOL4 it is
  an explicit part of the emtac/rmtac analogue.  Finally rotate the
  `j` new assumptions to the front of `asl` (rot_subgoals_tac
  semantics, §4.6) — in HOL4 a pure list rotation.
- **T5**: `(asl, G)` ↦ `(~G :: asl, F)` — CCONTR with the new
  assumption at the front (Isabelle needs the extra `rotate_tac ~1` to
  achieve this; a HOL4 implementation that conses at the front needs
  no rotation, but must pick one convention and stick to it, §8-D).
- **T1**: §6.5.

### 6.3 The central difference: replay cannot leave uninstantiated witnesses

In Isabelle, T4/T6 with `upd = true` use genuine resolution: applying
(the swapped form of) `exI` leaves a schematic `?x` in the proof
state, later closed by `assume_tac` unification — "Isabelle's proof
engine repeats the unifications done during the search" (paper §8.2
p.11).  HOL4 goals cannot contain metavariables (PLAN §1.3), so
**blast-style replay-by-re-resolution does not work directly**: at the
moment T6 applies an `EXISTS_INTRO_THM`-swap, the witness must already
be a concrete term.  Two architectures satisfy the constraint that the
recorded script is replayed left-to-right against the real goal:

**(a) Explicit-instantiation replay.**  When `cont` is reached, the
search's Var refs still hold the successful unifier (they are only
cleared by backtracking).  Extend the recorded steps to carry their
rule's *instantiated* pattern/premises (or the rule thm plus a
prototerm substitution for its Vars), and translate prototerms back to
HOL4 terms at reconstruction time.  Analysis:

- Rule variables occurring in the pattern need no back-translation:
  matching the (higher-order-pattern-free, first-order) pattern
  against the actual conclusion/assumption during replay re-derives
  them with full types — this is the part Isabelle also re-derives.
  Only variables *not* determined by the match (the genuine new
  unknowns: exI's witness, allE's instance) need their recorded
  values.
- Back-translation must produce **typed** terms from untyped
  prototerms: leaves are Skolems (mapped back to the goal frees /
  GEN-introduced frees they came from — requires a Skolem↔variable
  registry maintained during replay, since replay-side fresh names
  must track search-side gensyms), Frees (goal frees), Consts (name +
  typargs; the target type of each rule variable is known from the
  rule instance after the pattern match, so type reconstruction is
  local unification of the encoded typargs against known types), Bounds
  and Abs (structural).  Vars still unassigned at the end are
  don't-cares: instantiate with anything of the right type (`ARB`-at-τ
  or a fresh variable).
- T2's unifying half becomes: unify was already done in the search;
  replay closes by α-conversion *after* the relevant instantiations
  were forced by earlier explicit steps — i.e. with (a), every T2
  degrades to the `eq_assume` half plus possibly instantiating
  *pending rule variables of earlier steps*, which is exactly why the
  substitution must be applied at the step that *introduced* the
  variable, not the step that determined it.  This is the crux: in the
  recorded script, a variable is introduced at step i and determined
  at step j > i; left-to-right ground replay must know the final value
  already at step i.  Since the final trail *is* available before
  replay starts, this is soluble — but it means replay tactics are
  generated from (rule, final substitution), not from the rule alone.
- PROOF FAILED semantics survive: if back-translation or a step
  fails, backtrack into the search (the choices stack is alive).

**(b) Metavariable-capable replay layer.**  Replay the script not on
the kernel goal but on Phase 2's internal proof-state representation
with metavariables (PLAN §6.2 forest: goals + metavariable store +
validation composition), where T2/T4/T6 can genuinely resolve and
instantiate; when the script completes, the internal state is closed
and ground, and its own kernel-replay produces the theorem.  Analysis:

- Faithful to Isabelle's division of labor (search finds the proof
  shape; the replay engine re-finds first-order unifiers — cheap per
  the paper §8.2).  No back-translation of prototerms at all; no
  Skolem registry (the internal layer introduces eigenvariables
  itself).
- The "left-to-right on the real goal" constraint is met one level up:
  the internal state is initialized from the real goal, the script
  runs left-to-right on it, and grounding happens once at the end —
  the same trust story as MESON/metis (and as blast itself: the
  kernel checks everything at the final replay).
- Cost: BLAST becomes dependent on the §6.2 engine (a scheduling
  coupling: PLAN has them both in Phase 2, sharing intended), and
  divergence behavior changes subtly — failures that Isabelle would
  catch at kernel-replay of a *step* are caught at the internal
  layer's step (same effect) or at final grounding (later, but still
  inside the PROOF-FAILED-backtrack loop).
- Risk concentration: the internal layer must support elim-resolution
  with premise-structure stripping, rotation bookkeeping, and
  hyp-subst — i.e. most of §6.2's step vocabulary; if Phase 2 builds
  that anyway for FAST/BEST/DEEPEN, (b) is mostly reuse; if not, (b)
  smuggles the §6.2 workload into BLAST.

Both are honest ports of the architecture ("search externally, replay
through the kernel"); the choice is §8-B.  A hybrid is also coherent:
(b)'s layer but seeding it with (a)'s recorded final substitution to
skip re-unification — the paper measured that skip as worthless in
Isabelle (§8.2 p.11), but the measurement does not transfer
automatically to a from-scratch layer.

### 6.4 Assumption rotation and the ordering invariant

What reconstruction relies on: **at every replay step, the branch's
formula sequence and the subgoal's assumption list agree in order,
with the branch head at the front.**  Established by initBranch order
(goal :: hyps ~ conclusion + premise order after atomize), maintained
by: rot_subgoals_tac after every rule step (new hyps to the front, in
premise order, §4.6); T5's rotation (deferred goal's negation to the
front); rev_dup_elim's placement (duplicate to the back *after*
rotation, §4.5); and T1's affected-hyps-to-front contract (§6.5)
mirroring equalSubst's new head level (786).  Literals and deferred
unsafe formulas need no Isabelle-side action: they simply remain in
place as newer material is rotated in front of them.  The invariant is
what lets the *first-match* discipline of `ematch_tac`/`eresolve_tac`
pick the same assumption the tableau expanded; it is approximate —
"Typically, the tableau prover has allowed a branch's formulæ to get
out of order.  If two similar formulæ are exchanged, then the wrong
one might get expanded" (paper p.12) — and the `upd=false` matching
mode narrows the miss window (§4.4).

HOL4 analogue: `asl` is a plain list; rotation = list surgery with an
identity-strength validation (the kernel does not see assumption
order).  Two consequences: (i) rotation tactics are essentially free,
removing Isabelle's motivation to minimize them; (ii) HOL4 replay
*could* instead address assumptions by term (search records the
prototerm; replay finds the α-matching assumption), abandoning
positional addressing entirely — stronger against divergence but a
semantic departure with its own ambiguity on duplicate assumptions
(§8-C).  Note HOL4 tactic conventions (e.g. `STRIP_ASSUME_TAC`) grow
`asl` at the front, which happens to match the LIFO invariant
direction.

### 6.5 blast_hyp_subst_tac's contract (hypsubst.ML:233–282)

Selection: `eq_var false false false Bi` (268; eq_var at 108–123)
scans the subgoal's premises **in order** for the first equality
`t = u` acceptable to `inspect_pair false false` (83–104): after
eta-contraction, one side must be a Bound (subgoal parameter) with no
loose occurrence in the other side, or a Free not occurring in the
other side (`Logic.occs`); Vars are allowed (novars=false); it returns
the intervening-premise count `k` and orientation.  This must agree
with the branch side (`orientGoal`/`substOccur`, §5.3-1): Skolem ↔
Bound/parameter-Free, Free ↔ Free, same occurs check, same
orientation preference, and the equality being *first* in the
assumption list is guaranteed by the ordering invariant (the equation
G was the branch head).  Two deliberate mismatches to preserve, not
fix: the branch side refuses `t = ?y` when `?y` could later contain
`t` (substOccur's Var condition) while `eq_var … false` tolerates
Vars — harmless because the search only records T1 when its own check
passed; and hypsubst's "affected" test sees changes the search does
not ("even trivial changes are noticed, such as substitutions in the
arguments of a function Var", 234–235) — a known, documented
divergence source.

Action (266–282): `rev_mp` away the `k` premises before the equality,
rotate it into major-premise position, `rev_mp` the rest, apply the
substitution rule instance (`inst_subst_tac`, 159–188, oriented by
`symopt`), then `all_imp_intr_tac` (244–263) re-introduces the hyps
one by one, comparing each re-emerging hyp with its recorded original
(`Envir.aeconv`): **unchanged** hyps are re-introduced and rotated to
the back (preserving their order); **affected** hyps are left
accumulating at the end, and `reverse_n_tac` (237–242) finally
re-reverses those `r` affected hyps — net effect: *affected
hypotheses move to the front, in their original relative order; the
equation is consumed* — precisely `equalSubst`'s
`(changed',[])::pairs'` branch shape (786).

HOL4 port: `BasicProvers.VAR_EQ_TAC` (BasicProvers.sml:849–856) has
the right *selection* semantics (first variable-resolvable equality,
occurs check) but substitutes in place with no reordering and no
affected/unaffected distinction.  BLAST needs a dedicated
`BLAST_VAR_EQ_TAC` (in the blast directory or as a
`clasetLib`-adjacent utility) that (i) selects the *first* suitable
equality in `asl` under exactly `inspect_pair false false`'s rules
transposed to HOL4 (Free-or-parameter side, occurs check, orientation,
tolerate nothing HOL4-specific like markers), (ii) substitutes through
`asl` and `w`, (iii) reorders `asl` so affected assumptions are at the
front in original relative order, with the affectedness test being
term inequality after substitution (`aconv` comparison — mirroring
equalSubst's `nG aconv G` test at 767, *not* hypsubst's finer test, to
kill that divergence class at the root — a faithful-or-better choice
to record, §8-F).

### 6.6 PROOF FAILED = backtrack into the search (1254–1277)

```sml
fun cont (tacs,_,choices) =
    let val start = Timing.start ()
    in
    case Seq.pull(EVERY' (rev tacs) 1 st) of
        NONE => (cond_tracing trace (fn () => "PROOF FAILED for depth " ^ ...);
                 backtrack trace choices)
      | cell => (...timing...; Seq.make(fn()=> cell))
    end handle TERM _ => (...; backtrack trace choices)
```

(blast.ML:1261–1272, abridged tracing.)  The continuation is invoked
*inside* `prv`'s success case (940), so `backtrack` re-raises into the
newest surviving choice point and the search resumes where it left
off; recovery is rare because pruning removed most alternatives (paper
p.12).  The pruning guard at `nbrs = 1` (844–845) exists exactly so
this loop has something to resume.  HOL4: identical structure — replay
failure (including back-translation failure under option (a)) raises
back into the engine; only when `PROVE` finally escapes does
`BLAST_TAC` fail (raw_blast 1276–1277 maps it to the empty result).
PLAN §12 risk 2 (reconstruction divergence) is served by the same
telemetry: count and log PROOF FAILED events in the selftest.

---

## 7. Known limitations and where they surface

| limitation | code locus | HOL4 status |
|---|---|---|
| Wrappers ignored (`addss`, `addbefore`, …) — "this restriction is intrinsic" | blast.ML:16–17; the engine reads only netpairs (936–937) | carries over identically; document in BLAST_TAC's docfile; `AUTO_TAC` compensates by pairing blast with wrapper-aware search (clasimp.ML:147–159, Phase 3) |
| Weak elims rejected (premise loses the conclusion) | header 18–19; `delete_concl`/`ElimBadPrem` 441–447; warning 513–517 | carries over; Phase-0 `CLASSICAL_RULE` repair makes standard dests safe, as in Isabelle |
| Non-variable-conclusion elims silently skipped | `ElimBadConcl` 456–463, 518–522 (trace-only) | carries over |
| No higher-order unification; rules needing it unusable (e.g. ZF `apply_type`) | header 20–21; first-order `unify` 355–381 | carries over (search-side).  The *goal-translation* face of it — `TRANS "Function unknown's argument not a bound variable"` (1215–1219), "not a parameter" (1216), "Discrepancy among occurrences" (1230–1233), "argument not in normal form" (1236) — **vanishes**: HOL4 goals have no schematic variables |
| Too-flexible formulas get no rules | `isVarForm` 564–567, 576 | carries over (branch formulas can become Var-headed after instantiation) |
| Equality substitution can break reconstruction (affected formulas re-queued "but there's no way of putting it in the right place") | header 31–35; equalSubst 757–790; paper §7 p.9 | carries over; mitigated by making the HOL4 T1 affectedness test coincide with the branch test (§6.5) |
| Recursive-rule formula ordering can still go wrong ("WRONG" note) | header 24–29; 1088–1093, 1134–1137 | carries over |
| Duplication heuristic incomplete in principle (`md` propagation; header question at 7: "SKOLEMIZES ReplaceI WRONGLY: allow new vars in prems, or forbid such rules??") | 7–8, 823–826, 1082–1083 | carries over; note for seed-corpus review |
| Untyped search can find type-unsound proofs; caught at replay; residual Isabelle gap is axiomatic type classes | paper §6 p.8, p.12 | replay-caught likewise; **the type-class residue has no HOL4 counterpart** (§3.3) |
| Abs–Abs unification "can yield unifiers having dangling Bound vars" | 373–374 | carries over |
| Non-normalizing untyped terms theoretically possible | paper §6 p.8 ("(λx. xx)(λx. xx) … cannot simply be dismissed") | carries over; bounded by `lim` in practice |
| No timeout; user interrupts | absence in blast.ML; paper §1 p.2 | HOL4 may add an optional limit (§8-L) |
| Equality handling "simple and incomplete" overall | paper §10 p.14 | carries over (out of scope to improve in a faithful port) |

---

## 8. Genuine design choices for the HOL4 port (options only — no decisions)

**A. Typarg encoding.**  (a) per-constant typargs = encoded images of
the constant's generic tyvars (faithful; §3.3); (b) one typarg = whole
instance type; (c) none (search-precision loss documented in the paper
§6 p.8).  Sub-choice: canonical tyvar order source
(`Type.type_vars`-order vs sorted-by-name) — session-local either way.

**B. Replay instantiation architecture** (§6.3): (a) explicit
final-substitution replay with prototerm→term back-translation and a
Skolem↔variable registry; (b) metavariable-capable internal replay
layer shared with §6.2, grounded once at the end; (hybrid) (b) seeded
with (a)'s substitution.  This is the single largest divergence from a
mechanical port and interacts with G below.

**C. Assumption addressing during replay** (§6.4): (a) positional with
rotation tactics — faithful, preserves Isabelle's failure modes;
(b) by-term (α-match on the recorded prototerm rendering) — more
robust to order divergence, ambiguous under duplicate assumptions,
changes which proofs PROOF-FAIL; (c) positional with by-term fallback.

**D. asl/branch orientation conventions.**  Fix once: does front of
`asl` correspond to the branch head (recommended by HOL4's
cons-at-front habits, §6.4), and does the initial branch take `asl` in
list order or reversed?  Isabelle's initBranch is
`mkGoal concl :: hyps` with hyps in premise (oldest-first) order
(1274, 1259–1260); the HOL4 mapping of `asl` (newest-first by
convention) must pick the order that makes seed selftests match
Isabelle traces.

**E. Frees vs Skolem constants for goal atoms.**  HOL4 goal frees can
be translated as `Free` or as argument-less `Skolem`.  `Free` is
simpler; `Skolem` makes `orientGoal` (750–755, which prefers
eliminating Skolems over Frees) behave as it does for Isabelle
subgoal *parameters* vs global Frees.  In HOL4 the parameter/Free
distinction could be approximated as "free in `w`/`asl` only" vs
"free in the wider context" — or dropped.  Affects equality
substitution eagerness only.

**F. Hyp-subst affectedness test** (§6.5): (a) mirror hypsubst's
per-hyp aeconv-after-simp test (faithful, keeps the documented
divergence 234–235); (b) make the tactic compute affectedness exactly
as `equalSubst` does (aconv after substitution) — faithful-or-better,
removes a failure class; requires the tactic to be blast-private.

**G. Goal-directed `==>`/`!` handling.**  Isabelle's blast gets
`impI`/`allI` from the claset as ordinary intro rules (declared
`[intro!]`, HOL.thy:869–875) with *meta-level* premises that
`convertIntrPrem`/`skoPrem` digest.  Phase 0 deliberately seeded no
HOL4 impI/allI theorems (PLAN_phase_0.md §7: they are built-in steps
of the Phase-1 tactics).  BLAST must therefore handle Goal-formulas
headed by `==>`, `!`, (and by symmetry `~` is covered by notI =
`IMP_F`) via: (a) internal pseudo-rules — hardwired tableau rules
with pattern `Goal(p ==> q)` ↦ `[[Goal q, p]]` and `Goal(!x. P x)` ↦
`[[Goal (P sko)]]`, replay = DISCH-strip / GEN step, mirroring what
the Phase-1 safe steps do natively; or (b) trivial seed theorems
(`|- !p q. (p ==> q) ==> p ==> q`, `|- !P. (!x. P x) ==> $! P`) whose
canonical forms convert to exactly those tableau rules, with the
replay-side premise-strip (§6.2 T4) supplying the DISCH/GEN — uniform
with all other rules but the theorems are identities and their
replay-by-resolution makes no kernel progress before the strip.
Related sub-choice: are those rules blast-internal or claset-visible?

**H. Fidelity trimmings.**  Whether to keep dead/vestigial faithful
details: the `dup_intr` arm of fromIntrRule (dead, §4.2); the `rot`
flag (always true); `Trueprop` plumbing (vanishes, §1.2); the
`tryIt`/`fullTrace` debug surface (recommended for selftests).

**I. Where `REV_DUP_ELIM_RULE` lives** (§4.5): (a) in `clasetRules`
next to the other five derived rules (shared, tested there);
(b) blast-private.  Either way it is derived per-application from the
stored plain theorem, as Isabelle does — blast does not read the dup
netpair.

**J. Code sharing with the §6.2 engine.**  PLAN §6.2 designs one
internal AND/OR forest with metavariables for FAST/BEST/DEEPEN + aesop;
§6.3 keeps blast "a faithful separate engine".  Honest assessment of
sharing opportunities: (i) the prototerm language + destructive
trail-based unification is *blast-specific* — the forest needs
persistent/copyable states for best-first (aesop's copying treatment,
PLAN §6.4), which destructive refs actively obstruct; sharing the
datatype would force one side into an unnatural regime.  (ii) The
*replay-step vocabulary* (rule application with premise-strip +
rotation, contradiction/assumption closers, hyp-subst step) is needed
by both blast reconstruction (§6.2 T-steps) and the forest's kernel
replay — high-value shared module.  (iii) The rule-conversion front
door (claset candidate lookup + canonical-form destructuring) is
already shared via `clasetLib`/`clasetRules`.  (iv) If §8-B chooses
(b), blast additionally consumes the forest's state type as its replay
substrate — sharing by dependency, not by merging engines.
Recommendation-shaped observation (not a decision): share (ii)+(iii),
keep (i) private.

**K. Reserved-name handling** (113–121): (a) runtime check against the
ancestry that `*Goal*`/`*False*` are undeclared; (b) choose internal
head markers that are not `Const`s at all (extra prototerm
constructors) — slightly less faithful, removes the check and any
collision risk; (c) keep pseudo-Consts with names illegal in HOL4
source syntax.

**L. Config surface.**  Depth limit default 20 (blast.ML:79), trace,
stats — as refs/btraces; whether `BLAST_TAC` takes an optional depth
argument mirroring `(blast n)` = `Blast.depth_tac` (1313–1319; the
isar-ref recommends pinning the found depth for slow proofs); whether
to add an optional time limit (absent in the original, §7).

**M. Marker/abbreviation hygiene at entry.**  HOL4 goals may carry
`markerLib` abbreviations/labels in `asl`; Isabelle's entry pass is
`SELECT_GOAL + atomize_prems` (1289–1290).  Choose: translate markers
opaquely (they become unmatched literals — harmless but noisy),
strip/deal with them at entry, or fail fast.  Purely HOL4-side; no
Isabelle counterpart.

---

## 9. The Pelletier benchmark (paper §9, Table 1, pp.12–13) and the selftest

Baseline claims in the paper: leanTAP "proves the first 46 problems
[of Pelletier 1986] in under half a second each, while Fast_tac takes
several seconds for some of them and cannot prove others at all" (§3
p.4); blast "outperforms [Fast_tac and Best_tac] in most cases" (§9
p.12); benchmarks on a 300 MHz Pentium Pro, SML/NJ 110.0.3 (p.12).

Table 1 (p.13) — columns: search depth (the successful iterative-
deepening bound), branches created, search time (ms), recorded-tactic
count, verification (reconstruction) time (ms), Fast_tac time, leanTAP
time:

| problem | depth | branches | search ms | tactics | verify ms | Fast_tac | leanTAP |
|---|---|---|---|---|---|---|---|
| Pelletier 24 | 4 | 16 | 40 | 52 | 30 | 210 | 540 |
| Pelletier 26 | 3 | 17 | 30 | 43 | 40 | 430 | 0 |
| Pelletier 28 | 3 | 7 | 20 | 29 | 30 | 140 | 0 |
| Pelletier 34 (Andrews) | 7 | 100 | 200 | 431 | 2090 | failed | 24,170 |
| Pelletier 38 | 4 | 30 | 50 | 100 | 130 | 840 | 70 |
| Pelletier 43 | 5 | 24 | 50 | 48 | 60 | failed | 10 |
| Pelletier 46 | 7 | 15 | 610 | 48 | 50 | 2,090 | 590 |
| Pelletier 52 | 7 | 86 | 140 | 101 | 540 | 1,370 | n/a |
| Pelletier 62 | 1 | 17 | 10 | 46 | 40 | 130 | 0 |
| Halting II (Dafa 1997) | 7 | 2,015 | 10,990 | 1,086 | 8,310 | 220,000 | ∞ |
| Union-image | 3 | 12 | 90 | 40 | 50 | 560 | n/a |
| Inter-image | 3 | 12 | 90 | 36 | 50 | 1,430 (Best_tac) | n/a |
| Singleton I | 4 | 117 | 370 | 19 | 20 | ∞ | n/a |
| Singleton II | 4 | 115 | 370 | 19 | 10 | ∞ | n/a |

(∞ = still running after 5 min.)  The four set-theory problems
(p.13): Union-image `⋃x∈C (f x ∪ g x) = ⋃(f“C) ∪ ⋃(g“C)`; Inter-image
dually with ∩; Singleton I `(∀x∈S ∀y∈S. x ⊆ y) → ∃z. S ⊆ {z}`;
Singleton II `(∀x∈S. ⋃S ⊆ x) → ∃z. S ⊆ {z}`, where `y ∈ f“A ⇔ ∃x∈A.
y = f x`.  First-order rows were run in Isabelle/FOL but "also run in
Isabelle/HOL"; the set problems are Isabelle/HOL formulations (p.12).
Two qualitative observations to preserve: reconstruction often costs
more than search on long proofs (34: 200 vs 2090 ms; noted §9 p.13);
and the Singleton problems are solved *without* the `¬(?x ∈ UNIV)`
rule — adding it "greatly increases the search space" (p.13) — a
claset-sensitivity fact the seed corpus must respect.

**What the selftest should assert** (per PLAN §6.3 deliverables and
the repo test guidelines):

1. `BLAST_TAC` solves Pelletier 1–46 (HOL4 translations; propositional
   1–17, monadic/full-predicate 18–46 — the leanTAP-baseline set the
   paper invokes), plus 52 and 62, each within a generous per-goal
   time budget; all through `Tactical.VALID`.
2. Depth regressions from Table 1: the depth-`n` entry point (the
   `Blast.depth_tac` analogue) solves each Table-1 problem at its
   listed depth (24@4, 26@3, 28@3, 34@7, 38@4, 43@5, 46@7, 52@7,
   62@1) — locking the search discipline, penalties, and md logic
   (a wrong `log`/`lim` port shifts these depths immediately).
3. The four set-theory problems in `pred_set` form (with the seeded
   set rules), at their Table-1 depths (3, 3, 4, 4); assert Singleton
   I/II remain solved if/when a `UNIV`-membership rule enters the
   seeds — or document the sensitivity as an expected-tuning test.
4. Halting II behind a higher `HOLSELFTESTLEVEL` (large, 11 s search +
   8 s verify on 1999 hardware; cheap today but the translation is
   long).
5. Negative/robustness cases: a weak elim declared `[elim]` produces
   the "Ignoring weak elimination rule" warning and is skipped, not
   fatal; a goal needing HO unification fails cleanly; PROOF FAILED
   telemetry — at least one crafted goal exercising
   equality-substitution reordering, asserting either success via
   backtracking or clean failure with the diagnostic (PLAN §12 risk
   2); iterative deepening stops at the depth cap (default 20).
6. Strength-parity guard: every goal here must *stay* solved as the
   seed corpus grows (Phase 8 continuous benchmarking, PLAN §11);
   solved-goal counts and time budgets are assertions, not logs.

---

## 10. Cross-reference: engine pipeline vs PLAN §6.3

PLAN §6.3's four pipeline stages map onto this report: stage 1
(untyped translation, typargs) = §2–§3; stage 2 (lazy rule conversion,
weak-elim rejection) = §4; stage 3 (search) = §5 (PLAN's summary
"cascade: equality substitution → close against literals → safe rule →
defer" elides the two `closeF`/`closeFl` distinctions and the
unsafe-probe split in the defer step — §5.3 items 2–3 and 5 are the
precise form); stage 4 (reconstruction) = §6, where §6.3 records the
one place PLAN's sketch ("every step records the HOL4 tactic that
replays it … rotation … cheap assumption-reordering tactic") needs the
§8-B decision before it is implementable as written, because the
Isabelle tactics being imitated rely on proof-state metavariables for
the `upd = true` cases.
