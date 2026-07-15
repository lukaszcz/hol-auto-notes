# Isabelle Simplifier vs HOL4 simpLib — Architecture Comparison

> Research report, 2026-07-14.  One of four reports underlying
> `../PLAN.md`.  All cited Isabelle files are vendored at
> `../sources/` (mirror-isabelle commit `f7e02b7e1f31`).  HOL4 paths
> refer to this repository.  See `README.md` for the report index.

## 1. Isabelle's simplifier: algorithm and extension points

Primary sources read (raw fetches from `isabelle-prover/mirror-isabelle`, branch `master`):
- `src/Pure/raw_simplifier.ML` (1576 lines — full core engine)
- `src/Pure/simplifier.ML` (526 lines — tactic layer, simproc_setup)
- `src/HOL/Tools/simpdata.ML` (214 lines — HOL instantiation)
- `src/Provers/splitter.ML` (492 lines)
- `src/Doc/Isar_Ref/Generic.thy` (isar-ref "The Simplifier" chapter, lines 236–1148)
- `src/HOL/Numeral_Simprocs.thy`, `src/HOL/Tools/lin_arith.ML` (simproc/solver examples)

### 1.1 The simpset (raw_simplifier.ML:275–291)

```
Simpset of
 {rules: rrule Net.net, prems: thm list, depth: int * bool ref} *
 {congs: thm Congtab.table * cong_name list,        (* weak-cong names *)
  procs: term procedure Net.net * term procedure Net.net,  (* simprocs, congprocs *)
  mk_rews: {mk, mk_cong, mk_sym, mk_eq_True, reorient},
  term_ord: term ord,
  subgoal_tac: ctxt -> int -> tactic,
  loop_tacs: (string * (ctxt -> int -> tactic)) list,
  solvers: solver list * solver list}               (* unsafe, safe *)
```

An `rrule` (lines 135–142) carries `thm, name, lhs, elhs` (eta-contracted lhs used for matching), `extra` (extra Vars outside elhs), `fo` (first-order matching complete or lhs not a pattern), `perm` (permutative). Rules live in a first-order discrimination net keyed on `elhs`. The simpset is context data (`Generic_Data`, line 381) merged monotonically through the theory hierarchy; `[simp]`/`[cong]`/`[split]` attributes and `simp add/del/flip/only`, `cong add/del`, `split` method modifiers manipulate it (simplifier.ML:442–488).

### 1.2 Rule preprocessing (mksimps / reorient / mk_eq_True)

`mk_rrule` (raw_simplifier.ML:569): decompose `prems ⟹ lhs ≡ rhs`; if lhs/rhs are variable permutations of each other → mark `perm`; if extra vars on rhs or Var-headed lhs → fall back to `P ≡ True` form (`mk_eq_True`). `orient_rrule` (line 581) additionally applies the `reorient` heuristic (line 189: extra vars, Var head, rhs occurs in lhs, lhs matches rhs, const→non-const) and tries `mk_sym` to flip badly oriented rules, used when goal premises become rewrites. The `mk_rews` record is fully pluggable; HOL installs it in simpdata.ML:194–202 — `mksimps` with `mksimps_pairs` (line 186: `P⟶Q ↦ mp`, conjuncts, `spec`, if-elimination) plus `mk_eq`: `⊢P ↦ P≡True`, `⊢¬P ↦ P≡False`, `=` ↦ `≡` via `eq_reflection`, and `mk_meta_cong` for `cong` attribute normalization.

### 1.3 The rewriting strategy (bottomc, lines 1225–1443)

Strictly **bottom-up** (isar-ref line 246: "strictly bottom up, except for congruence rules, which are applied while descending"). `botc` first recurses into subterms (`subc`), then rewrites the node (`rewritec`), and repeats until no rule fires. Key devices:

- **Skeleton optimization** (lines 973–1008): the rhs of the just-applied rule is decomposed in parallel with the term; when the skeleton is a Var, the corresponding subterm is already in normal form and is skipped. The rhs may serve as skeleton only if no **weak congruence** (or weak congproc) hides unnormalized bits in the lhs (`uncond_skel`/`cond_skel`).
- **`rewritec`** (line 1020): tries in order (1) beta-redex reduction, (2) rules from `Net.match_term`, sorted unconditional-first (`sort_rrules`), (3) simprocs from the simproc net whose lhs pattern `Pattern.matches` the redex. For a conditional rule, the instantiated premises are proved by the **prover** (the mutual-recursion into the solver pipeline); depth-guarded by `simp_depth_limit` (declared default 40 at raw_simplifier.ML:433; isar-ref table says attribute default 100). For a `perm` rule, applied **only if** `term_ord (rhs', lhs') = LESS` — ordered rewriting; the order is per-simpset (`set_term_ord`, default `Term_Ord.term_ord`).
- **Congruence rules** (`subc` + `congc`, lines 1189–1312): at an application `h t1…tn`, congprocs are tried first (most-specific pattern first, `pattern_order`), then the *single* cong rule stored for head `h` in `Congtab`. If found, the instantiated cong rule's premises are proved by the prover; premises of form `x ≡ ?y` cause recursive simplification of exactly those arguments; premises not of that form are side conditions. Non-"full" congs (not covering all args with distinct vars, `is_full_cong` line 703) are recorded as **weak** and disable the skeleton optimization for that constant. Failing conditional congs are silently ignored (isar-ref line 1032). **Congprocs** (`proc_kind = Congproc weak`, new-ish) prove congruence rules on the fly.
- **Meta-implication / assumptions** (`impc`/`mut_impc`, lines 1315–1441): when simplifying `A ⟹ B` with mode `(simprem, useprem, mutsimp)`, premises are converted to rewrites via `extract_safe_rrules` (i.e., the object-logic mksimps + orient heuristics) and added to `rules` + `prems`. `mut_impc` performs **mutual, fixpoint simplification of the premises using each other** (with `disch`/`swap_prems_eq` bookkeeping and change counting); `nonmut_impc` is the legacy left-to-right mode. Modes map to tactics (simplifier.ML:350–354): `simp_tac (F,F,F)`, `asm_simp_tac (F,T,F)`, `full_simp_tac (T,F,F)`, `asm_lr_simp_tac (T,T,F)`, `asm_full_simp_tac (T,T,T)`; Isar `(no_asm)`, `(no_asm_simp)`, `(no_asm_use)`, `(asm_lr)`, default = asm_full.

### 1.4 The outer loop: subgoaler / solver / looper (simplifier.ML:312–329)

```
simp_loop_tac i =
  generic_rewrite_goal_tac mode (solve_all_tac unsafe_solvers) ctxt i THEN
  (solve_tac i ORELSE TRY ((loop_tac THEN_ALL_NEW simp_loop_tac) i))
```

- **Subgoaler**: tactic for subgoals from conditional rewrites/cong premises; default `asm_simp_tac` (set in simpdata.ML:199 / simplifier.ML:521) — i.e., the simplifier recursively. `solve_all_tac` = DEPTH_SOLVE of subgoaler with a given solver list installed.
- **Solvers**: two slots, *safe* and *unsafe*, each a list. Applied to what remains after rewriting; must handle `t = ?x` (congruence residues) by reflexivity. HOL's unsafe solver (simpdata.ML:127): resolve with `TrueI/refl/prems`, assumption, `FalseE`, splitting `conjI`, and `simp_impliesI` handling; HOL additionally adds **linear arithmetic as an unsafe solver** (lin_arith.ML:949). Solvers may instantiate unknowns — this is how conditional rules with extra condition variables get solved.
- **Loopers**: named list of tactics tried when the solver fails; on success the whole simplification restarts on each resulting subgoal. `simp only:` clears rules, congs *and* loopers but keeps solvers (isar-ref lines 299–305). The **splitter is installed as a looper** (`Splitter.add_split` → `Simplifier.add_loop ("split <name> :: <ty>", tac)`, splitter.ML:441–453); `split!` additionally runs the classical `safe_tac` after each split.

### 1.5 Simprocs

Declared with `simproc_setup name (pat1 | pat2 …) = ML` (simplifier.ML:160–231); certified terms as lhs patterns, stored in a discrimination net; invoked only when a pattern matches the redex (raw_simplifier.ML:1099–1121); the ML function `Proof.context -> cterm -> thm option` returns a (possibly conditional) rewrite `t ≡ u` which is then applied like an ordinary rrule (`mk_procrule`). Examples: `unit_eq` simproc (isar-ref line 874), ~40 cancellation simprocs in `src/HOL/Numeral_Simprocs.thy` (`nateq_cancel_numerals` etc.), `Fast_Arith.lin_arith_simproc` (lin_arith.ML:876). Simprocs are named objects in a name space, addable/removable via `[[simproc add/del: name]]`, and can be `passive`, `congproc`, or `weak_congproc`.

### 1.6 Ordered / permutative rewriting

isar-ref lines 622–707: permutative rules detected automatically (`var_perm`); applied only if the redex strictly decreases in `term_ord`. For AC operators the user supplies A (oriented l-to-r), C, and derived left-commutativity LC; ordered rewriting then bubble-sorts operands. Default order is a lexicographic structural order; replaceable per simpset via `Simplifier.set_term_ord`.

## 2. The splitter's algorithm (src/Provers/splitter.ML)

Split rules have the shape `?P(c t1…tn) = rhs` (`c` = `If`, a case constant, …; the whole point: `?P` captures arbitrary context). `split_thm_info`/`cmap_of_split_thms` (lines 58–81) index rules by the head constant `c`, distinguishing `_asm` rules (whose rhs starts with negation). `split_tac` (line 356):

1. `select` (line 288) scans the goal conclusion for occurrences of `c`-applications first-order-matching a rule pattern, producing "split packs" `(thm, apsns, pos, TB, tt)` where `apsns` records the λ-abstractions on the path (bound variables the split must be lifted over) and `pos` the path; packs sorted "shorter first" (fewest abstractions, then position).
2. Goal `⊢ t` is attacked via `meta_iffD` (`(P≡Q) ⟹ Q ⟹ P`), reducing to proving `t ≡ ?rhs`.
3. If the redex sits under abstractions, the **lift theorem** `⟦⋀x. Q x ≡ R x; P(λx. R x) ≡ C⟧ ⟹ P(λx. Q x) ≡ C` (proved on the fly, line 101) is instantiated with the computed context `P` (`mk_cntxt`, `inst_lift`) and composed repeatedly until the innermost occurrence is exposed; then the split theorem itself is instantiated with context abstraction `P := λa. …a…` (`mk_cntxt_splitthm`, `inst_split`) and composed.
4. `split_asm_tac` (line 389) splits inside a premise by contraposition: rotate the target premise, `contrapos2` moves it into the conclusion, `split_tac`, `contrapos` moves it back, then the resulting `∨/∧/∃/¬¬` structure is flattened with `disjE/conjE/exE/notnotD` — this **multiplies subgoals**.
5. `add_split` inspects the rule and installs the right variant as a looper; `add_split_bang` chains classical `safe_tac` after it. `split_inside_tac` uses the reversed pack order (innermost occurrence first).

The HOL instantiation (simpdata.ML:153–166) supplies `iffD2/disjE/conjE/exE/contrapos/notnotD` and `Classical.safe_tac`.

## 3. HOL4 simpLib architecture

All paths under `/home/lukasz/dev/HOL/worktrees/isabelle-tactics/`. simpLib.sml's header says it is "not-so-loosely" based on the Isabelle simplifier; `src/simp/src/notes.md` is a good design overview.

### 3.1 Layering

- **`src/simp/src/Travrules.sml`** — *preorders* (`PREORDER(rel, TRANS, refl)`) and `travrules` = `{relations, congprocs, weakenprocs}`. The engine is parametric in the relation: rewriting can proceed over any reflexive-transitive relation, not just `=` (`EQ_tr` is the equality instance). Weakenprocs allow switching to a weaker relation mid-traversal (`add_relsimp`/`add_weakener` in simpLib.sml:404–617, e.g. `permLib`-style relational simplification with `subsets` munging context thms into the relation).
- **`src/simp/src/Opening.sml`** — congruence procedures. `CONGPROC refl congrule` (line 126) turns a theorem `cond1 ⟹ … ⟹ R lhs rhs` into a congproc: `HO_PART_MATCH` the conclusion's lhs against the term; walk the antecedents distinguishing *sub-congruences* (`… ⟹ R' arg ?genvar`, dispatched to `depther` with the ASSUME'd hypotheses as new context — hypotheses marked for "reprocessing" if non-variable, e.g. `~g` in `COND_CONG`) from *side conditions* (sent to the `solver`); handles higher-order/bound-variable arguments by abstraction (`MK_ABSL_CONV`). If nothing changed anywhere it raises `UNCHANGED` (consumed specially by `Traverse.FIRSTCQC_CONV`). `EQ_CONGPROC` (line 268) is the generic fallback: `MK_COMB`/`AP_THM`/`AP_TERM`/`ABS` descent with alpha-renaming against context free variables.
- **`src/simp/src/Traverse.sml`** — the traversal engine. *Reducers* (line 36) are the sole extension point: `{name, initial: context(exn), addcontext, apply{solver,conv,context,stack,relation}}`. Two priority bands: `rewriters` (high) and `dprocs` (low). The main loop (line 276):

  ```
  loop = REPEATQC high_priority THENQC
         (descend IFCQC (fn change =>
             ((if change then high_priority else NO_CONV) ORELSEC
              low_priority ORELSEC weaken) THENCQC loop))
  ```

  i.e. **top-down**: rewrite at the node to quiescence, descend once via the first applicable congproc, then retry rewrites / try dprocs / try weakening, and loop on change. Side-condition solver = `EQT_ELIM o (recursive traversal under equality)` — hardwired recursive simplification. An optional `limit` (count of reducer applications, `Uref` decremented in `apply_reducer`) aborts runaway traversals; it is restored when a side-condition attempt fails.
- **`src/simp/src/Cond_rewr.sml`** — `COND_REWR_CONV` (line 140) turns one canonical conditional equation into a rewriting conv: `HO_PART_MATCH` on the lhs; **loop protections**: fail if an instantiated condition is already on the side-condition `stack` (aconv), if `length stack + conditions > !stack_limit` (default 4, line 11), if lhs = rhs, or — for permutative rules (`is_var_perm`) — if `ac_term_ord(l,r) <> GREATER` (ordered rewriting; fixed order at lines 32–91, size-first, AC-compatible, "based on some code in Isabelle", Vars > constants). Conditions are then solved by the passed solver and MP'd. `mk_cond_rewrs = QUANTIFY_CONDITIONS oo IMP_EQ_CANON oo IMP_CANON` (line 471) is the HOL4 `mksimps`: splits conjunctions, moves antecedents into hypotheses (incl. disjunctive/existential antecedent case analysis), `P ↦ P=T`, `¬P ↦ P=F`, `¬(a=b) ↦ (a=b)=F ∧ (b=a)=F`, looping equations ↦ `EQT_INTRO` both ways, extra rhs vars ↦ EQT form, `Abbrev` handling, then re-discharges conditions conjoined and existentially quantifies condition-only variables (`LEFT_FORALL_IMP_THM`) — extra condition vars become `∃`-side conditions (solved e.g. by `SatisfySimps.SATISFY_ss`, `src/simp/src/Satisfy.sml`, a dproc that unifies existential goals against context facts).
- **`src/simp/src/simpLib.sml`** — simpsets and fragments.
  - `ssfrag` (line 94): `{name, convs, rewrs (named), ac : (thm*thm) list, filter, dprocs, congs, relsimps}`. `SSFRAG` normalizes congs to iterated-implication form (`normCong`, line 107).
  - `simpset` (line 251): `{mk_rewrs, history, initial_net : Ho_Net of named convs, dprocs, travrules, limit, excluded}`. `ss ++ frag` (line 636) composes the `filter` onto `mk_rewrs`, converts `ac` pairs via `Drule.MK_AC_LCOMM` into the A/C/LC **triple automatically** (line 371), turns each rewrite into a keyed conv via `mk_rewr_convdata`/`COND_REWR_CONV` (key = lhs pattern in a **higher-order** term net, Ho_Net), and merges congs into travrules. Rewrites carry names (`thy$name`) supporting `-*`/`remove_simps`/`Excl "name"` removal and `Excl`, `ExclSF`, `SF fragname`, `Cong th`, `AC th1 th2` **markers inside the theorem-list argument** (`process_tags`, line 834); `exclude_ssfrags`/`force_add` (lines 721–747) give persistent exclusion with override; `history` allows rebuilding.
  - Bounded rewrites: `Once`/`Ntimes` theorems (BoundedRewrites) become convs that count down a ref (`appconv`, line 53); bounded permutative rules skip the term-order guard.
  - `rewriter_for_ss` (line 755) is the high-priority reducer: its `addcontext` runs `mk_rewrs` over incoming context theorems (goal assumptions in `ASM_SIMP_TAC`, and congruence-rule assumptions from `Opening`) and inserts them in the net — so contextual assumptions are canonicalized exactly like user rewrites. `SIMP_QCONV = TRAVERSE {rewriters=[rewriter_for_ss ss], dprocs, relation=equality, travrules, limit}`.
  - dprocs: e.g. `numSimps.ARITH_ss` (`src/num/arith/src/numSimps.sml:477–518`) wraps a **cached** (`src/simp/src/Cache.sml`) linear-arithmetic reducer whose `addcontext` filters context thms down to Presburger facts — the analogue of both Isabelle's lin-arith *solver* and *simproc*, but running as a low-priority in-traversal reducer.
- **Default fragments** (`src/simp/src/boolSimps.sml`): `pure_ss` = just the `mk_cond_rewrs` filter (pureSimps.sml); `bool_ss = pure_ss ++ BOOL_ss ++ NOT_ss ++ CONG_ss ++ UNWIND_ss` (line 214), where `CONG_ss` = `IMP_CONG, COND_CONG, RES_FORALL_CONG, RES_EXISTS_CONG` (line 121) — so contextual `⟹`/`if` simplification matches Isabelle's `if_cong` behaviour; beta-conversion is an ordinary keyed conv; `UNWIND_ss` does point-wise ∃/∀ elimination (`src/simp/src/Unwind.sml` — cf. Isabelle's `Quantifier1` simprocs in simpdata.ML:10).
- **Tactic layer**: `SIMP_TAC ss ths` ignores assumptions (inserts `NoAsms` marker); `ASM_SIMP_TAC` adds goal assumptions as context (≈ `(simp (no_asm_simp))`); `FULL_SIMP_TAC`/`fs` (simpLib.sml:929–962) simplifies assumptions **one pass, oldest-first, each using the already-simplified earlier ones** plus the goal (≈ `asm_lr` mode, not a fixpoint), `REV_FULL_SIMP_TAC`/`rfs` the reverse order; `global_simp_tac`/`gs/gvs` (line 980) repeats over all assumptions until quiescence — the closest to Isabelle's `mut_impc` fixpoint, but at tactic level with re-stripping/var-elimination options. `RW_TAC/SRW_TAC` (`src/basicProof/BasicProvers.sml:1005–1110`) interleave simplification with `IF_CASES_TAC` if-splitting, `VAR_EQ_TAC` substitution, stripping and let-elimination in a fixed tactic loop; `PRIM_NORM_TAC` additionally `CASE_TAC`-splits case expressions.
- **Stateful simpset**: `srw_ss()` (BasicProvers.sml:1119–1330) — a global `srw_state` seeded with `bool_ss ++ combinSimps ++ …`, extended per-datatype by TypeBase, persisted across theories via `ThmSetData.export_with_ancestry`; `export_rewrites` adds named theorems, `augment_srw_ss` adds fragments; `Theory.adjoin`-style deltas replay on descendant-theory load.

## 4. Gap analysis

| Feature | Isabelle simp | HOL4 simpLib | Gap |
|---|---|---|---|
| Traversal order | Strictly bottom-up with rhs-skeleton tracking to skip normal subterms (raw_simplifier.ML:973–1008) | Top-down `TOP_DEPTH`-style; re-traverses rewritten terms; only optimization is `UNCHANGED`-propagation from congprocs | HOL4 lacks skeleton/normal-form memoization → repeated renormalization; Isabelle's weak-cong bookkeeping exists precisely to keep this optimization sound |
| Congruence rules | One per head constant (`Congtab`); strong (full) vs weak distinction affects skeleton; conditional congs; congprocs generate congs on the fly, pattern-net-indexed, specificity-ordered | Arbitrary list of congprocs tried in order, HO-pattern-matched (so several per constant possible, and patterns can be deeper than a head constant); no weak/strong notion (no skeleton to protect); congs work over **any registered preorder** | Different trade-offs. HOL4 lacks: congproc-style procedural congruence API surfaced through ssfrags (Opening's congproc type is procedural, but `SSFRAG` only accepts theorem congs). Isabelle lacks: congruence/rewriting over arbitrary preorders + weakening (HOL4 `relsimp_ss`, `add_weakener`) |
| Splitter | In-engine looper; splits `?P(c args)` in conclusion or premises under λ-binders via lift theorem; `split:` modifier, `split!` + safe_tac; restart-simp-on-split | **No looper hook at all.** Splitting lives outside simp: `RW_TAC`'s `IF_CASES_TAC`, `CASE_TAC`, `TypeBase` case rewrites, `COND_elim_ss` rewrites, or manual `Cases_on` | Biggest structural gap on HOL4 side: HOL4's simp cannot split-and-resume inside a single invocation; if/case splitting under quantifiers or in premises must be scripted manually |
| Loopers (general) | Named tactic list, run after solver failure, restart simplification (isar-ref 1041–1119) | Absent | as above |
| Solvers | Safe/unsafe solver stacks, pluggable; solvers may instantiate unknowns; HOL adds lin-arith as unsafe solver; must solve `t = ?x` residues | Hardwired: side conditions solved by recursive simplification to `T`; instantiation only via dprocs like `SATISFY_ss` (unification against context) inside traversal | HOL4 has no user-pluggable solver slot; can't easily bolt an arbitrary tactic onto side-condition discharge. Conversely HOL4's `QUANTIFY_CONDITIONS`+SATISFY gives principled ∃-conditions where Isabelle relies on solver instantiating schematic vars |
| Subgoaler | Pluggable (`set_subgoaler`, default `asm_simp_tac`) | Hardwired recursive traversal | HOL4 lacks the hook |
| Decision procedures | Simprocs (rewrite-producing, pattern-indexed net) + solvers | `convs` keyed in Ho_Net (= simprocs; equivalent triggering, higher-order nets vs Isabelle's fo nets + `Pattern.matches` check) + low-priority `dprocs` with private incremental context and result `Cache` | Rough parity; HOL4 dprocs see context incrementally via `addcontext` (Isabelle simprocs re-read `prems_of` each call). Isabelle simprocs are first-class named objects with morphism/locale support; HOL4 convs are removable by name but not locale-aware |
| Conditional rewriting recursion control | `simp_depth_limit` (~40/100 nested invocations); premise-on-stack not checked | Side-condition **stack** with aconv-membership loop cut + `stack_limit` = 4 (!) total conditions; optional global rewrite-count `limit` on the simpset | Different philosophies: HOL4's stack cut kills loops Isabelle only catches by depth; but 4 is very shallow — deeply conditional rule sets that work in Isabelle can fail in HOL4. Isabelle has no rewrite-count budget (HOL4 `limit`) |
| Permutative rules | Auto-detected; ordered rewriting wrt per-simpset `term_ord` (settable); AC needs manual A+C+LC (or `ac_simps` collections) | Auto-detected in `COND_REWR_CONV`; fixed `ac_term_ord` (not settable); `ac_ss`/`AC th1 th2` **auto-derives LC** from A+C (`MK_AC_LCOMM`); bounded (Once) rewrites bypass the order check | Parity on mechanism; HOL4 nicer AC UX; Isabelle customizable order |
| Assumption usage | One engine, 5 modes; `asm_full` does **mutual fixpoint** premise simplification (`mut_impc`) inside the kernel-level conversion; premises→rewrites via mksimps with reorient/mk_sym/eq_True fallbacks | Modes are separate tactics: `SIMP/ASM_SIMP/FULL_SIMP/REV_FULL_SIMP/global_simp`; `fs` ≈ one `asm_lr` pass (moving asms through the goal), fixpoint only via `gs`; assumption canonicalization via `mk_rewrs` incl. looping-rule EQT fallback | So no, HOL4 `fs` ≠ Isabelle `simp` on asms: no in-engine mutual fixpoint; ordering artifacts differ (hence `rfs` existing at all). But HOL4's tactic-level version can strip/case-split assumptions as it goes, which Isabelle's cannot |
| `simp only:` | Clears rules+congs+loopers, keeps solvers | No direct analog; `SIMP_TAC pure_ss [ths]` (keeps nothing but mk_rewrs), `PURE_REWRITE_TAC`, or `-*`/`Excl`/`ExclSF` subtraction | Approximate parity via pure_ss, but "keep solvers/dprocs" variant must be assembled by hand |
| Rule bookkeeping | `simp add/del/flip`, duplicate detection in net, `print_simpset`, named simprocs; simpsets merge with theory merges; localized to contexts/locales | Named rewrites (`thy$name`), `Excl`/`ExclSF`/`SF`/`Cong`/`AC` **markers in the theorem list**, `exclude_ssfrags`/`force_add`, fragment registry, `-*`, history-based rebuild, `pp_simpset`; `track`/`used_rewrites` reporting | HOL4's per-invocation surface is arguably richer (fragment exclusion, tracking); Isabelle's persistence/scoping (local theories, locales, morphisms) is far more principled than the single global `srw_ss()` + ThmSetData ancestry replay |
| Bounded rewriting | None inside simp (use `subst` etc.) | `Once`/`Ntimes` per-theorem bounds | HOL4-only feature |
| Non-equality relations | Simplifier fixed to `≡` (object iff lifted via mk_eq) | Preorder-parametric engine (travrules), weakening congruences, `relsimp_ss` | HOL4-only feature |
| Goal-state integration | `simp_all` with parallel goals; methods fail if unchanged; safe variants for classical-reasoner integration (`clasimp`: `auto`, `force`, …) | Tactics never fail; no parallel all-goals simp; integration is ad hoc (`RW_TAC`, bossLib's `metis`/`decide` finishers) | Isabelle's clasimp fusion (simp+classical) has no HOL4 counterpart; HOL4 compensates with `RW_TAC`-style scripted loops |
| Tracing | `simp_trace`, depth-limited tracing, `trace_ops` hook (interactive Simplifier_Trace in PIDE) | `Trace` levels 1–7, `track_rewrites` | Isabelle's interactive trace is richer |

## 5. Everything read

Isabelle (fetched raw):
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Pure/raw_simplifier.ML
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Pure/simplifier.ML
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/Tools/simpdata.ML
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Provers/splitter.ML
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/Doc/Isar_Ref/Generic.thy (isar-ref "The Simplifier")
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/Numeral_Simprocs.thy
- https://raw.githubusercontent.com/isabelle-prover/mirror-isabelle/master/src/HOL/Tools/lin_arith.ML

HOL4 (local worktree `/home/lukasz/dev/HOL/worktrees/isabelle-tactics/`):
- `src/simp/src/simpLib.sml`, `src/simp/src/simpLib.sig`, `src/simp/src/Traverse.sml`, `src/simp/src/Travrules.sml`, `src/simp/src/Cond_rewr.sml`, `src/simp/src/Opening.sml`, `src/simp/src/boolSimps.sml`, `src/simp/src/pureSimps.sml`, `src/simp/src/Satisfy.sml`, `src/simp/src/notes.md` (design notes), plus targeted reads of `src/simp/src/Unwind.sml`/`Cache.sml` context
- `src/basicProof/BasicProvers.sml` (RW_TAC/PRIM_STP_TAC/PRIM_NORM_TAC lines 1005–1110; srw_ss/ThmSetData/export_rewrites lines 1119–1330)
- `src/num/arith/src/numSimps.sml` (ARITH_REDUCER/ARITH_ss, lines 462–519)

One correction to a common assumption: the isar-ref manual's attribute table lists `simp_depth_limit` default as 100, but the Pure code declares 40 (raw_simplifier.ML:433) — worth double-checking which applies in current HOL sessions if this matters for a port.
