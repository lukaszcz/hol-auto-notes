# Phase S research: HOL4 splitting idioms (Isabelle-style splitter)

All paths relative to repo root `/home/lukasz/dev/HOL/worktrees/isabelle-tactics`.
Line numbers verified against the current `isabelle-tactics` worktree.

## 1. Existing split-shaped theorems

### 1a. The if-split

boolTheory does NOT contain the Isabelle `if_split` /
HOL Light `COND_ELIM_THM` shape
`P (if b then x else y) <=> (b ==> P x) /\ (~b ==> P y)` literally.
What it has:

- `COND_RATOR` — `!b f g x. (if b then f else g) x = if b then f x else g x`
  (src/bool/boolScript.sml:2371-2401).
- `COND_RAND` — `!f b x y. f (if b then x else y) = if b then f x else f y`
  (src/bool/boolScript.sml:2404-2435).
- `COND_ABS` — `!b f g. (\x. if b then f x else g x) = if b then f else g`
  (src/bool/boolScript.sml:2438-2454).
- `COND_EXPAND` — `!b t1 t2. (if b then t1 else t2) = (~b \/ t1) /\ (b \/ t2)`
  (src/bool/boolScript.sml:2457-2501).
- `COND_EXPAND_IMP` — `!b t1 t2. (if b then t1 else t2) = ((b ==> t1) /\ (~b ==> t2))`
  (src/bool/boolScript.sml:2504-2529).  This is the split with P = identity
  on bool; the full split shape is `COND_RAND` composed with
  `COND_EXPAND_IMP` (one REWR each), trivially derivable.
- `COND_EXPAND_OR` — `(if b then t1 else t2) = (b /\ t1) \/ (~b /\ t2)`
  (src/bool/boolScript.sml:2532+), the split_asm dual.

Additionally, `bool` is itself in TypeBase with `case_const = COND`
scrutinising the condition (src/1/TypeBase.sml:63-79, `bool_info`;
case_def = `bool_case_thm` boolScript.sml:3539-3544, case_eq =
`bool_case_eq` boolScript.sml:3552, nchotomy = `BOOL_CASES_AX`, case_cong
= `COND_CONG`).  So the generic datatype mechanism below (1b) covers `if`
as the degenerate `bool` case: `TypeBase.case_pred_imp_of “:bool”` yields
the if-split (modulo `b = T`/`b = F` vs `b`/`~b` literal forms coming from
`BOOL_CASES_AX`).

The only "COND_ELIM" name in the tree is `Sub_and_cond.COND_ELIM_CONV`
(src/num/arith/src/Sub_and_cond.sml:264, exported in
src/num/arith/src/Arith.sig:7) — an arith-preprocessing conversion that
eliminates conditionals wholesale, not a theorem.

### 1b. Datatype case splits — THE SPLIT SHAPE ALREADY EXISTS

`Prim_rec` proves four related theorems from `{case_def, nchotomy}`:

- `prove_case_elim_thm` (src/1/Prim_rec.sml:1898-1987; comment 1892-1897):
  first-order, bool-valued branches:
  `ty_CASE x f1 .. fn <=> (?a1..ai. x = ctor1 a1..ai /\ f1 a1..ai) \/ ...`
- `prove_case_eq_thm` (src/1/Prim_rec.sml:1989-2004):
  `(ty_CASE x f1..fn = v) <=> (?a.. x = ctor1 a.. /\ f1 a.. = v) \/ ...`
- `prove_case_ho_elim_thm` (src/1/Prim_rec.sml:2012-2019; comment 2006-2011):
  `!f. f (ty_CASE x f1..fn) <=> (?a1..ai. x = ctor1 a1..ai /\ f (f1 a1..ai)) \/ ...`
  — Isabelle's `ty.split_asm` (disjunctive dual).
- `prove_case_ho_imp_thm` (src/1/Prim_rec.sml:2028-2043; comment 2021-2027):
  `!f. f (ty_CASE x f1..fn) <=> (!a1..ai. x = ctor1 a1..ai ==> f (f1 a1..ai)) /\ ...`
  — **exactly Isabelle's `ty.split`** (derived from ho_elim by negation +
  `NOT_EXISTS_THM`/`DE_MORGAN_THM`/`DISJ_EQ_IMP`).

For list these instantiate to
`!f. f (list_CASE l n c) <=> (l = [] ==> f n) /\ (!h t. l = h::t ==> f (c h t))`.
Verified shape for pairs in src/coretypes/selftest.sml:329-336: the
expected `case_pred_disj_of “:'b # 'c”` result is
`!P. P (pair_CASE p f) <=> ?q r. p = (q,r) /\ P (f q r)`.

All four are exported (src/1/Prim_rec.sig:54-57).

**TypeBase exposure.** tyinfo fields (record at src/1/TypeBasePure.sig:18-35,
accessors 56-81): ax, induction, case_def, case_cong, **case_eq**,
**case_elim**, nchotomy, size, encode, lift, one_one, distinct, fields,
accessors, updates, destructors, recognizers (+ simpls, extra).
Note carefully:

- the stored `case_eq` field = `prove_case_eq_thm`
  (src/1/TypeBasePure.sml:416-417, 444-445);
- the stored `case_elim` field = `prove_case_ho_elim_thm` — i.e. the
  quantified-`f` split_asm dual, NOT the first-order elim
  (src/1/TypeBasePure.sml:418-419, 446-447; same for the bool tyinfo at
  src/1/TypeBase.sml:69-73 and EnumType at src/datatype/EnumType.sml:388-390).
- Both fields are persisted per datatype (toSEXP/fromSEXP,
  src/1/TypeBasePure.sml:1093, 1159).

The **imp/split form is NOT a stored field**.  It is exposed only as an
on-demand derivation:
`TypeBase.case_pred_imp_of : hol_type -> thm`
(src/1/TypeBase.sml:236-237, sig at src/1/TypeBase.sig:73-77, alongside
`case_rand_of` and `case_pred_disj_of`).  Its only in-tree uses are
src/coretypes/optionScript.sml:834 (`option_imp_elim`, saving the
identity instance `option_CASE x v f <=> (x = NONE ==> v) /\ !x'. x = SOME x' ==> f x'`)
and doc/tests.  Nothing feeds it to any simpset.

### 1c. bossLib CaseEq / CasePred

Defined in src/1/TypeBase.sml, re-exported by bossLib
(src/boss/bossLib.sml:159-164, sig 55-60):

- `CaseEq "list"` = `case_eq_of` of the tyinfo (src/1/TypeBase.sml:216):
  `(list_CASE l n c = v) <=> (l = [] /\ n = v) \/ (?h t. l = h::t /\ c h t = v)`.
  Plus `CaseEqs`, `AllCaseEqs()` (216-227).
- `CasePred "list"` (src/1/TypeBase.sml:239-250): `case_elim_of` ISPECed
  with `\x.x` and beta-reduced on the LHS only, giving the first-order elim
  `list_CASE l n c <=> (l = [] /\ n) \/ (?h t. l = h::t /\ c h t)`
  (RHS betas are left to the surrounding simp).  Plus `CasePreds`,
  `AllCasePreds()` (250-260).  Usage tests:
  src/boss/theory_tests/casePredScript.sml.

Both are *rewrites handed manually to simp*, both are the disjunctive
(assumption-flavoured) orientation, and `CaseEq` only fires on
`_ = v` shapes; neither is the goal-oriented conjunctive split, and
neither is applied automatically.

## 2. How RW_TAC / SRW_TAC do if-splitting today

`PRIM_STP_TAC` (src/basicProof/BasicProvers.sml:1005-1043), the engine of
RW_TAC/SRW_TAC (STP_TAC 1095-1096, RW_TAC 1098-1102):

    THEN TRY (IF_CASES_TAC THEN REPEAT IF_CASES_TAC THEN ASM_SIMP)   (line 1034)

- `IF_CASES_TAC` (src/1/Tactic.sml:541-552) =
  `GEN_COND_CASES_TAC` (src/1/Tactic.sml:510-526) with a test rejecting
  conditions that are constants or nested conditionals.
  `GEN_COND_CASES_TAC` does
  `find_term (fn tm => P tm andalso free_in tm w) w`: **conclusion only**
  (never assumptions), and the conditional must occur *free* in `w` — an
  `if` whose condition mentions a quantifier-bound variable is skipped
  (no splitting under binders).  On success it case-splits with
  `EXCLUDED_MIDDLE`, substitutes `b = T`/`b = F` everywhere in the goal
  (`SUBST1_TAC (EQT_INTRO th)`), rewrites the residual
  `if T/F then _ else _` with `COND_CLAUSES`, and `ASSUME_TAC`s `b`/`~b`.
  No simplification of the condition into other assumptions beyond the
  follow-up `ASM_SIMP` in PRIM_STP_TAC.
- RW_TAC has **no datatype-case analogue**: nothing in PRIM_STP_TAC
  splits `list_CASE` etc.

`PRIM_NORM_TAC` (BasicProvers.sml:1069-1086, driving bossLib's NORM_TAC)
additionally uses `splittable` (1059-1061: goal contains a *free*
`is_cond` or `TypeBase.is_case` subterm) with
`SPLIT_SIMP = TRY (IF_CASES_TAC ORELSE CASE_TAC) THEN simp` (1067) on the
conclusion and `LIFT_SPLIT_SIMP` (1063-1065: move assumption to goal,
`CASE_TAC`, simp) on assumptions — again gated on the case/cond term
being free, so nothing under binders.

`CASE_TAC` (BasicProvers.sml:791-792) = `PURE_CASE_TAC` (686-688:
`first_subterm` of the conclusion whose case-scrutinee is free —
`scrutinized_and_free_in` 672-680) then `Cases_on` on the scrutinee, plus
cleanup `use_new_assum` (781-785) and `CASE_SIMP_CONV` (726, built from
case_def + distinct + one_one rewrites, 699-727).  `TOP_CASE_TAC`
(794-795) restricts to top-level; `FULL_CASE_TAC` (801-808) scans
`w::asl`.  All split *globally* via the nchotomy (the whole goal, not the
occurrence), and all fail when the scrutinee is not free (bound under a
binder).

`Cases_on` (BasicProvers.sml:324-325, engine `primCases_on` 293-321):
instantiates the TypeBase nchotomy; a variable bound by outer goal
quantifiers is handled by `FREEUP` (Bound case, line 314-316), but an
arbitrary scrutinee under a binder, or one occurring only inside a lambda,
is out of reach.  Splitting is global: every subgoal carries the
`l = h::t`-style assumption via `VAR_INTRO_TAC`/`TERM_INTRO_TAC`.

## 3. Rewrite-based conditional elimination fragments

src/simp/src/boolSimps.sml:

- `COND_elim_ss` (boolSimps.sml:284-301, commentary 218-232): convs
  `celim_rand_CONV` (243-264: guarded `REWR_CONV COND_RAND`, with an
  ordering test to avoid looping when lifting one cond through another)
  and `COND_ABS_CONV` (266-281: `COND_ABS` under lambdas); rewrites
  `COND_RATOR`, `COND_EXPAND`, `NESTED_COND` (235-241).  Strategy: lift
  conditionals to bool type, then write out with COND_EXPAND
  (the \/-form, not the ==>-form).  Known weaknesses per the header
  comment: conds under lambdas that are not directly boolean don't
  disappear, and output can be "completely incomprehensible".
- `LIFT_COND_ss` (boolSimps.sml:303-317): same lifting convs + COND_RATOR
  + NESTED_COND but *without* COND_EXPAND — pure hoisting to the boolean
  level, no case split.

Datatype analogue, opt-in only: `DatatypeSimps.lift_cases_typeinfos_ss`
(src/datatype/DatatypeSimps.sml:315-334) — case_rand/case_rator/case_abs
lifting with stop-consts to avoid case-of-case loops.  Pattern-match
counterpart: `patternMatchesLib.PMATCH_LIFT_BOOL_CONV` / `_ss`
(src/pattern_matches/patternMatchesLib.sig:169-179) lifts PMATCH to
boolean structure, and `PMATCH_CASE_SPLIT_ss`
(src/pattern_matches/patternMatchesLib.sml:2208-2209) is the PMATCH
compiler, not a splitter.

## 4. Weak vs strong congruences in today's simp

- `COND_CONG` (src/bool/boolScript.sml:2993-2999):
  `!P Q x x' y y'. (P = Q) /\ (Q ==> (x = x')) /\ (~Q ==> (y = y'))
   ==> ((if P then x else y) = (if Q then x' else y'))` — the *strong*
  (contextual) congruence.  It sits in `CONG_ss`
  (src/simp/src/boolSimps.sml:118-125, AND_IMP_INTRO-normalised), which
  is part of `bool_ss` (boolSimps.sml:214) and hence of srw_ss
  (`initial_simpset`, src/basicProof/BasicProvers.sml:1123-1127).  So
  HOL4 simp rewrites if-branches *with* the `b`/`~b` context — unlike
  Isabelle, whose default is `if_weak_cong` (no descent) + splitter.
- Datatype `case_cong` (strong, e.g. `option_case_cong` statement at
  src/coretypes/optionScript.sml:823-828; generated by
  `Prim_rec.case_cong_thm`, stored via TypeBasePure gen_datatype_info
  src/1/TypeBasePure.sml:430, saved as `<ty>_case_cong` at
  src/datatype/Datatype.sml:708) is **NOT in any simpset**.  Datatype
  augmentation of srw_ss goes through
  `TypeBase.register_update_fn (update_fn)` →
  `simpLib.tyi_to_ssdata` (src/basicProof/BasicProvers.sml:1243-1249),
  and `tyi_to_ssdata` (src/simp/src/simpLib.sml:1011-1026) takes only
  `TypeBasePure.simpls_of` (rewrs + convs; congs field empty).  simpls =
  case_def + distinct(+GSYM) + one_one + size
  (`gen_std_rewrs`/`add_std_simpls`, src/1/TypeBasePure.sml:397-410).
  RW_TAC's per-call augmentation `add_simpls`
  (BasicProvers.sml:877-878) uses the same `tyi_to_ssdata`.
  Consequently `SIMP_TAC (srw_ss()) []` simplifies inside `list_CASE`
  branches by *plain* congruence descent — no `l = h::t` context is ever
  available there.  The case_congs are used elsewhere: TFL termination
  extraction (src/tfl/src/Defn.sml:64) and the opt-in
  `DatatypeSimps.case_cong_typeinfos_ss` (DatatypeSimps.sml:389-404).

## 5. Name availability

- `splitLib`, `split_ss`, `SPLIT_TAC`: no structure/value with these
  names anywhere in src/ (checked `*.sml`/`*.sig`).  The only `SPLIT_TAC`
  in the repo is a script-local `val SPLIT_TAC = ...` in
  examples/machine-code/hoare-triple/set_sepScript.sml:60 (with a local
  `SPLIT_ss`, and a `SPLIT` set-separation constant) — not exported, but
  it means a bossLib-level `SPLIT_TAC` would shadow inside that one
  example script.  Closest existing exported names:
  `PMATCH_CASE_SPLIT_ss/„_CONV` (src/pattern_matches/patternMatchesLib.sig:384).
- Marker `Split`: free.  src/marker/markerScript.sml defines stmarker,
  unint, Abbrev, IfCases (line 104 — defined but with **zero users** in
  src/), AC, Req0, ReqD, Cong (114), Exclude, ExcludeFrag, FRAG (117),
  label, using, Case (183), hide, NoAsms, IgnAsm — no `Split`.  Phase-0
  claset markers are SIntro/Intro/SElim/Elim/SDest/Dest
  (src/auto/rules/clasetMarkerScript.sml:7-12).  simpLib consumes
  marker-tagged theorems in `process_tags`
  (src/simp/src/simpLib.sml:834-857: Cong, AC, Excl/ExclSF, SF frags) —
  the natural place to add a `Split th` tag.
- ThmSetData settype "split": free.  Registered settypes found:
  simp (BasicProvers.sml:1214), tfl_termsimp/tfl_WF/tfl_termsolve
  (src/num/termination/TotalDefn.sml:200,220,571), rule_induction/mono
  (src/IndDef/IndDefLib.sml:97,139), quotient* (src/quotient/src/quotient.sml),
  liftQt (src/transfer/liftLib.sml:21), defncong (src/coretypes/DefnBase.sml:208),
  userdef (src/1/DefnBaseCore.sml:112), compute (src/compute/src/computeLib.sml:394),
  difftool (src/real/analysis/Diff.sml:32), transfer_rule/safe/simp
  (src/transfer/transferLib.sml:786-788), gh130 (test).
- Attribute `[split]`: free.  Attribute names arise from settypes
  (ThmSetData.sml:228,294) plus clasetLib's explicit
  intro/sintro/elim/selim/dest/sdest
  (src/auto/rules/clasetLib.sml:709-712 via register_rule_attribute
  697-707).  No `split` anywhere.

## 6. TypeBase hook precedent (Phase 0 clasetLib)

src/auto/rules/clasetLib.sml:

- Contributors are keyed functions `tyinfo -> (spec * (name, thm)) list`
  kept in a `tyinfo_contributions` ref;
  `register_tyinfo_contribution (key, f)` (clasetLib.sml:576-584)
  installs/replaces a contributor and immediately reconciles the global
  claset against all existing TypeBase entries (`request_typebase_catchup`
  572-574, replayed lazily through the pending mechanism 524-536).
- New datatypes flow in via `typebase_update` registered with
  `TypeBase.register_update_fn` (clasetLib.sml:586-590; the hook itself
  is src/1/TypeBase.sml:94-99).  BasicProvers uses the same hook for
  srw_ss (BasicProvers.sml:1249), as does the CASE_TAC rewrite cache
  (BasicProvers.sml:716).
- Phase-0 contributions: constructor distinctness → safe-elim rules
  (`distinctness_contribution`, 633-647, using `distinct_elim_rule`
  602-614) and injectivity → safe-dest (`injectivity_contribution`,
  649-660), registered at 662-666.  TypeBase-derived rules are
  deliberately **never persisted as deltas**; they are recomputed on
  theory load/merge (comment + `claset_of_theory`/`merge_clasets`,
  684-690).  Persistence state is AncestryData with tag "claset"
  (544-553); lazy init replays pending updates against the collected
  typebase rules (`init_state` 524-532).
- A simp-side splitter can either (a) reuse this exact pattern
  (register_update_fn + derive-per-tyinfo, no persistence of derived
  thms), or (b) piggyback on BasicProvers' existing srw_ss update-fn
  path.  Constraint from src/auto/CLAUDE.md: `src/auto/rules/` must not
  depend on src/simp, so a simpset-fragment splitter belongs at
  src/simp or src/boss level (or clasimp/), not in rules/.

## 7. Deriving split theorems mechanically

Nothing needs to be invented: `Prim_rec.prove_case_ho_imp_thm
{case_def, nchotomy}` (src/1/Prim_rec.sml:2028-2043) already produces the
exact Isabelle split shape for any datatype, and both inputs are stored
tyinfo fields (`case_def_of`, `nchotomy_of`); the convenience wrapper is
`TypeBase.case_pred_imp_of : hol_type -> thm` (src/1/TypeBase.sml:229-237).
The dual (split_asm) is even cheaper: it is the stored `case_elim` field
itself (`case_elim_of`).  For `if`, either use the `bool` tyinfo through
the same code path or the two-rewrite composition
COND_RAND (boolScript.sml:2411) + COND_EXPAND_IMP (boolScript.sml:2511).
Costs: `case_pred_imp_of` re-derives ho_elim + rand thms each call
(Prim_rec.sml:2012-2019, 2028-2043) — a per-datatype cache (as clasetLib
does for TypeBase rules) is advisable.

Related but distinct machinery in src/datatype/DatatypeSimps.sml (all
opt-in, none in default simpsets):

- `mk_case_elim_thm_tyinfo` (98-118): despite the name this is the
  case-identity theorem `ty_CASE M (\a. c) ... (\n. c) = c` (COND_ID
  analogue), *not* a split; it is bundled into
  `mk_type_rewrites_tyinfo` (121-139).
- `mk_type_forall_thm_tyinfo` / `mk_type_quant_thms_tyinfo` (57-95):
  `!P. (!x. P x) <=> (!args. P (ctor1 args)) /\ ...` and the exists dual
  (Isabelle's split_paired_all analogue), exposed as
  `expand_type_quants_ss` (408-414).
- `mk_case_cong_thm_tyinfo` (142-192) + `case_cong_typeinfos_ss`
  (389-404): strong case congruences as an ssfrag.
- `mk_case_rand/rator/abs_thm_tyinfo` (195-297) + `lift_cases_*_ss`
  (304-334) and the un-lifting duals (341-375).
- `cases_to_top_RULE` (421-470): splits equations by instantiating the
  scrutinee variable with constructors — a rule-level splitter for
  definitions, not goals.

## Key implications for the plan

1. Split theorems: zero proof work per datatype — `case_pred_imp_of`
   (goal position) and `case_elim_of` (assumption position) already give
   both Isabelle orientations; only caching + a `[split]`-set +
   TypeBase-hook plumbing are new.
2. The splitter engine itself is the new part: HOL4 today has only
   (a) global nchotomy splitting on free scrutinees
   (IF_CASES_TAC/CASE_TAC — conclusion-oriented, fails under binders) and
   (b) loop-prone rewrite lifting (COND_elim_ss).  An Isabelle-style
   splitter (find `?P (c args)` at the propositional level, incl. under
   `!`-prefixes as Isabelle's `split_tac` does via lifting) does not
   exist.
3. Interaction with congruences differs from Isabelle: HOL4's simp
   already descends into if-branches with context (COND_CONG in bool_ss)
   and descends into case-branches without context; Isabelle pairs the
   splitter with *weak* congs.  The plan must decide whether the split
   fragment also installs weak case congs (Isabelle parity) or coexists
   with the current behaviour (COND_CONG context makes many if-splits
   unnecessary but does not surface case assumptions the way the
   splitter does).
4. All candidate names are free: `splitLib`, `split_ss`, `SPLIT_TAC`
   (only an unexported script-local clash in one examples/ file), marker
   `Split`, settype/attribute `split`.  The unused `IfCases` marker
   (markerScript.sml:104) is available/reclaimable too.
