# Isabelle simplifier hooks (subgoaler / solver / looper) and mut_impc — research for HOL4 Phase S

> Research report, 2026-07-16.  Companion to
> `isabelle-simplifier-vs-simplib.md` (which covers the overall
> architecture); this report drills into the outer proof loop and the
> assumption-fixpoint machinery.  All cited Isabelle files are
> vendored at `../sources/` (mirror-isabelle, same snapshot as the
> other reports).  HOL4 paths refer to this repository.  Everything
> below was verified directly against the sources; nothing is taken
> from documentation alone.

Isabelle sources read in full: `src/Pure/raw_simplifier.ML` (1576
lines), `src/Pure/simplifier.ML` (526 lines),
`src/HOL/Tools/simpdata.ML` (214 lines), `src/Provers/clasimp.ML`
(233 lines), `src/HOL/Tools/lin_arith.ML` (solver registration).
HOL4 sources read in full: `src/simp/src/Traverse.sml` (313 lines),
`src/simp/src/Cond_rewr.sml` (488 lines); plus
`src/simp/src/simpLib.sml:740–1000`, `src/boss/bossLib.sml:380–410`,
`src/marker/markerLib.sml:734–747`, `src/1/Tactic.sml:1098–1131`.

---

## 1. Division of labor: who proves what, and when

Isabelle has **two distinct proof obligations** with **two distinct
provers**, plus a third, purely tactic-level phase:

| obligation | arises | proved by |
|---|---|---|
| instantiated premises of a conditional rewrite rule / cong rule | DURING rewriting, inside the conversion engine | the `prover` parameter of `bottomc` = `solve_all_tac unsafe_solvers` = DEPTH_SOLVE of the **subgoaler** with **unsafe solvers** installed |
| the whole subgoal remaining after rewriting | AFTER rewriting, once per `simp_loop_tac` round | `solve_tac` = FIRST' over the final solver list (safe or unsafe depending on tactic variant) |
| goal transformation when the solver fails | AFTER the solver fails | `loop_tac` (loopers), then the whole loop restarts on every new subgoal |

### 1.1 The `prover` parameter inside raw rewriting

`bottomc ((simprem, useprem, mutsimp), prover, maxidx)`
(raw_simplifier.ML:1225) threads `prover` into every place a theorem
must be proved during rewriting:

- **Conditional rewrite rules**: `rewritec (prover, maxt) ctxt t`
  (raw_simplifier.ML:1020).  After matching and instantiating the
  rule (`thm'`, line 1040), if it still has premises
  (`unconditional = Logic.no_prems prop'`, line 1042 is false), then
  — depth-guarded by `simp_depth_limit`, line 1065 — the engine calls
  `prover ctxt' thm'` (raw_simplifier.ML:1069).  `prover :
  Proof.context -> thm -> thm option` receives the **whole
  instantiated conditional rule as a goal state** (its premises are
  the subgoals) and must return it with all premises discharged;
  `check_conv` (lines 934–955, called at 1072) then verifies the
  result is still an equation for the redex ("Proved wrong theorem
  (bad subgoaler?)", line 953).
- **Congruence rules**: `congc prover ctxt maxt cong t`
  (raw_simplifier.ML:1191), called from `subc` as
  `congc (prover ctxt) ctxt maxidx cong t0` (line 1300).  The
  instantiated cong rule's premises — both the `xᵢ ≡ ?yᵢ`
  recursive-simplification premises and genuine side conditions — are
  all proved by the same `prover` (line 1203).  This is the crucial
  subtlety: **argument simplification under a cong rule happens via
  the prover**, i.e. via the subgoaler: the subgoaler (default
  `asm_simp_tac`) rewrites the premise `xᵢ ≡ ?yᵢ` to `xᵢ' ≡ ?yᵢ` and
  then its solver closes it with `reflexive_thm`, instantiating
  `?yᵢ := xᵢ'`.  This is why every solver "must handle `t ≡ ?x` by
  reflexivity" — both Pure solvers include `reflexive_thm`
  (simplifier.ML:507, 512), and HOL's include it too
  (simpdata.ML:130, 148).
- `rebuild` inside `mut_impc` calls `rewritec (prover, maxidx)` on
  reconstructed implications (raw_simplifier.ML:1368).

`prover` is installed by `rewrite_cterm` (raw_simplifier.ML:1457):

```
ct |> bottomc (mode, Option.map (Drule.flexflex_unique (SOME ctxt)) oo prover, maxidx) ctxt
```
(raw_simplifier.ML:1476) — so every prover result is additionally
forced through `flexflex_unique`.  There are two provers in practice:

- `simple_prover = SINGLE o (fn ctxt => ALLGOALS (resolve_tac ctxt
  (prems_of ctxt)))` (raw_simplifier.ML:1480–1481) — used only by the
  bare meta-rewriting entry points `rewrite0` / `rewrite_goals_rule`
  (lines 1483, 1500–1502).
- The tactic layer's `solve_all_tac`-based prover — see next.

### 1.2 The tactic layer: exact code

`generic_rewrite_goal_tac` (raw_simplifier.ML:1511–1514):

```
fun generic_rewrite_goal_tac mode prover_tac ctxt i thm =
  if 0 < i andalso i <= Thm.nprems_of thm then
    Seq.single (Conv.gconv_rule (rewrite_cterm mode (SINGLE o prover_tac) ctxt) i thm)
  else Seq.empty;
```

Note: it **always succeeds** on a valid goal index (rewriting to
reflexivity if nothing changes, `try_botc` raw_simplifier.ML:1243–1246),
and it is deterministic (`Seq.single`).  `prover_tac : Proof.context
-> tactic` is run on the instantiated conditional rule and `SINGLE`
takes its first success.

`solve_all_tac` (simplifier.ML:312–316):

```
fun solve_all_tac solvers ctxt =
  let
    val subgoal_tac = subgoal_tac (set_solvers solvers ctxt);
    val solve_tac = subgoal_tac THEN_ALL_NEW (K no_tac);
  in DEPTH_SOLVE (solve_tac 1) end;
```

Three things to note.  (1) It runs the **subgoaler**, not the solvers
directly; the solvers are handed to the subgoaler by overwriting
*both* solver slots via `set_solvers` (raw_simplifier.ML:893–895 sets
`(solvers, solvers)`), so the recursive simplification inside the
subgoaler terminates with exactly this solver list whichever slot it
consults.  (2) `THEN_ALL_NEW (K no_tac)` makes a subgoaler
application count only if it **fully solves** the subgoal it attacks.
(3) `DEPTH_SOLVE (solve_tac 1)` keeps solving subgoal 1 until none
remain — i.e. all premises of the conditional rule must be proved, or
the whole prover fails and the conditional rewrite is not applied
(rewritec line 1070 "FAILED").

`generic_simp_tac` (simplifier.ML:318–329), the heart of the loop:

```
(*NOTE: may instantiate unknowns that appear also in other subgoals*)
fun generic_simp_tac safe mode ctxt =
  let
    val loop_tac = loop_tac ctxt;
    val (unsafe_solvers, solvers) = solvers ctxt;
    val solve_tac = FIRST' (map (solver ctxt)
      (rev (if safe then solvers else unsafe_solvers)));

    fun simp_loop_tac i =
      generic_rewrite_goal_tac mode (solve_all_tac unsafe_solvers) ctxt i THEN
      (solve_tac i ORELSE TRY ((loop_tac THEN_ALL_NEW simp_loop_tac) i));
  in PREFER_GOAL (simp_loop_tac 1) end;
```

Consequences, all load-bearing for the HOL4 design:

- **The internal prover always uses the unsafe solvers**
  (`solve_all_tac unsafe_solvers`, line 327), even in the
  `safe_*_simp_tac` variants.  The `safe` flag only selects which
  list the **final** `solve_tac` uses (lines 323–324).
- **Restart semantics**: after rewriting, try to solve the goal
  outright; if that fails, run `loop_tac` (one looper step), and on
  each subgoal the looper produces, restart the *entire* loop
  (`THEN_ALL_NEW simp_loop_tac`).  The `TRY` means: if no looper
  applies (or the looper's subtree fails), succeed anyway, leaving
  the rewritten goal.  So `simp` never fails at this level; failure
  behavior is added by the method wrapper.
- `loop_tac ctxt = FIRST' (map (fn (_, tac) => tac ctxt) (rev
  (#loop_tacs ...)))` (raw_simplifier.ML:419–420) — loopers are a
  *named alist* tried in `rev` order of the stored list; `set_loop`
  replaces the list with a single anonymous entry
  (raw_simplifier.ML:861–863), `add_loop` updates-or-adds by name
  (865–868), `del_loop` deletes by name with a warning (870–875).
- `subgoal_tac ctxt = (#subgoal_tac ...) ctxt ctxt`
  (raw_simplifier.ML:417); `set_subgoaler` (857–859).  Pure's default
  subgoaler is `asm_simp_tac` (simplifier.ML:521); HOL re-sets the
  same in `HOL_basic_ss` (simpdata.ML:199).  So conditional-premise
  proving is, by default, **a recursive invocation of the simplifier
  with assumptions** (which itself recursively uses `solve_all_tac
  unsafe_solvers` at its own premises — the recursion bottoms out in
  the depth limit, raw_simplifier.ML:433, 1065–1066).

### 1.3 Modes and method behavior

Mode triple `(simprem, useprem, mutsimp)` for `A ⟹ B`
(raw_simplifier.ML:1448–1455 comment: "simplify A / use A in
simplifying B / use prems of B to simplify A").  Tactic mapping
(simplifier.ML:350–354):

```
simp_tac          (false, false, false)
asm_simp_tac      (false, true,  false)
full_simp_tac     (true,  false, false)
asm_lr_simp_tac   (true,  true,  false)
asm_full_simp_tac (true,  true,  true)
```

with `safe_*` variants = same modes with `safe = true`
(simplifier.ML:357–361).  Isar option mapping (simplifier.ML:478–483):
`(no_asm)` → simp_tac, `(no_asm_simp)` → asm_simp_tac,
`(no_asm_use)` → full_simp_tac, `(asm_lr)` → asm_lr_simp_tac, default
→ asm_full_simp_tac.  `mutsimp = true` is what switches `impc` to
`mut_impc0` (raw_simplifier.ML:1315–1317); `asm_lr` is exactly
`nonmut_impc` with both simprem and useprem.

**Fail-if-unchanged** lives only in the method wrapper
(simplifier.ML:494–504): `simp` = `HEADGOAL (Method.insert_tac facts
THEN' (CHANGED_PROP oo tac) ctxt)`, `simp_all` = `CHANGED_PROP o
PARALLEL_ALLGOALS o tac`.  The underlying tactics never fail (same
contract as HOL4's SIMP_TAC, simpLib.sml:883–886).

---

## 2. Safe vs unsafe solvers

### 2.1 Representation

```
datatype solver = Solver of {name: string, solver: Proof.context -> int -> tactic, id: stamp};
fun mk_solver name solver = Solver {name = name, solver = solver, id = stamp ()};
fun eq_solver (Solver {id = id1, ...}, Solver {id = id2, ...}) = (id1 = id2);
```
(raw_simplifier.ML:243–253).  Identity is a `stamp` (creation-time
ref), so re-`mk_solver`-ing the same tactic gives a *different*
solver; merging simpsets unions by stamp (line 370–371).  The simpset
field is `solvers: solver list * solver list` with **fst = unsafe,
snd = safe** (raw_simplifier.ML:291; confirmed by `dest_ss` lines
327–328 naming them `unsafe_solvers`/`safe_solvers`).  Setters
(raw_simplifier.ML:877–895): `set_safe_solver` (replaces safe slot
with singleton), `add_safe_solver` (inserts by `eq_solver`),
`set_unsafe_solver`, `add_unsafe_solver`, `set_solvers` (sets both
slots to the same list).  Isabelle's classic aliases `setSolver =
set_safe_solver`, `setSSolver`… map onto these; `FIRST'` over `rev`
of the list means the earliest-added solver is tried first
(simplifier.ML:323–324).

### 2.2 Exact HOL definitions (simpdata.ML:127–151)

```
fun unsafe_solver_tac ctxt =
  let
    val sol_thms =
      reflexive_thm :: @{thm TrueI} :: @{thm refl} :: Simplifier.prems_of ctxt;
    fun sol_tac i =
      FIRST
       [resolve_tac ctxt sol_thms i,
        assume_tac ctxt i,
        eresolve_tac ctxt @{thms FalseE} i] ORELSE
          (match_tac ctxt [@{thm conjI}]
      THEN_ALL_NEW sol_tac) i
  in
    (fn i => REPEAT_DETERM (match_tac ctxt @{thms simp_impliesI} i)) THEN' sol_tac
  end;

(*No premature instantiation of variables during simplification*)
fun safe_solver_tac ctxt =
  (fn i => REPEAT_DETERM (match_tac ctxt @{thms simp_impliesI} i)) THEN'
  FIRST' [match_tac ctxt (reflexive_thm :: @{thm TrueI} :: @{thm refl} :: Simplifier.prems_of ctxt),
    eq_assume_tac, ematch_tac ctxt @{thms FalseE}];
```

Both first strip `simp_implies` premises.  The differences:

| | unsafe ("HOL unsafe") | safe ("HOL safe") |
|---|---|---|
| rule application | `resolve_tac` (unifies; may instantiate goal unknowns) | `match_tac` (matches only; never instantiates goal unknowns) |
| assumption | `assume_tac` (unification against premises) | `eq_assume_tac` (alpha-conversion-only test) |
| False elim | `eresolve_tac FalseE` | `ematch_tac FalseE` |
| conjunction | recursively splits with `match_tac conjI THEN_ALL_NEW sol_tac` | **no conj splitting** |

Both draw on `Simplifier.prems_of ctxt` — the accumulated
rewriting-context premises (raw_simplifier.ML:490–494), fed by
`add_prems` from `impc`'s `add_rrules` (line 1332–1333).  The Pure
analogues are simplifier.ML:506–513 (`resolve_tac
[reflexive_thm]+prems / assume_tac` vs `match_tac / eq_assume_tac`).

### 2.3 What "safe" guarantees, and where each list is used

"Safe" = **the solver never instantiates schematic variables of the
proof state**.  A subgoal may share unknowns (`?x`) with other
subgoals of the same proof state; a solver that closes one subgoal by
unifying `?x` commits every other subgoal to that instantiation.
`match_tac`/`eq_assume_tac`/`ematch_tac` only instantiate variables
of the applied *rule*, never of the *goal*, hence "no premature
instantiation of variables during simplification" (simplifier.ML:510,
simpdata.ML:145).  Isabelle is explicit that even the safe variants
are "not totally safe" (simplifier.ML:356; also the NOTE at 318),
because (a) the internal premise prover still uses unsafe solvers
(§1.2), and (b) loopers may instantiate.

Usage matrix (all verified in code):

- **Rewriting-internal** (conditional-rule and cong premises):
  always the **unsafe** list, via `solve_all_tac unsafe_solvers`
  (simplifier.ML:327) and via the conversion/`simplify` entry points
  (simplifier.ML:333–338: `solve_all_tac (rev unsafe_solvers)`).
  This is deliberate: conditional rules whose conditions have extra
  unknowns (e.g. `?m < ?n ⟹ …`) can only be discharged by a solver
  allowed to instantiate them — HOL's `lin_arith` solver is
  registered **unsafe** for exactly this role (lin_arith.ML:947–949):

  ```
  Simplifier.map_theory_simpset
    (Simplifier.add_unsafe_solver (Simplifier.mk_solver "lin_arith"
      (add_arith_facts #> Fast_Arith.prems_lin_arith_tac)))
  ```

- **Final subgoal solving**: safe list iff the tactic variant is
  `safe_*` (simplifier.ML:319–324), unsafe otherwise.
- **`safe_asm_full_simp_tac` as classical wrapper** — clasimp.ML:46–54:

  ```
  (*Caution: only one simpset added can be added by each of addSss and addss*)
  local
    fun add_wrapper f name tac ctxt = f (ctxt, (name, fn _ => CHANGED o tac ctxt));
  in
    val addSss =
      add_wrapper Classical.addSafter "safe_asm_full_simp_tac" Simplifier.safe_asm_full_simp_tac;
    val addss =
      add_wrapper Classical.addbefore "asm_full_simp_tac" Simplifier.asm_full_simp_tac;
  end;
  ```

  `addSss` installs simplification as a **safe wrapper** (`addSafter`)
  of the classical reasoner, so it must not instantiate proof-state
  unknowns — hence the safe-solver variant.  `addss` runs as an
  unsafe `addbefore` wrapper and uses the plain (unsafe-solver)
  variant.  `clarsimp_tac` similarly leads with
  `safe_asm_full_simp_tac` (clasimp.ML:119–121), and `auto_tac`'s
  final safe pass uses `addSss` (clasimp.ML:157) while its main
  depth search uses `addss` (line 152).

### 2.4 How HOL wires it all up (bottom of simpdata.ML)

```
val HOL_basic_ss =
  Simplifier.empty_ss
  |> Simplifier.simpset_map \<^context> (
    Simplifier.set_safe_solver safe_solver
    #> Simplifier.set_unsafe_solver unsafe_solver
    #> Simplifier.set_subgoaler asm_simp_tac
    #> Simplifier.set_mksimps (mksimps mksimps_pairs)
    #> Simplifier.set_mkeqTrue mk_eq_True
    #> Simplifier.set_mkcong mk_meta_cong);
```
(simpdata.ML:194–202).  Note: **no looper is set here**; loopers
enter only later via `Splitter.add_split` when split rules are
declared (see isabelle-simplifier-vs-simplib.md §1.4/§2), and
`lin_arith` adds its unsafe solver at its own setup
(lin_arith.ML:947–949).  Also relevant: `mksimps` (simpdata.ML:125)
`= map_filter (try mk_eq) o mk_atomize ctxt pairs o Variable.gen_all
ctxt` with `mksimps_pairs` (186–192: `⟶↦mp`, `∧↦conjunct1/2`,
`∀↦spec`, `If↦if_bool_eq_conj RS iffD1`), and `mk_eq`
(simpdata.ML:54–60: `≡` kept, `=`→`eq_reflection`, `¬P`→`Eq_FalseI`,
else `Eq_TrueI`); these are what `extract_safe_rrules` ultimately
runs on goal premises (§3.1).  `Simplifier.set_mksimps` wraps a
context-free function into the contextual `mk` slot
(simplifier.ML:77).

---

## 3. mut_impc in full detail (raw_simplifier.ML:1315–1441)

### 3.1 Entry and premise-to-rewrite conversion

```
and impc ct ctxt =
  if mutsimp then mut_impc0 [] ct [] [] ctxt
  else nonmut_impc ct ctxt
```
(1315–1317).  `impc` is invoked from `subc` whenever the term is
`Pure.imp $ _ $ _` (line 1259) — i.e. *before* any congruence
machinery sees the implication.  A subgoal `⋀xs. A₁ ⟹ … ⟹ Aₙ ⟹ C`
reaches it after `botc`/`subc` descends through the parameters (Abs
case, lines 1251–1256).

`rules_of_prem prem ctxt` (1319–1330): if the premise contains any
schematic (type) variables (`maxidx_of_term ≠ ~1`, line 1320) it is
**not** turned into rewrites (traced message, lines 1322–1324) —
`(([], NONE), ctxt)`.  Otherwise `Thm.assume_hyps prem` produces the
assumption theorem (with itself as hyp) and `extract_safe_rrules`
(raw_simplifier.ML:606–607 = `extract_rews` via the pluggable
`mksimps` `mk`, then `orient_rrule` with the `reorient`/`mk_sym`
heuristics, lines 581–597) yields the rrules.  `add_rrules (rrss,
asms) ctxt` inserts all of them into the net **and** appends the
assumption thms to `prems` (1332–1333) — which is what the solvers
later see via `Simplifier.prems_of`.

### 3.2 The disch / swap_prems_eq bookkeeping

```
and disch r prem eq =                                        (1335–1358)
```
Given `eq : lhs ≡ rhs` (possibly with `prem` among its hyps),
`Thm.implies_intr prem eq` discharges the hyp, and `Drule.imp_cong`
(instantiated at `vA,vB,vC`, lines 1213–1215) produces
`(prem ⟹ lhs) ≡ (prem ⟹ rhs)`.  That is `disch false`.  With
`r = true` (lines 1344–1357), both sides are assumed to be
implications `prem' ⟹ concl` / `prem'' ⟹ concl`, and two
`Drule.swap_prems_eq` instances (`(A ⟹ B ⟹ C) ≡ (B ⟹ A ⟹ C)`) are
composed by transitivity so that the result is

```
(prem' ⟹ prem ⟹ concl) ≡ (prem'' ⟹ prem ⟹ concl)
```

i.e. `prem` is inserted in *second* position rather than first.  This
is used when the equation for a simplified premise depends (as
hypotheses) on *later* premises: those must be discharged around it
while keeping the changed premise in front of them in the rebuilt
implication.

### 3.3 The zipper and the change counter

`mut_impc0 prems concl rrss asms ctxt` (1375–1382) strips the premise
spine of `concl` (`strip_imp_prems`/`strip_imp_concl`), runs
`rules_of_prem` on the new premises, and enters the worklist:

```
mut_impc (prems @ prems') (strip_imp_concl concl) (rrss @ rrss')
  (asms @ asms') [] [] [] [] ctxt' ~1 ~1
```

`mut_impc todo concl todo_rrss todo_asms done' done_rrss' done_asms'
eqns ctxt changed k` (1384–1415) processes premises left to right,
carrying the processed ones (reversed) in the primed accumulators:

- **Work clause** (1393–1415).  The head premise `prem` is simplified
  (unless `k = 0`) by

  ```
  botc skel0 (add_rrules (rev rrss' @ rrss, rev asms' @ asms) ctxt) prem
  ```

  (1395–1396): the context contains the rewrites of **every premise
  except `prem` itself** — both already-processed (`rrss'`) and
  not-yet-processed (`rrss`) ones.  This bidirectionality is the
  whole point of "mutual".
  - **Unchanged** (`NONE`, 1397–1399): push `(prem, rrs, asm, NONE)`
    onto the accumulators and decrement `k` (floored at 0).
  - **Changed** (`SOME eqn`, 1400–1415): let `prem' = rhs of eqn`.
    Compute `i` = 1 + the largest index (in the *remaining* premise
    list `prems`) of any premise that occurs among `Thm.hyps_of eqn`
    (1403–1405) — i.e. how many of the *later* premises the
    simplification actually used.  Re-extract rewrites from the new
    premise (`rules_of_prem prem'`, 1406).  Store as this premise's
    equation

    ```
    fold_rev (disch true) (take i prems)
      (Drule.imp_cong_rule eqn
        (Thm.reflexive (Drule.list_implies (drop i prems, concl))))
    ```

    (1410–1413): first extend `prem ≡ prem'` to
    `(prem ⟹ drop i prems ⟹ concl) ≡ (prem' ⟹ …)` by `imp_cong_rule`
    with a reflexive tail, then discharge the `i` later premises it
    depended on with `disch true`, which weaves them in *behind* the
    changed premise via `swap_prems_eq`.  (Hypotheses that are
    *earlier* — already-processed — premises are left in place; they
    are discharged later by the final assembly's `disch false`.)
    Continue with `changed := length done'` (the index of this
    premise) and `k := ~1` (re-enable simplification for all
    subsequent premises), 1414.

- **Terminal clause** (1384–1391), when the todo list is empty:

  ```
  transitive1 (fold (fn (eq1, prem) => fn eq2 => transitive1 eq1
      (Option.map (disch false prem) eq2)) (eqns ~~ prems') NONE)
    (if changed > 0 then
       mut_impc (rev prems') concl (rev rrss') (rev asms') [] [] [] [] ctxt ~1 changed
     else rebuild prems' concl rrss' asms' ctxt
       (botc skel0 (add_rrules (rev rrss', rev asms') ctxt) concl))
  ```

  The `fold` telescopes the per-premise equations (innermost premise
  first, since the accumulators are reversed) into one equation
  `(A₁ ⟹ … ⟹ Aₙ ⟹ C) ≡ (A₁' ⟹ … ⟹ Aₙ' ⟹ C)`, wrapping each processed
  premise around the accumulated suffix equation with `disch false`
  (which also discharges that premise's hyp occurrences).  Then:
  - **Restart** if `changed > 0`: some premise *other than the first*
    changed, so premises *before* it saw only its old rewrites.  The
    pass restarts with `k := changed`.  On the new pass, `k` counts
    down on every unchanged premise: if the first `changed` premises
    are all unchanged, `k` hits 0 exactly at the last-changed premise
    and everything from there on is **skipped** (they were already
    simplified against the final rule set in the previous pass).  Any
    new change resets `k := ~1` (simplify everything after it) and
    records a new `changed`.  Note `changed = 0` (only the *first*
    premise changed) does **not** restart: no earlier premise exists,
    and all later ones were re-simplified after the change within the
    same pass.
  - **Fixpoint reached** (`changed ≤ 0`): simplify the **conclusion**
    with all premises' rewrites installed, and hand the result to
    `rebuild`.

- **`rebuild`** (1360–1373): walks back out through the premises
  (innermost first), rebuilding `concl' = prem ⟹ concl` and — with
  the *outer* premises' rewrites in context (1363) — tries
  `rewritec` on the rebuilt implication itself (1368).  This lets
  rewrite rules whose lhs is an implication (`(?P ⟹ ?Q) ≡ …`, e.g.
  `simp_implies` rules or `swap_prems`-style laws) fire across the
  premise/conclusion boundary; if one fires, the **whole `mut_impc0`
  machinery restarts** on the rewritten term (1370–1372).  Otherwise
  the equation is discharged (`dprem = disch false prem`) and the
  walk continues.

**Termination**: each restart requires at least one premise change in
the previous pass, and each skipped tail is provably at fixpoint, but
there is no global termination guarantee — a set of premises that
keep rewriting each other back and forth loops, exactly like any
simplifier loop (guarded in practice by `simp_depth_limit` only for
the conditional-premise recursion, not for `mut_impc` passes).

### 3.4 nonmut_impc (legacy, 1417–1441)

```
and nonmut_impc ct ctxt =
  let
    val (prem, conc) = Thm.dest_implies ct;
    val thm1 = if simprem then botc skel0 ctxt prem else NONE;
    val prem1 = the_default prem (Option.map Thm.rhs_of thm1);
    val ctxt1 =
      if not useprem then ctxt
      else ... add_rrules ([rrs], [asm]) ... (* from prem1 *)
  in (case botc skel0 ctxt1 conc of ... imp_cong_rule / disch false ...)
```

Strictly **left-to-right, single pass**: premise `Aᵢ` is simplified
using only the outer context plus `A₁…Aᵢ₋₁` (via the recursion — the
`conc` of one step is the next implication, handled by `subc` →
`impc` again), never using later premises, and never revisited.  This
is the `asm_lr` behavior.

### 3.5 What "mutual" buys — concrete example

Goal `⟦P a; a = b⟧ ⟹ Q`:
- `nonmut_impc` (asm_lr): `P a` is simplified before `a = b` is even
  seen, so it stays `P a`; then `a = b` becomes a rewrite for the
  conclusion only.
- `mut_impc`: when `P a` is simplified, the context already contains
  the rewrite `a ≡ b` extracted from the *later* premise (line
  1395–1396 adds `rrss` — the unprocessed tail — too), so the premise
  becomes `P b`; if e.g. `P b ≡ True` is known, the premise
  disappears entirely.  Symmetrically, iteration to fixpoint handles
  chains: in `⟦f x = g x; g x = 3; R (f x)⟧ ⟹ S`, the first pass may
  rewrite premise 1 to `f x = 3` (using premise 2) after premise 3
  was already processed with the old rule; the change counter forces
  another pass in which premise 3 becomes `R 3`.

### 3.6 Contrast with HOL4's existing behaviors (precise)

- **`FULL_SIMP_TAC`** (simpLib.sml:941–955): `GEN_FULL_SIMP_TAC`'s
  worker is

  ```
  fun simp_asm (t, l') = SIMP_RULE ss (l' @ thms) t :: l'
  fun f asms = MAP_EVERY tac (List.foldl simp_asm [] (r asms))
               THEN drop (List.length asms)
  ```

  — a **single left fold**: each assumption is simplified using only
  the *previously processed* assumptions (`l'`), never later ones,
  and never revisited; then `ASM_SIMP_TAC ss l` does the conclusion
  (line 949).  This is `nonmut_impc`/`asm_lr` semantics, one pass.
  (`REV_FULL_SIMP_TAC` is the same fold over the reversed list,
  line 952.)

- **`global_simp_tac`** (simpLib.sml:980–994) with its helpers
  (simpLib.sml:964–978):

  ```
  fun psr cfg ss =
      let val popper = if #oldestfirst cfg then pop_last_assum else pop_assum
      in popper (fn th =>
                   ASSUM_LIST (fn asms => stdcon cfg (SIMP_RULE ss asms th)))
      end
  fun allasms cfg ss (g as (asl,_)) = ntac (length asl) (psr cfg ss) g
  ...
  rpt (CHANGED_TAC (allasms cfg ss)) THEN ASM_SIMP_TAC ss []
  ```

  Each pass pops each assumption in turn (oldest first for
  `gs`/`gvs`, bossLib.sml:402–409) and simplifies it with **all
  remaining assumptions** (`ASSUM_LIST` — a mixture of
  already-simplified ones pushed back by `stdcon`/`BF_ASSUME_TAC`,
  lines 914–927/964–968, and not-yet-processed ones).  So within a
  pass it *does* use both earlier and later assumptions — genuine
  mutual simplification — and `rpt CHANGED_TAC` iterates passes to a
  fixpoint.  What it lacks relative to `mut_impc`:
  1. **No change counting**: every pass re-simplifies every
     assumption from scratch; termination detection costs one full
     no-op pass, and a change at assumption *n* re-simplifies
     assumptions that provably cannot change (`mut_impc`'s `k`
     skipping, §3.3).
  2. **No implication-level rewriting**: nothing corresponds to
     `rebuild`'s `rewritec` on `prem ⟹ concl` (raw_simplifier.ML:1368);
     rules relating an assumption to the conclusion as a whole can
     never fire.
  3. **The conclusion is outside the fixpoint**: `ASM_SIMP_TAC ss []`
     runs once at the end (simpLib.sml:990); in Isabelle the
     conclusion is simplified after the premise fixpoint too, but a
     hit in `rebuild` restarts everything.
  4. Structural differences: `stdcon` **re-strips** each simplified
     assumption (`STRIP_ALL_THEN`, line 933/967 — splitting `∧`, `∃`,
     case splits into several assumptions) and optionally
     **eliminates variable equations** by substitution (`elimvars`
     → `VSUBST_TAC`, simpLib.sml:964–965; Tactic.sml:1098–1131,
     `SUBST_ALL_TAC` of an oriented `v = t`), and drops `T`
     assumptions (`droptrues`, simpLib.sml:920–927).  `mut_impc`
     never restructures the premise list — it only replaces each
     premise by its simplified form (`extract_safe_rrules` extracts
     usable rewrites *without* changing the premise itself) and
     leaves `x = t` premises in place.

- **`gvs` plumbing**: bossLib.sml:402–409 — `gvs = stateful (cfg true
  true true) []` where `cfg ev s ofirst = global_simp_tac {elimvars =
  ev, strip = s, droptrues = true, oldestfirst = ofirst}`; `gs`, `gns`,
  `gnvs`, `rgs` are the other flag combinations.  (`BasicProvers.sml`
  itself contains no `global_simp_tac`/`gvs` references; the plumbing
  is entirely in `bossLib.sml`.)

---

## 4. HOL4 mapping

### 4.0 Current HOL4 side-condition architecture (baseline)

- A reducer's `apply` receives
  `{solver: term list -> term -> thm, conv: term list -> term -> thm,
  context, stack: term list, relation: term * (term -> thm)}`
  (Traverse.sml:36–44).
- The engine builds these in `trav` (Traverse.sml:241–258):

  ```
  fun ctxt_solver stack tm =
    ... EQT_ELIM (trav_with_rel' equality stack context tm) ...   (241–246)
  fun ctxt_conv stack tm = trav_with_rel' equality stack context tm  (247–252)
  ```

  — the side-condition **solver is hardwired** to "recursively
  traverse (simplify) the condition at relation `=` and `EQT_ELIM`
  the result", with the rewrite-limit counter rolled back on failure
  (245, 251).  Congruence side conditions use the same closure
  (`congproc_args` solver, Traverse.sml:269; consumed at
  Opening.sml:243 `solver condition`), while sub-congruence argument
  traversal goes through `depther` (Traverse.sml:266–267) — HOL4
  separates the two roles that Isabelle fuses into the single
  `prover` (§1.1).
- `Cond_rewr.COND_REWR_CONV` (Cond_rewr.sml:140–195) is the consumer:
  after `HO_PART_MATCH` instantiation, it fails if any condition is
  already on the `stack` (loop cut, 150–152) or if `length stack +
  length conditions > !stack_limit` (`val stack_limit = ref 4`,
  line 11; check 153–155); otherwise `solver (conditions @ stack)
  condition` per condition (171–179) and `MP`s the results (181).
- `mk_cond_rewrs = QUANTIFY_CONDITIONS oo IMP_EQ_CANON oo IMP_CANON`
  (Cond_rewr.sml:471–473; installed as the `filter` of `pureSimps`,
  pureSimps.sml:12, composed into `mk_rewrs` at simpLib.sml:641–643).
  Crucially `QUANTIFY_CONDITIONS` (381–397) takes variables free only
  in the conditions and turns them into an **existential inside the
  condition** (via `LEFT_FORALL_IMP_THM`).  So HOL4 has no analogue
  of Isabelle's "solver instantiates the rule's extra unknowns by
  unification" — the witness search is pushed into proving
  `∃x. cond x` by recursive simplification.  (Isabelle instead keeps
  the unknowns and lets unsafe solvers unify them, §2.3; its
  skeleton optimization must then be disabled, `cond_skel`
  raw_simplifier.ML:1002–1008.)
- Tactic layer: `ASM_SIMP_TAC ss ths = markerLib.process_taclist_then
  {arg=ths} (CONV_TAC o SIMP_CONV ss)` (simpLib.sml:893–895), where
  `process_taclist_then`/`filter_then` pass `map ASSUME asl @ asms`
  to the conversion (markerLib.sml:734–747) — assumptions are context
  rewrites; `SIMP_TAC` merely prepends the `NoAsms` marker
  (simpLib.sml:896).  There is **no post-rewriting phase at all**: no
  final solver, no looper, no restart.  If the conversion produces
  `⊢ goal = T`, `CONV_TAC` closes the goal; otherwise the rewritten
  goal is the new goal.

### 4.a Solver stacks → replace/augment `ctxt_solver`

Where it lands: `Traverse.trav` (Traverse.sml:241–246) is the single
construction site of the solver every reducer and congproc sees, so a
pluggable solver pipeline belongs there (fed from a new simpset field
threaded through `traversedata_for_ss`, simpLib.sml:778–783).

Type candidates:

1. **Conversion-level (native)**:
   `solver = {name: string, solve: {recurse: term list -> term -> thm (*the current ctxt_solver*), conv: term list -> term -> thm, context_thms: thm list} -> term list -> term -> thm}` —
   i.e. keep the `term list (stack) -> term -> thm` calling
   convention of Cond_rewr (Cond_rewr.sml:147, 171–179) and
   Opening (Opening.sml:10, 243), but let a *list* of named solvers
   be tried in order, each also given the recursive-simplification
   solver so the default pipeline (`EQT_ELIM o trav`) is just the
   first entry.  This keeps the loop-cut/stack-limit machinery intact
   (it lives in Cond_rewr, on the *caller* side, so it applies
   uniformly to whatever solver is installed).
2. **Tactic-based**, converting via
   `TAC_PROOF ((asl, cond), tac)`: possible, but two gaps must be
   filled.  (i) The result may legitimately have hypotheses (context
   assumptions arrive as `[a] ⊢ a` theorems whose hyps must survive
   the `MP` at Cond_rewr.sml:181), so the goal's `asl` must be the
   current context assumptions — and **Traverse currently does not
   keep a term/thm list of the accumulated context**: `TSTATE`
   carries only opaque per-reducer contexts plus `freevars`
   (Traverse.sml:57–62); context thms are consumed by
   `add_context` into the reducers' private nets (79–108) and are not
   recoverable.  Isabelle solves precisely this with the `prems: thm
   list` simpset field (raw_simplifier.ML:279, 490–494) populated by
   `add_prems` whenever premises become rewrites (1332–1333), and its
   solvers consume `Simplifier.prems_of` (simpdata.ML:130, 148).  The
   HOL4 port therefore needs a parallel `context_thms : thm list`
   accumulated in `TSTATE` by `add_context`, handed to solvers (and
   this is what makes HOL-style `assume_tac`-ish solver behavior
   expressible).  (ii) Free variables in the condition may be
   congruence-bound (`freevars` field exists for this); a tactic
   proof must not generalize or clash with them.
   Recommendation implicit in the sources: adapt tactics *into* form
   (1) with a wrapper (`fn stack => fn tm => TAC_PROOF((map concl
   context_thms? or [], tm), tac)` + `PROVE_HYP` plumbing), rather
   than change the reducer interface, since every existing reducer
   (rewriter_for_ss simpLib.sml:755–776, dproc `apply`
   simpLib.sml:572–583, USER_CONV simpLib.sml:340–357) is written
   against `term list -> term -> thm`.

Safe/unsafe split: meaningful in HOL4 only in attenuated form.  HOL4
goals have no schematic variables, so the Isabelle notion of "safe =
no proof-state instantiation" (§2.3) has no direct counterpart at the
conversion level; the useful residue is the *classical-wrapper*
distinction (§2.3 addSss): a solver variant that is
deterministic/non-committal enough to run inside a "safe" outer
tactic.  Worth preserving as two lists for parity, with the caveat
recorded.

### 4.b Subgoaler = the recursive-traversal part

In Isabelle the subgoaler is the tactic the internal prover runs on
conditional premises (§1.1–1.2), default `asm_simp_tac` — i.e. "the
simplifier itself, with assumptions".  HOL4's counterpart is the
hardwired body of `ctxt_solver`: `EQT_ELIM (trav_with_rel' equality
stack context tm)` (Traverse.sml:241–246) — the recursive traversal
*is* the default subgoaler, and `EQT_ELIM` is the trivial final
solver fused onto it.  Making the subgoaler settable means: factor
`ctxt_solver` into `final_solvers (subgoaler {recurse = trav…}) …`,
where the default subgoaler is `recurse` (simplify the condition) and
the default final solver is `EQT_ELIM`-if-`T` plus
lookup-in-context-assumptions.  Note Isabelle's subgoaler/solver
interplay (`set_solvers` overwriting both slots inside
`solve_all_tac`, §1.2) tells us the HOL4 subgoaler must receive the
*currently installed* solver list, not capture one at simpset-build
time.

### 4.c Loopers must live at the tactic layer — verified

Claim verified against Isabelle: `loop_tacs` is stored in the simpset
(raw_simplifier.ML:290) but the **raw rewriting engine never reads
it** — the only consumers are the accessor `loop_tac`
(raw_simplifier.ML:419–420) and `generic_simp_tac`
(simplifier.ML:321, 328).  `bottomc`/`rewritec`/`impc` contain no
reference to loopers.  So even in Isabelle, loopers are strictly a
tactic-layer device: they exist because a looper (canonically the
splitter, and `split_asm_tac` in particular) **multiplies subgoals**,
which a conversion/`rewrite_cterm` (one cterm in, one `≡`-theorem
out) cannot express.  The same holds a fortiori in HOL4: a
`Traverse` conversion returns a single `⊢ t = t'`; goal splitting
requires `(asl, w) -> goal list * validation`.

The HOL4 reproduction of `simp_loop_tac` semantics is therefore a new
tactic in simpLib (schematically, mirroring simplifier.ML:312–329):

```
fun SIMP_LOOP_TAC ss =
  let val rewr = (* CONV_TAC-like application of SIMP_QCONV ss,
                    succeeding with reflexivity if unchanged *)
      val solve = FIRST (map #tac (final_solvers_of ss))   (* whole-goal solvers as tactics *)
      val loop  = FIRST (map #tac (loopers_of ss))
      fun main g = (rewr THEN (solve ORELSE TRY (loop THEN_LT ALLGOALS main))) g
  in main end
```

with the loopers stored as a named alist in the simpset (add/del by
name, `set_loop` replacing — mirroring raw_simplifier.ML:861–875),
tried FIRST'-style.  Two Isabelle behaviors to preserve exactly:
(1) the rewrite step must not fail on no-change (Isabelle's
`generic_rewrite_goal_tac` always succeeds, §1.2; HOL4's `SIMP_CONV`
already wraps `TRY_CONV`, simpLib.sml:859–862) with fail-if-unchanged
added only in user-facing wrappers (CHANGED_PROP analogue =
`markerLib.mk_require_tac` / `CHANGED_TAC`); (2) the looper branch is
inside `TRY`, so a failing looper leaves the rewritten goal rather
than failing the tactic.  The existing HOL4 tactic-level solvers to
seed the final-solver list: contradiction/accept against assumptions
(what `caa_tac0` does post-hoc in the FULL/global family,
simpLib.sml:920–927).

### 4.d mut_impc for HOL4

HOL4 goals are `(asl, w)` with `asl : term list`, not an iterated
implication.  Two implementation strategies:

1. **Tactic-level mutual fixpoint over the assumption list**
   (extend/replace `global_simp_tac`).  Already 80% present
   (§3.6): passes of pop-simplify-push with all other assumptions in
   context, `rpt CHANGED_TAC` outer fixpoint.  To reach `mut_impc`
   parity, add: (i) change counting — track the index of the last
   changed assumption per pass and skip the provably-fixed tail on
   the next pass (mirroring `changed`/`k`, §3.3); this changes cost
   from `passes × n` simp calls to Isabelle's near-optimal schedule;
   (ii) optionally a `rebuild`-analogue: after the fixpoint, instead
   of plain `ASM_SIMP_TAC ss []`, try simplifying
   `DISCH`-ed forms (`a ⟹ w`) so implication-shaped rewrites can
   fire, undischarging afterwards — this is the piece with no current
   HOL4 counterpart (§3.6 item 2) and the most speculative value.
   Validity bookkeeping is free (ordinary tactics), and the
   `strip`/`elimvars`/`droptrues` post-processing of `stdcon`
   composes naturally.

2. **Iterated-implication conversion**: `DISCH`-fold the goal to
   `a₁ ⟹ … ⟹ aₙ ⟹ w`, run a `mut_impc`-style *conversion*, then
   re-strip.  This would let the fixpoint live inside `SIMP_CONV`
   (usable in `SIMP_RULE`, under binders, on embedded implications).
   Costs: HOL4's traversal already handles `==>` via congruence rules
   (context collection through `Opening`/`depther` — the
   `nonmut_impc`-equivalent left-to-right behavior comes for free
   today), and Isabelle only achieves mutuality by **special-casing
   `Pure.imp` in `subc` ahead of the congruence machinery**
   (raw_simplifier.ML:1259); the HOL4 analogue would be a special
   case in `Traverse.trav`/`loop` intercepting `==>`, plus
   `disch`-style equation surgery (HOL4 would use `IMP_CONG`-chains
   or `AP_TERM/MK_COMB` on `$==>` — mechanically simpler than
   `swap_prems_eq` since everything is object-level `bool`).  Also,
   re-stripping afterwards duplicates what `STRIP_ALL_THEN` already
   does at the tactic layer.

Given HOL4's goal representation, strategy 1 matches the existing
ecosystem (`gvs` etc. keep their interface; only the engine under
`global_simp_tac` changes), while strategy 2 is the only route if
mutual premise simplification is wanted *inside* `SIMP_RULE`
/ nested implications.  They are not exclusive: Isabelle's own split
is engine-level `mut_impc` + a thin tactic; HOL4's natural split is
engine-level status quo + a smarter tactic.

## 5. What `simp only:` keeps and clears (for the HOL4 analogue)

`only:` is a method modifier whose `init` is `clear_simpset`
(simplifier.ML:466–467 and 474–475):

```
Args.$$$ simpN -- Args.$$$ onlyN -- Args.colon >>
  K {init = clear_simpset, attribute = simp_add, pos = \<^here>}
```

`clear_simpset` (raw_simplifier.ML:408–410):

```
val clear_simpset =
  map_ss' (fn Simpset ({depth, ...}, {mk_rews, term_ord, subgoal_tac, solvers, ...}) =>
    init_ss depth mk_rews term_ord subgoal_tac solvers);
```

and `init_ss` (raw_simplifier.ML:333–335) rebuilds with `rules =
Net.empty`, `prems = []`, `congs = empty`, `procs = (Net.empty,
Net.empty)`, `loop_tacs = []`.  Therefore `simp only:` **keeps**:
`mk_rews` (mksimps/reorient/…), `term_ord`, the **subgoaler**, and
both **solver** lists; **clears**: rewrite rules, prems, congruence
rules, simprocs/congprocs, and **all loopers** (so `simp only:` does
not split).  For HOL4: the analogue of `simp only:` (roughly
`SIMP_TAC pure_ss [ths]` today) should keep solver/subgoaler hooks
and drop rewrites, congs, dprocs, and loopers.  (Note HOL's
`Simplifier.clear_simpset` composed after `put_simpset HOL_basic_ss`
is likewise how `unfold_tac` gets a bare-but-solvered simpset,
simpdata.ML:207–209.)

## 6. Open questions

1. **`AList.update` insertion position for loopers** — `add_loop`
   uses `AList.update` (raw_simplifier.ML:865–868) and `loop_tac`
   applies `FIRST'` over `rev loop_tacs` (419–420).  I did not read
   Isabelle's `AList.update` source; assuming it prepends new
   entries, `rev` means oldest-registered looper is tried first.  Not
   verified; affects only default looper ordering parity.
2. **`Drule.imp_cong` / `swap_prems_eq` / `imp_cong_rule` exact
   statements** — used as described (raw_simplifier.ML:1335–1358,
   1412) but `drule.ML` was not in the vendored set; the shapes
   `(A ⟹ B ≡ C) ⟹ (A ⟹ B) ≡ (A ⟹ C)`-style and
   `(A ⟹ B ⟹ C) ≡ (B ⟹ A ⟹ C)` are inferred from the instantiation
   sites and variable names (`vA,vB,vC`, lines 1213–1215).
3. **Telescoping of the terminal `fold`** in `mut_impc` (1384–1386):
   I verified the hypothesis-discharge division of labor (later
   premises via `disch true` at store time, earlier ones via `disch
   false` at assembly time) by index reasoning, not by machine
   checking the thm plumbing; a HOL4 re-implementation via the
   iterated-implication route should re-derive it from scratch rather
   than transliterate.
4. **`strip_imp_prems`/`strip_imp_concl` (cterm level)** used by
   `mut_impc0` (1377, 1380) — presumably `Drule`'s cterm versions
   stripping *all* leading implications; not independently read.
5. **Where HOL's global simpset first installs `Splitter.split_tac`
   as looper** — simpdata.ML sets no looper (§2.4); the prior report
   (isabelle-simplifier-vs-simplib.md §1.4) locates it in
   splitter.ML:441–453 via split-rule declaration; the exact HOL.thy
   `simpset` bootstrap declaring `if_split` etc. was not re-checked
   in this pass.
6. **`PREFER_GOAL`/`SELECT_GOAL` semantics** (simplifier.ML:329) —
   assumed to focus goal `i` while allowing instantiation to leak (cf.
   the NOTE at line 318); `tactical.ML` not read.
7. **HOL4 `ASSUM_LIST` ordering** inside `FULL_SIMP_TAC`'s fold
   (simpLib.sml:944–951): the report states the left-to-right/one-pass
   structure, which is order-independent; the precise oldest-vs-newest
   direction of `List.foldl simp_asm [] asms` relative to goal
   assumption order (and hence which end `REV_FULL_SIMP_TAC` favors)
   was not traced through `ASSUM_LIST`'s reversal conventions.
