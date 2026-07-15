# Isabelle/HOL Classical Reasoning Automation: Architecture Report

> Research report, 2026-07-14.  One of four reports underlying
> `../PLAN.md`.  All cited Isabelle files are vendored at
> `../sources/` (mirror-isabelle commit `f7e02b7e1f31`); cited papers
> are archived at `../papers/`.  See `README.md` for the report index.

All source citations below are to the GitHub mirror `isabelle-prover/mirror-isabelle`, branch `master`, fetched 2026-07-14. Line numbers refer to those fetched files.

**Sources fetched (exact URLs):**
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/classical.ML (872 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/blast.ML (1321 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/clasimp.ML (233 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/hypsubst.ML (306 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Pure/bires.ML (334 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Pure/Isar/context_rules.ML (215 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/HOL.thy (2203 lines)
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/Tools/simpdata.ML
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Doc/Isar_Ref/Generic.thy (isar-ref, "The Classical Reasoner", §"sec:classical", lines 1150–1760)
- L. C. Paulson, *A Generic Tableau Prover and its Integration with Isabelle*, J. Universal Computer Science 5(3), 1999 — https://www.cl.cam.ac.uk/~lp15/papers/Reports/blast.pdf (16 pp., read in full)
- J. Limperg & A. H. From, *Aesop: White-Box Best-First Proof Search for Lean*, CPP 2023, doi:10.1145/3573105.3575671 — https://people.compute.dtu.dk/ahfrom/aesop-camera-ready.pdf (read §§1–4)

Architecture overview: the whole stack is three ML functors layered over Pure, instantiated by each object logic. `Classical(Data: CLASSICAL_DATA)` (classical.ML:132) provides the claset and the search tactics (`fast`/`best`/`slow`/`deepen`/`safe`/`clarify`/`step`); `Blast(Data: BLAST_DATA)` (blast.ML:72) is an independent tableau engine that *reads the same claset*; `Clasimp(Data: CLASIMP_DATA)` (clasimp.ML:36) couples Classical with the Simplifier and defines `auto`, `force`, `fastforce`, `clarsimp`, `slowsimp`, `bestsimp`. HOL instantiates all three in `src/HOL/HOL.thy` (Classical at 840–848, Blast at 923–935) and `src/HOL/Tools/simpdata.ML` (Clasimp at 174–184).

---

## 1. The claset: data structure and rule classification

### 1.1 Rule kinds

Rules are classified along two axes — {intro, elim, dest} × {safe (`!`), unsafe (plain), extra (`?`)} — giving the nine kinds in `Pure/bires.ML:113–142` (`intro_bang_kind` … `dest_query_kind`). The `?` ("extra") kinds live outside the claset proper: they are `Context_Rules` declarations in Pure (context_rules.ML:185–193), used only by single-step methods (`rule`, `iprover`), not by the searching tactics.

Semantics (classical.ML header, lines 8–16; isar-ref Generic.thy:1344–1371):

- **Safe** (`intro!`/`elim!`/`dest!`): may be applied blindly, i.e. the rule must never turn a provable goal into an unprovable one; premises and conclusion should be logically equivalent; no unknowns in premises that are absent from the conclusion. Safe rules are applied by *matching* (`bimatch_from_nets_tac`), never instantiating unknowns in the goal, so a "safe" application really is invertible-and-deterministic.
- **Unsafe** (`intro`/`elim`/`dest`): everything else — rules that lose information (`disjI1`), introduce fresh unknowns (`exI`, `allE`), or loop (quantifier duplication). Applied by *resolution* (unification), under backtracking.
- Rules are kept in "canonical reverse order": later declarations take precedence (classical.ML:15–16; implemented by the decreasing `next` counter in `Bires.decls`, bires.ML:196–243).

### 1.2 The claset record

`datatype claset = CS {...}` at classical.ML:241–250:

```
decls          : rule declarations in canonical order (Proptab keyed by thm)
swrappers      : (string * (ctxt -> wrapper)) list   -- transform safe_step_tac
uwrappers      : (string * (ctxt -> wrapper)) list   -- transform step_tac
safe0_netpair  : nets for safe rules yielding 0 subgoals ("trivial cases")
safep_netpair  : nets for safe rules yielding >0 subgoals
unsafe_netpair : nets for unsafe rules
dup_netpair    : nets for *duplicating* variants of unsafe rules
extra_netpair  : plain (untransformed) rules, for the structured `rule` method
```

A **netpair** (bires.ML:251) is a pair of discrimination nets: intro rules indexed by conclusion, elim rules indexed by major premise; lookup + application is `Bires.biresolution_from_nets_tac` (bires.ML:291–299), which unifies the subgoal's conclusion against the intro net and every hypothesis against the elim net, orders candidates by tag (weight = number of new subgoals, then declaration recency; bires.ML:97–108, classical.ML:268–269), and calls kernel `Thm.biresolution`. This ordering realizes "fewest new subgoals first, later declarations win" (isar-ref Generic.thy:1409–1412). Safe rules are routed to `safe0_netpair` iff they produce no subgoals, else `safep_netpair` (`add_safe_rule`, classical.ML:323–327); unsafe rules go to both `unsafe_netpair` and (in duplicated form) `dup_netpair` (classical.ML:329–334).

The claset is context data: `structure Claset = Generic_Data` (classical.ML:466–471) with `merge = merge_cs` (classical.ML:400–422), so clasets merge automatically when theories/contexts merge; `claset_of`, `put_claset`, `map_theory_claset` at 473–494.

### 1.3 dest → elim, weak-elim repair, and swapped rules

`ext_info` (classical.ML:348–368) is where declared theorems become internal rule forms (`type info = {rl, dup_rl, plain}`, line 227):

- **dest becomes elim** via `Bires.kind_make_elim` (bires.ML:149), which applies Pure's `Tactic.make_elim` (essentially `thm RS revcut_rl`): `A ⟹ B` becomes `A ⟹ (B ⟹ R) ⟹ R`. Thereafter dest and elim rules are treated identically.
- **Weak elims are classically strengthened** by `classical_rule` (classical.ML:150–169): an elim whose conclusion `R` is not assumed classically, e.g. `make_elim injD` = `⟦inj f; f x = f y; x = y ⟹ W⟧ ⟹ W`, is resolved with `classical` (`(¬P ⟹ P) ⟹ P`) and cleaned up to `⟦inj f; ¬W ⟹ f x = f y; x = y ⟹ W⟧ ⟹ W`, making the negated goal available in side premises. The comment (lines 139–148) notes that without this, `fast` can fail and `blast` reports PROOF FAILED.
- **Swapped rules**: every intro rule additionally gets a *swapped* variant `intr RSN (2, swap)` where `swap = ¬P ⟹ (¬R ⟹ P) ⟹ R` (`maybe_swap_rule`/`swap_rule`, classical.ML:195–202; HOL proves `swap` at HOL.thy:819). The swapped form is an elim-resolution rule that applies the intro rule to a *negated assumption*, which is how the natural-deduction engine simulates the multiple-conclusion sequent calculus (isar-ref Generic.thy:1242ff. explains this "simulating sequents by natural deduction" trick). Both forms are inserted into the nets: unswapped at index `2k+1`, swapped at `2k` (`insert_rl`, classical.ML:271–273). Elim/dest rules get no swapped form (`no_swapped_rl`).
- **Duplicating variants** for complete search: `dup_intr th = th RS classical` (classical.ML:216) makes an intro rule that keeps `¬(conclusion)` as an extra premise assumption; `dup_elim` (classical.ML:218–220) rebuilds an elim so the major premise survives in the subgoals. These populate `dup_netpair`, used only by `depth_tac`/`deepen_tac` (§2.4).
- Premises are flattened (`flat_rule` = atomize nested meta-connectives in prems, classical.ML:174–175) so the net-based matching sees object-level structure.

### 1.4 HOL's Data instantiation and base claset

HOL.thy:840–848 instantiates `Classical` with `imp_elim`, `not_elim = notE`, `swap`, `classical`, `sizef = Drule.size_of_thm` (the best-first heuristic), and `hyp_subst_tacs = [Hypsubst.hyp_subst_tac]`. Hypsubst (hypsubst.ML) provides the "safe" step that eliminates assumptions `x = t` / `t = x` (Free or Bound variable, occurs-check enforced, `inspect_pair` hypsubst.ML:83–104) by `rev_mp`-ing the other hypotheses, substituting, and re-introducing them. The base HOL claset is declared at HOL.thy:869–904: `iffI notI impI disjCI conjI TrueI refl [intro!]`, `iffCE FalseE impCE disjE conjE [elim!]`, `allI ex_ex1I [intro!]`, `exI ex1I [intro]`, `exE alt_ex1E [elim!]`, `allE [elim]`, `ext [intro]`; `HOL_cs` snapshot at line 890. Note the *classical* variants `disjCI`/`impCE`/`iffCE` (make disjunction-introduction safe by assuming the negation of the other disjunct) and `alt_ex1E` (HOL.thy:903–911), chosen to avoid quantifier duplication.

---

## 2. The search tactics: safe/step composition, fast, best, slow, deepen

### 2.1 The step hierarchy (classical.ML:578–655)

```
safe_step_tac  (581) = swrappers applied to FIRST'
                        [eq_assume_tac,                       -- trivial assumption (no inst)
                         eq_mp_tac,                           -- notE/imp_elim + eq_assume (mp without inst, 192)
                         bimatch safe0_netpair,               -- 0-subgoal safe rules, matching only
                         hyp_subst_tacs,                      -- x = t elimination
                         bimatch safep_netpair]               -- branching safe rules, matching only
safe_steps_tac (591) = REPEAT_DETERM1 safe_step_tac (guarded by has_fewer_prems)
safe_tac       (595) = REPEAT_DETERM1 (FIRSTGOAL safe_steps_tac)      -- the `safe` method; deterministic

inst0_step_tac (633) = assume_tac APPEND' contr_tac APPEND' biresolve safe0_netpair
instp_step_tac (639) = biresolve safep_netpair
inst_step_tac  (643) = inst0 APPEND' instp     -- safe RULES but by unification: may instantiate ⇒ unsafe
unsafe_step_tac(645) = biresolve unsafe_netpair

step_tac       (649) = safe_tac ORELSE uwrappers(inst_step_tac ORELSE' unsafe_step_tac)
slow_step_tac  (654) = safe_tac ORELSE uwrappers(inst_step_tac APPEND' unsafe_step_tac)
```

Key distinctions: safe steps use *matching* (`bimatch...`), so they never instantiate schematic variables in the goal — instantiating an unknown shared with other subgoals is unsafe even for a "safe" rule (isar-ref Generic.thy:1368–1371). `inst_step_tac` reuses the *safe* rule nets but with genuine resolution, as the middle rung between `safe_tac` and unsafe rules. `contr_tac` (183) closes goals having both `P` and `¬P`. `step_tac`'s `ORELSE'` commits to safe-rule instantiation if it succeeds; `slow_step_tac`'s `APPEND'` keeps unsafe alternatives open on backtracking — that is the entire fast/slow difference.

### 2.2 fast, best, slow, astar (classical.ML:658–697)

All of these fail unless they *completely solve* one subgoal (they wrap `SELECT_GOAL (DEPTH_SOLVE ...)`), and all first atomize premises:

- `fast_tac` (661): `atomize_prems THEN' SELECT_GOAL (DEPTH_SOLVE (step_tac 1))` — depth-first, unbounded, backtracking through the lazy-sequence tactic engine.
- `best_tac` (665): `BEST_FIRST (no_prems, sizef) (step_tac 1)` — best-first over entire proof states, priority = size of the proof state (`Drule.size_of_thm` in HOL).
- `first_best_tac` (670): like `best`, but each expansion is `FIRSTGOAL step_tac` ("even a bit smarter"; used by `force`).
- `slow_tac` (674) / `slow_best_tac` (678): same searches over `slow_step_tac`.
- `astar_tac` / `slow_astar_tac` (687–697): `ASTAR` with cost `sizef thm + 5 * level` (Norbert Völker).

Method bindings at classical.ML:824–854 (`fast`, `slow`, `best`, `deepen`, `safe`, `clarify`, plus single-step methods `safe_step`, `inst_step`, `step`, `slow_step`, `clarify_step`).

### 2.3 clarify (classical.ML:599–625)

`clarify_step_tac` (616–623) is a restricted safe step that must not split into open case analyses: `eq_assume_contr_tac` (assumption/contradiction without instantiation), then safe0 matching, then hyp-subst, then **only 1-subgoal** safep rules (`n_bimatch_from_nets_tac ctxt 1`, 603–605), then 2-subgoal safep rules but *only if one of the two branches closes immediately* (`bimatch2_tac`, 611–613). `clarify_tac` (625) = `SELECT_GOAL (REPEAT_DETERM (clarify_step_tac 1))`. So `clarify` exposes the goal's structure ("repeatedly apply safe steps without splitting subgoals", isar-ref Generic.thy:1621–1622) — e.g. it leaves `A ∧ B` alone as a goal — and is the entry pass of `force`.

### 2.4 deepen (classical.ML:700–732)

The "complete tactic, loosely based upon LeanTaP" (comment at 700). `depth_tac ctxt m i` (715–719):

```
SELECT_GOAL (safe_steps_tac 1 THEN_ELSE
  (DEPTH_SOLVE (depth_tac m 1),                       -- safe progress: recurse at same depth
   inst0_step_tac 1 APPEND
     COND (m=0) no_tac
       (slow_step_tac' 1 THEN DEPTH_SOLVE (depth_tac (m-1) 1))))
```

where `slow_step_tac' = uwrappers (instp_step_tac APPEND' dup_step_tac)` and `dup_step_tac` (708) resolves from **dup_netpair** — i.e. unsafe steps *duplicate* the formula they consume (γ-rule treatment), which is what makes iterative deepening complete-ish and what the manual means by "unsafe rules are modified to preserve the formula they act on" (Generic.thy:1583–1584). Only unsafe steps decrement the bound `m`. `safe_depth_tac` (724–730) does `safe_tac` first and wraps the search in `DETERM` when the goal has no schematic Vars (no need to backtrack between goals). `deepen_tac = DEEPEN (2, 10) safe_depth_tac` (732): iterative deepening, increment 2, ceiling 10; the `deepen` method (839–842) takes the start depth (default 4).

### 2.5 Wrappers (classical.ML:513–574)

`type wrapper = (int -> tactic) -> int -> tactic`. Two named lists in the claset: `swrappers` transform `safe_step_tac` (applied via `appSWrappers`, 529), `uwrappers` transform the unsafe part of `step_tac`/`slow_step_tac` (`appWrappers`, 530). Derived combinators show the intended composition semantics (556–565): safe wrappers compose with `ORELSE'` (`addSbefore`/`addSafter` — deterministic alternative), unsafe wrappers with `APPEND'` (`addbefore`/`addafter` — both alternatives kept for backtracking). `addD2/addE2/addSD2/addSE2` (567–574) add a single rule as an after-wrapper whose application must be immediately discharged by assumption. Wrappers are the extension point that `blast` cannot use (blast.ML:16).

---

## 3. blast: the generic tableau prover with proof reconstruction

`src/Provers/blast.ML` (Paulson, 1997; paper: JUCS 5(3) 1999). Design per the paper: start from leanTAP (Beckert–Posegga), recode in ML, extend to *generic* tableau rules taken from the ambient claset, and, crucially, satisfy two constraints (paper p. 4): "Isabelle must be able to verify (efficiently!) any claimed proof" and "to the user, the prover should simply behave like a more powerful version of Fast_tac".

### 3.1 Untyped first-order translation

Blast has its own term datatype (blast.ML:84–91) with `Var of term option Unsynchronized.ref` — destructive unification variables with a trail — and `Skolem of string * ref list`. Types are *discarded* almost entirely (paper §6): terms are translated by `fromTerm` (386–405) / `fromSubgoal` (1205–1248) with dummy types; only "typargs" of certain constants are kept dynamically (`Const of string * term list`, line 85, paper §6's dynamic type-recording to handle overloading, e.g. distinguishing bool-equality/iff from set equality). Goals are identified with negated formulas: a pseudo-constant `*Goal*` marks goal formulas (`mkGoal`, 167), `*False*` marks elim conclusions; a branch may hold several goals, "essential for classical reasoning" (paper §2).

**Rule conversion happens lazily per node**, from the same claset netpairs: `netMkRules` (569–580) looks up `safe0_netpair`/`safep_netpair` (safe list) or `unsafe_netpair` (unsafe list) of the *Classical* structure (see `prove`, 936–937) and converts each hit: intro rules via `fromIntrRule` (540–548), elim/dest rules via `fromRule` (503–522). Elim conversion (`convertRule`, 457–463) requires the conclusion to be a formula variable — it is destructively set to `*False*` and deleted from the premises (`delete_concl`, 441–447); rules failing this are rejected with "Ignoring ill-formed/weak elimination rule" (512–522; cf. blast.ML:18–19 header). Each converted rule carries **the Isabelle tactic that replays it** (see §3.4).

**Skolemization**: blast does not Skolemize the input formula up front. Subgoal parameters become Skolem constants (`fromSubgoal`'s `skoSubgoal`, 1242–1246); rule premises with meta-quantifiers (`⋀x`, i.e. eigenvariable conditions / δ-rules) get Skolem terms applied to the branch's current variables (`skoPrem`, 449–451). The paper (§5) explains why the *liberalized* δ-rules were rejected: with standard δ-rules the tableau inference corresponds exactly to the standard ∃-elimination/∀-introduction rule, so reconstruction inside Isabelle (which has no Skolemization, only eigenvariables via higher-order Vars) stays cheap; liberalized rules would force ε-term manipulation, "prohibitively inefficient".

**Unification** (355–381) is first-order, destructive, trailed (`trail`/`ntrail`, `clearTo` 344–348), with occurs check (`varOccur`); bound variables are de Bruijn; η/β handled minimally (paper §7). No higher-order unification — hence the documented limitation "Function unknown's argument not a bound variable" (blast.ML:20–21, 1215–1219; isar-ref Generic.thy:1526–1530).

### 3.2 Branch representation and search discipline

`type branch` (94–99): `pairs` — a *stack of levels*, each level a pair (safe formulas, deferred unsafe formulas), each formula tagged with an `md` (may-duplicate) flag; `lits` — literals (irreducible w.r.t. the current rules — note "literal" is rule-relative, paper §7); `vars`; `lim` — the resource bound. The stack (LIFO) discipline — newly generated formulas are expanded before older ones — is a deliberate departure from `fast_tac`'s queue discipline (paper §3), and is why reconstruction needs assumption rotation (§3.4).

The engine `prove` (932–1176) processes the first branch's head formula `G` through a cascade (1033–1063), each stage tried on the previous one's failure exception:

1. **Equality substitution** (`equalSubst`, 760–790): if `G` is `s = t` with `s` a substitutable Skolem/Free (occurs-check via `substOccur`, 721–735; orientation via `orientGoal`, 750–755), substitute throughout the branch and delete the equation; affected literals move back to the unexpanded list (a known source of reconstruction failure, header comment 31–35 and paper §7 "Equality"). Records `Data.hyp_subst_tac` as the replay tactic (1036).
2. **Close with a literal** (`closeF lits`, 1008–1025): unify `G` with a complementary literal (`tryClose`, 802–815); replay tactic is assumption (`eq_assume_tac ORELSE assume_tac`) or `notE`-contradiction (`contr_tac`, 798–799).
3. **Close with any queued formula** (`closeFl`, 1027–1031).
4. **Apply a safe rule** (`deeper rules`, 970–1006) from safe0+safep nets: unify rule pattern `P` with `G`; new premises become a new stack level; if unification instantiated branch variables (`updated`), charge `lim - (1 + log₄ (#applicable rules))` (`log`, 899; the paper §4 justifies the log₄N penalty for instantiating inferences as "a compromise between banning instantiation altogether and allowing it freely"); push a choice point; on backtrack (`PRV`), undo the trail and try the next rule.
5. **Defer** (1045–1063): if no safe rule fires, move `G` to the unsafe list of its level (if some unsafe rule could apply) or to `lits`.

When a branch has no safe formulas left at any level (1073–1174), the head *unsafe* formula `H` is expanded: `lim` is decremented by 1 (or the larger instantiation penalty); if `H`'s `md` flag is set, `H` (negated goal form) is **duplicated** — re-queued at the back — implementing γ-rule retention; premises matching the rule's own pattern are detected as "recursive" (transitivity-style) and placed to avoid starving other formulas (1088–1093; paper §7 "Transitivity" and header comment 24–29). Backtracking from an unsafe rule application is allowed only if other rules matched, variables were updated, or no new Vars were introduced (`mayUndo`, 1121–1132 — "aim is to emulate Fast_tac", cf. paper §7 "Undoable rules"). Choice-point **pruning** (`prune`, 841–865; paper §3 "Search-Space Pruning"): when a branch closes, delete choice points of solved sibling goals unless their proofs instantiated variables visible in remaining branches.

### 3.3 Iterative deepening

`blast_tac` (1284–1292) = `SELECT_GOAL (atomize_prems THEN DEEPEN (1, depth_limit) (fn m => raw_blast start ctxt m) 0 1)`: the bound (mainly counting unsafe expansions + instantiation penalties) starts at 0 and increases by 1 up to `blast_depth_limit` (config, default 20; line 79). `(blast n)` maps to `Blast.depth_tac` (1279–1282) with a fixed bound — the isar-ref (Generic.thy:1536–1542) recommends supplying the successful bound to speed up slow blasts. Depth-first iterative deepening is the leanTAP inheritance (paper §3, citing Korf 1985).

### 3.4 Proof reconstruction — verified claim

**Verified: blast does not check or translate the tableau itself; it re-runs a recorded classical proof script through the Isabelle kernel.** Mechanism:

- Every search step conses a *tactic* onto `tacs`: `emtac`/`rmtac` (494–498) do `ematch_tac`/`rmatch_tac` — or `eresolve_tac`/`resolve_tac` when the step instantiated variables (`upd` flag) — with the *original Isabelle theorem* (possibly `rev_dup_elim`/`dup_intr` for duplicating steps, 467, 546), followed by `rot_subgoals_tac` (471–483) which rotates the new hypotheses to mimic the tableau's LIFO stack order (the paper §8.2: "I had to add an Isabelle primitive for re-ordering a subgoal's assumptions", i.e. `Thm.rotate_rule`). Closing steps record assumption/`notE` tactics (802–815); equality steps record `Hypsubst.blast_hyp_subst_tac` (1036, HOL.thy:932), a variant that moves substitution-affected hypotheses to the front to match the branch reordering (hypsubst.ML:236ff.).
- On success the continuation `cont` (1261–1272, inside `raw_blast`) runs `EVERY' (rev tacs) 1 st` — the whole recorded script applied to the original proof state, every inference passing through kernel primitives (`Thm.biresolution` etc.). Search and reconstruction are timed separately (`blast_stats`; "for search" 918–924 vs "for reconstruction" 1268).
- If replay fails, it prints "PROOF FAILED for depth n" and **backtracks into the tableau search** (`backtrack trace choices`, 1265–1266) to find a different tableau proof. The paper (p. 12) confirms: "Rarely, proof reconstruction fails... The usual cause... is that the tableau and Isabelle proofs have somehow diverged", typically branch formulas getting out of order; unsoundness of the untyped search (overloading) is also caught here. This is the LCF-style safety argument (abstract, p. 1): "Because Isabelle verifies the proof, the prover can cut corners for efficiency's sake without compromising soundness", e.g. discarding types.
- The prover does *not* even hand its unifiers to Isabelle: "Isabelle's proof engine repeats the unifications done during the search. An attempt to deliver those instantiations to Isabelle yielded no speed-up" (paper §8.2). Table 1 (paper p. 13) shows reconstruction ("Verify") often costs more than search for long proofs (e.g. Pelletier 34: 200 ms search, 2090 ms verify, 431 tactics).

Limitations that follow from the architecture (blast.ML:14–22; Generic.thy:1518–1534): wrappers ignored (no simplifier integration), elim rules needing non-variable conclusions rejected, no higher-order unification.

---

## 4. auto: precise algorithm (clasimp.ML)

`Clasimp` (clasimp.ML:36) couples the three tools. The bridge is simp-as-wrapper (44–54):

- `addss ctxt` = `Classical.addbefore ("asm_full_simp_tac", CHANGED o asm_full_simp_tac)` — full simplification offered as an **unsafe** wrapper alternative (`APPEND'`) before every unsafe step.
- `addSss ctxt` = `Classical.addSafter ("safe_asm_full_simp_tac", CHANGED o safe_asm_full_simp_tac)` — the *safe* simplifier (safe solver only, no premature instantiation; simpdata.ML:146–151) as a **safe** wrapper tried when ordinary safe steps fail (`ORELSE'`).

What the simplifier does with hypotheses inside these calls is governed by the simpset's `mksimps`: HOL's `mksimps_pairs` (simpdata.ML:186–192, mechanism at 105–125) decompose assumptions through `∧`, `⟶`, `∀`, `If` into rewrite rules.

`mk_auto_tac ctxt m n` (clasimp.ML:147–159), with defaults `auto_tac = mk_auto_tac ctxt 4 2` (161):

```
1  PARALLEL_ALLGOALS (asm_full_simp_tac ctxt)          -- simplify every subgoal (in parallel)
2  THEN TRY (Classical.safe_tac ctxt)                  -- all safe classical steps, no simp
3  THEN REPEAT_DETERM (FIRSTGOAL main_tac)             -- try to *close* goals one at a time:
     main_tac = Blast.depth_tac ctxt m                 --   blast with fixed bound m=4 (fast, no wrappers)
                ORELSE' (CHANGED o nodup_depth_tac (addss ctxt) n)   -- depth-n classical search with simp inside
4  THEN TRY (Classical.safe_tac (addSss ctxt))         -- final safe pass with safe-simp wrapper
5  Simplifier.prune_params_tac                          -- cosmetic: drop unused parameters
```

`nodup_depth_tac` (clasimp.ML:128–143) is exactly `Classical.depth_tac` except its unsafe step uses `unsafe_step_tac` (plain `unsafe_netpair`) instead of `dup_step_tac` — no formula duplication — "a variant of depth_tac that avoids interference of the simplifier with dup_step_tac" (126–127). Since it is wrapped in `CHANGED` rather than required to solve the goal, step 3 can make *partial* progress on a goal via blast-or-search; `REPEAT_DETERM (FIRSTGOAL ...)` keeps going until no goal changes. This is why `auto` acts on **all** subgoals, proves the easy ones, and leaves simplified/clarified residue — and why it is "designed to be idempotent, except if Blast.depth_tac instantiates variables" (145–146). The `(auto m n)` syntax (method parser at 217–221) sets the blast bound `m` (default 4) and the wrapper-aware search depth `n` (default 2), matching isar-ref Generic.thy:1550–1554. The method wraps everything in `CHANGED_PROP`, so `auto` as a method fails if it changes nothing.

So "auto = clasimpset" concretely means: one classical claset + one simpset in the same `Proof.context`; the simpset participates (a) as the up-front and final simplification passes, and (b) via `addss`/`addSss` wrappers inside the classical step tactics; `iff` declarations feed both databases at once (§6).

---

## 5. force, fastforce, clarsimp, slowsimp, bestsimp

All are single-goal (`SELECT_GOAL`/`SIMPLE_METHOD'`) and, except clarsimp, must close the goal:

- **force_tac** (clasimp.ML:167–173):
  ```
  let ctxt' = addss ctxt in SELECT_GOAL
    (Classical.clarify_tac ctxt' 1
     THEN IF_UNSOLVED (Simplifier.asm_full_simp_tac ctxt 1)
     THEN ALLGOALS (Classical.first_best_tac ctxt'))
  ```
  Clarify (non-splitting safe steps), then simplify, then **best-first** search (`first_best_tac`, classical.ML:670) with simp available as an unsafe wrapper; every emerging subgoal must be solved (`ALLGOALS` + `first_best_tac` fails unless it solves). Hence isar-ref: "intended to prove the first subgoal completely... proof attempts may take rather long or diverge" (Generic.thy:1556–1559).
- **fast_force_tac** = `Classical.fast_tac o addss` (clasimp.ML:178): plain `fast` — unbounded **depth-first** `DEPTH_SOLVE (step_tac 1)` — over a claset whose unsafe step also offers `CHANGED o asm_full_simp_tac`. Cheaper and often terminates faster than `force` (no best-first queue, no separate clarify/simp phases). `slow_simp_tac`/`best_simp_tac` (179–180) are `slow`/`best` plus `addss`. Method names `fastforce`, `slowsimp`, `bestsimp` at 225–227.
- **clarsimp_tac** (119–121) = `safe_asm_full_simp_tac THEN_ALL_NEW clarify_tac (addSss ctxt)`: simplify (safely) then clarify, with the safe simplifier re-invoked as a safe wrapper after each failing clarify step. Doesn't close goals; the method is `CHANGED_PROP oo clarsimp_tac` (230–231). Caveat from the manual: a premise splitter in the simpset can still split the subgoal (Generic.thy:1624–1626).

Summary of the family, one line each: `fast`/`best`/`slow` = pure claset search (DFS / best-first / DFS-with-more-backtracking); `deepen` = iterative-deepening DFS with rule duplication; `blast` = external tableau + kernel replay; `fastforce`/`bestsimp`/`slowsimp` = the first three with simp as unsafe wrapper; `force` = clarify + simp + best-first with simp; `auto` = simp-everywhere + safe + (blast ∥ bounded search with simp) on each goal + safe-with-simp, allowed to leave residue; `safe`/`clarify`/`clarsimp` = deterministic residue-producing prefixes of the same machinery.

---

## 6. Context, attributes, and method modifiers

- **Attributes** `[intro!/intro/intro?]`, `[elim...]`, `[dest...]`, `[rule del]` are set up at classical.ML:764–775 via `Context_Rules.add safe_X unsafe_X Context_Rules.X_query` — i.e. the same syntax dispatches `!` to the claset's safe kind, plain to unsafe, and `?` to Pure's `Context_Rules` only. The attribute bodies (`attrib kind w`, classical.ML:740–749) map `extend_rules` over the generic context, so declarations work in theories, locales, and inside proofs (`declare`, `note [intro]`, etc.), and the optional nat is a weight used only for single-rule-step ordering (isar-ref Generic.thy:1401–1404). Deletion `[rule del]` removes from both claset and Context_Rules (751–755).
- **`[iff]`** (clasimp.ML:87–112, 188–195): a (possibly conditional) `A ⟷ B` is added *simultaneously* to the simpset and, via `iffD2`/`iffD1`, as intro+dest pair — safe if unconditional, unsafe if conditional; `¬A` becomes a safe elim via `notE`; other formulas become safe intros. `[iff?]` targets Pure rules only; `[iff del]` removes from both. (isar-ref Generic.thy:1423–1432.)
- **`[swapped]`** (classical.ML:202, 766): user-visible form of the internal swap transformation, "mainly for illustrative purposes" (Generic.thy:1434–1437).
- **Method modifiers**: every classical method accepts `intro!:/intro:/elim:/dest:/del:` sections (`cla_modifiers`, classical.ML:809–816); the clasimp methods additionally accept `simp add/del/only:`, `cong:`, `split:`, `iff:` (`clasimp_modifiers`, clasimp.ML:207–209). These are ordinary attribute applications to a temporary context, so `auto simp: foo intro!: bar` is literally `auto` run in a context extended with those declarations. Chained facts are inserted into the goal first (`SIMPLE_METHOD'`).
- **Storage/merging**: the claset is `Generic_Data` keyed by theorem proposition (`Bires.decls` = `Proptab`), with canonical-order-preserving merge (`Bires.merge_decls`, bires.ML:230–231; `merge_cs` classical.ML:400–422 rebuilds the five netpairs incrementally and merges wrapper alists). Theorems are `trim_context`ed for heap hygiene (classical.ML:342–346).
- The `extra_netpair` also feeds the *structured* `rule` method: with no arguments, `rule` picks applicable declared intro/elim/dest rules from Context_Rules plus the claset's plain rules (`some_rule_tac`, classical.ML:783–793), and `standard_tac` (800–803) is the default initial proof step.
- Pure's parallel `Context_Rules` structure (context_rules.ML) keeps three weighted netpairs of its own (`!`/plain/`?` kinds, lines 93–127) for `rule`-style single stepping and the intuitionistic prover, with its own wrapper lists (157–172) — HOL adds a Pure safe wrapper doing non-bool `hyp_subst_tac` at HOL.thy:854–867.

---

## 7. Comparison: Lean 4's Aesop (Limperg & From, CPP 2023)

Aesop ("Automated Extensible Search for Obvious Proofs") is explicitly a redesign of this idea — the paper names Isabelle's `auto` as the model twice (§1: "Users of Isabelle's auto will recognise some of these features"; §2.4: "Aesop, like Isabelle's auto, lets users mark rules as safe").

Correspondences:

- **Rule sets ≈ claset**: rules are arbitrary tactics registered globally via attributes (`@[aesop safe]`, `@[aesop 50%]`, ...) or per-invocation, organized in named rule sets; *rule builders* (`apply`, `constructors`, `forward`, `destruct`, `cases`, `simp`, `tactic`; §3.1) play the role of intro/elim/dest classification plus HOL's datatype/case machinery. `forward`/`destruct` ≈ dest rules (with an explicit loop-prevention check instead of Isabelle's make_elim format); indexing is by discrimination trees on target or hypothesis patterns (§3.3) ≈ Bires netpairs.
- **Safe/unsafe with the same semantics**: safe rules "are applied eagerly without backtracking... unsafe rules... may be backtracked" (§1); safe rules must preserve provability *relative to the whole rule set* (§2.4 discusses the same subtlety Isabelle's docs discuss — ∧-introduction's safety depends on which other rules exist).
- **Normalization phase ≈ auto's simp passes + safe wrappers**: a distinct rule category applied in a fixpoint loop before search, *including a built-in invocation of Lean's simplifier over goal and hypotheses* (§2.5, §3.2), with hypothesis-as-rewrite behavior mirroring `asm_full_simp`/`mksimps`. Registering unfolding lemmas as normalization rules ≈ `[simp]`/`[iff]` feeding auto.
- **Search**: the big departure. Instead of Isabelle's fixed script (safe-saturate, then depth-first/depth-limited unsafe steps, per-goal), Aesop maintains one global AND/OR tree of goal nodes and rule-application nodes and runs **best-first search** ranked by user-assigned *success probabilities* (rule priority; goal priority = product of probabilities along the path; §2.3). Safe rules get 100%; unsafe rules e.g. 50% for each ∨-intro. This replaces both `best`'s opaque size heuristic and `auto`'s hardwired phase ordering with a single explicit, user-tunable queue — the "white-box" thesis: users should be able to predict how rules will be applied (§1, abstract).
- **Residue**: on failure Aesop reports *safe goals* — what remains after normalization + safe rules only (§2.6) — the exact analogue of `safe`/`clarify`/`clarsimp` residue, and the paper describes the same workflow (run, do the manual step, turn it into a rule).
- **Metavariables**: Aesop needed a new algorithm (§4) to handle goals sharing metavariables under best-first search (copying instead of backtracking), whereas Isabelle's tactics handle shared unknowns by sequence-based backtracking (and blast simply defers to reconstruction; classical.ML's `safe_depth_tac` even switches to `DETERM` when no Vars are present).
- **Soundness architecture**: both are kernel-checked, but differently — Aesop's rules are Lean tactics producing proof terms checked by Lean's kernel as they run, so there is no search/replay split; blast's split (untyped external search, then tactic replay) is unique to its untyped-first-order shortcut.

---

## 8. Quick file/line index

| Mechanism | Location |
|---|---|
| claset record, netpairs | `src/Provers/classical.ML` 241–261; `src/Pure/bires.ML` 251–303 |
| rule kinds, safe/unsafe/extra | `src/Pure/bires.ML` 113–160 |
| dest→elim (`make_elim`), weak-elim repair | `bires.ML` 149; `classical.ML` 150–169 (`classical_rule`), 348–368 (`ext_info`) |
| swap / swapped rules | `classical.ML` 195–213; HOL `swap` lemma `src/HOL/HOL.thy` 819 |
| dup_intr / dup_elim (γ-duplication) | `classical.ML` 216–220, 708–709 |
| safe_step/safe/clarify/step/slow_step | `classical.ML` 581–655; clarify 599–625 |
| fast/best/slow/astar/deepen | `classical.ML` 658–732 |
| wrappers (addSWrapper/addbefore/…) | `classical.ML` 513–574; docs Generic.thy 1672–1760 |
| attributes intro!/elim/dest/rule del | `classical.ML` 736–775; `src/Pure/Isar/context_rules.ML` 176–213 |
| method setup (fast, slow, best, deepen, safe, clarify, step…) | `classical.ML` 824–854 |
| blast branch/state, unification, trail | `src/Provers/blast.ML` 84–111, 344–381 |
| blast rule conversion + replay tactics | `blast.ML` 434–548 (`convertRule`, `fromRule`, `fromIntrRule`, `emtac`/`rmtac`, `rot_subgoals_tac` 471–483) |
| blast main loop, penalties, pruning | `blast.ML` 932–1176; `log` 899; `prune` 841–865 |
| blast reconstruction (`cont`, PROOF FAILED) | `blast.ML` 1254–1277 |
| blast_tac iterative deepening, depth_limit=20 | `blast.ML` 79, 1279–1292 |
| HOL Classical/Blast instantiation | `src/HOL/HOL.thy` 824–852, 923–935; base claset 869–904 |
| hyp_subst_tac / blast_hyp_subst_tac | `src/Provers/hypsubst.ML` 83–104, 200–232, 236ff. |
| addss/addSss, iff attribute | `src/Provers/clasimp.ML` 44–54, 87–112 |
| clarsimp / auto / force / fastforce | `clasimp.ML` 119–121, 126–161, 167–173, 178–180; methods 214–231 |
| mksimps, safe/unsafe simp solvers | `src/HOL/Tools/simpdata.ML` 105–125, 127–151, 186–192 |
| Clasimp/Splitter instantiation | `simpdata.ML` 153–184 |
| user documentation | `src/Doc/Isar_Ref/Generic.thy` 1150–1760 |

Sources: [classical.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/classical.ML), [blast.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/blast.ML), [clasimp.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/clasimp.ML), [hypsubst.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/hypsubst.ML), [bires.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Pure/bires.ML), [context_rules.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Pure/Isar/context_rules.ML), [HOL.thy](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/HOL.thy), [simpdata.ML](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/Tools/simpdata.ML), [Isar_Ref/Generic.thy](https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Doc/Isar_Ref/Generic.thy), [Paulson 1999 blast paper](https://www.cl.cam.ac.uk/~lp15/papers/Reports/blast.pdf), [Limperg & From 2023 Aesop paper](https://people.compute.dtu.dk/ahfrom/aesop-camera-ready.pdf), [Aesop CPP'23 page](https://popl23.sigplan.org/details/CPP-2023-papers/5/Aesop-White-Box-Best-First-Proof-Search-for-Lean).
