# Phase 5 implementation plan — generic linear arithmetic
# (`src/auto/linarith/`)

Date: 2026-07-30.  Owner decisions D59–D62 (this file §0), on top of the
Phase-5 scope decisions D55–D56 (PLAN.md §2).  Sources: full reads of
`sources/src/Provers/Arith/fast_lin_arith.ML` (819 lines) and
`sources/src/HOL/Tools/lin_arith.ML` (961 lines); research report
`research/isabelle-arith-algebra.md`; verified surveys of the Phase-S
simpLib/splitLib extension points, the HOL4 per-type theorem inventory,
and the `src/auto` layer substrate (this session, 2026-07-30; the
substrate facts cited below were checked against the working tree).

Every `file.ML:NN` reference resolves against `.agent-files/sources/`;
every `*.sml:NN` / `*Script.sml:NN` reference against this repository.

## 0. Owner decisions (2026-07-30, one-by-one)

- **D59 — Goal-level splitting** (replaces the `pre_decomp`/`pre_tac`
  mirror pair of `lin_arith.ML:424–836`): the operator-elimination
  layer (`min`/`max`/`abs`/nat-subtraction/`div`/`mod`) runs as genuine
  tactic preprocessing on the real goal — negate the conclusion into
  the premises, repeat splitLib-driven splitting with proved P-form
  split rules, eliminate `div`/`mod` with *literal* divisors by
  fact-augmentation (§5.4), NNF-flatten, then run certificate search +
  replay per subgoal.  The engine keeps in-engine `≠`-splitting
  (`elim_neq`, `neq_limit`) in both replay styles, because the
  forward/simproc path needs it there.  Rejected: the faithful mirror
  port (two implementations of one split semantics, an invariant the
  upstream source itself flags as fragile — `fast_lin_arith.ML:80–85`);
  a hybrid fast path.  Gained: user-registered split rules extend
  preprocessing for free, strictly beyond Isabelle's hand-listed
  operator set (`lin_arith.ML:372–392`).
- **D60 — Two directories + live registry** (revises §8.2's
  "persistent registry, ThmSetData-backed", which cannot hold: instance
  records contain ML closures; precedent D46): `src/auto/linarith` =
  engine, decomp, replay, in-memory instance registry, `[arith]` and
  `[arith_split]` sets, the whole public surface, and the **num**
  instance — pre-`src/boss` dependencies only, built between
  `auto/blast` and `auto/clasimp`.  `src/auto/linarith/instances` =
  int, real, rat instance modules plus a theory proving the missing
  lemmas — parallel band, `INCLUDES` on `src/integer`, `src/real`,
  `src/rational`.  Instances self-register at module load (ssfrag
  precedent); theorem sets persist via ThmSetData; the D56 cache edits
  reference only the core, whose solver closure reads the registry
  dynamically, so clasimp/aesop automation strengthens as instance
  modules load.  At promotion each instance moves into its type's home
  library with identical semantics.  Rejected: one post-boss directory
  (breaks the `upto-auto` gate and the stratification rule, and would
  forever bar `LINARITH_ss` from replacing nat-only `ARITH_ss` in the
  distribution simpsets); hard-wiring the instances into clasimp.
- **D61 — Attribute surface `[arith]` + `[arith_split]`**: settypes
  `"arith"` (facts) and `"arith_split"` (P-form split rules,
  shape-validated on add), both Symtab-keyed with `REMOVE` support and
  removal functions `remove_arith`/`remove_arith_split` (splitLib's
  pattern), so `Thy.name`-based deletion works as for `[simp]`/
  `[split]`.  Per-invocation extras: plain theorems = facts (D30);
  `Split th` = extra split rule for this call.  Rejected: Isabelle's
  attribute name `linarith_split` (family consistency with `[arith]`
  wins; greppability handled by a source comment); an unpersisted
  split corpus.
- **D62 — Full public surface with a config-explicit twin**:
  `LINARITH_TAC : thm list -> tactic` (close-or-fail, full
  preprocessing), `SIMPLE_LINARITH_TAC : thm list -> tactic` (no
  operator splitting — `simple_tac`, `lin_arith.ML:851`),
  `CFG_LINARITH_TAC : linarith_config -> thm list -> tactic` with
  `linarith_config = {neq_limit : int, split_limit : int}` (defaults
  9/9, matching `lin_arith.ML:103–104`), `LINARITH_PROVE : term ->
  thm`, `LINARITH_CONV : conv` (prove-or-disprove to `T`/`F`),
  `LINARITH_ss`, `linarith_solver : Traverse.ssolver` (slot name
  string `"lin_arith"`, kept greppable against `lin_arith.ML:949` per
  the D37 precedent), `register_instance`, set accessors and removal
  functions, `clear_linarith_caches`.  Rejected: a minimal surface
  (hides the forward entry the reducer needs anyway); global mutable
  limit refs (hidden state; D36 exists to avoid it).

Overarching (unchanged): judge by resulting tactic strength; general,
principled, extensible; no recognition shortcuts.

## 1. Scope

Delivered by Phase 5 (per PLAN.md §8 as revised by D55–D56, D59–D62):

1. The `Fast_Lin_Arith` engine as HOL4 modules: untrusted
   Fourier–Motzkin over integer-scaled `lineq` records with `injust`
   Farkas-certificate trees, kernel replay (`mkthm`) in both tactic
   and forward styles, in-engine `≠`-splitting.
2. Instance records for `num`, `int`, `real`, `rat` (rat has **no**
   decision procedure today — `ratLib.RAT_BASIC_ARITH_CONV` normalizes
   and calls the *nat* `ARITH_CONV`, `src/rational/ratLib.sml:488` —
   so this is a net new capability, beyond strict parity).
3. Goal-level preprocessing (D59): relevance filtering, splitting,
   div/mod fact-augmentation, NNF flattening.
4. The D62 tactic/conversion surface plus `[arith]`/`[arith_split]`.
5. Simp integration: `LINARITH_ss` (reducer + cache, `CTXT_ARITH`
   pattern) and the `"lin_arith"` unsafe solver; D56 wiring into the
   clasimp cache and `aesop_ss`.
6. Selftests (unit, per-instance, persistence, strength corpus) and
   user documentation.

Explicitly not in scope: any `ARITH_TAC`/registry (D55), changes to
`DECIDE`/`numLib`/`intLib` (D55: no shadowing), distribution simpset
changes (`srw_ss`, `std_ss` — promotion only, D10/D56), reflected or
verified QE (later phase per D1), a simplex backend (recorded
alternative only).

## 2. Grounding

### 2.1 Port targets (vendored)

- `fast_lin_arith.ML`: data records 119–146; `injust`/`lineq` 191–202;
  FM core 225–349 (`find_add_type`, `multiply_ineq`, `add_ineq`,
  `elim_var`, `elim` with equations-first / minimal-|coeff| /
  blowup-minimizing pivoting); `mkthm` replay 384–508; `integ`/
  `mklineq` 510–541; `mknat` 549–553; `split_items`/`elim_neq`
  574–629; `refutes`/`refute`/`prove` 631–681; tactic replay
  `refute_tac` 683–707; `simpset_lin_arith_tac` 713–731; forward
  prover `splitasms`/`fwdproof`/`prover` 741–795; simproc 803–817.
  The counterexample finder is deleted upstream (only comments remain,
  204–218) — nothing to port.
- `lin_arith.ML`: `LA_Logic` instantiation 32–66; context data 71–105;
  `decomp`/`demult`/`poly` 124–292; abstraction 295–361 (superseded
  here, §4.4); split simulation 364–836 (superseded by D59); `tac` =
  `FIRST' [simple_tac, atomize/split/refute]` 913–942; solver and
  method setup 945–959.  `arith_data.ML` is *not* ported (D55) and
  nothing in the two files above depends on it except
  `global_setup:959`.

### 2.2 HOL4 assets consumed (verified this session)

- **Solver slots (Phase S, D15)**: `Traverse.ssolver =
  {name : string, solve : simp_prover_ctxt -> term -> thm}` with
  `simp_prover_ctxt = {stack, context_thms, recurse}`
  (`Traverse.sig:90–96`); engine side conditions always use the
  *unsafe* list (`simpLib.sml:1189–1207`); tactic-level residue uses
  safe/unsafe by mode (`final_solver_tac`, `simpLib.sml:1391–1411`);
  registration `add_unsafe_solver`/`solver_ss`
  (`simpLib.sig:163–172`, `106`).
- **splitLib (Phase S, D19–D20)**: `SPLIT_CONV`/`SPLIT_TAC`/
  `SPLIT_ASM_TAC : thm list -> _` take plain theorem lists in the
  P-form shape `!P x̄. P (c x̄) = rhs` (validated by `rule_parts`,
  `splitLib.sml:24–49`); no DB or simpset registration required;
  `mk_asm_split` derives the assumption-side companion; rules are
  keyed by head constant × type shape, so `:num`-`MIN` and int-`min`
  rules coexist.  One split per call; deterministic order.
- **Reducer pattern**: `numSimps.ARITH_REDUCER`/`CTXT_ARITH`
  (`src/num/arith/src/numSimps.sml:352–491`) with
  `Cache.RCACHE {capacity=2000, per_key_cap=50}` keyed on goal term
  with hypothesis-subset reuse of successes *and* failures
  (`Cache.sig:1–60`); `dp_vars` connected-component splitting.
- **Arbitrary precision**: `portableML/Arbint`, `portableML/Arbrat`
  (mosml-safe; the portability rule forbids native `int` coefficients,
  31-bit under Moscow ML).
- **Atom generalization**: `Instance.INSTANCE_T_CONV :
  (term -> term list) -> conv -> conv` (`src/num/arith/src/`) — the
  existing abstract-non-arith-subterms wrapper (§4.4).
- **Literal evaluation**: `reduceLib.REDUCE_CONV` (num);
  `intReduce.REDUCE_CONV`, `INT_REDUCE_ss` (int);
  `RealField.REAL_RAT_REDUCE_CONV` and `RealArith.term_of_rat`/
  `rat_of_term` (real); `ratReduce.RAT_ADD_CONV`/`RAT_MUL_CONV`,
  `ratLib.RAT_CALC_CONV` (rat).
- **Canonicalizers for replay normalization**:
  `numSimps.ADDR_CANON_CONV`; `intSimps.ADDR_CANON_CONV`;
  `realSimps.REALADDCANON`/`RealField.REAL_POLY_CONV`;
  `ratLib.RAT_ADDAC_CONV`/`RAT_MULAC_CONV`.
- **Layer plumbing**: `ThmSetData.export_with_ancestry` (auto-registers
  the argument-less attribute, `ThmSetData.sml:293–296`; collision
  guard convention `aesopData.sml:26–34`);
  `clasetLib.INSERT_FACTS_TAC` and `classify_simp_args` (D30/D42);
  marker rejection precedent `check_aesop_markers`
  (`clasetLib.sml:1179–1205`); derived-simpset caches
  `clasimpLib.sml:8–27` and `aesopData.sml:48–83`;
  `BasicProvers.make_simpset_derived_value`
  (`BasicProvers.sml:1364–1378`).

### 2.3 Per-type theorem inventory (verified; gaps marked "prove")

Shared logic (engine-level, type-independent): `CONJ`, `CCONTR`,
`SYM`, `TRUTH`, `EQT_INTRO`/`EQF_INTRO`, `CONJUNCTS` — the whole of
Isabelle's `LA_Logic` (`lin_arith.ML:32–66`) except the four per-type
order lemmas, which move into the instance kits.

| Slot (Isabelle name) | num | int | real | rat |
|---|---|---|---|---|
| add mono ≤+≤ | `LESS_EQ_LESS_EQ_MONO` | `INT_LE_ADD2` | `REAL_LE_ADD2` | `RAT_ADD_MONO` |
| add mono <+< | **prove** (no `LT_ADD2`) | `INT_LT_ADD2` | `REAL_LT_ADD2` | **prove** |
| add mono mixed ≤+< , <+≤ | **prove** | **prove** (from `INT_LT_ADD2`/`INT_LE_LT`) | `REAL_LET_ADD2`, `REAL_LTE_ADD2` | **prove** |
| mult mono ≤ (`mult_left_mono`) | `LESS_MONO_MULT` | `INT_LE_MONO` (iff, `0<x`) | `REAL_LE_LMUL` (iff) | **prove** (`RAT_LEQ_LMUL_POS` absent) |
| mult mono < (`mult_strict_left_mono`) | `LT_MULT_LCANCEL` (iff) | `INT_LT_MONO` (iff) | `REAL_LT_LMUL` (iff) | `RAT_LES_LMUL_POS` (iff) |
| scale `=` (`arg_cong`) | `AP_TERM` — no lemma needed (any type) | ditto | ditto | ditto |
| `not_lessD` (¬< ⟹ ≤) | `NOT_LESS` | `INT_NOT_LT` | `REAL_NOT_LT` | `RAT_LEQ_LES` |
| `not_leD` (¬≤ ⟹ <) | `NOT_LESS_EQUAL` | `INT_NOT_LE` | `REAL_NOT_LE` | `RAT_LES_LEQ` |
| `lessD` (discrete: < ⟹ succ ≤) | `LESS_EQ` (`m<n ⟺ SUC m≤n`) + `ADD1` | `INT_LT_LE1` (`x<y ⟺ x+1≤y`) | — (dense) | — (dense) |
| `neqE` (≠ case split) | **prove** (from `LESS_CASES`) | **prove** (from `INT_LT_TOTAL`) | **prove** (from `REAL_LT_TOTAL`) | **prove** (from `RAT_LES_TOTAL`) |
| nonneg atoms | `ZERO_LESS_EQ` (every nat atom) | `INT_POS` (`&`-atoms) | `REAL_POS` (`&`-atoms) | **prove** `0 ≤ &n` (from `RAT_OF_NUM_LEQ`) |
| min/max split rules (P-form) | **prove** (facts `MIN_LE`/`MAX_LE`/`MIN_DEF`/`MAX_DEF` exist) | **prove** (only weak `INT_MIN_LT`/`INT_MAX_LT` exist) | **prove** (`REAL_MIN_LE`/`REAL_MAX_LE`/`min_def`/`max_def` exist) | — (no rat min/max/abs constants; out of scope) |
| abs split rule (P-form) | — (no nat abs) | **prove** (`INT_ABS` if-def exists) | **prove** (`ABS_BOUNDS`, `abs` def exist) | — |
| nat-sub split rule (P-form) | **prove** (`P (m−n) ⟺ (m<n ⟹ P 0) ∧ ∀d. m=n+d ⟹ P d`) | — (int minus is linear) | — | — |
| div/mod facts | `DIVISION` (`0<n` guard) | `INT_DIVISION`, `INT_DIV_P`/`INT_MOD_P` (`c≠0` guard) | — (field: `demult` handles literal `/`) | — (field) |
| injections | — | num→int: `INT_INJ` `INT_LE` `INT_LT` `INT_ADD` `INT_MUL` | num→real: `REAL_INJ` `REAL_LE` `REAL_LT` `REAL_ADD` `REAL_MUL`; int→real: `real_of_int_add/mul/le/lt/11/num` (intrealTheory) | num→rat: `RAT_OF_NUM_LEQ/LES`, `RAT_ADD_NUM_CALCULATE`, `RAT_MUL_NUM_CALCULATE`; int→rat: `rat_of_int_ADD/MUL/LE/LT/11/of_num` |

All "prove" entries are elementary consequences of listed facts and go
into `linarithSeedScript.sml` (num) or `linarithInstScript.sml`
(int/real/rat) — §7.  `ratSyntax` lacks `rat_of_int` term operations
(build in `ratLinarith`).  rat→real transfer lemmas are not needed (no
cross-registration between dense types).

## 3. Architecture

```
                LINARITH_TAC [facts]
                        |
   insert [arith] set, then argument facts        (D30, §5.1)
                        v
   negate conclusion into premises (CCONTR shape) (§5.2)
                        v
   relevance filter + REPEAT bounded split        (D59, §5.3)
   [arith_split] ∪ Split markers ∪ seeds, via splitLib;
   div/mod literal-divisor fact-augmentation      (§5.4)
   NNF + conj/disj/ex flattening
                        v            per subgoal [A1..An] ?- F
   decomp (registry-driven, §4.3)  -->  lineq system
                        v
   elim_neq (≤ neq_limit) --> FM elim --> injust certificates
                        v
   mkthm kernel replay per case (§4.4); tactic assembly
```

The forward path (`LINARITH_PROVE`/`LINARITH_CONV`/reducer/solver)
shares everything from `decomp` down, replaying with the
`splitasms`/`fwdproof` assumption-tree method instead of tactics, and
performs no operator splitting (exactly the upstream simproc contract,
`fast_lin_arith.ML:803–817`).

Module map (core directory):

| Module | Contents | Port of |
|---|---|---|
| `linarithData` | instance record type, registry, injections, `[arith]`/`[arith_split]` settypes, config, trace | `Generic_Data`/`Lin_Arith_Data` (`fast_lin_arith.ML:119–180`, `lin_arith.ML:71–105`) |
| `linarithSolve` | `lineq`/`injust`, FM core, `integ`/`mklineq`/`mknonneg`, `elim_neq`/`split_items`, `refute`/`prove` | `fast_lin_arith.ML:191–349, 510–681` |
| `linarithDecomp` | registry-driven `decomp`/`demult`/`poly`, relation analysis, relevance test | `lin_arith.ML:124–292` |
| `linarithReplay` | `mkthm`, forward prover (`splitasms`/`fwdproof`), atom generalization | `fast_lin_arith.ML:384–508, 741–795` |
| `linarithLib` | preprocessing, D62 surface, `LINARITH_ss`, solver, num instance registration | `lin_arith.ML:806–959` + HOL packaging |
| `linarithSeedScript` | num lemmas to prove + num `[arith_split]` seeds | — |

Instances directory: `linarithInstScript` (int/real/rat lemmas +
`[arith_split]` seeds), `intLinarith`, `realLinarith`, `ratLinarith`
(kits + self-registration), `selftest`.

## 4. Module design

### 4.1 `linarithData`

Instance record (the §8.2 "instance record" made concrete; one per
carrier type):

```sml
type linarith_instance = {
  ty          : hol_type,          (* carrier, e.g. ``:int`` *)
  discrete    : bool,
  dest        : {                  (* atom decomposition, §4.3 *)
    dest_plus  : term -> term * term,     (* raise to decline *)
    dest_minus : (term -> term * term) option,  (* NONE for num *)
    dest_neg   : (term -> term) option,
    dest_mult  : term -> term * term,
    dest_div   : (term -> term * term) option,  (* fields only *)
    dest_suc   : (term -> term) option,         (* num only *)
    dest_lit   : term -> Arbrat.rat,      (* raise if not literal *)
    mk_lit     : Arbrat.rat -> term,      (* `number_of` analogue *)
    dest_less  : term -> term * term,
    dest_leq   : term -> term * term },
  kit         : {                  (* replay lemmas, §2.3 table *)
    add_mono   : thm list,   (* conj-premise form, Groups.thy:1486 shape *)
    mult_mono  : thm list,   (* `0 < c ==> (c*x R c*y <=> x R y)` iffs
                                or implications; replay specializes *)
    lessD      : thm list,   (* discrete only *)
    not_less   : thm,  not_le : thm,
    neqE       : thm,        (* `x<>y ==> (x<y ==> F) ==> (y<x ==> F) ==> F` *)
    nonneg     : term -> thm option },
  norm_conv   : conv,        (* canonical linear form + literal decision;
                                cancels common summands, reduces ground
                                relations to T/F  (the data simpset's job,
                                fast_lin_arith.ML:87–89) *)
  pre_split   : thm list,    (* built-in P-form split rules for this type *)
  divmod_facts : (term -> thm list) option  (* §5.4 *)
}
```

Registry: `Sref`-held `(hol_type * linarith_instance) list`;
`register_instance : linarith_instance -> unit` replaces an existing
entry for the same type with a `HOL_WARNING`; `instance_for :
hol_type -> linarith_instance option`.  Injections are registered
separately (Isabelle's `add_inj_const` + `inj_thms`):

```sml
type linarith_injection = {
  from_ty : hol_type, to_ty : hol_type, inj : term,   (* the constant *)
  hom     : {le : thm, lt : thm, eq : thm, add : thm, mul : thm} }
val register_injection : linarith_injection -> unit
```

used (a) by `demult`/`poly` to unwrap injections
(`lin_arith.ML:199–201, 238–239`), (b) by `mkthm`'s add-fallback
(`fast_lin_arith.ML:407–417`), (c) by preprocessing to normalize
injected literals.

Settypes `"arith"` and `"arith_split"` (D61): both
`export_with_ancestry` over `thm Symtab.table` keyed by
`KernelSig.name_toString`, with the splitLib-style `remove_name` and
the standard collision guard; `"arith_split"`'s `apply_delta`
validates the P-form shape on add (reject with the theorem name in the
message).  Accessors `arith_facts : unit -> thm list`,
`arith_split_thms : unit -> thm list`; removal `remove_arith`,
`remove_arith_split : string -> unit` (write `REMOVE` deltas).  No
generation counters are needed: no derived simpset bakes these sets in
(§6).

Config and trace: `type linarith_config = {neq_limit : int,
split_limit : int}`; `val default_config = {neq_limit = 9,
split_limit = 9}`; `Feedback.register_trace ("linarith", trace_level,
3)` gating diagnostics equivalent to `print_ineqs`/`trace_thm`
(`fast_lin_arith.ML:299–305, 355–366`).

### 4.2 `linarithSolve` — the untrusted core

Faithful port, `Arbint` coefficients:

```sml
datatype lineq_type = Eq | Le | Lt
datatype injust =
    Asm of int | Nonneg of int
  | LessD of injust | NotLessD of injust
  | NotLeD of injust | NotLeDD of injust
  | Multiplied of Arbint.int * injust | Added of injust * injust
datatype lineq = Lineq of Arbint.int * lineq_type * Arbint.int list * injust
```

`Nonneg` generalizes upstream `Nat` (index of atom whose instance
`nonneg` returns `SOME`): the num instance yields `0 ≤ atom` for every
nat atom (= upstream `mknat`), and the int/real/rat instances yield it
for `&`-injected atoms — strictly beyond upstream, which only covers
nat-typed atoms (`fast_lin_arith.ML:549–553`).

FM core functions mirror upstream one-for-one (`find_add_type`,
`multiply_ineq`, `add_ineq`, `elim_var`, `is_trivial`,
`is_contradictory`, `calc_blowup`, `extract_first`, `elim`) including
the pivot heuristics: equations first, minimal absolute coefficient,
then blowup-minimizing inequality pivot (`fast_lin_arith.ML:281–349`).

`decomp` output type (deviation, recorded): relations are a datatype
`REL_LE | REL_LT | REL_EQ | REL_NEQ` plus a `negated` flag, not
strings.  `integ` scales `Arbrat` coefficients to `Arbint` by the LCM
of denominators; `mklineq` builds the row exactly as upstream 521–541,
mapping discrete `<` to `≤ c−1` (`LessD`), discrete `¬≤` to `NotLeDD`,
dense to strict `Lt`/`NotLeD`.

`elim_neq`/`split_items` (upstream 574–629) ports with one recorded
fix: instead of the order-sensitive "nat neqE first" convention the
upstream FIXME complains about (`fast_lin_arith.ML:579–583`), each
`≠`-premise selects its `neqE` theorem *by the premise's type* through
the registry — the test-based implementation upstream wishes for.
The two-pass structure (discrete types first, then the rest) is
preserved so case order matches replay order.

`prove : linarith_config -> (term -> decomp option) -> term list ->
term -> bool * injust list option` = upstream 658–681: append the
negated conclusion, count `≠`s against `neq_limit`, refute every case.

### 4.3 `linarithDecomp`

Registry-driven port of `decomp`/`demult`/`poly`
(`lin_arith.ML:124–292`):

- `poly` walks `+`, `−` (declined for num, where subtraction is
  non-linear — atom instead, upstream 214–215), unary `−`, literals
  (via `dest_lit`, covering numerals and `SUC`-towers), `*` and field
  `/` via `demult` (right-bracketing product normalization; division
  only when the divisor `demult`s to a literal, upstream 165–184;
  divide-by-zero declines the atom), injection unwrapping via the
  injection registry, everything else an atom (`aconv`-keyed
  coefficient map).
- Relation layer: `=`, `<`, `≤` and their negations, with the
  carrier's instance looked up by the relation's argument type;
  unregistered types yield `NONE` (the term is simply not linear
  arithmetic — the caller's error message for a *goal* whose top
  relation is over an unregistered type names the type and the
  instances module, §4.5).
- `is_relevant : term -> bool` = `isSome o decomp` — the premise
  filter (upstream `filter_prems_tac` test, `lin_arith.ML:762–764`).

### 4.4 `linarithReplay`

**Atom generalization at entry** (recorded deviation): upstream
threads an abstraction environment through `mkthm`
(`abstract`/`abstract_arith`, `lin_arith.ML:295–361`,
`fast_lin_arith.ML:456–468`) to keep the replay simpset off
non-arithmetic subterms.  Here replay conversions are per-instance
`norm_conv`s that treat non-arithmetic heads as atoms *by
construction*, so per-step abstraction buys nothing; instead the
engine generalizes non-arithmetic atoms once at entry, HOL4's existing
pattern (`Instance.INSTANCE_T_CONV`): collect `decomp` atoms that are
not variables/literals, abstract them to fresh variables, prove the
generalized sequent, instantiate back.  Same protection, one
mechanism, and shared atoms dedup once globally.

**`mkthm : instance-env -> thm list -> injust -> thm`** (upstream
384–508): assumptions indexed by `Asm i`; `Nonneg i` from the
instance's `nonneg`; `LessD`/`NotLessD`/`NotLeD`/`NotLeDD` by MATCH_MP
against the kit; `Added` via the conj-premise `add_mono` list
(`th1 CONJ th2` then first matching MATCH_MP), with the injection
fallback exactly as upstream 407–417 (lift one side through `hom`
lemmas, retry); `Multiplied` by specializing a `mult_mono` lemma to
the literal `mk_lit n`, discharging `0 < n` with `norm_conv`
(EQT-elim), falling back to iterated addition (`mult_by_add`) as
upstream 419–445; `= `-scaling by `AP_TERM` + `norm_conv` (no lemma).
After every `Added`: `norm_conv` on both relation arguments
(`BINOP_CONV`), early-`False` escape when a side collapses (upstream
`FalseE`, 380–381, 452–454).  Final theorem must be `F` on the
premises' hypotheses; a non-`F` result is an implementation error
surfaced with the upstream warning text (498–502) under the trace —
never a silent fallback.

**Forward prover**: `splitasms` builds the `≠`-split tree by
COMP-ing each splittable assumption against its type's `neqE`
(upstream 757–772, with by-type selection per §4.2); `fwdproof`
recurses producing `F`-theorems per leaf and discharges the two case
hypotheses (774–781); `prover` assumes the negated conclusion, runs
`fwdproof`, and closes with `CCONTR`/`EQF_INTRO`/`EQT_INTRO`
(784–793).  This backs `LINARITH_PROVE`, `LINARITH_CONV`, the reducer
and the solver.

**Tactic replay**: per split-case `REPEAT` of the by-type `neqE`
eliminations followed by resolution with the case's `mkthm` result
(upstream `refute_tac`, 683–707) — case order guaranteed by §4.2's
preserved two-pass structure.

### 4.5 `linarithLib` — surface

- `SIMPLE_LINARITH_TAC facts`: insert `arith_facts()` then `facts`
  (D30, `INSERT_FACTS_TAC`); negate conclusion; **no** operator
  splitting; `≠`-split + FM + replay.  Fails (`HOL_ERR`) if any case
  lacks a certificate.  (Deviation, recorded: upstream `simple_tac`
  inserts nothing; uniform-insertion wins per D30.)
- `LINARITH_TAC facts` = `CFG_LINARITH_TAC default_config facts`;
  `CFG_LINARITH_TAC cfg facts` = facts insertion, then the D59
  preprocessing pipeline (§5), then per-subgoal `SIMPLE`-core.
  Close-or-fail (FORCE-family semantics, D34).  Argument processing:
  plain theorems = facts; `Split th` = per-invocation split rule
  (validated); claset markers (`Intro`…), `Simp`, `Iff`, aesop markers
  rejected loudly (message names the tactic, `check_aesop_markers`
  precedent).
- `LINARITH_PROVE tm`: forward path on `tm` alone (universal closure
  stripped, implications hoisted as premises); returns `|- tm`.
  `LINARITH_CONV tm`: prove-or-disprove, `|- tm = T` or `|- tm = F`
  (upstream simproc's two attempts, `fast_lin_arith.ML:803–817`,
  including premise atomization by `CONJUNCTS`).
- Errors: an entry point whose goal's outer relation is over an
  unregistered carrier fails with
  `"no linarith instance for :ty (load intLinarith / realLinarith /
  ratLinarith?)"`.
- num instance + num→(nothing) injections registered at load;
  `linarithSeedScript` seeds num `[arith_split]` rules.

## 5. Preprocessing (D59)

Pipeline of `CFG_LINARITH_TAC` (mirrors the *semantics* of
`lin_arith.ML:898–942` on the real goal):

1. **Insertion**: `arith_facts()` then argument facts as assumptions.
2. **Negation**: move the conclusion into the premises
   (`CCONTR_TAC`-shape; conclusion `¬t` adds `t` — upstream
   `neg_prop`, no double negation).
3. **Relevance filter**: drop premises that are neither
   `is_relevant` nor connectives/quantifier shells over relevant
   leaves (upstream `filter_prems_tac` semantics; keeps order
   discipline — filtered premises never re-enter).
4. **Split fixpoint**: rule set = `arith_split_thms()` ∪ per-call
   `Split` rules ∪ each registered instance's `pre_split`; one
   `splitLib.SPLIT_TAC`/`SPLIT_ASM_TAC` pack per round (cmap hoisted
   once per invocation); rounds bounded by `#split_limit cfg`,
   exceeding it fails with the upstream trace message
   (`lin_arith.ML:439–441`).  After each split round: NNF of new
   premises (fixed rewrite list — the `nnf_simpset` corpus
   `imp_conv_disj`, de Morgan, `NOT_FORALL`/`NOT_EXISTS`, `NOT_NOT`,
   `lin_arith.ML:107–114`) and flattening (`conj`/`disj`/`exists`
   elimination; disjunctions branch subgoals), plus the
   `notE + assumption` immediate-contradiction closer
   (upstream 770–772).
5. **div/mod fact-augmentation** (replaces upstream's nat/int
   div/mod splits, 547–718): for each `decomp` atom `x DIV c`,
   `x MOD c` (num) or `x / c`, `x % c` (int) with a *literal*
   divisor: num `0 < c` / int `c ≠ 0` decided by evaluation, then
   `ASSUME_TAC` the specialization of `DIVISION` / `INT_DIVISION` —
   the equation `x = c * (x DIV c) + x MOD c` plus the remainder
   bounds, with the div/mod terms left as atoms.  Iterated to a
   fixpoint (nested divisors), counted against `split_limit`.
   Non-literal divisors leave the atom untouched (upstream's numeral
   restriction, and for the same reason: a variable divisor makes the
   problem non-linear).  Rationale, recorded: for linear refutation
   the defining facts subsume the case-split — every FM certificate
   over the split cases exists over the single augmented system, at
   one problem instead of 2–3 cases per occurrence.

The reducer/solver/`PROVE`/`CONV` path performs none of steps 3–5
(upstream parity: the simproc calls `prove` with `do_pre = false`).

## 6. Simp integration and D56 wiring

### 6.1 `LINARITH_ss`

`named_merge_ss "LINARITH"` over one `SSFRAG` containing the reducer:

- `LINARITH_REDUCER`: `numSimps.ARITH_REDUCER` transposed —
  local-exception context; `addcontext` admits theorems whose
  conclusions `decomp` (post-`CONJUNCTS`), with the `contains_forall`
  and triviality screens generalized from `numSimps.sml:314–343`;
  `apply` calls the cached context conversion.
- `CACHED_LINARITH = Cache.RCACHE {capacity=2000, per_key_cap=50}
  (linarith_vars, check, CTXT_LINARITH)` where `linarith_vars`
  returns `decomp` atoms (the generic `dp_vars`), `check` accepts
  boolean `decomp`-relevant terms and `F`, and
  `CTXT_LINARITH : thm list -> conv` is the forward prover over
  context + goal (prove, else disprove).  `[arith]` facts join the
  *context argument* at each call (not baked into the fragment), so
  cache validity reasoning (hypothesis-subset checks) covers set
  growth with no extra invalidation machinery.
- `clear_linarith_caches : unit -> unit` exported
  (`numSimps.clear_arith_caches` precedent).

`LINARITH_ss` is not added to any distribution simpset in Phase 5
(promotion supersedes nat-only `ARITH_ss` per §8.4/D10).

### 6.2 The solver

`linarith_solver : Traverse.ssolver`, name string `"lin_arith"`
(greppable against `Simplifier.mk_solver "lin_arith"`,
`lin_arith.ML:949`): `solve {context_thms, ...} tm` runs the forward
prover on `context_thms @ arith_facts()` ⊢ `tm` — the
`add_arith_facts #> prems_lin_arith_tac` composition, dynamic in both
the registry and the `[arith]` set.  Registered *unsafe only* (HOL
parity; a safe-list registration is recorded as rejected — unsafe
solvers already serve side conditions in safe-mode invocations, D15,
which is the slot Isabelle's `auto`/`simp` give `lin_arith`).

### 6.3 D56 edits

- `clasimpLib.sml:17–21` (`derive_clasimp_ss`): add
  `|> simpLib.add_unsafe_solver linarithLib.linarith_solver`.
  No generation counter: the solver reads `[arith]` and the registry
  at invocation.
- `aesopData.sml:56–63` (`derive_aesop_ss`): same one-line addition.
  Aesop discipline is respected: unsafe solvers do not run as final
  solvers in safe mode, so normalisation stays ≤ 1-subgoal and
  deterministic; the solver only discharges conditional-rewrite side
  conditions there.
- `src/auto/clasimp/Holmakefile`: `INCLUDES += auto/linarith`
  (aesop inherits visibility, `aesop/Holmakefile` already includes
  clasimp).
- Selftest additions in both directories: an `AUTO_TAC` and an
  `AESOP_TAC` goal that close only through an arithmetic side
  condition, plus an `[arith]`-fact-dependent variant.

## 7. Build integration, seeds, theory scripts

- `tools/sequences/upto-auto`: insert `src/auto/linarith` after
  `src/auto/blast`, before `src/auto/clasimp`; add
  `!src/auto/linarith/theory_tests`.  The instances directory is
  **not** in `upto-auto` (D60).
- `src/parallel_builds/core/Holmakefile` `SRCRELNAMES`: add
  `auto/linarith auto/linarith/instances`.
- `tools/sequences/more-theories`: add
  `!src/auto/linarith/theory_tests`.
- Core `Holmakefile`: `HOLHEAP = bin/hol.state0` pin, `INCLUDES` =
  `src/auto/rules` + `src/simp/src` (splitLib) only (num arith modules
  are in sigobj by this band), `selftest.exe`,
  `linarith-selftest.log`, the OpenTheory `.ot.art` block (theory
  script present), `EXTRA_CLEANS`.
- Instances `Holmakefile`: `INCLUDES = .. ../../integer ../../real
  ../../rational` (plus what those pull), same selftest scaffold
  (`linarith-instances-selftest.log`), OpenTheory block.
- `linarithSeedScript.sml` (core): proves the num "prove" entries of
  §2.3 (`LT_ADD2`-analogue, mixed add-monos, num `neqE`, P-form
  `MIN`/`MAX`/nat-sub split rules) and declares the split rules
  `[arith_split]`.  `[arith]` itself ships **empty** (Isabelle
  parity: the `arith` named-theorems set has no default members;
  users and later seed theories populate it).
- `linarithInstScript.sml` (instances): int min/max P-form iffs and
  split rules, int abs split rule, int/real/rat `neqE`s, rat
  ≤-scaling and mixed add-monos, real min/max/abs P-form rules;
  declares the int/real `[arith_split]` rules.
- `theory_tests/` (core): base/child scripts asserting `[arith]` and
  `[arith_split]` declaration → visibility in a child theory →
  reload idempotence, and `remove_arith` writing `RM` deltas
  (aesop `theory_tests` round-trip pattern).

## 8. Selftests

Core `selftest.sml`:

1. FM-core unit tests (ML level): known systems with expected
   `injust` shapes; blowup pivot choice; equation-first pivoting;
   trivial/contradictory detection.
2. Replay golden tests: one goal per `injust` constructor per shipped
   kit slot (Asm/Nonneg/LessD/NotLessD/NotLeD/NotLeDD/Multiplied incl.
   the mult-mono-fails→mult_by_add fallback/Added incl. the injection
   fallback), asserting kernel acceptance.
3. num tactic battery: Isabelle regression shapes — discreteness
   (`x < y ==> x + 1 <= y` uses), `≠`-splitting up to and at
   `neq_limit` (boundary: limit exceeded ⇒ `≠` premises ignored, not
   failure — upstream 670–673), MIN/MAX/ABS-free goals,
   nat-subtraction splits, DIV/MOD augmentation goals
   (`0 < n ==> n MOD 3 < 3` etc.), `Split` marker, marker rejection,
   `CFG_` limit overrides, `SIMPLE_` vs full strength difference.
4. `LINARITH_PROVE`/`LINARITH_CONV` forward forms incl. disproof.
5. `LINARITH_ss` reducer: side-condition discharge inside a
   conditional rewrite; context admission screens; cache behavior
   (`clear_linarith_caches`; failure caching under context growth
   with an `[arith]` addition between calls).
6. Negative: nonlinear goals fail cleanly; unregistered-type message;
   no state leaked on failure (claset/simpset/registry unchanged).
7. Strength suite: translations of Isabelle's
   `src/HOL/ex/Arith_Examples.thy` goal corpus (vendor that file at
   the pinned commit `f7e02b7e1f31` into `sources/` with a README row
   — task T9) behind `HOLSELFTESTLEVEL >= 2`; known-incomplete goals
   (genuine integer-divisibility reasoning beyond discreteness — the
   documented `fast_lin_arith` incompleteness) asserted as expected
   failures citing `intLib.ARITH_TAC`/`COOPER_TAC` as the remedy
   (D55/D57 accounting).

Instances `selftest.sml`: per-type batteries mirroring 3 (int abs and
`INT_DIV_P`-backed div/mod augmentation; real dense behavior — no
rounding; rat goals that `RAT_BASIC_ARITH_CONV` cannot do), mixed-type
injection goals (`&n ≤ x` num/int, int/real, num/rat, incl. the
`Nonneg`-of-injected-atom strengthening), registration idempotence
(reload → warning, not duplication).

Both suites run successes through `Tactical.VALID`; benchmarks are
count + time-budget assertions; no goal pruning.

## 9. Documentation

`help/Docfiles` (grammar pragma + 72-hyphen rule + Failure/Example/
See-also structure): `linarithLib.smd` (structure overview incl. the
attribute family and instance-loading story),
`linarithLib.LINARITH_TAC.smd`, `.SIMPLE_LINARITH_TAC.smd`,
`.CFG_LINARITH_TAC.smd`, `.LINARITH_PROVE.smd`, `.LINARITH_CONV.smd`,
`.LINARITH_ss.smd`, `.linarith_solver.smd`, `.register_instance.smd`,
`.arith.smd`, `.arith_split.smd`, `.remove_arith.smd` (covers both
removers).

`src/auto/CLAUDE.md`: fix the stale layout lines — `linarith/` is
"generic linear arith, `LINARITH_TAC` (D55: no registry)"; delete the
`presburger/` and `algebra/` lines (D57/D58); note the two-directory
linarith layout and that `instances/` is the one `src/auto` directory
allowed post-boss `INCLUDES`.

`PLAN.md`: append D59–D62 to §2; update §3's layout block and §8 with
a pointer to this file; add the phase gate to §11's record when green.

## 10. Task breakdown (each task ends green on
`bin/build -t --seq=tools/sequences/upto-auto`; phase boundary on
`bin/build -F -t`)

- **T1** Record D59–D62 in PLAN.md §2; CLAUDE.md §9 edits; create
  `src/auto/linarith` skeleton + build wiring (sequence + SRCRELNAMES
  entries for the core dir only).
- **T2** `linarithSolve`: datatypes + FM core + `integ`/`mklineq`/
  `mknonneg` + `elim_neq`/`prove`; ML-level unit selftests (§8.1).
- **T3** `linarithData`: instance/injection records, registry,
  settypes, config, trace; `theory_tests` persistence scenarios.
- **T4** `linarithDecomp` + `linarithSeedScript` (num lemmas/seeds) +
  num instance record (kit per §2.3).
- **T5** `linarithReplay`: `mkthm` + forward prover + atom
  generalization; golden replay tests (§8.2).
- **T6** `linarithLib` surface: preprocessing pipeline (D59),
  `LINARITH_TAC`/`SIMPLE_`/`CFG_`, `PROVE`/`CONV`, argument
  processing; num battery (§8.3–4, §8.6).
- **T7** `LINARITH_ss` + solver + cache (§6.1–6.2); reducer tests
  (§8.5).
- **T8** D56 wiring: clasimp + aesop edits, Holmakefile include,
  their selftest additions (§6.3).
- **T9** `src/auto/linarith/instances`: build wiring,
  `linarithInstScript`, `intLinarith`/`realLinarith`/`ratLinarith`,
  instance selftests; vendor `Arith_Examples.thy` (README row) and
  land the strength suite incl. expected failures.
- **T10** Docfiles (§9); final audit that every delivered mechanism
  has a live consumer (Phase-4 audit discipline); phase gate
  `bin/build -F -t`; PLAN.md status/gate record.

Dependencies: T2–T5 are sequential; T6 needs T2–T5; T7 needs T6; T8
needs T7; T9 needs T6 (instances) and T7 (reducer tests over int/real/
rat); T10 last.  T3 can proceed in parallel with T2.

## 11. Risks and mitigations

- **Replay/search misalignment** (the classic port failure): golden
  tests per `injust` constructor (§8.2) land *before* the tactic
  surface (T5 before T6); the trace reproduces upstream's step
  logging for diagnosis.
- **`norm_conv` adequacy**: the data-simpset contract
  (`fast_lin_arith.ML:87–89` — reduce contradictory `≤` to `False`,
  cancel common summands) is restated as per-instance unit tests over
  the existing canonicalizers before they are trusted in replay.
- **Coefficient growth**: `Arbint` throughout (also the mosml
  portability requirement); LCM-based `elim_var` scaling as upstream.
- **Case-order drift between `elim_neq` and replay**: preserved
  two-pass structure + by-type `neqE` selection makes order a
  function of premise order only; a dedicated test permutes `≠`
  premises across types.
- **Cache soundness under `[arith]` growth**: facts flow through the
  cache's context argument, whose subset logic already governs reuse;
  tested explicitly (§8.5).
- **Preprocessing loops**: split fixpoint and div/mod augmentation
  both counted against `split_limit`; augmentation marks processed
  atoms.
- **Performance vs `ARITH_ss` on nat goals**: not a Phase-5 gate
  (promotion decides the swap), but the strength suite carries time
  budgets so regressions surface early.
- **Instances load-order surprises**: registration idempotent with
  warning; error messages from unregistered types name the module to
  load.

## 12. Interfaces later phases rely on (freeze list)

- `linarithLib`: `LINARITH_TAC`, `SIMPLE_LINARITH_TAC`,
  `CFG_LINARITH_TAC`, `linarith_config` (+ `default_config`),
  `LINARITH_PROVE`, `LINARITH_CONV`, `LINARITH_ss`,
  `linarith_solver` (name string `"lin_arith"`),
  `clear_linarith_caches`.
- `linarithData`: `linarith_instance`, `linarith_injection`,
  `register_instance`, `register_injection`, `instance_for`,
  `arith_facts`, `arith_split_thms`, `remove_arith`,
  `remove_arith_split`; settype names `"arith"`, `"arith_split"`.
- Instance modules `intLinarith`, `realLinarith`, `ratLinarith`
  (self-registering on load).
- Consumers already scheduled: Phase-8 parity suite maps Isabelle's
  `arith`/`linarith` goal classes to `LINARITH_TAC` (D55); promotion
  (Phase 9) swaps `LINARITH_ss`'s num instance in for
  `numSimps.ARITH_ss` and moves the instance registrations into
  `intLib`/`realLib`/`ratLib` (D10/D60).
