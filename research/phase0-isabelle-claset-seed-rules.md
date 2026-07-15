# Isabelle base claset rules vs. HOL4 core theorems (Phase 0 planning report)

> Research report, 2026-07-15.  One of four reports produced by parallel
> research agents during the Phase 0 planning round (see `README.md`),
> underlying `../PLAN_phase_0.md` §7.  Isabelle citations resolve against
> `../sources/` (commit `f7e02b7e1f31`); HOL4 citations refer to this
> repository (worktree `isabelle-tactics`, HEAD `af5d4a63f`).

Context: Isabelle's base claset (`src/HOL/HOL.thy:819-935`) declares the
rules below; this report determines, for each, whether HOL4 already has
the corresponding *theorem* (not ML derived rule), under what name and
statement.  All HOL4 statements were verified by printing the actual
theorems from the built `boolTheory` (source `src/bool/boolScript.sml`,
cited by line) and by `DB.match` sweeps over every theory in the default
hol heap for the missing forms.  HOL4 states everything with object-level
`==>` / `!` in curried form (e.g. `|- !t1 t2. t1 ==> t2 ==> t1 /\ t2`),
since it has no meta-implication.

| Isabelle rule | Isabelle statement | HOL4 counterpart |
|---|---|---|
| `refl` | `t = t` | **bool.EQ_REFL** `\|- !x. x = x` (boolScript.sml:1154); `REFL_CLAUSE` `\|- !x. x = x <=> T` (1160) |
| `TrueI` | `True` | **bool.TRUTH** `\|- T` (432) |
| `iffI` | `(A⟹B) ⟹ (B⟹A) ⟹ A=B` | **bool.IMP_ANTISYM_AX** `\|- !t1 t2. (t1 ==> t2) ==> (t2 ==> t1) ==> (t1 <=> t2)` (471; a proved thm despite the `_AX` name) |
| `notI` | `(A⟹False) ⟹ ¬A` | **bool.IMP_F** `\|- !t. (t ==> F) ==> ~t` (843) |
| `impI` | `(P⟹Q) ⟹ P⟶Q` | N/A — meta/object mediation; kernel rule `DISCH`.  No theorem, none possible/needed |
| `conjI` | `⟦P;Q⟧ ⟹ P∧Q` | **bool.AND_INTRO_THM** `\|- !t1 t2. t1 ==> t2 ==> t1 /\ t2` (694) |
| `disjCI` | `(¬B⟹A) ⟹ A∨B` | **bool.DISJ_EQ_IMP** `\|- !A B. A \/ B <=> ~A ==> B` (4469) — equation form, and it discharges the *first* disjunct's negation (Isabelle discharges the second).  No exact implication-form thm |
| `allI` | `(⋀x. P x) ⟹ ∀x. P x` | N/A — kernel rule `GEN`.  No theorem, none possible |
| `ex_ex1I` | `∃x. P x ⟹ (⋀x y. ⟦P x;P y⟧⟹x=y) ⟹ ∃!x. P x` | **bool.EXISTS_UNIQUE_THM** `\|- (?!x. P x) <=> (?x. P x) /\ !x y. P x /\ P y ==> x = y` (2732; note `P` is **free**, not `!P.`) — RL direction |
| `FalseE` | `False ⟹ P` | **bool.FALSITY** `\|- !t. F ==> t` (495) |
| `conjE` | `⟦A∧B; ⟦A;B⟧⟹R⟧ ⟹ R` | **MISSING** as elim form.  Projections exist: `AND1_THM` `\|- !t1 t2. t1 /\ t2 ==> t1` (709), `AND2_THM` (723); converter `AND_IMP_INTRO` `\|- !t1 t2 t3. t1 ==> t2 ==> t3 <=> t1 /\ t2 ==> t3` (2283) |
| `disjE` | `⟦P∨Q; P⟹R; Q⟹R⟧ ⟹ R` | **bool.OR_ELIM_THM** `\|- !t t1 t2. t1 \/ t2 ==> (t1 ==> t) ==> (t2 ==> t) ==> t` (820); also `DISJ_IMP_THM` `\|- !P Q R. P \/ Q ==> R <=> (P ==> R) /\ (Q ==> R)` (2221) |
| `impCE` | `⟦A⟶B; ¬A⟹R; B⟹R⟧ ⟹ R` | **MISSING** as elim form.  Classical equation exists: **bool.IMP_DISJ_THM** `\|- !A B. A ==> B <=> ~A \/ B` (2167) |
| `iffCE` | `⟦P=Q; ⟦P;Q⟧⟹R; ⟦¬P;¬Q⟧⟹R⟧ ⟹ R` | **MISSING** as elim form.  Classical equation exists: **bool.EQ_EXPAND** `\|- !t1 t2. (t1 <=> t2) <=> t1 /\ t2 \/ ~t1 /\ ~t2` (2342) |
| `exE` | `⟦∃x. P x; ⋀x. P x⟹Q⟧ ⟹ Q` | **MISSING** as theorem (kernel rule `CHOOSE`).  DB.match over the whole heap finds no `(?x. P x) ==> (!x. P x ==> Q) ==> Q` |
| `alt_ex1E` | `⟦∃!x. P x; ⋀x. ⟦P x; ∀y y'. P y∧P y'⟶y=y'⟧⟹R⟧⟹R` | **bool.EXISTS_UNIQUE_THM** (2732) LR direction gives exactly the needed content (`?x. P x` + pairwise-equality conjunct); elim packaging itself missing |
| `exI` | `P x ⟹ ∃x. P x` | **MISSING** as theorem (kernel rule `EXISTS`).  No `P y ==> ?x. P x` anywhere in the heap.  (Only special case: `EXISTS_REFL` `\|- !a. ?x. x = a`, 3333) |
| `ex1I` | `P a ⟹ (⋀x. P x⟹x=a) ⟹ ∃!x. P x` | **MISSING**.  Related: **bool.EXISTS_UNIQUE_ALT'** `\|- (?!x. P x) <=> ?x. !y. P y <=> y = x` (2748, `P` free) — intro form derivable but not stated |
| `ext` | `(⋀x. f x = g x) ⟹ (λx. f x)=(λx. g x)` | **bool.EQ_EXT** `\|- !f g. (!x. f x = g x) ==> f = g` (1188); equation form **FUN_EQ_THM** `\|- !f g. f = g <=> !x. f x = g x` (1200) |
| `allE` / `spec` | `⟦∀x. P x; P x⟹R⟧ ⟹ R` | **MISSING** as theorem (kernel rule `SPEC`).  No `(!x. P x) ==> P y` theorem exists in the heap |
| `swap` | `¬P ⟹ (¬R ⟹ P) ⟹ R` | **MISSING**.  Nearest: **bool.MONO_NOT** `\|- (y ==> x) ==> ~x ==> ~y` (3214), **MONO_NOT_EQ** `\|- y ==> x <=> ~x ==> ~y` (3232), **CONTRAPOS_THM** `\|- !t1 t2. ~t1 ==> ~t2 <=> t2 ==> t1` (4487) |
| `classical` | `(¬P ⟹ P) ⟹ P` | **MISSING**.  Nearest: **bool.PEIRCE** `\|- ((P ==> Q) ==> P) ==> P` (4408; note free vars, not `!`-quantified) |
| `notE` | `⟦¬P; P⟧ ⟹ R` | **MISSING** in exact form (`~p ==> p ==> r`).  **bool.F_IMP** `\|- !t. ~t ==> t ==> F` (855) is the `R = F` instance; chain with `FALSITY`.  (Kernel ML rule `NOT_ELIM`, std-thm.ML:1050, is a rule not a thm.)  Also **sat.AND_INV_IMP** `\|- !A. A ==> ~A ==> F` (src/HolSat/satScript.sml:22) |
| `impE` | `⟦A⟶B; A; B⟹R⟧ ⟹ R` | **MISSING** (trivial from MP; no stated theorem) |
| `mp` | `⟦P⟶Q; P⟧ ⟹ Q` | N/A — kernel rule `MP` (std-thm.ML:449).  Theorem form `(p ==> q) ==> p ==> q` not stated anywhere |
| `subst` / `ssubst` | `s = t ⟹ P s ⟹ P t` | **MISSING** as theorem (kernel rule `SUBST`, std-thm.ML:353).  No `(x = y) ==> P x ==> P y` in the heap |
| `iffD1` | `Q = P ⟹ Q ⟹ P` | **bool.EQ_IMPLIES** `\|- !t1 t2. (t1 <=> t2) ==> t1 ==> t2` (1117); also first conjunct of **EQ_IMP_THM** `\|- !t1 t2. (t1 <=> t2) <=> (t1 ==> t2) /\ (t2 ==> t1)` (2313) |
| `iffD2` | `P = Q ⟹ Q ⟹ P` | **MISSING** as standalone; second conjunct of **bool.EQ_IMP_THM** (2313) after instantiation.  Kernel rule `EQ_MP` + `SYM` covers it operationally |
| `ccontr` | `(¬P ⟹ False) ⟹ P` | **MISSING** in boolTheory (kernel ML rule `CCONTR`, std-thm.ML:1080).  Equation form exists: **sat.NOT_ELIM2** `\|- ~A ==> F <=> A` (src/HolSat/satScript.sml:31); also **sat.pth_nn** `\|- ~~p ==> p` (satScript.sml:59-71), and `\|- !t. ~~t <=> t` = conjunct 1 of **bool.NOT_CLAUSES** (1135) |
| `excluded_middle` | `¬P ∨ P` | **bool.EXCLUDED_MIDDLE** `\|- !t. t \/ ~t` (610) — **disjunct order reversed** vs. Isabelle |

Supporting axioms also present: **bool.BOOL_CASES_AX**
`|- !t. (t <=> T) \/ (t <=> F)` (228), **SELECT_AX**
`|- !P x. P x ==> P ($@ P)` (234), **ETA_AX** (231).

## Key findings for the seed script

1. **Must be proved fresh** (no theorem anywhere in the default heap;
   verified by DB.match): `swap`, `classical` (quantified form), `ccontr`
   (implication form), `exI`, `exE`, `allE`/`spec`, `conjE`, `impCE`,
   `iffCE`, `subst`, `ex1I`, `notE` (general-R form), `impE`, `iffD2`
   (standalone), `mp` (thm form, if wanted).
2. **Quantification irregularities to watch**: `EXISTS_UNIQUE_THM`,
   `EXISTS_UNIQUE_ALT'`, `PEIRCE`, `NOT_AND`, `MONO_*` all have **free**
   variables rather than outer `!`-quantifiers; everything else listed is
   fully `!`-quantified.
3. `satTheory` (src/HolSat, builds immediately after the kernel sequence
   per tools/sequences/base-hol:4, so effectively core) contributes
   `NOT_ELIM2`, `NOT_NOT`, `AND_INV_IMP`, `pth_nn`.
4. Isabelle's `NOT_INTRO`/`NOT_ELIM`/`CCONTR` analogues in HOL4 are
   kernel **ML derived rules** (src/thm/std-thm.ML:1028, 1050, 1080), not
   theorems; the theorem forms are `IMP_F`/`F_IMP` only.
