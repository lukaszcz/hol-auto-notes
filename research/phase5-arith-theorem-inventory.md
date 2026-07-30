# HOL4 per-type theorem inventory for the Fast_Lin_Arith port

> Research report, 2026-07-30, Phase 5 planning round (prior to owner
> decisions D59–D62 and `../PLAN_phase_5.md`).  HOL4 citations refer
> to worktree HEAD `7a8a286b5`.  Produced by a survey agent; theorem
> existence checked against generated `.sig` files
> (`sigobj/arithmeticTheory.sig`, `src/integer/.hol/objs/
> integerTheory.sig`, `src/real/.hol/objs/realTheory.sig`,
> `src/rational/.hol/objs/ratTheory.sig`), statements read from the
> `*Script.sml` sources.

## 1. rat support

**Location & build position**

- `src/rational/`; main theory `ratTheory` (`ratScript.sml`);
  supporting `fracTheory`, `intExtensionTheory`.
- `src/rational/Holmakefile:1` — `INCLUDES = ../integer
  ../res_quan/src ../sort`.
- Build band: `rational` is not named in any `tools/sequences/*` file;
  it is built via `src/parallel_builds/core/Holmakefile:22`
  (`SRCRELNAMES` contains `rational real real/analysis
  res_quan/src`), pulled in by `tools/sequences/more-theories:3`.
  `integer` is at `parallel_builds/core/Holmakefile:17`.
  **Consequence: a single `src/auto/linarith/` instantiating num, int,
  real and rat would have to live at/after the parallel band; only the
  num instance can live in the `upto-auto` band.**

**Ordering / arithmetic theorems in `ratTheory`** (`ratScript.sml`)

| Need | Theorem | Statement | Line |
|---|---|---|---|
| add-mono ≤ | `RAT_ADD_MONO` | `!a b c d. a <= b /\ c <= d ==> a + c <= b + d` | 2017 |
| add-cancel ≤ | `RAT_LEQ_RADD`/`RAT_LEQ_LADD` | `(r1+r3 <= r2+r3) = (r1 <= r2)` | 2005, 2011 |
| add-cancel < | `RAT_LES_RADD`/`RAT_LES_LADD` | `(r1+r3 < r2+r3) = (r1 < r2)` | 1991, 2000 |
| scale by pos, < | `RAT_LES_RMUL_POS`, `RAT_LES_LMUL_POS` | `0 < r3 ==> (r1*r3 < r2*r3 <=> r1 < r2)` | 2084, 2112 |
| scale by neg, < | `RAT_LES_RMUL_NEG`, `RAT_LES_LMUL_NEG` | | 2117, 2156 |
| linear order | `RAT_LES_TOTAL` 1630; `RAT_LEQ_LES` (`~(r2<r1) = r1<=r2`) 1728; `RAT_LES_LEQ` (`~(r2<=r1) = r1<r2`) 1742; `RAT_LES_LEQ2` 1749; `RAT_LES_TRANS` 1612; `RAT_LEQ_TRANS` 1672; `RAT_LES_LEQ_TRANS` 1763; `RAT_LEQ_LES_TRANS` 1770 | | |
| distributivity | `RAT_RDISTRIB` 1139, `RAT_LDISTRIB` 1155, `RAT_SUB_RDISTRIB` 1361, `RAT_SUB_LDISTRIB` 1369 | | |
| sub/side moves | `RAT_LSUB_LEQ` 2063, `RAT_LSUB_LES`, `RAT_LES_SUB0` 2281, `RAT_LES_0SUB` 2296 | | |
| div by pos | `RAT_LDIV_LEQ_POS` 2229, `RAT_LDIV_LES_POS`, `RAT_LDIV_LEQ_NEG`, `RAT_LDIV_LES_NEG` | | |
| products | `RAT_LT_MUL` 3725, `RAT_LEQ_MUL` 3737 | | |

**Gaps (explicitly absent):**

- `RAT_LEQ_LMUL_POS`/`RAT_LEQ_RMUL_POS` **do not exist** (verified by
  grep over `ratScript.sml` and `ratTheory.sig`) — the "scale by
  positive constant preserves ≤" lemma `mkthm` needs must be derived
  (from `RAT_LES_LMUL_POS` + `RAT_EQ_LMUL` (1973) via `rat_leq_def`).
- rat discreteness: N/A (dense ordered field).
- No rat min/max/abs constants at all (no such names in
  `ratTheory.sig`).

**Literals & evaluation**

- Literals: `rat_of_num` (`&n`) and `rat_of_int`
  (`rat_of_int_def`, `ratScript.sml:2921`); `RATN`/`RATD` with
  `RATN_RATD_EQ_THM` (3128).
- Calculation rewrites: `RAT_ADD_NUM_CALCULATE` 2721,
  `RAT_MUL_NUM_CALCULATE` 2769, `RAT_EQ_NUM_CALCULATE`,
  `RAT_LT_NUM_CALCULATE` 2889 `[simp]`, `RAT_LE_NUM_CALCULATE` 2914
  `[simp]`, `RAT_LES_CALCULATE` 714, `RAT_LEQ_CALCULATE` 729,
  `RAT_OF_NUM_CALCULATE` 737, `RAT_OF_INT_CALCULATE` 3042,
  `RAT_SUB_CALCULATE`, `RAT_DIV_CALCULATE`, `RAT_MINV_CALCULATE`.
- Conversions: `ratReduce.RAT_ADD_CONV`/`RAT_MUL_CONV` only
  (`ratReduce.sig`); `ratLib.sig` offers `RAT_EQ_CONV`,
  `RAT_CALC_CONV`, `RAT_ADDAC_CONV`, `RAT_MULAC_CONV`,
  `RAT_BASIC_ARITH_CONV`, rewrite lists `int_rewrites`,
  `rat_basic_rewrites`, `rat_rewrites`, `rat_num_rewrites`.
- **No rat ssfrag** and **no rat decision procedure**:
  `RAT_BASIC_ARITH_CONV` (`ratLib.sml:488-491`) normalises to
  `frac`/`int` form and calls the *nat* `ARITH_CONV`.  The rat
  linarith instance is the largest single win of the port.

## 2. num (`arithmeticTheory`, `arithmeticScript.sml`)

**Monotone addition**

| Theorem | Statement | Line |
|---|---|---|
| `LESS_EQ_LESS_EQ_MONO` | `m <= p /\ n <= q ==> m + n <= p + q` | 992 |
| `LESS_MONO_ADD` | `m < n ==> m + p < n + p` | 906 |
| `LESS_MONO_ADD_EQ` | `(m+p) < (n+p) = m < n` | 926 |
| `LESS_EQ_MONO_ADD_EQ` | `(m+p) <= (n+p) = m <= n` | 949 |
| `ADD_MONO_LESS_EQ` | `m+n <= m+p <=> n <= p` | 1893 |
| `LT_ADD_RCANCEL`/`LT_ADD_LCANCEL` | = 926 (comm'd) | 934-935 |

**Gap: no `LT_ADD2`** (strict-strict addition `m<p /\ n<q ==> m+n <
p+q`) — no `*ADD2*` name in `arithmeticTheory.sig`.  Derive from
`LESS_MONO_ADD` + `LESS_EQ_LESS_TRANS` (205) / `LESS_LESS_EQ_TRANS`
(216), or reduce strict to non-strict via `LESS_EQ` (discrete).

**Multiplication by a constant**: `LESS_MONO_MULT` 1021
(`m <= n ==> m*p <= n*p`), `LESS_MONO_MULT2` 1036,
`LE_MULT_LCANCEL` 1984 (`m*n <= m*p <=> (m=0) \/ n <= p`),
`LE_MULT_RCANCEL` 1994, `LT_MULT_LCANCEL` 1999
(`m*n < m*p <=> 0 < m /\ n < p`), `LT_MULT_RCANCEL` 2009,
`MULT_LESS_EQ_SUC` 1956 (`m <= n <=> SUC p * m <= SUC p * n`);
distribution `LEFT_ADD_DISTRIB`, `RIGHT_ADD_DISTRIB`.

**Discreteness**: `LESS_EQ` 441 (`(m < n) = (SUC m <= n)`);
`LESS_EQ_IFF_LESS_SUC` 459; `LE_LT1` 3057 (`x <= y <=> x < y + 1` —
Isabelle's shape); `ADD1`/`SUC_ONE_ADD` for `SUC` ↔ `+1`.

**Subtraction / DIV / MOD**: `SUB_LEFT_LESS` 2121
(`(m < n - p) = (m + p < n)`), `SUB_RIGHT_LESS` 2138,
`SUB_LEFT_LESS_EQ` 2105, `SUB_RIGHT_LESS_EQ` 2113, `SUB_LEFT_ADD`
2055, `SUB_RIGHT_ADD` 2063, `SUB_LEFT_EQ` 2184, `SUB_RIGHT_EQ` 2192,
`SUB_LEFT_GREATER` 2166, `SUB_LEFT_GREATER_EQ` 2148; `DIVISION` 2342
(`0 < n ==> !k. k = k DIV n * n + k MOD n /\ k MOD n < n`);
in the sig: `DIV_LESS_EQ`, `DIV_LE_X`, `DIV_LT_X`, `X_LE_DIV`,
`X_LT_DIV`, `MOD_LESS`, `MOD_LESS_EQ`.

**Numeral evaluation**: `reduceLib` (`REDUCE_CONV`, `RED_CONV`,
one-step `ADD/MUL/SBC/LT/LE/NEQ/DIV/MOD_CONV`, `num_compset`),
re-exported through `numLib`; `numSimps` fragments `REDUCE_ss`,
`ARITH_ss`, `ARITH_DP_ss`, `ARITH_RWTS_ss`, `ARITH_NORM_ss`,
`MOD_ss`; `ADDL_CANON_CONV`, `ADDR_CANON_CONV`, `MUL_CANON_CONV`.

## 3. int (`integerTheory`, `integerScript.sml`)

**Addition**: `INT_LE_ADD2` 1014 (`w <= x /\ y <= z ==> w+y <= x+z`),
`INT_LT_ADD2` 1006, `INT_LE_LADD` 992, `INT_LE_RADD` 999,
`INT_LT_LADD` 749, `INT_LT_RADD` 760.  Note `INT_LE_ADD` is the
different lemma `0<=x /\ 0<=y ==> 0<=x+y`.

**Scaling**: `INT_LE_MONO` 3476 (`0 < x ==> (x*y <= x*z <=> y <= z)`),
`INT_LT_MONO` 3467, `INT_LE_MUL` 957, `INT_LT_MUL`, `INT_LT_MUL2`;
`INT_LDISTRIB` (re-exported 520), `INT_RDISTRIB` 633.

**Discreteness — exactly Isabelle's shape**: `INT_DISCRETE` 1815
(`~(x < y /\ y < x + 1)`), `INT_LE_LT1` 1842 (`x <= y <=> x < y + 1`),
**`INT_LT_LE1` 1854 (`x < y <=> x + 1 <= y`)** — the wanted one,
`INT_LT_ADD1` 1059.

**Order**: `INT_LT_TOTAL` (521), `INT_LE_TOTAL` 801, `INT_NOT_LT` 767,
`INT_NOT_LE` 795, `INT_LE_LT`, `INT_LT_LE`.

**div/mod**: `INT_DIVISION` 2140 (`~(q=0) ==> ...` with sign-split
remainder bounds); **`INT_DIV_P` 2467 and `INT_MOD_P` 2476** — the
Isabelle-style case-split theorems (`!P x c. c <> 0 ==>
(P (x/c) <=> ?k r. x = k*c + r /\ (...) /\ P k)`); `INT_MOD_BOUNDS`
2095; `INT_DIV_FORALL_P`, `INT_MOD_FORALL_P`, `INT_DIV_UNIQUE`,
`INT_MOD_UNIQUE`, `INT_DIV_REDUCE`, `INT_MOD_REDUCE`; definitions
`int_div`/`int_mod` in the sig.

**Literals**: `intReduce.sig` — `REDUCE_CONV`, `RED_CONV`,
`INT_REDUCE_ss`, `int_compset`, `add_int_compset`,
`collect_additive_consts`, HOL-Light-compatible one-step conversions
(`INT_LE_CONV` etc.).  There is **no** `INT_REDUCE_CONV` name.
`intSimps.sig` adds `INT_RWTS_ss`, `int_ss`, `INT_AC_ss`,
`INT_ARITH_ss` (Omega), `OMEGA_ss`, `COOPER_ss`, `ADDL_CANON_CONV`,
`ADDR_CANON_CONV`.  `intLib.sig`: `ARITH_CONV/PROVE/TAC` (Omega),
`COOPER_*`, `INT_RING`, `INTEGER_TAC`.

## 4. real

**Ordering/arithmetic** (`realScript.sml`; some in `realaxScript.sml`)

| Theorem | Statement | Location |
|---|---|---|
| `REAL_LE_ADD2` | `w<=x /\ y<=z ==> w+y <= x+z` | realScript.sml:246 |
| `REAL_LT_ADD2` | strict | realScript.sml:240 |
| `REAL_LET_ADD2` | `w<=x /\ y<z ==> w+y < x+z` | realScript.sml:882 |
| `REAL_LTE_ADD2` | `w<x /\ y<=z ==> w+y < x+z` | realScript.sml:888 |
| `REAL_LE_LADD`/`REAL_LE_RADD` | iff cancel | realaxScript.sml:470/670 |
| `REAL_LT_LADD`/`REAL_LT_RADD` | iff cancel | realaxScript.sml:458/663 |
| `REAL_LE_LMUL` | `0 < x ==> (x*y <= x*z <=> y <= z)` | realScript.sml:495 |
| `REAL_LE_RMUL` | | realScript.sml:503 |
| `REAL_LT_LMUL` | | realScript.sml:463 |
| `REAL_LT_RMUL` | | realScript.sml:473 |
| `REAL_LE_LMUL_IMP`/`REAL_LE_RMUL_IMP` | | realScript.sml:1169/1179 |
| `REAL_LT_LMUL_IMP` | | realScript.sml:487 |
| `REAL_NOT_LT`/`REAL_NOT_LE` | | realaxScript.sml:863/577 |
| `REAL_LE_TOTAL`, `REAL_LT_TOTAL`, `REAL_LE_LT`, `REAL_LT_LE`, `REAL_LT_IMP_LE` | | realaxScript.sml:947, realScript.sml:35, … |
| `REAL_LDISTRIB`/`REAL_RDISTRIB` | | realScript.sml:34 / realaxScript.sml:391 |

**Literals**: `RealField.REAL_RAT_REDUCE_CONV` plus one-step
`REAL_RAT_{LE,LT,GE,GT,EQ,NEG,ABS,INV,ADD,SUB,MUL,DIV,POW,MAX,MIN,
SGN}_CONV` and `REAL_POLY_*`/`REAL_POLY_CONV`; `RealArith.sig`
integer-real conversions (`REAL_INT_REDUCE_CONV` etc.) and
rational-literal marshalling `is_ratconst`/`rat_of_term`/
`term_of_rat`, `is_realintconst`/`dest_realintconst`/
`mk_realintconst`; `realSimps.sig`: `REAL_REDUCE_ss`, `real_SS`,
`real_ss`, `REAL_ARITH_ss` + `arith_cache`, `REALADDCANON`,
`REALMULCANON`, `REAL_LITCANON`, `real_compset`.

**Existing FM-with-certificates for real — already there**:
`RealArith0.sig` defines

```
datatype positivstellensatz =
    Axiom_eq of int | Axiom_le of int | Axiom_lt of int
  | Rational_eq of Arbrat.rat | Rational_le of Arbrat.rat
  | Rational_lt of Arbrat.rat
  | Square of term | Eqmul of term * positivstellensatz
  | Sum of positivstellensatz * positivstellensatz
  | Product of positivstellensatz * positivstellensatz
```

with `REAL_LINEAR_PROVER : (thm list * thm list * thm list ->
positivstellensatz -> 'a) -> thm list * thm list * thm list -> 'a`
(translator-parametric — the analogue of `mkthm`).  Genuinely FM with
Farkas multipliers: `linear_ineqs` `RealArith0.sml:541`, `linear_eqs`
`:654`, `linear_add` `:479`, elimination at `:600-610` recording
`Sum(Product(Rational_lt |c2|, p1), Product(Rational_lt |c1|, p2))`;
`REAL_LINEAR_PROVER` proper at `:756` with kernel lemmas
`realaxTheory.REAL_LINEAR_PROVER_pth`/`_pth'`
(`realaxScript.sml:1322,1324`).  `GEN_REAL_ARITH`/`GEN_REAL_ARITH0`
are the closest existing analogue of the Isabelle functor's parameter
record but are hardwired to `:real`.  Also `NLArith`, `SOSLib`,
`RealField.REAL_ARITH/REAL_FIELD`; `realLib.sig`: `REAL_ARITH`,
`REAL_ARITH_TAC`, `REAL_ASM_ARITH_TAC`, `PURE_REAL_ARITH_TAC`.
`ABSMAXMIN_ELIM_CONV1/2` fed into `GEN_REAL_ARITH0`
(`RealArith0.sml:831`) model abs/max/min elimination by case split.

## 5. Injections

**num → int** (`integerScript.sml`): `INT_INJ` 1345 `[simp]`,
`INT_LE` 1319, `INT_LT` 1332 `[simp]`, `INT_ADD` 1360, `INT_MUL`
1369, `INT_SUB` 1613 (conditional).

**int → real** (`intrealTheory`, `src/real/intrealScript.sml`):
`real_of_int` def :15; `real_of_int_add[simp]` 442,
`real_of_int_neg[simp]` 450, `real_of_int_sub[simp]` 456,
`real_of_int_mul[simp]` 462, `real_of_int_lt[simp]` 469,
`real_of_int_le[simp]` 483, `real_of_int_11[simp]` 476,
`real_of_int_num[simp]` 405 (composes the num→int→real triangle),
`real_of_int_monotonic` 64; also `INT_FLOOR`/`INT_CEILING`,
`INT_FLOOR_BOUNDS` 118, `INT_CEILING_BOUNDS` 387.

**num → real**: `REAL_INJ` realaxScript.sml:972 (`realScript.sml:656`
`[simp]`), `REAL_LE` :778 (646), `REAL_LT` realScript.sml:648
`[simp]`, `REAL_ADD` :527 (659), `REAL_MUL` :548 (662).

**num → rat**: `RAT_OF_NUM_LEQ[simp]` 748, `RAT_OF_NUM_LES[simp]`
755, `RAT_ADD_NUM_CALCULATE` 2721 (incl. `RAT_ADD_NUM1` 2678),
`RAT_MUL_NUM_CALCULATE` 2769 (incl. `RAT_MUL_NUM1` 2739),
`RAT_EQ_NUM_CALCULATE`, `RAT_LE_NUM_CALCULATE` 2914,
`RAT_LT_NUM_CALCULATE` 2889.

**int → rat**: `rat_of_int_def` 2921; `rat_of_int_of_num[simp]` 2931;
`rat_of_int_ADD` 2957; `rat_of_int_MUL` 2945; `rat_of_int_LE[simp]`
3017; `rat_of_int_LT[simp]` 3025; `rat_of_int_11[simp]` 2925.
Caveat: `ratSyntax.sig` has **no** `rat_of_int` term operations (only
`rat_of_num_tm`, `mk_rat_of_num`, …; it does provide `is_literal`,
`int_of_term`, `term_of_int`).

**rat → real** (`real_of_ratTheory`, `src/real/real_of_ratScript.sml`):
`real_of_rat_def` 43, `REAL_OF_RAT_INJ` 76, `REAL_OF_RAT_ADD` 108,
`REAL_OF_RAT_MUL` 124, `REAL_OF_RAT_NEG` 136, `REAL_OF_RAT_SUB` 144,
`REAL_OF_RAT_OF_INT` 59.  **No `REAL_OF_RAT_LE`/`_LT`** — add if
order transfer is ever wanted.

## 6. Boulton nat arith — public API

`src/num/arith/src/` surfaced through `src/num/numLib.sig` as
`ARITH_CONV : conv`, `ARITH_PROVE : conv`, `ARITH_TAC : tactic`
(plus `REDUCE_*`, `std_ss`/`arith_ss`, re-exported
`DECIDE`/`DECIDE_TAC`).  Lower-level `Arith.sig` exposes
`ARITH_FORM_NORM_CONV`, `SUB_AND_COND_ELIM_CONV`, `COND_ELIM_CONV`,
`PRENEX_CONV`, `DISJ_INEQS_FALSE_CONV`, `EXISTS_ARITH_CONV`,
`FORALL_ARITH_CONV`, `is_presburger`, `non_presburger_subterms`, and
`INSTANCE_T_CONV : (term -> term list) -> conv -> conv` (also in
`Instance.sig`) — the existing "abstract non-arithmetic subterms to
fresh variables" wrapper, directly reusable.

## 7. min/max/abs split & case theorems

**num**: `MAX_DEF` 4004, `MIN_DEF` 4005 (aliases `MAX`/`MIN`
4007-4008); `MIN_LE` 4096 (two-sided iff pair), `MAX_LE` 4102,
`MIN_LT` 4080, `MAX_LT` 4088; `MIN_MAX_LE` in the sig.  `LE_MIN` and
`LT_MAX` do not exist as separate names.  No nat abs.

**int**: `INT_MIN` def 3429, `INT_MAX` def 3433; `INT_MIN_LT` 3436
and `INT_MAX_LT` 3443 are **one-directional implications only**;
`INT_MIN_NUM` 3450 / `INT_MAX_NUM` 3456.  **Gap: no iff-form int
min/max case theorems** — must be proved (trivial from the if-defs).
`INT_ABS` def `integerScript.sml:2542` `[nocompute]`; supporting
`INT_ABS_POS`, `INT_ABS_LE`, `INT_ABS_LT`, `INT_ABS_NEG`,
`INT_ABS_MUL`, `INT_ABS_TRIANGLE`, `INT_ABS_EQ0`, `INT_ABS_NUM`,
`INT_ABS_ABS`, `INT_ABS_0LT`, `INT_ABS_LT0`, `INT_ABS_LE0`,
`INT_ABS_SUB`, `INT_ABS_QUOT`.

**real**: `min_def` realScript.sml:3194, `max_def` 3330, `abs` 1335;
`REAL_MIN_LE` 3209 (`min x y <= z <=> x <= z \/ y <= z`),
`REAL_MAX_LE` 3357, `REAL_MIN_LT` 3235, `REAL_MAX_LT` 3371 (one-sided;
complements as `REAL_MIN_LE1/2`, `REAL_LE_MIN`-style; sig also lists
`REAL_MIN_ALT`, `REAL_MAX_ALT`, `REAL_MIN_MAX`, `REAL_MAX_MIN`,
`REAL_MIN_ACI`, `REAL_MAX_ACI`, `REAL_MIN_ADD`, `REAL_MAX_ADD`,
`REAL_MIN_SUB`, `REAL_MAX_SUB`, `REAL_MIN_LE_MAX`).  `ABS_BOUNDS`
1721 (`abs x <= k <=> ~k <= x /\ x <= k`), `ABS_BOUNDS_LT`,
`ABS_BOUNDS_MIN_MAX`.  `RealField.REAL_RAT_MAX/MIN/ABS_CONV` for
literals.

**rat**: no `rat_min`/`rat_max`/`rat_abs` constants.

## 8. Summary of lemmas to prove in Phase 5

1. rat: `0 < c ==> (c * x <= c * y <=> x <= y)` (+ RMUL mirror).
2. num: `m < p /\ n < q ==> m + n < p + q` (no `LT_ADD2`) and the
   mixed `≤`+`<` forms.
3. int: iff-form min/max case theorems.
4. rat→real order transfer (`REAL_OF_RAT_LE`/`_LT`) — only if ever
   needed (not needed by the Phase-5 design).
5. `ratSyntax` `rat_of_int` term constructors/destructors.
6. rat min/max/abs — out of scope (constants do not exist).
7. `neqE`-shape case-split lemmas per type (from the respective
   totality/trichotomy theorems).
8. P-form split rules (splitLib shape) for num `MIN`/`MAX`/nat-sub,
   int `int_min`/`int_max`/`ABS`, real `min`/`max`/`abs`.
