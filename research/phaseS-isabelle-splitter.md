# Isabelle's Simplifier Splitter (`Provers/splitter.ML`) — porting research

> Research report, 2026-07-16.  Input to the Phase-S (splitter) part of
> `../PLAN.md`.  All cited Isabelle files are vendored at `../sources/`
> (mirror-isabelle commit `f7e02b7e1f31`).  HOL4 paths refer to this
> repository.  Citations are `file:line` into the vendored sources unless
> otherwise noted.

Primary sources read in full:
- `src/Provers/splitter.ML` (492 lines — the generic splitter functor)
- `src/HOL/Tools/simpdata.ML` (215 lines — HOL instantiation)
- `src/Doc/Isar_Ref/Generic.thy` (split method 180–233, simp modifiers
  258–338, split attribute 475–545, looper section 1041–1119)
- `src/Pure/raw_simplifier.ML` / `src/Pure/simplifier.ML` (looper
  storage/invocation only)
- `src/HOL/HOL.thy` (split/cong rule declarations, rule statements)

## 0. Terminology and rule format

A **split rule** is a theorem whose conclusion (after conversion to a Pure
equality by `Data.mk_eq`) has the form

```
?P (Const(key,·) $ a1 $ … $ an)  ==  rhs
```

i.e. a schematic *context variable* `?P` applied to an application of a
fixed head constant `key`; splitter.ML:5–7 states the intent: "Deals with
equalities of the form `?P(f args) = ...` where `f args` must be a
first-order term without duplicate variables."  Example
(HOL.thy:1161–1167):

```
if_split:     P (if Q then x else y) = ((Q --> P x) & (~Q --> P y))
if_split_asm: P (if Q then x else y) = (~ ((Q & ~P x) | (~Q & ~P y)))
```

The rhs is arbitrary (Generic.thy:1088–1097; the `case_prod` example there
is `?P (case_prod ?f ?p) <-> (ALL a b. ?p = (a,b) --> ?P (f a b))`).

The functor argument signature `SPLITTER_DATA` (splitter.ML:10–23)
requires: `mk_eq`, `meta_eq_to_iff`, `iffD`, `disjE`, `conjE`, `exE`,
`contrapos`, `contrapos2`, `notnotD`, `safe_tac` (see §3 for the HOL
instances).  From these the functor derives the object-logic constants: it
extracts `const_not` from the premise of `notnotD` (splitter.ML:45–47),
`const_or` from the major premise of `disjE` (49–51), and
`const_Trueprop = Object_Logic.judgment_name` (53).

## 1. The splitter algorithm, step by step

### 1.1 `split_thm_info` (splitter.ML:58–64)

Applies `Data.mk_eq` and destructs the conclusion as
`Pure.eq $ (Var _ $ t) $ c`.  `strip_comb t` must yield a `Const p` head,
otherwise `split_format_err ()` ("Wrong format for split rule",
splitter.ML:56).  Returns `(p, asm)` where `p = (key_name, key_type)` and
the **asm flag** is true iff the rhs `c` has the shape
`Const (s,_) $ _` with `s = const_not` (line 62) — i.e. *a split rule is
an `_asm` rule exactly when its right-hand side is a negation*.  This is
how `if_split_asm` (rhs `~ (...)`, HOL.thy:1169–1170) is distinguished
from `if_split`.

### 1.2 `cmap_of_split_thms` (splitter.ML:66–81)

Converts each split thm with `Data.mk_eq` (line 68), destructs the
conclusion as `_ $ (t as _ $ lhs) $ _` — so `t = ?P $ lhs` and `lhs =
Const(a,aT) $ args` (lines 70–71) — and builds an association list keyed
by the head-constant name `a`:

```
cmap : (string * (typ * term * thm * typ * int) list) list
info = (aT,       (* type of the key constant in the pattern *)
        lhs,      (* the pattern  Const(a,aT) $ args          *)
        thm,      (* the meta-eq split theorem                *)
        fastype_of t,  (* T := type of ?P(lhs), i.e. bool in HOL *)
        length args)   (* n := arity of the key constant in the pattern *)
```

Multiple rules for the same constant accumulate (`info::infos`, line 74);
wrong shapes raise `split_format_err` (77–78).

### 1.3 Goal decomposition: `meta_iffD` and `select`

`split_tac` (splitter.ML:356–374) first checks `has_fewer_prems i` (372)
and then resolves subgoal `i` with

```
meta_iffD = Data.meta_eq_to_iff RS Data.iffD    (* (P == Q) ==> Q ==> P *)
```

(splitter.ML:99; in HOL, `meta_eq_to_obj_eq RS iffD2`).  Resolution
against a subgoal with conclusion `Trueprop C` produces two subgoals:

1. subgoal `i`:   `C == ?Q`   (a Pure equality between *bool* terms —
   `Trueprop` is gone, so subsequent scanning works on the bare formula),
2. subgoal `i+1`: `Trueprop ?Q` — the schematic "result" that will become
   the new goal once `?Q` is instantiated to the split rhs.

`select` (splitter.ML:288–293) then reads subgoal `i`:
`Ts = rev (map #2 (Logic.strip_params goal))` (goal parameters, i.e.
`!!`-bound variables) and `_ $ t $ _ = Logic.strip_assums_concl goal` —
`t` is the *lhs of the meta-equality*, the term to be scanned.  Only the
conclusion is ever scanned; hypotheses are `split_asm_tac`'s business.
It returns `(Ts, t, sort shorter (split_posns cmap thy Ts t))`.

### 1.4 Position search: `split_posns` (splitter.ML:254–277)

`split_posns cmap thy Ts t` scans `t` recursively and returns one
"split pack" per admissible occurrence of any key constant.  State
carried down:

- `pos` — the path from the root, as a list of integers, *innermost step
  first* (each recursive step conses): descending into an `Abs` body
  conses `0` (line 259); descending into the `i`-th argument of an
  application (arguments numbered from 0 by `strip_comb`) conses `i`
  (line 263).
- `apsns` — one triple `(T, U, pos)` for *every* `Abs` on the path,
  where `T` = binder type, `U` = body type, `pos` = path to that body
  (lines 257–259, documented at 180–186).  Innermost-first while
  scanning.
- `Ts` — types of enclosing binders (goal parameters + entered `Abs`es),
  and `T' = fastype_of1 (Ts, t)` of the *whole scanned term* computed
  once at line 256.

At every non-`Abs` node, `strip_comb`; if the head is `Const (c, cT)`,
look up `c` in the cmap and run `find` over its infos (lines 265–274):
the candidate matches when

- `Sign.typ_instance thy (cT, gcT)` — the concrete constant's type is an
  instance of the pattern constant's type (line 270), and
- `fomatch thy (Ts, pat, t2)` where `t2 = list_comb (h, take n ts)` —
  simplified **first-order matching** (line 270).

`find` commits to the **first info that matches** for this constant at
this position; note that if the match succeeds but `mk_split_pack`
rejects (returns `[]`), later infos for the same constant are *not*
tried (lines 268–273 — `then mk_split_pack(...) else find tups`).
Arguments are always scanned recursively regardless of the head
(`fold iter ts`, line 276); the *head itself* is never scanned below
`strip_comb` (a beta-redex head or `Var`-headed application yields no
packs at that node, only its arguments are searched).

**`fomatch`** (splitter.ML:229–252) — "Simplified first-order matching;
assumes that all Vars in the pattern are distinct":

- pattern `Var (_, T)` matches *any* term, checking only
  `typ_match (T, fastype_of1 (Ts, t))` (238–239); no term binding is
  recorded, so duplicate pattern Vars would **not** enforce equal
  instances (hence the "without duplicate variables" caveat at line 7 —
  soundness is unaffected because the actual application goes through
  `compose_tac`, but a false-positive match would make the tactic fail
  rather than try another rule);
- `Free`/`Const` need identical names + type match (240–243);
- `Bound i` needs identical index (244–245);
- `Abs` and `$` recurse structurally (246–249);
- everything else fails (250).  So a pattern application can never match
  a term `Var`/`Abs` — the matching is entirely syntactic/first-order;
  there is no eta or beta flexibility here.  Var-headed *redexes* are
  rejected simply because the cmap lookup requires a `Const` head
  (line 265–266, 275).

### 1.5 `mk_split_pack` (splitter.ML:198–208) and `type_test` (163–168)

Given a matched occurrence, `mk_split_pack (thm, T, T', n, ts, apsns,
pos, TB, t)` (T = split thm's `?P`-body type, i.e. bool; T' = type of the
whole scanned term; `TB = type_of1 (Ts, t2)` = type of the redex;
`t = t2` the redex itself):

- if `n > length ts` — the key constant is **partially applied** —
  reject (line 199).  (Over-application `length ts > n` is fine: the
  extra arguments simply stay in the context; only `take n ts` counts as
  the redex.)
- `lev = length apsns`; `lbnos` = loose bound indices occurring in
  `take n ts` (only the matched arguments! line 201);
  `flbnos = filter (< lev) lbnos` — the loose bounds that refer to
  `Abs`-binders *inside* `t` (indices `>= lev` refer to goal parameters
  and are unproblematic, since the context `P` is later abstracted over
  all goal parameters).
- `tt = incr_boundvars (~lev) t` — the redex renumbered to top level
  (line 203; only sound/used when `flbnos = []`).
- If `flbnos = []`: the split can be applied **directly** — pack
  `(thm, [], pos, TB, tt)`, but only if `T = T'` (line 205): the whole
  scanned term must have the `?P`-body type (bool).  At the top level
  this always holds in HOL; during lift-recursion (see 1.7) it holds
  exactly when we have descended to a bool-typed binder body.
- Otherwise the position requires **lifting**; pack
  `(thm, rev apsns, pos, TB, tt)` (apsns now outermost-first, comment
  192–195), guarded by `type_test (T, flbnos, apsns)` (line 206):
  `nth apsns (min flbnos)` is the **innermost binder actually referenced
  by the redex**, and its body type `U` must equal `T` (= bool)
  (166–168) — "check if the innermost abstraction that needs to be
  removed has a body of type T; otherwise the expansion thm will fail
  later on" (163–165).  This is the *only* liftability restriction:
  Isabelle **can** lift over binders whose bound variables occur in the
  redex; what it cannot do is apply a split when, after entering all
  referenced binders, the exposed body is not of type bool.

### 1.6 Ordering: `shorter` (splitter.ML:279–281), `split_inside_tac`

```
fun shorter ((_,ps,pos,_,_), (_,qs,qos,_,_)) =
  prod_ord (int_ord o apply2 length) (order o apply2 length)
    ((ps, pos), (qs, qos));
```

Packs are sorted by (1) number of apsns ascending — *fewest binders to
lift over first*, always `int_ord`; then (2) `order` on the length of
`pos`.  `mk_case_split_tac int_ord` = `split_tac` prefers **shorter
paths, i.e. outermost occurrences** (line 379);
`mk_case_split_tac (rev_order o int_ord)` = `split_inside_tac` prefers
**innermost occurrences** (line 381).  Only the *first* pack of the
sorted list is ever used (line 364, `(thm, apsns, pos, TB, tt)::_`);
there is no backtracking over packs.

### 1.7 The lift theorem and descending under binders

`meta_iffD` and the lift infrastructure live inside `mk_case_split_tac`
(89–376).  The lift theorem is proved on the fly (splitter.ML:101–105):

```
lift:   (!!x :: 'b. Q(x) == R(x) :: 'c)  ==>  P(%x. Q(x)) == P(%x. R(x))
trlift = lift RS transitive_thm
      :  [| !!x. Q x == R x;  P(%x. R x) == C |]  ==>  P(%x. Q x) == C
```

(comment 93–96; `trlift` at 109; `abs_lift` — the subterm `%x. Q x` of
`lift`, used only for bound-variable renaming — extracted at 107).

**`mk_cntxt t pos T`** (splitter.ML:121–136) splits `t` at path `pos`
(consumed outside-in via `down (rev pos) t`, line 135): it returns
`(Abs ("", T, u1), u2)` where `u2` is the subterm at `pos` and `u1` is
`t` with that subterm replaced by `Bound 0` (all other parts
`incr_boundvars 1`, lines 130–133).  Used with `T --> U` (binder type →
body type of the abstraction being lifted over): the hole has the type
of the *whole abstraction* sitting at `pos`.

**`inst_lift`** (splitter.ML:315–323): with the pack's first (=
outermost) apsn `(T, U, pos)`,

1. `(cntxt, u) = mk_cntxt t pos (T --> U)` — `u` is the `Abs` at `pos`;
2. `trlift' = Thm.lift_rule (cprem_of state i) (rename_boundvars
   abs_lift u trlift)` — lift the rule over the subgoal's parameters
   and premises (and keep the user's bound-variable name);
3. instantiate `?P := abss Ts cntxt` (`abss = fold (Term.abs o pair "")`,
   line 83 — the context is additionally abstracted over all goal
   parameters `Ts`, because the lifted rule's `?P` is applied to them).

`lift_tac` (line 359) then does `compose_tac ctxt (false, trlift', 2) i`:
subgoal `i` (`t == ?C`) is replaced by the two premises of the
instantiated `trlift'`; unification of the conclusion `P(%x. Q x) == C`
against `t == ?C` binds `Q` := the body of the abstraction at `pos` and
`C := ?C`, leaving `R` schematic:

- new subgoal `i`:   `!!x. Q x == ?R x` — a meta-equality *under one
  more parameter*, whose lhs is the abstraction body;
- new subgoal `i+1`: `P(%x. ?R x) == ?C`.

`lift_split_tac` (360–371) runs `EVERY [lift_tac Ts t p,
resolve_tac [reflexive_thm] (i+1), lift_split_tac]`: subgoal `i+1` is
closed by **reflexivity**, instantiating `?C := P(%x. ?R x)` (with `?R`
still schematic, to be filled in by the recursion); then the whole
procedure **recurses on subgoal `i`** — `select` runs again on the new
goal (whose parameters now include `x`), positions and packs are
recomputed from scratch, and either another lift or the final split is
performed.  Thus the "lift-theorem tower" is built one binder per
iteration, outermost binder first; unreferenced binders *inside* the
innermost referenced one are never entered (they end up with
`flbnos = []` and are absorbed into the split context).

### 1.8 Applying the split theorem: `mk_cntxt_splitthm` / `inst_split`

**`mk_cntxt_splitthm t tt TB`** (splitter.ML:149–157) builds the context
for the split rule's `?P` as `Abs ("", TB, repl 0 t)` where `repl`
replaces **every occurrence of the redex** `tt` in `t` — compared up to
alpha/eta (`Envir.aeconv`) and adjusted for binder depth
(`incr_boundvars lev tt`, line 151) — by the hole `Bound lev`.  So one
split application rewrites *all* syntactically identical occurrences of
the redex at once, at any depth (including under binders that do not
capture variables of `tt`).

**`inst_split`** (splitter.ML:339–346): lift the split thm over subgoal
`i` (`Thm.lift_rule`), find its `?P` variable, and
`infer_instantiate ctxt [(P, abss Ts cntxt)]` — `infer_instantiate`
also computes the necessary *type* instantiation of `?P` (and hence of
the rule) from the context term; the remaining schematic variables of
the rule (the redex arguments `?Q ?x ?y`, and type variables fixed by
the `typ_instance` check of 1.4) are solved by unification during
`compose_tac ctxt (false, inst_split ..., 0) i` (line 367): the rule
now has **no premises** (arity 0), its conclusion
`P'(Const key $ ?args) == rhs` beta-eta-unifies with the goal
`t == ?C`, closing subgoal `i` and instantiating `?C` (and, through the
chain of reflexivity steps of 1.7, the original `?Q` of `meta_iffD`) to
the instantiated split rhs.  What remains is `meta_iffD`'s second
premise `Trueprop ?Q` — now the new, split, goal.

### 1.9 `split_tac` — overall composition (splitter.ML:356–374)

```
fun split_tac _ [] i = no_tac
  | split_tac ctxt splits i =
      ... cmap = cmap_of_split_thms splits ...
      COND (has_fewer_prems i) no_tac
           (resolve_tac ctxt [meta_iffD] i THEN lift_split_tac)
```

with `lift_split_tac` = select; if no packs, `no_tac` (line 363); if the
first pack has `apsns = []`, apply `inst_split` via `compose_tac`
(line 367); otherwise one `lift_tac` + `reflexive` + recursion
(lines 368–370).  Note `split_tac` performs **exactly one split** (of
one redex — though all identical copies of it) per invocation.

### 1.10 `split_asm_tac` (splitter.ML:389–417)

`split_asm_tac _ [] = K no_tac`; otherwise, with `cname_list` = key
constant names of the given (asm-form) splits (line 392), `SUBGOAL`:

1. `n = find_index (exists_Const (member cname_list o #1))
   (Logic.strip_assums_hyp t)` (394–395) — the first hypothesis
   *syntactically containing* any key constant; `n < 0` → `no_tac`
   (line 410).  (No matching check — if the constant occurs but no
   split position matches, the tactic fails as a whole.)
2. `DETERM (EVERY' [rotate_tac n, eresolve_tac [Data.contrapos2],
   split_tac ctxt splits, rotate_tac ~1, eresolve_tac [Data.contrapos],
   rotate_tac ~1, flat_prems_tac] i)` (410–414).  The contraposition
   dance, for goal `Γ, A ⟹ C` with redex-bearing assumption `A`:
   - `rotate_tac n` brings `A` to the front;
   - `eresolve contrapos2` (HOL `contrapos_pp`: `⟦Q; ¬P ⟹ ¬Q⟧ ⟹ P`)
     consumes `A` and yields goal `Γ, ¬C ⟹ ¬A` — the assumption is now
     in the conclusion, negated;
   - `split_tac` with the asm rule (e.g. `if_split_asm`): matching
     `?P(redex) = ¬A` gives `?P := λa. ¬A[a]`; the rule's rhs
     `¬((Q ∧ ¬?P x) ∨ (¬Q ∧ ¬?P y))` therefore instantiates to
     `¬((Q ∧ ¬¬A[x]) ∨ (¬Q ∧ ¬¬A[y]))` — note the **double negations**;
     new conclusion is that formula;
   - `rotate_tac ~1; eresolve contrapos` (HOL `contrapos_nn`:
     `⟦¬Q; P ⟹ Q⟧ ⟹ ¬P`) consumes the `¬C` assumption and un-negates:
     goal becomes `Γ, (Q ∧ ¬¬A[x]) ∨ (¬Q ∧ ¬¬A[y]) ⟹ C`; another
     `rotate_tac ~1` puts the disjunction first;
   - `flat_prems_tac` (402–409): while the first premise is a
     disjunction (`first_prem_is_disj`, 396–400, looks through
     `Pure.all` and checks `Trueprop (_ ∨ _)`), `eresolve disjE`
     (splitting the subgoal in two), `rotate_tac ~1` in both, recurse on
     `i+1`; then in each branch `REPEAT (eresolve [conjE, exE])` and
     `REPEAT (dresolve [notnotD])` — flattening conjunctions and
     existentials (from case rules like `option.split_asm`, whose
     disjuncts are `∃x. p = SOME x ∧ ¬P …`) and removing the double
     negations introduced above.  Net result for `if`: two subgoals
     `Γ, Q, A[x] ⟹ C` and `Γ, ¬Q, A[y] ⟹ C`.

So `split_asm_tac` genuinely **splits the subgoal** (Generic.thy:
1099–1107, and the warning at 1114–1118 that tactics assuming ≤1
subgoal after simp can break), and each branch's assumptions
proliferate (`Q`/`¬Q` plus the instantiated assumption).  Known
limitation, verbatim comment at line 401: "does not work properly if
the split variable is bound by a quantifier".

### 1.11 `gen_split_tac` (splitter.ML:419–424)

The `split` method's tactic: for each given rule *individually*,
dispatch on the asm flag from `split_thm_info` —
`(if asm then split_asm_tac else split_tac) ctxt [split] ORELSE'
gen_split_tac ctxt splits`.  The method wraps it in `CHANGED_PROP`
(splitter.ML:489).  Documented: split method applies a single step, in
conclusion or an assumption depending on the rule's structure
(Generic.thy:226–232); repeating `(split thms)` ≈ `(simp only: split:
thms)` (Generic.thy:319–321).

## 2. Declaration interface and looper integration

### 2.1 `add_split` / `add_split_bang` / `del_split` (splitter.ML:441–460)

`gen_add_split bang split`:

- `(name, asm) = split_thm_info split`; the theorem is stored
  context-free (`Thm.trim_context`, 444) and re-transferred at use time
  (446);
- the looper tactic is `split_asm_tac ctxt' [split']` if `asm`, else
  `split_tac ctxt' [split']`, and with `bang` additionally
  `THEN_ALL_NEW TRY o (SELECT_GOAL (Data.safe_tac ctxt'))`
  (447–451) — the aggressive variant runs the classical `safe_tac` on
  every subgoal after the split, so the goal really is divided into
  cases (Generic.thy:312–317);
- registered via `Simplifier.add_loop (split_name name asm, tac)`
  (453).

**Naming convention** (splitter.ML:438–439):
`"split " ^ (if asm then "asm " else "") ^ name ^ " :: " ^
string_of_typ T` where `(name, T)` is the key constant and its type
rendered with all `TVar`s as `"_"` (431–436).  Because
`Simplifier.add_loop` is an `AList.update` keyed on the name
(raw_simplifier.ML:865–868), re-declaring a split rule for the *same
constant, same asm-ness, and same type shape* **overwrites** the
previous one ("overwriting previous split tactic for the same
constant", Generic.thy:1076–1083), while different type instances
coexist.  `del_split` = `Simplifier.del_loop (split_name name asm)`
(splitter.ML:458–460); a mismatch produces the warning in
raw_simplifier.ML:870–875.

Attribute `[split]`, `[split!]`, `[split del]` (splitter.ML:465–476)
and the simp-method modifiers `split:` / `split!:` / `split del:`
(481–484; rail diagram Generic.thy:276–278) all funnel into
`gen_add_split`/`del_split`.

### 2.2 Looper storage and invocation

- Simpset field `loop_tacs : (string * (Proof.context -> int ->
  tactic)) list` (raw_simplifier.ML:290).
- `add_loop` = `AList.update` (adds *at the front* if new)
  (raw_simplifier.ML:865–868); `set_loop` replaces the whole list with
  one unnamed entry (861–863); merge of simpsets merges by name
  (369).
- Invocation: `loop_tac ctxt = FIRST' (map snd (rev loop_tacs))`
  (raw_simplifier.ML:419–420) — the `rev` means loopers run
  oldest-first ("tried after the looper tactics that had already been
  present", Generic.thy:1068–1071).
- The driver (simplifier.ML:326–329):

  ```
  fun simp_loop_tac i =
    generic_rewrite_goal_tac mode (solve_all_tac unsafe_solvers) ctxt i
    THEN (solve_tac i ORELSE TRY ((loop_tac THEN_ALL_NEW simp_loop_tac) i));
  ```

  i.e. rewrite to normal form; try the solver; only if the solver fails
  run the looper, and on success **restart the full simplification on
  every resulting subgoal**; the `TRY` means looper failure just ends
  the loop, with the simplified goal as result.  Documented at
  Generic.thy:1057–1060 ("applied after simplification, in case the
  solver failed … the simplification process is started all over
  again.  Each of the subgoals generated by the looper is attacked in
  turn, in reverse order.").
- `simp only:` maps to `{init = clear_simpset, attribute = simp_add}`
  (simplifier.ML:466–467, 474–475); `clear_simpset`
  (raw_simplifier.ML:408–410) keeps only `mk_rews`, `term_ord`,
  `subgoal_tac`, `solvers` and resets everything else — so `only`
  removes rewrite rules, congruence rules **and all loopers (split
  rules)** but keeps solvers (Generic.thy:299–305).  Hence
  `simp only: split: thms` = splitter with exactly the given rules.

### 2.3 `split_inside_tac`

Exported at splitter.ML:381 (and re-exported for HOL at
simpdata.ML:169); identical algorithm with the position order reversed
(innermost redex first, §1.6).  It is *not* wired to any attribute or
method syntax — ML-only.

## 3. The HOL instantiation (`simpdata.ML:153–166`)

```
structure Splitter = Splitter
( val context = context
  val mk_eq = mk_eq                       (* simpdata.ML:54–60 *)
  val meta_eq_to_iff = meta_eq_to_obj_eq
  val iffD = iffD2
  val disjE = disjE
  val conjE = conjE
  val exE = exE
  val contrapos = contrapos_nn
  val contrapos2 = contrapos_pp
  val notnotD = notnotD
  val safe_tac = Classical.safe_tac );
```

Exact theorem statements (all in HOL.thy):

| functor slot | HOL thm | statement | cite |
|---|---|---|---|
| `mk_eq` | — | `≡`-concl: identity; `_ = _`: `RS eq_reflection`; `¬P`: `RS Eq_FalseI`; else `RS Eq_TrueI` | simpdata.ML:54–60; `eq_reflection`: `x = y ⟹ x ≡ y` HOL.thy:722; `Eq_TrueI`/`Eq_FalseI` HOL.thy:1188–1189 |
| `meta_eq_to_iff` | `meta_eq_to_obj_eq` | `A ≡ B ⟹ A = B` | HOL.thy:280–283 |
| `iffD` | `iffD2` | `⟦P = Q; Q⟧ ⟹ P` | HOL.thy:328 |
| `disjE` | `disjE` | `⟦P ∨ Q; P ⟹ R; Q ⟹ R⟧ ⟹ R` | HOL.thy:437–443 |
| `conjE` | `conjE` | `⟦P ∧ Q; ⟦P; Q⟧ ⟹ R⟧ ⟹ R` | HOL.thy:522–527 |
| `exE` | `exE` | `⟦∃x. P x; ⋀x. P x ⟹ Q⟧ ⟹ Q` | HOL.thy:504–508 |
| `contrapos` | `contrapos_nn` | `⟦¬Q; P ⟹ Q⟧ ⟹ ¬P` | HOL.thy:415–419 |
| `contrapos2` | `contrapos_pp` | `⟦Q; ¬P ⟹ ¬Q⟧ ⟹ P` | HOL.thy:577–581 |
| `notnotD` | `notnotD` | `¬¬P ⟹ P` | HOL.thy:574 |
| `safe_tac` | `Classical.safe_tac` | classical reasoner's safe steps | simpdata.ML:165 |

So `meta_iffD` in HOL is `A ≡ B ⟹ B ⟹ A` (bool-typed), and
`const_not = HOL.Not`, `const_or = HOL.disj`, `const_Trueprop =
HOL.Trueprop` (derived per splitter.ML:45–53).

Related but distinct: `mksimps_pairs` maps an *assumption* headed by
`If` through `if_bool_eq_conj RS iffD1` (simpdata.ML:186–192;
`if_bool_eq_conj: (if P then Q else R) = ((P ⟶ Q) ∧ (¬P ⟶ R))`,
HOL.thy:1180–1182) — a top-level `if` in a premise is dissolved by the
rewrite-rule extractor, not the splitter.

Direct programmatic uses of `Splitter.split_tac` with `if_split` and
with datatype `split` theorems from `Ctr_Sugar.ctr_sugar_of` appear in
the list-comprehension simproc (List.thy:694, 711–715).

## 4. HOL4 mapping considerations

Setting: HOL4 goals are `term list * term` with genuinely free
variables; no schematic Vars, no meta-implication, no goal parameters;
conversions produce `|- t = t'`.

### 4.1 What becomes simpler

*The entire `meta_iffD`/schematic-`?Q` device disappears.*  Isabelle
needs `resolve meta_iffD` to turn "prove `C`" into "prove `C == ?Q`
with `?Q` to be discovered by unification".  A HOL4 conversion *is*
that: implement the splitter core as

```
SPLIT_CONV (splits : thm list) : conv        (* w  ↦  |- w = rhs *)
```

and obtain the tactic as `CONV_TAC (CHANGED_CONV (SPLIT_CONV splits))`
(or `SUBST_TAC`/`MATCH_MP_TAC (snd (EQ_IMP_RULE th))`-style; `CONV_TAC`
is the natural fit and directly answers (c) of the task: the resulting
equation `|- w = rhs` is applied by `CONV_TAC`, no substitution
machinery needed).

*No lift-theorem tower.*  Isabelle's `trlift` iteration exists solely
because instantiating `?P` and descending under a binder must be
expressed as resolution steps on a schematic goal.  In HOL4 the same
descent is exactly what the standard conversional machinery does:
`ABS_CONV`/`BINDER_CONV` prove `|- (\x. Q x) = (\x. R x)` from a proof
of `|- Q x' = R x'` where `x'` is a (variant/genvar) *free* variable —
`ABS`/`MK_COMB` are the primitive analogues of `lift`+`transitive`.
One pass suffices: compose `RATOR_CONV`/`RAND_CONV`/`ABS_CONV` along
the chosen path and apply the core split step at the end; no
re-scanning per binder (Isabelle re-runs `select` after each lift only
because each lift is a separate resolution step).

*No `Thm.lift_rule`, no `infer_instantiate`.*  The context is built as
an explicit lambda abstraction and the split theorem instantiated
directly: given redex `tt = c a1 … an` inside a bool-typed term `u`
(all of `tt`'s variables free at `u`'s level),

```
P0 := mk_abs (a, subst_all tt→a u)   (* replace ALL occurrences, cf. mk_cntxt_splitthm *)
th  := ISPECL [P0, a1', …] split_thm  (* or: PART_MATCH on the c-application:
        INST_TYPE from match_term (c ?x1…?xn) tt, then SPEC the args and P0 *)
th  := CONV_RULE (LAND_CONV BETA_CONV THENC RAND_CONV (TOP_DEPTH_CONV BETA_CONV)) th
```

yielding `|- u = rhs'`.  Two practical notes: (i) do **not** rely on
`HO_PART_MATCH` matching `P (c x y z)` against `u` — `?P` applied to a
non-bound-variable argument is not a higher-order pattern, and HO
matching would have to guess the occurrence set; the Isabelle algorithm
*never* solves for `?P` by matching either — it always constructs the
context term explicitly (`mk_cntxt_splitthm`) and only lets unification
solve the first-order argument variables.  Mirror that: explicit
context + `match_term` on the `c`-application for the argument/type
instantiation (the analogue of the `Sign.typ_instance` + `fomatch`
check, splitter.ML:270).  (ii) The "replace all alpha-equivalent
occurrences" semantics of `mk_cntxt_splitthm` (splitter.ML:149–157) is
free variable capture-safe term substitution in HOL4 once under the
right binders.

*Goal parameters.*  Isabelle strips `!!`-params and abstracts the
context over them (`abss Ts`, splitter.ML:83, 323, 346).  HOL4 goals
have no parameters, so this bookkeeping vanishes — **but** HOL4 goals
carry their universals as explicit `!x.` binders in the term, so an
occurrence that Isabelle would see at param-depth 0 sits under `!`
binders in HOL4.  The binder-descent machinery therefore triggers more
often (or the tactic layer should `REPEAT GEN_TAC`/strip first, which
is what the simplifier's normal goal handling already does).

### 4.2 When is a position liftable / not liftable — the exact rule

Verified from splitter.ML:198–208: Isabelle **does** lift over binders
whose bound variables occur in the redex (that is the whole point of
`apsns`); `exclude_vars`-style rejection does not exist.  The *only*
rejections are:

1. partially applied key constant (`n > length ts`, line 199);
2. no referenced binder and whole-term type ≠ `?P`-body type
   (`T = T'`, line 205 — vacuous at bool top level);
3. some binder referenced, and the **innermost referenced binder's body
   type is not bool** (`type_test`, 166–168, 206).

Rule 3 is the semantic essence, and it carries over verbatim to HOL4:
the split theorem's context `P` is bool-valued, so the equation
`P(c …) = rhs` can only be proved at a bool-typed subterm; if the redex
mentions a bound variable `x` of `\x. body`, the split must happen
*inside* that lambda, i.e. we need a bool-typed context between the
innermost such binder and the redex.  Isabelle insists that the *entire
body* of that innermost referenced binder is the context (type bool);
under that condition the composed conversion is:

```
concrete HOL4 algorithm for one occurrence:
  scan w (cf. §4.4) → path pos, list of binders B1…Bk on the path,
    subset {Bi} referenced by the redex's n matched arguments;
  let Bj = innermost referenced binder; require type_of(body of Bj) = bool
    (if no referenced binder: require the chosen context term = w, type bool);
  navigate: for the path from w down to body(Bj), map each step to
    RATOR_CONV/RAND_CONV (application steps; note strip_comb positions
    must be re-expressed as rator/rand spine steps) and ABS_CONV
    (binder steps — including *unreferenced* binders B1…B(j-1) on the
    way, which ABS_CONV handles by renaming to fresh frees);
  at body(Bj) (all needed vars now free): build P0 by abstracting all
    occurrences of the redex, instantiate the split thm, beta-reduce
    → |- body = rhs;  the conversional composition rebuilds
    |- w = w' by ABS/MK_COMB automatically.
```

Bound-variable escape is impossible by construction: `ABS_CONV`
introduces the variable as a free variable before we abstract the
redex, and re-binds it afterwards; the redex is only ever abstracted at
a level where all its variables are in scope.  (Where HOL4 could be
*stronger* than Isabelle: rule 3 could be relaxed to "some bool-typed
subterm of body(Bj) containing all redex occurrences", since a
conversion can stop at any bool node, whereas Isabelle is locked to
whole binder bodies by the shape of `lift`.  For parity, keep
Isabelle's rule; note the relaxation as a possible extension.)

Binders *inside* whose scope the redex sits but whose variables the
redex does not use are absorbed into `P0` exactly as in
`mk_cntxt_splitthm` — in HOL4, once we are at body(Bj), any deeper
lambdas simply remain part of the abstracted context (substitution
avoids capture; occurrences of the redex under such lambdas are still
replaced because the redex has no variables bound by them).

### 4.3 `split_asm` in HOL4 tactic terms

The entire contraposition dance (§1.10) exists because Isabelle's
splitter can only rewrite conclusions of schematic meta-equalities.  In
HOL4, assumptions are first-class:

```
SPLIT_ASM_TAC splits (A, i.e. first assumption containing a key const):
  th : |- A = A'        (* SPLIT_CONV applied to the assumption *)
  POP that assumption (PAT_X_ASSUM / UNDISCH-style), then
  STRIP_ASSUME_TAC (EQ_MP th (ASSUME A))
```

Two design choices, mirroring Isabelle's observable behaviour:

- Using the **plain** split rule on the assumption gives
  `A = (Q ⟹ A[x]) ∧ (¬Q ⟹ A[y])` — which does *not* split the goal.
  Isabelle's asm form produces, after its double-contraposition and
  `notnotD` cleanup, effectively `A ⇔ (Q ∧ A[x]) ∨ (¬Q ∧ A[y])` — a
  *disjunction* — and then `disjE`/`conjE`/`exE` flatten it into one
  subgoal per case with the case condition and instantiated assumption
  as new hypotheses.  In HOL4, apply `SPLIT_CONV` with the `_asm` rule
  to `~A`? Unnecessary: instantiate the `_asm` rule's context as
  `P0 := λa. A[a]` directly on `A` — `|- A = ¬((Q ∧ ¬A[x]) ∨ (¬Q ∧
  ¬A[y]))` — then normalize `¬(∨)`/`¬¬` (a fixed small rewrite:
  `DE_MORGAN_THM`, `NOT_CLAUSES`) to `|- A = (Q ∧ A[x]) ∨ (¬Q ∧ A[y])`
  — wait: careful — `¬((Q∧¬A[x])∨(¬Q∧¬A[y]))` normalizes to
  `(Q ⟹ A[x]) ∧ (¬Q ⟹ A[y])`, not a disjunction; the disjunction in
  Isabelle arises because the rule is applied to the *negated*
  assumption.  The faithful HOL4 derivation is: instantiate the asm
  rule with `P0 := λa. ¬A[a]` against `¬A`, i.e.
  `|- ¬A = ¬((Q ∧ ¬¬A[x]) ∨ (¬Q ∧ ¬¬A[y]))`, cancel the outer and
  inner double negations (`AP_TERM`-free: rewrite with `NOT_CLAUSES` +
  take `EQ_IMP_RULE`… simplest is `CONV_RULE` with
  `RAND_CONV (REWRITE_CONV [NOT_CLAUSES]) o AP_TERM boolSyntax.negation`
  — or just prove `A ⇔ (Q ∧ A[x]) ∨ (¬Q ∧ A[y])` once and for all by
  `EQ_TRANS` with the instantiated rule and a `¬(¬p ⇔ ¬q) ⇒ …`
  cleanup lemma), then `STRIP_ASSUME_TAC` on the disjunction.
- `STRIP_ASSUME_TAC` already performs the whole `disjE`+`conjE`+`exE`
  flattening (case split per disjunct, conjunct splitting, `CHOOSE` for
  existentials); the `notnotD` step corresponds to the double-negation
  cleanup above.  Assumption proliferation (each branch gets the case
  condition + instantiated hypothesis) is inherent and matches
  Isabelle, as does the "may split subgoals inside simp" caveat
  (Generic.thy:1114–1118).
- Selection of the target assumption: mirror `find_index
  (exists_Const …)` (splitter.ML:394) — first assumption containing a
  key constant syntactically, and fail (`no_tac`) if none.  Also mirror
  the documented weakness: no attempt to split an assumption whose
  redex is under a quantifier *within the assumption* unless the
  binder-descent conversion handles it (Isabelle's does for the
  conclusion-side `split_tac` call but the flattening "does not work
  properly if the split variable is bound by a quantifier",
  splitter.ML:401 — in HOL4 the conversion-based route under binders
  yields implication/conjunction structure under `!x.`, which
  `STRIP_ASSUME_TAC` will not case-split; matching Isabelle means
  simply accepting the same limitation).

### 4.4 Position search and packs in HOL4

Direct transcription: scan the goal term; at each `Const`-headed
application, `match_term (list_comb (c, pattern_args)) (list_comb (c,
take n args))` with a type-instance check on `c` (splitter.ML:270);
collect `(thm, #referenced-binders, path)` packs; sort by
(number-of-binders-to-enter, path-length) with `int_ord`
(outermost-first) for `split_tac` and reversed path order for
`split_inside_tac` (splitter.ML:279–281, 379–381); take the first pack
only.  HOL4's `match_term` is more permissive than `fomatch` (it does
enforce duplicate-variable consistency and handles types via
`match_type`), which is fine — `fomatch` is only a pre-filter.
The `n > length ts` partial-application rejection and the
first-match-wins-per-constant behaviour (including the
rejected-pack-shadows-later-rules quirk, §1.4) should be preserved or
consciously improved (trying remaining rules is strictly stronger and
arguably a bug fix; decide in the plan).

## 5. Behaviors that are easy to get wrong

1. **Ordering**: sort key is `(length apsns, length pos)` with the
   *first* component always ascending; only the path-length comparison
   flips between `split_tac` (outermost first) and `split_inside_tac`
   (innermost first) (splitter.ML:279–281, 379–381).  Only the first
   pack is used; no backtracking (364).
2. **One split per invocation; the looper restarts simp.**
   `split_tac` splits exactly one redex (all identical copies of it,
   §1.8), then `simp_loop_tac` re-simplifies every resulting subgoal
   from scratch (simplifier.ML:326–329).  Termination is *not*
   guaranteed by the splitter itself; it relies on the split rhs being
   simplified so the same redex does not reappear.  The `split` method
   additionally guards with `CHANGED_PROP` (splitter.ML:489).
3. **Weak congruence rules are the splitter's designed partner.**
   `if_weak_cong [cong]`: `b = c ⟹ (if b then x else y) = (if c then x
   else y)` (HOL.thy:1462–1465) — declared `[cong]` in HOL by default —
   blocks simplification inside the branches ("Prevents simplification
   of x and y: faster and allows the execution of functional
   programs", 1460–1461; Generic.thy:578–586: "may require an extra
   case split over the condition to prove the goal").  So the splitter
   sees *unsimplified* branches, and each branch is simplified only
   after the split, under the corresponding case assumption
   (`Q ⟶ P x` etc., with asm_full simp turning `Q` into a rewrite).
   The strong `if_cong` (HOL.thy:1453–1458) is available but not
   default.  `[split] = if_split` is declared at HOL.thy:1448.
   `cases_simp: (P ⟶ Q) ∧ (¬P ⟶ Q) ⟷ Q` (HOL.thy:1113–1116, in the
   default simpset via the `simp_thms`-area declarations around
   HOL.thy:1426–1445) collapses splits whose branches simplify to the
   same thing — porting the splitter without an analogous rule
   duplicates subgoals.  For datatype case constants the vendored
   sources do not contain the generating package — see open questions.
4. **Looper naming/overwrite semantics**: name = `"split [asm ]<const>
   :: <type-with-_-for-tyvars>"`; `add_loop` overwrites by exact name
   (splitter.ML:438–439, raw_simplifier.ML:865–868).  A HOL4 port that
   keys split rules only by constant name would wrongly merge distinct
   type instances; keying by `(const, asm, type-shape)` matches.
5. **`simp only:` must drop split rules** (loopers) as well as rewrites
   and congs, but keep solvers (simplifier.ML:466–475,
   raw_simplifier.ML:408–410; Generic.thy:299–305).
6. **`split!` semantics**: plain split leaves one subgoal with an
   implication/conjunction structure; the bang variant follows each
   split with classical `safe_tac` (TRY, per subgoal) to actually
   divide into cases (splitter.ML:447–451; Generic.thy:312–317).  Note
   the bang wrapper applies only to the *non-asm* tactic path — for an
   asm rule, `bang` is ignored (447–448: `if asm then split_asm_tac …`
   before the `bang` test).
7. **All identical occurrences are rewritten at once**
   (`mk_cntxt_splitthm` replaces every aeconv occurrence, 149–157) —
   replacing only the found occurrence changes behaviour (and can loop:
   the other copy is found again with the weak cong blocking its
   simplification).
8. **asm-rule detection is syntactic on the rhs head** (`rhs = ¬ _`,
   splitter.ML:62): a user split rule whose rhs happens to be a
   negation will silently be routed to `split_asm_tac` by `add_split`
   and `gen_split_tac`.
9. **`split_asm_tac` picks the first assumption by syntactic constant
   occurrence** (394) with no match check; if the occurrence is not
   actually splittable the whole tactic fails rather than trying the
   next assumption.  Also the double negations it must clean are
   introduced by its *own* context instantiation — forget `notnotD`
   (or its HOL4 double-negation analogue) and every asm split leaves
   `¬¬` junk.
10. **Redex argument scanning for loose bounds covers only the first
    `n` args** (`take n ts`, line 201): an over-applied redex's extra
    arguments live in the context, so their bound variables do not
    force lifting.

## 6. Exact failure conditions of `split_tac` (looper termination)

`split_tac` fails (returns the empty tactic result, leaving the goal
unchanged) iff any of:

1. empty split-rule list (`split_tac _ [] i = no_tac`,
   splitter.ML:356);
2. subgoal `i` does not exist (`COND (has_fewer_prems i) no_tac …`,
   372);
3. malformed split rule — `error` (not graceful failure!) from
   `split_format_err` in `cmap_of_split_thms` (56, 77–78);
4. `resolve_tac [meta_iffD] i` fails (373) — cannot happen for a
   normal object-logic subgoal;
5. `select` finds **no split pack** (`[] => no_tac`, 362–363): no
   occurrence of any key constant in the conclusion body, or every
   occurrence rejected by the §1.5 conditions (partial application;
   `T ≠ T'`; `type_test` failure), or the head-constant type is not an
   instance / `fomatch` fails (270);
6. `compose_tac` unification failure in `inst_split`/`inst_lift`
   (359, 367) — e.g. a `fomatch` false positive from duplicate pattern
   variables.

`split_asm_tac` additionally fails when no hypothesis contains a key
constant (`n < 0`, 410) or when any step of the DETERM'd sequence
(contraposition, inner `split_tac`, flattening) fails (410–414).

In the simp loop, looper failure is wrapped in `TRY`
(simplifier.ML:328), so the loop terminates with the rewritten goal;
the looper only runs when the solver has already failed on the
simplified goal.

## 7. Open questions

- **Weak congruence rules for datatype case constants**: the vendored
  sources contain neither `Product_Type.thy` nor the
  BNF/`Ctr_Sugar` package sources, so I could not verify whether/which
  `t.case_cong_weak` rules are generated and whether any is declared
  `[cong]` by default.  Verified facts are limited to: `if_weak_cong
  [cong]` (HOL.thy:1462–1465), `let_weak_cong` (stated, *not* declared
  `[cong]`; HOL.thy:1468–1471), and that datatype `split` theorems are
  obtained from `Ctr_Sugar.ctr_sugar_of` (List.thy:711–715).  The
  Generic.thy discussion (578–586) confirms the design principle
  (weak cong ⇒ extra case split) but not per-datatype defaults.  Needs
  a source check against the full Isabelle tree before the plan relies
  on it.
- **`Splitter.split_posns` export**: `exported_split_posns`
  (splitter.ML:295–296) exists for external consumers; I found no user
  in the vendored subset; whether HOL4 needs a public analogue is a
  plan decision, not a porting requirement.
- The exact interaction of a `split` rule whose key constant is
  polymorphic and registered at two different type shapes (two looper
  entries, both `FIRST'`-tried) is inferred from the naming scheme +
  `AList.update` semantics (438–439, raw_simplifier.ML:865–868); I did
  not find a test exercising it.
