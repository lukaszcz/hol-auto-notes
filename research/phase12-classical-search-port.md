# Phases 1–2 research: Isabelle classical step/search tactics — exact semantics and HOL4 port mapping

> Research report, 2026-07-16, for planning `PLAN.md` §6.1–6.2 (Phase 1:
> `SAFE_TAC`/`CLARIFY_TAC` step layer; Phase 2: `FAST_TAC`/`BEST_TAC`/
> `SLOW_TAC`/`DEEPEN_TAC` search layer on the metavariable engine).
> All citations resolve against the vendored Isabelle sources at
> `.agent-files/sources/` (mirror-isabelle commit `f7e02b7e1f31`).
> **Provenance note**: the original Phase-plan vendoring lacked several
> Pure files this report needed line-by-line.  They were fetched at the
> *same pinned commit* on 2026-07-16 and added to `sources/src/Pure/`:
> `search.ML`, `tactical.ML`, `tactic.ML`, `thm.ML`, `drule.ML`,
> `logic.ML`, `term.ML`, `goal.ML`, `unify.ML`, `pattern.ML`,
> `library.ML`, `General/alist.ML`, `Isar/object_logic.ML`
> (see the updated `sources/README.md`).

Structure follows the seven deliverables:
§1 combinator preliminaries; §2 kernel biresolution semantics; §3 exact
operational semantics of every tactic in `classical.ML:578–732` plus the
`search.ML` combinators; §4 wrapper semantics under search; §5 Phase 1
mapping table + design-choice register; §6 Phase 2 engine requirements +
design-choice register; §7 numeric constants; §8 verification of
`isabelle-classical-reasoner.md` §2 (one genuine discrepancy found).

Throughout, "state" means an Isabelle proof state: a theorem
`⟦B1;…;Bn⟧ ⟹ C` whose premises `Bi` are the open subgoals; a tactic is
`thm -> thm Seq.seq` (`tactical.ML:73`).

---

## 1. Tactical combinators (Pure/tactical.ML, Pure/goal.ML) — exact semantics

These fix the composition semantics everything in §3 relies on.  The
Phase-0 `NTactical` module already mirrors most of them; the entries
below are the normative reference.

| Combinator | Definition (cited) | Semantics |
|---|---|---|
| `THEN` | `Seq.maps tac2 (tac1 st)` (`tactical.ML:79`) | full backtracking product, lazy |
| `ORELSE` | `case Seq.pull (tac1 st) of NONE => tac2 st \| some => some` (`tactical.ML:85–88`) | *committed* choice: if `tac1` yields ≥1 result, `tac2` is never consulted, but **all** of `tac1`'s results remain available |
| `APPEND` | `Seq.append (tac1 st) (delayed tac2 st)` (`tactical.ML:94–95`) | keeps both alternative sets; `tac2` delayed |
| `THEN_ELSE` | `tactical.ML:101–104` | if `tac`'s seq nonempty, map `tac1` over it; else run `tac2` |
| `DETERM` | `Seq.DETERM` — first result only (`tactical.ML:121`) | chops the alternatives |
| `COND p t e` | `if p st then t st else e st` (`tactical.ML:125–126`); both branches eagerly *evaluated* as values (comment line 124) | state-predicate switch |
| `REPEAT_DETERM` | keep applying, take **first** result each round, succeed with the last state when `tac` fails (`tactical.ML:185–195`); never fails | deterministic saturation |
| `REPEAT_DETERM1` | `DETERM tac THEN REPEAT_DETERM tac` (`tactical.ML:212`) | like `REPEAT_DETERM` but **fails** unless ≥1 application succeeded |
| `CHANGED` | filter results with `not (Thm.eq_thm (st, st'))` (`tactical.ML:221–223`); `CHANGED_PROP` compares only prop (`:227–229`) | progress filter |
| `FIRST'`/`FIRST` | right fold of `ORELSE'` (`tactical.ML:164–167`) | committed first-success over the list |
| `FIRSTGOAL tac` | `tac 1 ORELSE tac 2 ORELSE … ORELSE tac n` (`tactical.ML:251–253`) | first subgoal (lowest index) where `tac` applies; commits to that goal but keeps that goal's alternatives |
| `SELECT_GOAL tac i` | if state has exactly one subgoal and `i=1`, run `tac` directly; else `restrict i 1` (rotate subgoal `i` to front and `protect`-mark the rest), run `tac` on the 1-subgoal state, `unrestrict` (`goal.ML:259–274`) | runs `tac` on a state whose *only* premise is subgoal `i`; instantiations of schematic Vars shared with the other (hidden) subgoals still propagate — the hidden goals live in the protected conclusion |
| `SUBGOAL f i` | passes the *term* of subgoal `i` to `f` (`tactical.ML:271–277`) | goal inspection |
| `PRIMSEQ f` | `f st handle THM _ => Seq.empty` (`tactical.ML:311`) | kernel-rule lifting |

`Object_Logic.atomize_prems_tac` (`Isar/object_logic.ML:208–213`)
rewrites the *premises* of subgoal `i`, converting nested meta
connectives (`⋀`, `⟹`) into object connectives (`∀`, `⟶`) — a no-op
when `Logic.has_meta_prems` is false.  HOL4 assumptions can never
contain meta structure, so this maps to a **no-op** in the port.

---

## 2. What `Thm.biresolution`/bimatch does operationally (deliverable 2)

### 2.1 Net retrieval and candidate ordering (bires.ML)

`Bires.biresolution_from_nets_tac ctxt ord pred match (inet, enet) i`
(`bires.ML:291–299`):

1. Decompose subgoal `i`'s term: `hyps = Logic.strip_assums_hyp prem`,
   `concl = Logic.strip_assums_concl prem` (hyps/concl *under* the
   parameter prefix, `logic.ML:523–534`).
2. Candidates = `Net.unify_term inet concl @ maps (Net.unify_term enet) hyps`
   — intro rules retrieved by conclusion, elim rules by each hypothesis;
   `unify_term` is an over-approximation (the strict match/unify
   distinction is enforced later, by the kernel call).
3. Order with `make_order_list ord pred` (`library.ML:1056–1060`):
   optional predicate filter, sort ascending by tag, and
   **suppress adjacent duplicates with equal tags** (`untag_list`,
   `library.ML:1050–1054` — the same elim rule retrieved via several
   hypotheses appears once; `Thm.biresolution` itself tries all
   assumptions).
4. `PRIMSEQ (Thm.biresolution (SOME ctxt) match ordered i)`.

Tags: `{weight, index}`; `tag_ord = weight, then index`, both ascending
(`bires.ML:97–102`).  At net insertion the weight is the rule's
new-subgoal count `Bires.subgoals_of brl` — `nprems` for an intro,
`nprems − 1` for an elim (`bires.ML:86–87`, `classical.ML:268–269`) —
and the index is `2k+1` for the unswapped form, `2k` for the swapped
form, `k` = declaration index, a *decreasing negative* counter
(`classical.ML:271–273`, `bires.ML:196–243`).  Hence candidate order =
**fewest new subgoals first; ties: most recent declaration first;
within one declaration the swapped form sorts before the unswapped**
(2k < 2k+1 for negative k).  The declaration-tag weight defaulted from
`kind_index` (`classical.ML:293–295`) and the optional user weight
(e.g. `ex_ex1I [intro! 2]`, `HOL.thy:895`) matter only for the
`extra_netpair`/`rule` method, which the port drops.

`bimatch_from_nets_tac = biresolution_from_nets_tac … NONE true`;
`biresolve_… false` (`bires.ML:302–303`).  `n_bimatch_from_nets_tac n`
passes `pred = (subgoals_of rl = n)`, match mode (`classical.ML:603–605`).

### 2.2 `Thm.biresolution` (thm.ML:2604–2620)

Given `(match, brules, i, state)`:

- `dest_state` splits state into `(stpairs, Bs, Bi, C)`: flexflex pairs,
  other subgoals, subgoal `i`, conclusion (`thm.ML:2153–2157`).
- `lift = lift_rule (cprem_of state i)` is computed **once** and applied
  to every candidate rule (§2.3).
- Per candidate `(eres_flg, rule)`: quick filter `could_bires`
  (`thm.ML:2595–2600`): `could_unify (concl_of rule, B)` and, for elims,
  first premise could-unify with some hypothesis.  Surviving candidates
  are composed by
  `bicompose_aux {flatten=true, match, incremented=true}
     (state, …, lifted=true) (eres_flg, lift rule, nprems_of rule)`,
  and the per-rule result sequences are concatenated **lazily in
  candidate order** (`thm.ML:2612–2620`).

### 2.3 Lifting over parameters and hypotheses (thm.ML:2161–2192, logic.ML:508–520)

`lift_rule goal orule` for goal `Bi = ⋀x1…xk. H1 ⟹ … ⟹ Hm ⟹ B`:

- All schematic variables of the rule get their indices incremented by
  `gmax+1` (freshness w.r.t. the state).
- Every rule premise `A` becomes `⋀x1…xk. H1 ⟹ … ⟹ Hm ⟹ A'`
  (`lift_all`), and the rule's conclusion likewise; in `A'` every
  schematic `?v : T` is replaced by `?v' : τ(x1)→…→τ(xk)→T` **applied to
  the bound parameters** `?v' x1 … xk` (`lift_abs`/`lift_all` end in
  `incr_indexes (rev Ts, inc)`, `logic.ML:508–520`).

This is the entire eigenvariable mechanism: a *fresh* rule unknown may
depend on the subgoal's parameters because it is explicitly applied to
them; a *pre-existing* state unknown `?y` (not applied to `xj`) can
never be instantiated with a term mentioning `xj`, because `xj` is a
bound (de Bruijn) variable inside `Bi` and any such assignment would
create a loose bound variable — ill-formed by construction.  There is
no runtime "eigenvariable check"; soundness is representational.

### 2.4 `bicompose_aux` (thm.ML:2484–2586)

With lifted rule `⟦A1;…;An⟧ ⟹ B'` (each `Ai`, `B'` carrying the copied
parameter/hyp prefix):

- Disagreement pairs: `dpairs = (B″, Bi″) :: rule-tpairs @ state-tpairs`
  where `strip_assums2` strips the identical lifted prefix from `(B', Bi)`
  (`thm.ML:2549–2550, 2440–2446`).
- **Ordinary resolution** (`res`, `thm.ML:2574–2579`): compute
  `Unify.unifiers (context, env0, dpairs)`; for each unifier
  `(env, tpairs)` build the new state
  `⟦Bs; A1σ; …; Anσ⟧ ⟹ Cσ`, where each new subgoal `Aiσ` is
  `flatten_params 0` -normalized (all parameters moved to the front and
  renamed apart, `logic.ML:568–575`) and `σ = env` is applied to the
  *whole* proof state (`addth`, `thm.ML:2495–2532`) — this is the
  in-goal instantiation HOL4 cannot perform.  Leftover flex-flex pairs
  join the state's `tpairs`.
- **Elim-resolution** (`eres_flg = true`, `thm.ML:2553–2571`): the
  (lifted) first premise `A1 = ⋀params. H1 ⟹ … ⟹ Hm ⟹ A1core` is
  decomposed by `Logic.assum_problems (nlift+1, A1)`
  (`logic.ML:619–625`); for each hypothesis `Hn` (in order, n = 1…m)
  that could-unify with `A1core`, unify `(Hn, A1core) :: dpairs`
  simultaneously; on success the new subgoals are the *remaining*
  premises `A2…An` with **assumption #n deleted** from each
  (`newAs (As, n, …)` → `Logic.flatten_params n`, `thm.ML:2536–2548`;
  `remove_params`, `logic.ML:556–566`).  That is the precise sense in
  which an elim rule "consumes" an assumption: the rule's major premise
  is solved against hypothesis `n` of the subgoal, and hypothesis `n`
  is removed from every new subgoal (deleted **by position**, so a
  duplicated assumption term loses only one copy).  All `(n, unifier)`
  combinations are enumerated as alternatives.
- **Match mode** (`match=true`): unifiers are computed exactly as
  above, then any unifier whose assignments are not strictly above
  `smax` (the state's maxidx) is discarded —
  `else if match then raise COMPOSE` (`thm.ML:2503–2510`).  Since the
  lifted rule's variables all have indices `> smax`, *matching =
  unification filtered to instantiate only rule variables (term and
  type)*.  Rule variables are instantiated freely in both modes.
- `Envir.above env smax` short-circuit: if only rule variables were
  assigned, the other subgoals `Bs` and `C` are *not* renormalized
  (`norm_term_skip`, `thm.ML:2499–2510`) — pure optimization.

Corollaries the port must reproduce:

1. A "safe" rule applied by matching can still leave rule variables
   (term or type) **uninstantiated** if they don't occur in the indexed
   pattern (conclusion for intros; major premise for elims): the new
   subgoals then contain fresh schematic Vars.  Isabelle's claset
   doctrine forbids such safe rules (`classical.ML:12–13`) but nothing
   enforces it.  (§5, choice C3.)
2. New subgoals replace subgoal `i` *in place, in premise order*.
3. Elim candidates try hypotheses left-to-right; rule candidates in tag
   order; the full alternative set is exposed to backtracking.

### 2.5 `assumption` vs `eq_assumption`, and the derived closers

- `Thm.assumption i` (`thm.ML:2214–2252`): for each hypothesis `Hn` of
  subgoal `i` (under its parameters), try to **unify** `Hn` with the
  subgoal's conclusion (plus the state's flexflex pairs); each unifier
  yields a state with subgoal `i` deleted and the unifier applied
  globally.  May instantiate state Vars — this is why `assume_tac` is
  in the *unsafe* `inst0_step_tac`, not among safe steps.
- `Thm.eq_assumption i` (`thm.ML:2256–2283`): find the **first**
  hypothesis α/η-convertible (`Envir.aeconv`) to the conclusion; delete
  subgoal `i`; no instantiation, single result.
- `assume_tac = PRIMSEQ ∘ Thm.assumption`; `eq_assume_tac = PRIMITIVE ∘
  Thm.eq_assumption` (`tactic.ML:72–75`).

Unification is Isabelle's full HOU with the Pattern fast path:
`Unify.unifiers` first tries `Pattern.unify` on all pairs (single
most-general unifier, no alternatives); only on `Pattern.Pattern`
(non-pattern problem) does it fall into `hounifiers` with search bound
`unify_search_bound = 60` (`unify.ML:32, 632–635`).

### 2.6 `Drule.size_of_thm`

`size_of_thm = size_of_term o Thm.full_prop_of` (`drule.ML:327`);
`full_prop_of` attaches the flexflex pairs to the prop (`thm.ML:501`);
`size_of_term` counts **atoms and abstractions** (applications add
nothing themselves) (`term.ML:468–473`).  On a `SELECT_GOAL`-restricted
state this measures the whole restricted state: all remaining subgoals
+ protected conclusion + flexflex pairs.

---

## 3. Exact operational semantics, classical.ML:578–732 (deliverable 1)

### 3.0 Building blocks (classical.ML:180–220)

- `contr_tac` (`:183–184`) =
  `eresolve_tac [not_elim] THEN' (eq_assume_tac ORELSE' assume_tac)`:
  consume some assumption `¬P` by elim-*resolution* (may instantiate),
  then close the resulting subgoal `P` by α-assumption, else by
  unifying assumption.  Closes the whole subgoal.
- `mp_tac` (`:186–189`) = `eresolve_tac [not_elim, imp_elim] THEN
  assume_tac`: with HOL's
  `imp_elim = P⟶Q ⟹ (¬R⟹P) ⟹ (Q⟹R) ⟹ R` (`HOL.thy:816`), the
  `imp_elim` branch consumes an assumption `P⟶Q`, produces subgoals
  `(¬R⟹P)` and `(Q⟹R)`, and requires the *first* to close by
  assumption; net effect: replace assumption `P⟶Q` by `Q` when `P` is
  among the assumptions.  The `not_elim` branch is `contr_tac` by
  resolution.
- `eq_mp_tac` (`:192`) = same with `ematch_tac`/`eq_assume_tac`: the
  instantiation-free version (safe).
- `swap_res_tac` (`:206–213`): `assume ORELSE' contr ORELSE'`
  biresolve against a given rule list, each rule paired with its
  swapped variant `(true, swap_rule rl)` — used by `Splitter`'s
  `safe_tac` parameter, not by the step tactics; port only if the
  splitter needs it.
- `dup_intr th = zero_var_indexes (th RS classical)` (`:216`);
  `dup_elim` (`:218–220`) rebuilds an elim so the consumed major
  premise reappears as an assumption of every remaining premise
  (Phase 0's `DUP_INTRO_RULE`/`DUP_ELIM_RULE` implement exactly this).

### 3.1 `safe_step_tac` (classical.ML:581–588)

```
fun safe_step_tac ctxt =
  appSWrappers ctxt
    (FIRST'
     [eq_assume_tac,
      eq_mp_tac ctxt,
      Bires.bimatch_from_nets_tac ctxt (safe0_netpair_of ctxt),
      FIRST' (map (fn tac => tac ctxt) Data.hyp_subst_tacs),
      Bires.bimatch_from_nets_tac ctxt (safep_netpair_of ctxt)]);
```

One safe inference on subgoal `i`, all by **matching** (§2.4 match
mode), in this fixed priority order:

1. close by α-assumption;
2. `eq_mp_tac`: contradiction-by-matching (`¬P` + `P` assumptions) or
   modus ponens on an assumption implication whose antecedent is
   literally an assumption;
3. 0-subgoal safe rules (`safe0` netpair) by bimatch — closes the goal;
4. hypothesis substitution — in HOL:
   `Hypsubst.hyp_subst_tac` (`HOL.thy:847`), which is
   `REPEAT_DETERM1 o FIRST' [ematch thin_refl, gen_hyp_subst_tac false,
   vars_gen_hyp_subst_tac false, (thin? — config off by default)]`
   (`hypsubst.ML:218–226`): deletes reflexive equations and *saturates*
   all substitutable assumption equalities `x = t`/`t = x` (Free or
   parameter; occurs-check; orientation; deletes the used equation —
   `inspect_pair`, `hypsubst.ML:83–104`, `gen_hyp_subst_tac:144–155`).
   NB the non-bool-equality guard at `HOL.thy:854–867` wraps *Pure's*
   `Context_Rules` wrapper (the `rule`/intuitionistic path), **not**
   the claset step tactics;
5. branching safe rules (`safep` netpair) by bimatch.

The whole `FIRST'` is transformed by the **safe wrappers** (§4).
`FIRST'` commits to the first nonempty category, but the chosen
category's alternative sequence (several rules / several target
assumptions) survives; it is the *callers* (`REPEAT_DETERM1` etc.) that
truncate.

### 3.2 `safe_steps_tac`, `safe_tac` (classical.ML:591–595)

```
fun safe_steps_tac ctxt =
  REPEAT_DETERM1 o (fn i => COND (has_fewer_prems i) no_tac (safe_step_tac ctxt i));
fun safe_tac ctxt = REPEAT_DETERM1 (FIRSTGOAL (safe_steps_tac ctxt));
```

- `has_fewer_prems n st ⟺ nprems st < n` (`search.ML:52`); the guard
  makes the repetition stop when subgoal `i` no longer exists (the
  index fell off the end).
- `safe_steps_tac i`: deterministically saturate *position* `i`: apply
  one safe step at `i`, then again at `i` (which is now the first child
  of the previous step) … — leftmost-descendant descent; fails iff no
  safe step applies at `i` initially.
- `safe_tac`: repeat `FIRSTGOAL safe_steps_tac` — find the first goal
  admitting a safe step, saturate at that position, rescan from goal 1.
  Deterministic (first results only); **fails if no safe step applied
  at all**; otherwise leaves the safe residue.  Acts on *all* subgoals.
  (The `safe` method additionally wraps `CHANGED_PROP`,
  `classical.ML:843–844`.)

### 3.3 clarify family (classical.ML:599–625)

```
fun n_bimatch_from_nets_tac ctxt n =
  Bires.biresolution_from_nets_tac ctxt Bires.tag_ord
    (SOME (fn rl => Bires.subgoals_of rl = n)) true;
fun eq_contr_tac ctxt i = ematch_tac ctxt [Data.not_elim] i THEN eq_assume_tac i;
fun eq_assume_contr_tac ctxt = eq_assume_tac ORELSE' eq_contr_tac ctxt;
fun bimatch2_tac ctxt netpair i =
  n_bimatch_from_nets_tac ctxt 2 netpair i THEN
  (eq_assume_contr_tac ctxt i ORELSE eq_assume_contr_tac ctxt (i + 1));
fun clarify_step_tac ctxt =
  appSWrappers ctxt
   (FIRST'
     [eq_assume_contr_tac ctxt,
      Bires.bimatch_from_nets_tac ctxt (safe0_netpair_of ctxt),
      FIRST' (map (fn tac => tac ctxt) Data.hyp_subst_tacs),
      n_bimatch_from_nets_tac ctxt 1 (safep_netpair_of ctxt),
      bimatch2_tac ctxt (safep_netpair_of ctxt)]);
fun clarify_tac ctxt = SELECT_GOAL (REPEAT_DETERM (clarify_step_tac ctxt 1));
```

Differences from `safe_step_tac`, all deliberate:

- **no `eq_mp_tac`** (no assumption-mp step; only
  assumption/contradiction closing via `eq_assume_contr_tac`);
- branching safe rules restricted: rules creating **exactly 1** subgoal
  (`n_bimatch … 1`) always allowed; rules creating **exactly 2**
  subgoals allowed only when, after application, subgoal `i` *or*
  subgoal `i+1` immediately closes by α-assumption or
  matching-contradiction (`bimatch2_tac` — the `THEN` distributes the
  check over every candidate application, so a rule application whose
  branches don't close is backtracked away and the next candidate
  tried; the `ORELSE` between positions commits to closing the left
  branch if possible).  Rules with ≥3 subgoals never fire;
- `clarify_step_tac` still gets the safe wrappers;
- `clarify_tac` is **single-goal** (`SELECT_GOAL`) and uses
  `REPEAT_DETERM` (not `…1`), hence **never fails** as a tactic (the
  `clarify` method wraps `CHANGED_PROP`, `classical.ML:834`).

`subgoals_of` counts the *rule's* new subgoals (elim: nprems−1), so for
an elim rule "2 subgoals" means 3 premises.  Note the swapped intro
variants in the safep net are elim-form and count accordingly.

### 3.4 Unsafe steps (classical.ML:633–655)

```
fun inst0_step_tac ctxt =
  assume_tac ctxt APPEND' contr_tac ctxt APPEND'
  Bires.biresolve_from_nets_tac ctxt (safe0_netpair_of ctxt);
fun instp_step_tac ctxt =
  Bires.biresolve_from_nets_tac ctxt (safep_netpair_of ctxt);
fun inst_step_tac ctxt = inst0_step_tac ctxt APPEND' instp_step_tac ctxt;
fun unsafe_step_tac ctxt =
  Bires.biresolve_from_nets_tac ctxt (unsafe_netpair_of ctxt);
fun step_tac ctxt i =
  safe_tac ctxt ORELSE appWrappers ctxt (inst_step_tac ctxt ORELSE' unsafe_step_tac ctxt) i;
fun slow_step_tac ctxt i =
  safe_tac ctxt ORELSE appWrappers ctxt (inst_step_tac ctxt APPEND' unsafe_step_tac ctxt) i;
```

- `inst0_step_tac`: the goal-*closing* unsafe steps — assumption by
  unification, contradiction by resolution, 0-subgoal **safe** rules by
  resolution (all may instantiate state Vars).  All alternatives kept
  (`APPEND'`).
- `instp_step_tac`: branching safe rules by resolution.
- `inst_step_tac`: both — "safe rules but by unification".
- `unsafe_step_tac`: the unsafe netpair by resolution.
- `step_tac i`: **first** try full `safe_tac` (all goals, whole-state,
  deterministic); if it made no step, apply the wrapper-transformed
  `inst_step ORELSE' unsafe_step` at goal `i`.  `ORELSE'` means: if any
  safe-rule-by-unification alternative exists at `i`, the unsafe
  netpair is *never* consulted (commitment, though all `inst_step`
  alternatives remain).
- `slow_step_tac i`: identical except `APPEND'` — unsafe-net
  alternatives stay available after `inst_step` alternatives are
  exhausted by backtracking.  That is the entire fast/slow difference.
- Note the asymmetry: `safe_tac` inside `step_tac` ignores `i` (acts on
  the whole state, rescanning from goal 1), while the unsafe rung acts
  on goal `i` only.  Under `SELECT_GOAL` (all §3.5 drivers) this
  collapses to "safe everywhere in the restricted state, unsafe at
  goal 1".

### 3.5 The solving drivers (classical.ML:658–697)

All five fail unless they **completely solve** the selected subgoal:
they run inside `SELECT_GOAL` with a search whose success predicate is
`Thm.no_prems` on the restricted state.  All five first run
`Object_Logic.atomize_prems_tac` on the subgoal (no-op in HOL4, §1).

```
fast_tac    = atomize_prems THEN' SELECT_GOAL (DEPTH_SOLVE (step_tac 1))          (:661–662)
best_tac    = atomize_prems THEN' SELECT_GOAL (BEST_FIRST (no_prems, sizef) (step_tac 1))   (:665–667)
first_best_tac = … BEST_FIRST (no_prems, sizef) (FIRSTGOAL (step_tac))            (:670–672)
slow_tac    = … SELECT_GOAL (DEPTH_SOLVE (slow_step_tac 1))                       (:674–676)
slow_best_tac = … BEST_FIRST (no_prems, sizef) (slow_step_tac 1)                  (:678–680)
astar_tac   = … ASTAR (no_prems, fn lev => fn thm => sizef thm + 5*lev) (step_tac 1)   (:687–691)
slow_astar_tac = … same with slow_step_tac 1                                      (:693–697)
```

`sizef = Drule.size_of_thm` in HOL (`HOL.thy:846`; §2.6).
`best_tac` expands the queue-min state with `step_tac 1`;
`first_best_tac` with `FIRSTGOAL step_tac` — the difference matters
because `step_tac i`'s *unsafe* rung works at goal `i`: `best_tac`
always attacks subgoal 1 of the popped state, `first_best_tac` attacks
the first subgoal where *anything* (including safe steps, which are
whole-state anyway) applies — "even a bit smarter" (`:669`); it is what
`force` uses (`clasimp.ML:172`).

### 3.6 The search combinators (search.ML) — exact semantics

- **`DEPTH_FIRST satp tac`** (`search.ML:38–48`): maintains an explicit
  stack of result sequences.  Pop lazily; a state satisfying `satp`
  that is not `Thm.eq_thm` to a previously returned solution is emitted
  (and remembered in `used`); otherwise push `tac st` on the stack.
  So: DFS through the alternative tree, unbounded, **suppressing
  duplicate solutions** (not duplicate intermediate states); solutions
  stream lazily.  `DEPTH_SOLVE = DEPTH_FIRST Thm.no_prems` (`:75`);
  `DEPTH_SOLVE_1 tac = DEPTH_FIRST (has_fewer_prems n)` with `n` the
  current premise count (`:69–72`).
- **`DEEPEN (inc, lim) tacf m i`** (`:147–154`):
  ```
  fun dpn m st =
    st |> (if has_fewer_prems i st then no_tac
           else if m > lim then no_tac
           else tacf m i ORELSE dpn (m+inc))
  ```
  iterative deepening by *restart*: try bound `m`; on **empty** result
  seq retry with `m+inc`; hard fail once `m > lim`; also fails if goal
  `i` disappeared.  `ORELSE` = if the bound-`m` search succeeds at
  least once, deeper bounds are never explored (even on later
  backtracking exhaustion).
- **`THEN_BEST_FIRST tac0 (satp, sizef) tac`** (`:180–196`): priority
  queue = min-heap of `(sizef st, st)` ordered by size then
  `Term_Ord.term_ord` on props (`Thm_Heap`, `:160–164`).  Loop: pop the
  min; **fully evaluate** `Seq.list_of (tac st)`; if any child
  satisfies `satp`, emit all satisfying children (as the result seq)
  and stop expanding; else insert all children and continue.
  Duplicates of the popped state at the heap minimum are deleted
  (`delete_all_min`, `:171–175`).  The initial state is checked against
  `satp` too (via `tac0 = all_tac`, `BEST_FIRST`, `:199`).  Result seq:
  the satisfying children of one expansion; further pulls resume with
  the *remaining list*, not the queue (no re-entry into the search).
- **`ASTAR (satp, costf) tac` / `THEN_ASTAR`** (`:226–249`): sorted
  *list* queue of `(level, cost, state)`; cost = `costf level state`
  computed at insertion with `level` = generation depth (parent's
  level+1, `:245`); insertion before the first entry of ≥ cost (LIFO
  among equal costs), with duplicate suppression only against the first
  equal-cost entry (`Thm.eq_thm`, `:227–230`).  Pop head, expand
  eagerly, same satp discipline as best-first.  With
  `costf = fn lev => fn thm => sizef thm + 5*lev` this is A* with
  g = 5·depth, h = state size.
- **`THEN_ITER_DEEPEN lim tac0 satp tac1`** (`:109–142`) — not used by
  the classical tactics (blast uses `DEEPEN`; meson uses this) but
  specified for completeness: queue entries `(k, np, rgd, q)` = cost so
  far, #prems, "first subgoal rigid (Var-free)" flag, alternatives seq.
  Expansion cost `k' = k + (np' − np) + 1` (`:133`); a node is cut when
  `k' + np' ≥ bnd` (admissible: every open premise costs ≥1); the next
  restart increment is lowered to the smallest useful one
  (`Int.min (inc, k'+np'+1−bnd)`, `:135`); restarts go `bnd+inc` with
  `inc` reset to 10 (`:119`), initial `(bnd,inc) = (0,5)` (`:140`),
  give up when `bnd > lim`.  On solving a subgoal (`np' < np`), Stickel
  pruning (`prune`, `:90–101`): if the immediate ancestor entry has
  `np = np'+1` and its first subgoal was rigid, its remaining
  alternatives are discarded (the solved subgoal shared no Vars with
  its siblings, so alternative proofs of it are redundant).

### 3.7 depth/deepen (classical.ML:700–732)

Header comment (`:700–703`): *"Changing APPEND to ORELSE below would
prove easy theorems faster, but loses completeness — and many of the
harder theorems such as 43."*

```
fun dup_step_tac ctxt = Bires.biresolve_from_nets_tac ctxt (dup_netpair_of ctxt);   (:708–709)
local
  fun slow_step_tac' ctxt = appWrappers ctxt (instp_step_tac ctxt APPEND' dup_step_tac ctxt);
in
fun depth_tac ctxt m i state = SELECT_GOAL
  (safe_steps_tac ctxt 1 THEN_ELSE
    (DEPTH_SOLVE (depth_tac ctxt m 1),
      inst0_step_tac ctxt 1 APPEND COND (K (m = 0)) no_tac
        (slow_step_tac' ctxt 1 THEN DEPTH_SOLVE (depth_tac ctxt (m - 1) 1)))) i state;
end;                                                                    (:712–720)
```

Reading of `depth_tac m i` (one *complete solve* of subgoal `i`, at
most `m` non-trivial unsafe expansions on any path):

1. Restrict to subgoal `i`.
2. If a safe step applies at position 1: saturate deterministically
   (`safe_steps_tac 1`), then `DEPTH_SOLVE (depth_tac m 1)` — solve all
   resulting goals, leftmost first, **same bound** (safe steps are
   free).
3. Otherwise, alternatives (in order):
   a. close goal 1 now by `inst0_step_tac` (assumption/contradiction/
      safe0-rule, by unification) — note **not**
      wrapper-transformed and free of charge; `APPEND`
   b. if `m > 0`: one step of `slow_step_tac'` — the
      wrapper-transformed `instp APPEND' dup_step` — then
      `DEPTH_SOLVE (depth_tac (m−1) 1)`.
      So both a branching safe-rule-by-unification (`instp`) and a
      *duplicating* unsafe rule (`dup` netpair — γ-rule retention:
      `dup_intr`/`dup_elim` keep the consumed formula available) cost
      one bound unit; all alternatives of both nets are kept.
4. Since 2./3.b end in `DEPTH_SOLVE (depth_tac … 1)`, the bound is
   per-path within the subtree; every subgoal created by a
   bound-consuming step is solved with bound `m−1`.

`clasimp.ML:136–141` (`nodup_depth_tac`) is the same code with
`unsafe_step_tac` in place of `dup_step_tac` (no duplication) — Phase 3
uses it inside `auto`; the Phase 2 engine should implement the shape
once, parameterized by the unsafe netpair choice.

```
fun safe_depth_tac ctxt m = SUBGOAL (fn (prem, i) =>
  let
    val deti = (*No Vars in the goal?  No need to backtrack between goals.*)
      if exists_subterm (fn Var _ => true | _ => false) prem then DETERM else I;
  in
    SELECT_GOAL (TRY (safe_tac ctxt) THEN DEPTH_SOLVE (deti (depth_tac ctxt m 1))) i
  end);                                                                  (:724–730)
fun deepen_tac ctxt = DEEPEN (2, 10) (safe_depth_tac ctxt);              (:732)
```

`safe_depth_tac m i`: restrict to subgoal `i`; optional safe
saturation; then solve everything by depth-bounded search.  **The
`deti` polarity is inverted relative to its own comment**: as written
since Isabelle2009, `DETERM` is applied when the goal *does* contain
schematic Vars — i.e. exactly when alternative proofs of one subgoal
could matter for its siblings, backtracking between the
`depth_tac`-solved subgoals is cut off.  Isabelle2005 had the
comment's semantics (`case term_vars prem of [] => DETERM | _ => I`).
Evidence: `Provers/classical.ML` at tags Isabelle2005 (lines 774–786)
vs Isabelle2009 (lines 784–794) — fetched and diffed 2026-07-16; the
refactoring that introduced `exists_subterm` flipped the branch and
every release since (2013, 2021, 2024, and the pinned master) carries
the inversion.  Consequences and the port decision: §6 (choice E10)
and §8 (discrepancy flag).

`deepen_tac ctxt n i`: iterative deepening of `safe_depth_tac` with
start bound `n`, increment 2, ceiling 10 (a start bound > 10 fails
immediately by `DEEPEN`'s `m > lim` test).  The `deepen` method default
start is 4 (`classical.ML:839–842`).  Note `deepen_tac` does **not**
atomize premises (unlike the §3.5 drivers) and applies no top-level
`SELECT_GOAL` beyond the one inside `safe_depth_tac`.

---

## 4. Wrapper semantics under search (deliverable 5)

### 4.1 Data structure and composition

`type wrapper = (int -> tactic) -> int -> tactic` (`classical.ML:239`).
Two name-keyed alists on the claset: `swrappers`, `uwrappers`
(`:244–245`).  `addSWrapper`/`addWrapper` insert with
`AList.update`: replace in place if the name exists, else **cons at the
front** (`classical.ML:532–545`; `General/alist.ML:48–53, 63–64`).
Application:

```
fun appSWrappers ctxt = fold (fn (_, w) => w ctxt) (#swrappers (rep_claset_of ctxt));
fun appWrappers  ctxt = fold (fn (_, w) => w ctxt) (#uwrappers (rep_claset_of ctxt));
```
(`classical.ML:529–530`).  `fold` applies the head first, so the
**newest wrapper is innermost** and the oldest outermost.

Derived combinators (`:556–574`) fix the composition discipline:

- safe: `addSbefore (name, tac1)` ↦ wrapper `fn tac2 => tac1 ORELSE' tac2`;
  `addSafter` ↦ `fn tac1 => tac1 ORELSE' tac2` — deterministic
  committed choice;
- unsafe: `addbefore` ↦ `fn tac2 => tac1 APPEND' tac2`; `addafter` ↦
  `fn tac1 => tac1 APPEND' tac2` — alternatives preserved;
- `addD2/addE2` = `addafter (dresolve/eresolve [thm] THEN' assume_tac)`
  (unification); `addSD2/addSE2` = `addSafter (dmatch/ematch [thm]
  THEN' eq_assume_tac)` (matching) (`:567–574`).

This is exactly the D13 `ntactic` wrapper contract (Phase 0
`app_safe_wrappers`/`app_unsafe_wrappers`).

### 4.2 Exact application points

| Site | Wrapped expression | Wrapper list |
|---|---|---|
| `safe_step_tac` (`:582`) | the whole 5-way `FIRST'` | safe |
| `clarify_step_tac` (`:617`) | the whole 5-way `FIRST'` | safe |
| `step_tac` (`:650`) | `inst_step_tac ORELSE' unsafe_step_tac` | unsafe |
| `slow_step_tac` (`:655`) | `inst_step_tac APPEND' unsafe_step_tac` | unsafe |
| `depth_tac`'s `slow_step_tac'` (`:713`) | `instp_step_tac APPEND' dup_step_tac` | unsafe |
| `nodup_depth_tac`'s `slow_step_tac'` (`clasimp.ML:130–132`) | `instp_step_tac APPEND' unsafe_step_tac` | unsafe |

**Not** wrapped: `inst0_step_tac` inside `depth_tac`/`nodup_depth_tac`
(`classical.ML:718`, `clasimp.ML:140`) — so in the deepen/auto searches
an unsafe wrapper (e.g. `addss`'s simp) is offered *as an alternative
to the bound-consuming branching step*, never to the trivial closers;
whereas in `step_tac`/`slow_step_tac` the wrapper wraps the whole
unsafe rung including `inst0`.  Safe wrappers reach every search
because every search calls `safe_steps_tac`/`safe_tac`, which calls
`safe_step_tac`.

Since `step_tac = safe_tac ORELSE appWrappers (…)`, an unsafe
`addbefore` wrapper runs **only when no safe step applies anywhere**
in the restricted state, and (being `APPEND'`) its alternatives
interleave with rule alternatives under the driver's backtracking.  A
safe `addSbefore` wrapper runs *before every single safe step attempt*,
inside the deterministic saturation loops — it must be cheap and must
fail fast, which is why `addSss` uses `addSafter` (try normal safe
steps first, simp only when they fail) and both clasimp wrappers guard
with `CHANGED` (`clasimp.ML:48–54`).

### 4.3 Wrapper tactics on goals containing schematic Vars

During Phase-2-style search the state contains Vars, and wrappers run
on it.  What Isabelle guarantees, precisely:

- The **rewriter treats goal Vars as rigid**: rewrite-rule matching
  instantiates only rule variables; rewriting never assigns to the
  goal's own Vars.
- Instantiation can still happen through **solvers**: conditional
  rewriting discharges side conditions with the *unsafe* solvers
  regardless of mode (`generic_simp_tac`:
  `generic_rewrite_goal_tac mode (solve_all_tac unsafe_solvers)`,
  `simplifier.ML:327`), and HOL's unsafe solver uses
  `resolve_tac`/`assume_tac` (`simpdata.ML:127–142`).  The `safe`
  variant differs **only** in the solver applied to the fully
  simplified residual goal (`solve_tac`, `simplifier.ML:322–324`), and
  HOL's safe solver uses `match_tac`/`eq_assume_tac`/`ematch_tac`
  (`simpdata.ML:146–151`).  Upstream states this explicitly:
  *"NOTE: may instantiate unknowns that appear also in other subgoals"*
  (`simplifier.ML:318`) and *"not totally safe: may instantiate
  unknowns …"* (`simplifier.ML:356`) — even `safe_asm_full_simp_tac`.
- Consequence for the port, to be designed into the Phase 2 engine now:
  the engine must expose a hook that runs an arbitrary goal-level HOL4
  `ntactic` on an engine node.  The node must be *materializable* as a
  HOL4 goal with metavariables rendered as marked fresh free variables
  (rigid by construction — a HOL4 tactic cannot instantiate a free
  variable), and the wrapper result lifted back (new goals re-abstract
  the markers; the validation is recorded for replay).  This gives
  exactly Isabelle's rewriter-level rigidity; what it *cannot* give is
  the solver-level instantiation Isabelle's `addss` enjoys.  Options at
  Phase 3, recorded now: (a) accept the (slightly weaker, still sound)
  rigid behavior — wrapper simp never instantiates engine metavars;
  (b) let the engine also offer designated "solver" steps that unify a
  goal against `refl`-style closers, recovering the common cases of
  Isabelle's unsafe-solver instantiation (`?x = t` side conditions);
  (c) full generality (wrapper returns instantiations) — requires a
  metavariable-aware tactic interface and is not recommended.
  Decision deferred to Phase 3; the Phase 2 engine only needs the
  materialization hook plus per-node wrapper-step recording (§6.6).

### 4.4 Replay interaction

A wrapper step inside the search is an *opaque* goal transformation.
For kernel replay (§6.6) the engine records the materialized input
goal, the chosen output (goal list, validation) — the validation IS the
replay for that step, so wrapper steps replay for free; they need no
re-execution and no re-unification.  (Contrast Isabelle, which has no
replay at all here — its searches run directly on kernel states; only
blast has the replay split, and blast ignores wrappers,
`blast.ML:16`.)

---

## 5. Phase 1 mapping: goal-level SAFE/CLARIFY (deliverable 3)

Setting: HOL4 goals `(asl, w)` contain **no metavariables and no
parameters-as-binders** (universally quantified goals keep an explicit
`!x.` in `w`; "parameters" appear only after a `GEN`-like step turns
them into fresh free variables).  Safe steps never instantiate goal
unknowns, so Phase 1 runs directly on goals as `ntactic`s (PLAN §1.3,
D13).

### 5.1 Collapse table (Isabelle notion → HOL4 notion)

| Isabelle | HOL4 Phase 1 | Status |
|---|---|---|
| proof state `⟦B1…Bn⟧⟹C` | `goal list` inside the ntactic layer; validations compose the proof | structural |
| subgoal `⋀xs. ⟦Hs⟧ ⟹ B` | goal `(asl, w)`: `Hs` ↦ `asl`, params ↦ (nothing — see C4) | see C4 |
| `Thm.eq_assumption` (α/η) | assumption `aconv` w | collapses (C2 for η) |
| `assume_tac` (unification) | same as above | **collapses**: no Vars ⇒ unification ≡ αβη-equality |
| `bimatch` vs `biresolve` on safe nets | one matching application primitive | **collapses** (no goal Vars to protect), *except* C3 |
| `contr_tac` vs `eq_contr_tac` | one `¬P`+`P` closer | collapses |
| `mp_tac` vs `eq_mp_tac` | one assumption-mp step | collapses |
| `inst0/instp/inst_step_tac` | not needed in Phase 1 (they only differ from safe steps on Var-containing states); Phase 2 engine implements them | deferred |
| `Object_Logic.atomize_prems_tac` | no-op | collapses |
| `SELECT_GOAL` | ntactics are per-goal by construction | collapses |
| `FIRSTGOAL` / goal indices / `has_fewer_prems i` guards | list traversal over the ntactic's goal list; the guard is exactly "position `i` still exists" | mechanical (C7) |
| `flat_rule`/atomized rule premises | Phase 0 canonical form (`clasetRules.canonical_form`) | done in Phase 0 |
| netpair lookup + tag order | `clasetLib.match_*_candidates` (tag-sorted) | done in Phase 0; add untag-style dedup check (C9) |
| swapped intro variants | Phase 0 `SWAP_INTRO_RULE` entries in the elim nets | done in Phase 0 |
| `hyp_subst_tacs` | `BasicProvers.VAR_EQ_TAC` slot (`claset_config`) | see C6 |
| safe wrappers (`appSWrappers`) | `app_safe_wrappers` around the whole FIRST-of-five | done in Phase 0 (D13) |
| `safe` method `CHANGED_PROP` | `NCHANGED` / failure semantics | see C8 |

### 5.2 What does *not* collapse — Phase 1 design choices (options only)

**C1 — matching primitive power.**  Isabelle matches with full HOU
(pattern fast path, bound-60 search; §2.5), one-way (rule vars only).
The seed corpus needs at least higher-order *pattern* matching
(`allI`-shape `∀x. ?P x` conclusions; `exE`'s `?P` major premise).
Options: (a) HOL4 `ho_match_term`-based matching (higher-order,
pattern-biased, as simpLib uses) — recommended baseline; (b) restrict
to HO patterns with explicit failure otherwise; (c) reimplement
Isabelle-style enumerative HO matching (multiple matchers ⇒ the
application point becomes a seq of alternatives — note Isabelle's
biresolution genuinely enumerates multiple unifiers as alternatives).
The choice determines whether a rule application site yields one or
several results; the ntactic type supports either.

**C2 — equality test for assumption/closing steps.**  Isabelle:
`aeconv` (α+η, terms kept β-normal by the kernel).  HOL4 `aconv` is
α-only.  Options: (a) `aconv` (fast; misses η-variants); (b)
`aconv` after βη-normalization of the compared pair; (c) full
αβη-conversion check.  Affects `eq_assume`/`eq_contr`/`eq_mp` and
`bimatch2`'s closing test uniformly — one shared primitive.

**C3 — safe rules whose variables are not fixed by the indexed
pattern.**  In Isabelle, matching such a rule *introduces fresh Vars
(term or type) into the goal* (§2.4 corollary 1).  Impossible at HOL4
goal level.  Options: (a) reject/warn at declaration time (enforce the
`classical.ML:8–16` doctrine mechanically: safe rules must have
`prem vars ∪ prem tyvars ⊆ concl vars` after preprocessing — for elims,
w.r.t. the major premise plus conclusion); (b) skip such rules at
application time (silently weaker than Isabelle on rule sets that abuse
the doctrine); (c) instantiate leftovers with fixed dummies (unsound
w.r.t. provability preservation — not really an option).  Note the
*swapped* variant of a safe intro binds the extra variable `r` to the
goal's conclusion, so swap entries are unaffected; and the seed corpus
(PLAN_phase_0 §7) satisfies the constraint.  Whatever is chosen must
also govern TypeBase/Phase 8 seeding audits.

**C4 — the shape of new subgoals from rule premises.**  Isabelle lifts
premises over parameters and hypotheses automatically: a premise
`⟦qs⟧ ⟹ Ci` yields subgoal with hyps `Hs @ qs`; a premise
`⋀x. P x ⟹ q` yields a subgoal with a *new parameter*.  HOL4 goals
are flat.  Options: (a) **lazy**: new goal = `(asl, ⟦qs⟧ ⟹ Ci)` with
the premise kept whole in the conclusion, and built-in safe steps
(`DISCH`-intro, `GEN`-intro analogues of Isabelle's `impI`/`allI`
meta-resolution, cf. PLAN_phase_0 §7) strip it on the next iteration —
maximally faithful to what the *user sees mid-clarify*, and the strip
steps are already required as claset-external built-ins; (b) **eager**:
strip `!`/`==>` into `asl` (choosing fresh names) at subgoal creation
(`STRIP_TAC`-style) — fewer steps, but changes the observable
step-count semantics of `clarify_step_tac` (a 1-subgoal rule whose
premise is `⟦qs⟧⟹Ci` would do the stripping "for free" where Isabelle
counts it inside the same lifted subgoal — note Isabelle's lifting IS
eager for premise-level `qs`, but new *nested* `!`/`==>` inside `Ci`
stay).  Recommendation direction (not decided): (b) for the lifted
prefix (`qs` into `asl`, matching Isabelle's lifting exactly) and (a)
for genuinely nested structure — this is precisely Isabelle's
semantics.  Sub-choices: fresh-name policy for eigenvariables
(Isabelle keeps the rule's bound name, renamed apart —
`flatten_params`/`rename_bvars`, `thm.ML:2536–2543`); new assumptions
appended after inherited ones (Isabelle's order: lifted hyps first,
rule-premise hyps after).

**C5 — elim consumption bookkeeping.**  Deletion of the consumed
assumption from every child (§2.4), *by position* (only one copy of a
duplicated assumption).  HOL4 `asl` is a list — mechanical, but the
port must pick assumption-*position* semantics (Isabelle tries
hypotheses in order, first-to-last, as backtracking alternatives) and
delete only the used position.  Also: swapped-rule applications consume
the negated assumption `¬C` the same way.

**C6 — hypothesis substitution slot.**  Isabelle's step (§3.1 item 4)
does, per invocation: delete `x=x` assumptions; substitute+delete
`Free = t` / `t = Free` (occurs-check, orientation), preferring
parameter (Bound) eliminations; loop to saturation (`REPEAT_DETERM1`).
`VAR_EQ_TAC` does one variable-equality elimination.  Options: (a) use
`REPEAT_DETERM1 VAR_EQ_TAC` + a `refl`-assumption deleter, and audit
the differences (orientation, which side counts as eliminable,
occurs-check semantics — `hypsubst.ML:83–104` vs
`BasicProvers.sml:842` region); (b) write a dedicated `HYP_SUBST_TAC`
port of `hypsubst.ML` (needed anyway for blast's reordering variant in
Phase 2/3, `hypsubst.ML:233ff`).  Either way the slot stays a
`claset_config` field (done in Phase 0).  Note HOL4 has no Bound-var
(parameter) case — parameters are frees, so the Free case covers it,
*but* the safety argument differs: Isabelle refuses to substitute a
Free that also occurs in other subgoals' shared context only implicitly
(frees in goals are locally fixed); HOL4 free variables in `asl`/`w`
may also occur in *other* goals of the same proof — substitution is
still sound per-goal (validation-checked), matching current
`VAR_EQ_TAC` practice.

**C7 — the driver loops.**  `SAFE_TAC` must reproduce: leftmost
position saturation with rescan (§3.2), i.e. over the ntactic's goal
list: find the first goal admitting a safe step, saturate its leftmost
descendants, rescan from the start; fail iff zero steps fired.
`CLARIFY_TAC` is per-goal, `REPEAT_DETERM`, never fails.  Mechanical
given `NTactical`, but the *residual subgoal order* is user-visible:
keep "children replace their parent in place, premise order".

**C8 — failure semantics of the user-facing tactics.**  Isabelle:
`safe_tac` fails on no-step; the `safe` *method* wraps `CHANGED_PROP`;
`clarify_tac` never fails, method wraps `CHANGED_PROP`.  HOL4
convention (e.g. `rw`/`fs` succeed vacuously; `STRIP_TAC` fails).
Options: (a) `SAFE_TAC`/`CLARIFY_TAC` fail unless they change the goal
(method semantics — recommended for HOL4 interactive use);
(b) tactic-level semantics (SAFE fails on zero steps, CLARIFY never
fails).  Also decide whether `SAFE_STEP_TAC`/`CLARIFY_STEP_TAC`
(single-step, useful for debugging clasets) are exported — Isabelle
exposes them as methods (`classical.ML:845–854`).

**C9 — candidate dedup.**  Reproduce `untag_list`'s equal-tag
suppression (one elim candidate per rule even when several assumptions
match the net key) — otherwise duplicate alternatives multiply the
backtracking space.  Phase 0's `candidate_order` should be checked for
this (its contract lists sorting only).

**C10 — `eq_mp_tac`'s implication forms.**  Isabelle's step keys on
the two fixed theorems `not_elim`/`imp_elim` — i.e. object `¬` and
`⟶` assumptions only.  HOL4: same two shapes (`~p`, `p ==> q`).
Decide whether `p <=> q` assumptions participate (Isabelle comment
`classical.ML:186–187` explicitly notes iff is *not* handled; parity
says no; the seeded `IFF_CELIM_THM` covers iff as a safe elim).

### 5.3 Phase 1 skeleton (for the plan, informative)

`SAFE_STEP_TAC cs : ntactic` = `app_safe_wrappers cs (NFIRST [assum_close,
mp_or_contr, safe0_match, hyp_subst, safep_match])` with the C1–C6
choices instantiated; `SAFE_TAC` per C7/C8; `CLARIFY_STEP_TAC` swaps
slots per §3.3 (`n_bimatch 1`, `bimatch2` with the C2 closing test, no
mp); the built-in `DISCH`/`GEN` intro steps sit in the safe0/safep
*built-in* lists per C4.  All consume the Phase 0 marker vocabulary via
`process_claset_tags`.

---

## 6. Phase 2 mapping: the metavariable engine (deliverable 4)

The engine executes §3.4–3.7 semantics on an internal representation;
kernel replay reconstructs the proof (PLAN §1.3, §6.2).  Requirements
derived line-by-line from the semantics above, then the design-choice
register.

### 6.1 State representation — what it must support

An engine **node** (proof state analogue) must determine:

- an ordered list of open **goals**; each goal: assumption list +
  conclusion + its **parameter context** (the eigenvariables in scope,
  §6.3);
- a shared **metavariable store**: term metavars (typed) and *type*
  metavars (rules are polymorphic; conclusion matching instantiates
  type vars too — Isabelle unifies types inside `Unify.unifiers`, and
  match mode protects state *type* vars equally, §2.4), with the
  current (idempotent) substitution;
- the **replay script** accumulated so far (§6.6);
- bookkeeping for search: size (for `sizef`), creation level (ASTAR),
  and an identity/ordering key (§6.5).

Goals within one node share metavars: instantiation during work on one
goal rewrites (lazily or eagerly) the others — Isabelle's global-env
behavior (`addth` normalizes the whole state, §2.4).  The user-facing
HOL4 goal seeds the engine with zero metavars; only rule application
creates them.

### 6.2 Rule application (both modes)

For a candidate `(eres_flg, th)` from a netpair against goal
`G = (params, asl, w)`:

1. Freshly rename `th`'s canonical variables (term+type) to new engine
   metavars, each recorded as **parameterized by `G.params`**
   (equivalently: permitted to depend on exactly `G.params`) — the
   engine analogue of `lift_rule` (§2.3).
2. Intro (`eres_flg = false`): unify rule concl with `w`.  New goals:
   the rule's premises, prefix-lifted per C4 into `(params', asl', w')`
   children, replacing `G` in place, premise order.
3. Elim (`true`): additionally unify the major premise's core with an
   assumption `asl[n]` (all `n`, in order, as alternatives), delete
   position `n` from children's `asl`.
4. **Match mode** (safe nets, used by the `safe_tac` component of
   `step_tac` — the engine needs matching *on Var-containing states*,
   this does not collapse as in Phase 1): run unification, then reject
   any solution that assigns to a metavar (term or type) created
   before this application (the `Envir.above smax` test, §2.4).
   Phase 0's dual `match_*`/`unify_*` candidate entry points
   anticipate exactly this split.
5. Each unifier yields a child node: substitution composed into the
   store; new goals in place; replay record appended (§6.6).

`inst0_step_tac`/`instp_step_tac`/`unsafe_step_tac`/`dup_step_tac` are
then this operation over safe0/safep/unsafe/dup parts with match=false;
`assume` = unify `w` with each `asl[k]`; `contr` = elim-apply
`NOT_ELIM`-analogue then assume; the safe steps of §3.1–3.3 run with
match=true and their Phase 1 implementations otherwise unchanged
(shared code, different mode flag — one more reason the step layer is
written over the engine's goal shape from the start).

### 6.3 Eigenvariable discipline (the invariant, precisely)

Isabelle's mechanism (§2.3): parameters are binders; pre-existing Vars
cannot capture them (representation); new Vars are functions applied to
them (lifting).  The HOL4 engine's parameters will be fresh free
variables (there is no goal binder), so the invariant must be imposed
explicitly:

> **Invariant.** Every metavariable `?m` carries the set (or ordered
> list) `allow(?m)` of engine parameters in scope at its creation.  A
> substitution binding `?m ↦ t` is legal iff every engine parameter
> free in `t` is in `allow(?m)` (plus occurs check).  Every parameter
> created by a `GEN`/`CHOOSE`-style step in goal `G` is fresh and is
> added to the scope of `G`'s descendants only.

Two standard realizations, both sound — **design choice E1**:

- (a) *Skolem-parameterized metavars* (Isabelle-style, dual-free):
  represent `?m` as a fresh variable applied to `allow(?m)`
  (`?m x1 … xk`); unification is then HO-pattern unification and the
  invariant is representational, no explicit check.  Natural if C1
  chose ho-pattern machinery; instantiations read back directly as the
  λ-abstractions replay needs.
- (b) *FO metavars + permission records* (blast/MESON-style):
  first-order unification with an explicit `allow`-set check at bind
  time.  Simpler unifier, engine-wide; the dual form (parameters
  recording which metavars may use them) is equivalent.

Corner Isabelle handles that the invariant must also cover: a
metavariable *shared between sibling goals* may be instantiated while
solving one sibling with a parameter of *that* sibling only if the
parameter was in scope at creation — the `allow` sets already encode
this; no extra cross-goal rule is needed.

### 6.4 Unification power — design choice E2

Isabelle: full HOU, bound 60, multiple unifiers as alternatives
(§2.5).  Options: (a) FO unification + HO patterns (blast's choice at
the term level; paper §7) — recommended baseline, loses some
higher-order rule applications `fast` can make (e.g. rules concluding
`?P ?x` applied non-pattern-ly); (b) pattern-only with failure; (c)
bounded enumerative HOU for parity.  Whichever is chosen, *matching*
mode is the same algorithm with the §6.2(4) filter.  Record explicitly:
this is a place where strict strength parity with `fast_tac` on
higher-order goals depends on (c); blast lives with (a) and Isabelle
documents the analogous limitation (`Generic.thy` "The Classical
Reasoner", function-unknown caveats).

### 6.5 Search drivers over nodes

- Node **expansion functions** = `step_tac`/`slow_step_tac`/
  `depth_tac`-step per §3.4/3.7, returning a lazy seq of child nodes
  (candidate order per §2.1; elim-assumption order per §2.4; `ORELSE`/
  `APPEND` structure preserved as seq concatenation vs committed
  choice).
- `FAST_TAC` = DEPTH_FIRST with satp "no open goals", duplicate-
  *solution* suppression (needs node equality, see below), stack of
  child seqs (§3.6) — a trail-based DFS is possible here, but see E3.
- `SLOW_TAC` = same over the slow step.
- `BEST_TAC`/`SLOW_BEST_TAC`/`FIRST_BEST_TAC` = §3.6 best-first: a
  min-heap keyed by `(size, tiebreak-order)`; **children of the popped
  node are computed eagerly and completely** (Isabelle's
  `Seq.list_of`); satisfying children end the search.  `size` = §2.6
  analogue: sum over open goals of (atoms + abstractions) of all
  assumptions and the conclusion, after substitution — pluggable
  (`claset_config.size_of` exists; extend to engine nodes).
- `ASTAR_TAC` variants = §3.6 ASTAR: sorted list, cost
  `size + 5·level`, LIFO among equal cost, weak dedup.
- `DEEPEN_TAC` = `DEEPEN (2,10)` restarts over `safe_depth_tac`
  structure (§3.7): safe saturation, then the `depth_tac` recursion
  with the dup netpair, `inst0` un-wrapped and free, bound decrement
  only on the `instp APPEND dup` step.  Keep the `nodup` variant
  parameterization for Phase 3.
- **State persistence — design choice E3**: BEST_FIRST/ASTAR hold many
  live nodes ⇒ the store must be **persistent** (pure substitution
  maps) or nodes must be cheaply copyable.  A destructive
  trail-and-undo engine (blast-style) supports only the DFS drivers.
  Options: (a) persistent env everywhere (uniform; enables sharing
  with the aesop forest, PLAN §6.2/6.4 — recommended direction);
  (b) trail for FAST/SLOW + persistent for BEST/ASTAR (two machineries
  — against "one shared representation").
- **Node equality/dedup — design choice E4**: needed by DEPTH_FIRST
  (solution dedup), BEST_FIRST (`delete_all_min`), ASTAR (equal-cost
  dedup).  Isabelle uses `Thm.eq_thm`/`term_ord` on the whole prop.
  Options: α-comparison of substituted goal lists (faithful, costly);
  hashing on a normalized print; or dropping dedup (semantics change:
  more duplicate work, same solutions — measurable, not silent).

### 6.6 Replay-script recording

Per applied step, record enough that a **HOL4 tactic replay on the
original goal succeeds with zero search**.  Unlike Isabelle (which
re-unifies at replay — blast even found delivering unifiers to be no
faster, paper §8.2), HOL4 replay cannot re-unify: mid-replay goals
cannot hold metavars, so **every step must be replayed fully
instantiated**.  Required record per step (tree-structured, one node
per goal):

1. step kind: rule application (which original theorem, which stored
   variant — plain/swapped/dup/make-elim — and the elim flag), or
   built-in (assume-close k, contradiction (k,l), mp, hyp-subst,
   DISCH/GEN/CHOOSE built-in, wrapper step);
2. target goal position, and for elims the consumed assumption
   position `n`;
3. the **final instantiation** of the metavars created at this step —
   computed once at search success by walking the final store; replay
   applies the rule via explicit instantiation
   (`PART_MATCH`-with-supplied-instance / `EXISTS_TAC witness` for
   `exI`-shaped intros / `INST_TYPE` for type metavars) rather than by
   matching;
4. eigenvariable names introduced (for `GEN`/`CHOOSE` replay
   stability);
5. for wrapper steps: the recorded `(goal list, validation)` pair
   (§4.4) — the validation is the replay.

Leftover metavars in a successful final state (Isabelle tolerates
schematic leftovers and flexflex pairs; `Goal.finish` smashes them):
**design choice E5** — ground them arbitrarily at success
(any closed term of the type, e.g. `ARB`; leftover *type* metavars to
an arbitrary type) before extracting witnesses.  Grounding is sound
(the proof is parametric in them) but the choice should be
deterministic for reproducibility.

Replay failure handling — **design choice E6**: with fully recorded
instantiations, replay failure indicates an engine bug rather than a
divergence (there is no untyped abstraction as in blast), so options:
(a) hard error with diagnostics (recommended; keeps the engine honest);
(b) blast-style backtrack-into-search on replay failure (needed for
blast in §6.3 of the PLAN, where the search is untyped; for this
engine it would mask bugs).

### 6.7 Remaining Phase 2 design choices

- **E7 — atomize/normal form at entry.**  The §3.5 drivers atomize
  subgoal premises (no-op, §1) — but the engine must fix its *goal
  intake* normal form: strip the HOL4 goal into engine shape
  identically to Phase 1's C4 choice.
- **E8 — `step_tac`'s whole-state `safe_tac`.**  Inside the drivers,
  safe steps act on all goals of the (restricted) node while unsafe
  steps act on goal 1 (§3.4 note).  Mechanical, but must be encoded in
  the expansion function, not left to the driver.
- **E9 — sizef pluggability** (already promised by `claset_config`);
  decide whether flexflex-analogue (unresolved constraints) counts —
  Isabelle counts tpairs via `full_prop_of` (§2.6); with E2(a) there
  are no flexflex pairs, so: count nothing extra.
- **E10 — the `safe_depth_tac` DETERM inversion (§3.7).**  Options:
  (a) implement the *intended* 2005 semantics (`DETERM` only when the
  restricted goal is metavar-free): never weaker than upstream — when
  no Vars are present DETERM-vs-not changes cost only, and when Vars
  are present it *keeps* the cross-subgoal backtracking current
  Isabelle wrongly discards, so this can only solve more goals (at
  possibly higher cost); (b) bug-compatibility with post-2009 Isabelle
  (DETERM when Vars present) for benchmark comparability.  Given the
  program's "at least as strong" criterion, (a) is the natural
  recommendation, with (b) available behind a flag for A/B
  benchmarking; final call is the owner's.
- **E11 — engine-level wrappers.**  §4.3's materialization hook: fix
  the marker convention for rendered metavars (e.g. reserved-name
  frees or `markerLib`-tagged frees) and the rule that a wrapper result
  mentioning a rendered metavar re-abstracts to the same metavar.
  Also decide whether Phase 2 exposes user wrappers on FAST/BEST/etc.
  from day one (Isabelle does; `addss` arrives in Phase 3 as the first
  real client).

---

## 7. Numeric constants (deliverable 6)

| Constant | Value | Source |
|---|---|---|
| `deepen_tac` deepening | increment 2, ceiling 10 | `classical.ML:732` |
| `deepen` method start depth | 4 (optional nat) | `classical.ML:839–842` |
| `weight_ASTAR` | 5; cost = `sizef thm + 5 * level` | `classical.ML:685–691` |
| `sizef` (HOL) | `Drule.size_of_thm` = atoms+abstractions of `full_prop_of` (incl. flexflex pairs) | `HOL.thy:846`; `drule.ML:327`; `term.ML:468–473`; `thm.ML:501` |
| `has_fewer_prems n st` | `nprems st < n`; used as `COND (has_fewer_prems i) no_tac …` guard (`classical.ML:592`) and as `DEEPEN`'s existence check (`search.ML:151`) | `search.ML:52` |
| BEST_FIRST satp | `Thm.no_prems` (restricted state fully solved) | `classical.ML:667` etc. |
| ITER_DEEPEN initial (bnd, inc) | (0, 5); restart inc 10; cut `k'+np' ≥ bnd`; `lim` caller-supplied | `search.ML:109–142` |
| unify search bound | 60 (`unify_search_bound`) | `unify.ML:32` |
| `auto` depths (Phase 3, for context) | blast 4, claset 2 | `clasimp.ML:161` |
| candidate tag order | (weight asc = new subgoals, index asc = recency; swapped `2k` before unswapped `2k+1`) | `bires.ML:97–110`; `classical.ML:268–273` |

---

## 8. Verification of `isabelle-classical-reasoner.md` §2 (deliverable 7)

Every §2 claim this report relies on was re-checked against the
vendored sources.  Results:

**Confirmed** (spot list, all verified at the cited lines):
- §2.1 step-hierarchy table: all nine definitions and line numbers
  (581, 591, 595, 633, 639, 643, 645, 649–650, 654–655) match; the
  `ORELSE'` vs `APPEND'` fast/slow characterization is exact;
  `eq_mp_tac` at 192; `contr_tac` at 183; safe steps are matching-only;
  `inst_step_tac` reuses the safe nets by resolution.
- §2.2: all drivers wrap `SELECT_GOAL` and atomize premises first
  (660–697); `fast` = unbounded `DEPTH_SOLVE (step_tac 1)`; `best` =
  `BEST_FIRST (no_prems, sizef)`; `first_best` uses
  `FIRSTGOAL step_tac` and is used by `force` (`clasimp.ML:172`);
  astar cost `sizef + 5·lev` (Norbert Völker, 683–697); method
  bindings at 824–854.
- §2.3 clarify: restriction to 1-subgoal safep rules
  (`n_bimatch … 1`, 603–605, 622), two-subgoal only if one branch
  closes immediately (`bimatch2_tac`, 611–613), `clarify_tac =
  SELECT_GOAL (REPEAT_DETERM …)` (625).
- §2.4 deepen: `depth_tac` code (715–719) quoted correctly;
  `slow_step_tac' = uwrappers (instp APPEND' dup_step)` (713);
  dup netpair only used here (708–709); `deepen_tac = DEEPEN (2,10)`
  (732); method default 4 (839–842).  One wording refinement: "only
  unsafe steps decrement the bound" — precisely, the
  `instp APPEND' dup` step decrements, which includes *safe rules
  applied by resolution*; `inst0` closers are free.
- §2.5 wrappers: types, lists, `appSWrappers`/`appWrappers` (529–530),
  `ORELSE'` composition for safe and `APPEND'` for unsafe (556–565),
  `addD2`/`addSE2` shapes (567–574).  Refinement: `addD2/addE2`
  discharge with `assume_tac` (unification) while `addSD2/addSE2` use
  `eq_assume_tac` — the report's "immediately discharged by assumption"
  covers both but blurs the match/unify split.
- §1 claims used here: netpair routing (`add_safe_rule` 323–327,
  unsafe→unsafe+dup 329–334), candidate ordering realization
  (bires.ML 97–108, classical.ML 268–269), `ext_info` forms (348–368),
  HOL instantiation (`HOL.thy:840–848`) and base claset (869–904).

**Discrepancy (one, genuine).**  §2.4 states: *"safe_depth_tac
(724–730) … wraps the search in DETERM when the goal has no schematic
Vars (no need to backtrack between goals)"*; §7 repeats it
("classical.ML's safe_depth_tac even switches to DETERM when no Vars
are present").  This describes the **comment**, not the code.  The
vendored code (and every Isabelle release since 2009) applies `DETERM`
when the goal **does** contain Vars:

```
val deti = (*No Vars in the goal?  No need to backtrack between goals.*)
  if exists_subterm (fn Var _ => true | _ => false) prem then DETERM else I;
```
(`classical.ML:726–727`).  Isabelle2005 had the comment's semantics
(`case term_vars prem of [] => DETERM | _ => I`,
`Provers/classical.ML:777–781` at tag Isabelle2005); the Isabelle2009
refactoring inverted the branch and the inversion persists at the
pinned commit.  Impact: in post-2009 Isabelle, `deepen_tac` cannot
backtrack between subgoal solutions exactly when subgoals share
schematic variables — a completeness loss relative to the documented
design (and to `DEEPEN`'s LeanTaP lineage).  Port decision: §6 E10.
The research report should be read with this correction; no other §2
claim this report relies on was found inaccurate.

**Minor imprecisions (no impact on the plan):**
- §2.1 describes `safe_steps_tac`'s guard as "guarded by
  has_fewer_prems" without noting the polarity (it *fails* when
  `nprems < i`, i.e. when position `i` fell off the end) — spelled out
  in §3.2 above.
- §2.2's "duplicate suppression" (via `DEPTH_FIRST`'s `used`) applies
  to emitted *solutions* only, not to intermediate states (§3.6).
- §2.5 does not mention that `inst0_step_tac` inside
  `depth_tac`/`nodup_depth_tac` bypasses the unsafe wrappers (§4.2) —
  relevant to Phase 3's `addss` placement.

---

## 9. Quick reference — new/changed vendored files

Added 2026-07-16 at the pinned commit (see `sources/README.md`):
`src/Pure/search.ML`, `tactical.ML`, `tactic.ML`, `thm.ML`, `drule.ML`,
`logic.ML`, `term.ML`, `goal.ML`, `unify.ML`, `pattern.ML`,
`library.ML`, `General/alist.ML`, `Isar/object_logic.ML`.
Release-comparison scratch copies of `classical.ML`
(Isabelle2005/2009/2013/2021) used for the §8 finding were *not*
vendored (they document history, not the pinned snapshot); the §8
citations give tag + line numbers for re-verification.
