# Phase-S extension points in `src/simp/src/` for the linarith port

> Research report, 2026-07-30, Phase 5 planning round (prior to owner
> decisions D59–D62 and `../PLAN_phase_5.md`).  HOL4 citations refer
> to worktree HEAD `7a8a286b5`.  Produced by a survey agent; findings
> verified against the working tree.

## 1. Solver architecture

### 1.1 Types

`src/simp/src/Traverse.sig:90-96`:

```sml
type simp_prover_ctxt =
     {stack        : term list,
      context_thms : thm list,
      recurse      : term -> thm}
type ssolver =
     {name : string, solve : simp_prover_ctxt -> term -> thm}
type subgoaler = simp_prover_ctxt -> term -> thm
```

A solver receives **no conversion argument and no reducer context** —
only the three-field record plus the term:

- `stack` — the side-condition stack (terms currently being solved,
  grows with nesting).
- `context_thms` — all theorems in scope: initial reducer/solver
  context theorems **plus** every assumption introduced by
  congruence-rule descent (`Traverse.sml:112, 135`;
  `notes.md:142-163`).  This is where a linarith solver picks up the
  hypotheses.
- `recurse : term -> thm` — recursively simplifies its argument under
  equality in the same traversal context, returning `|- c = c'`.  In
  `Traverse.sml:299-301` `recurse` is wrapped so a failure yields
  `REFL tm` (and restores the traversal limit).

`solve` must return `|- <the input term>` (a proof of the term, not an
equation).  At the tactic level `final_solver_tac` additionally checks
this: `simpLib.sml:1404-1405` raises `"Solver proved the wrong term"`
if `concl th` is not alpha-equal to the goal.

### 1.2 Storage on a simpset

Two separate named lists live in `strategy_data`,
`simpLib.sml:149-156`:

```sml
withtype strategy_data =
  {loopers        : (string * (simpset -> tactic)) list,
   unsafe_solvers : Traverse.ssolver list,
   safe_solvers   : Traverse.ssolver list,
   subgoaler      : Traverse.subgoaler option,
   cond_depth     : int option,
   term_ord       : (term * term -> order) option,
   excl_loopers   : string Binaryset.set}
```

`simpset = SS of {mk_rewrs, history, initial_net, dprocs, travrules,
limit, excluded, strategy}` (`simpLib.sml:137-146`).  Solver lists are
also carried on `ssfrag` (`unsafe_solvers`, `safe_solvers`,
`simpLib.sml:113-114`) and merged into the simpset by `++`
(`simpLib.sml:1017-1020`).

Ordering/dedup: `add_solver` (`simpLib.sml:545-548`) appends at the
end and silently drops a solver whose `name` already occurs.
`set_unsafe_solvers`/`set_safe_solvers` dedup via `dedup_solvers`
before replacing (`simpLib.sml:597-600`).

Every change is recorded as a `STRATEGY_EVENT` in the simpset
`history` (`simpLib.sml:124-136, 590-591`) so
`remove_ssfrags`/`exclude_ssfrags` rebuilds replay it faithfully.

### 1.3 Public signatures (`simpLib.sig:163-172`)

```sml
val add_unsafe_solver  : Traverse.ssolver -> simpset -> simpset
val add_safe_solver    : Traverse.ssolver -> simpset -> simpset
val set_unsafe_solvers : Traverse.ssolver list -> simpset -> simpset
val set_safe_solvers   : Traverse.ssolver list -> simpset -> simpset
val remove_solver      : string -> simpset -> simpset  (* both lists *)
val set_subgoaler      : Traverse.subgoaler -> simpset -> simpset
val set_cond_depth     : int -> simpset -> simpset
val set_term_ord       : (term * term -> order) -> simpset -> simpset
val mk_tactic_solver   : string * tactic -> Traverse.ssolver
```

Fragment-level (`simpLib.sig:106-107`):

```sml
val solver_ss      : Traverse.ssolver -> ssfrag   (* -> unsafe list *)
val safe_solver_ss : Traverse.ssolver -> ssfrag   (* -> safe list *)
```

`remove_solver` is a no-op when the name is absent
(`simpLib.sml:615-616`).

### 1.4 `mk_tactic_solver` — exact semantics

`simpLib.sml:732-739`:

```sml
fun mk_tactic_solver (name,tac) =
  let
    fun solve {context_thms,...} c =
      TAC_PROOF ((map concl context_thms,c),tac)
      |> Lib.itlist PROVE_HYP context_thms
  in
    {name=name,solve=solve}
  end
```

The goal `c` is proved by `tac` with the conclusions of `context_thms`
as the assumption list; the resulting hypotheses are then discharged
by `PROVE_HYP` against the context theorems themselves.  `stack` and
`recurse` are ignored.  Failure of `tac` propagates as `HOL_ERR`
(what the engine treats as "not applicable").  Example in the tree:
`src/auto/clasimp/clasimpLib.sml:8-15`.

### 1.5 Where each list is invoked

**Engine side conditions — always the *unsafe* list.**
`traversedata_for_ss_prepared` (`simpLib.sml:1189-1207`) sets
`solvers = #unsafe_solvers strategy` unconditionally — including when
the surrounding tactic runs in safe mode (`notes.md:184-186`).

Call chain for a conditional rewrite:
1. `rewriter_for_ss_prepared`'s `apply` (`simpLib.sml:1178-1183`)
   calls `conval solver stack tm`, where `conval` is
   `Cond_rewr.COND_REWR_CONV (nm,th)` (`simpLib.sml:65-85`).
2. `COND_REWR_CONV` (`Cond_rewr.sml:141-196`) instantiates the
   rewrite, checks the loop-cut and stack limit
   (`Cond_rewr.sml:151-156`), then calls `solver new_stack condition`
   per condition (`Cond_rewr.sml:172-181`).
3. `solver` is `Traverse.ctxt_solver` (bound at `Traverse.sml:330`);
   congruence-rule side conditions go through the same `ctxt_solver`
   (`Traverse.sml:345`).
4. `ctxt_solver` pipeline (`Traverse.sml:291-322`): fast path when
   `(subgoaler, solvers) = (NONE, [])`: `EQT_ELIM (raw_recurse tm)`
   (line 319); otherwise run `subgoaler prover_ctxt tm` or
   `recurse tm` to get `|- c = c'` (309-311); if `c'` is `T`,
   `EQT_ELIM`; else `first_solver solvers tm'` tries each `ssolver`
   in list order, catching only `HOL_ERR` (304-308), and the result
   is transported back with `EQ_MP (SYM eq)` (315).  Traversal-limit
   state is restored on failure (321).

**Tactic-level residual goals — safe or unsafe, per mode.**
`final_solver_tac` (`simpLib.sml:1391-1411`):

```sml
val solvers = if #safe mode then #safe_solvers s
              else #unsafe_solvers s
val prover_ctxt =
  {stack=[], context_thms=reducer_context @ solver_context,
   recurse=QCONV (simp_conv_with_prepared_context ss prepared
                    reducer_context solver_context)}
```

`stack` is `[]`, `recurse` re-enters `SIMP_CONV` with the invocation
simpset, and the produced theorem is `reconcile_hyps`-checked
(`simpLib.sml:1370-1377`) — a solver may not introduce a hypothesis
that is not already an assumption of the goal.
`FIRST (map solve_with solvers)` is the disjunction.

Tactic loop shape (`simpLib.sml:1437-1467`, `notes.md:225-253`):

```
rewr_tac THEN (solve_tac ORELSE
               TRY (loop_tac THEN_LT ALLGOALS (recur main)))
```

`SIMP_CONV`/`SIMP_RULE`/`SIMP_PROVE` never touch safe solvers or
loopers (`simpLib.sml:1332-1340`, `notes.md:248-253`).

**Implication for Phase 5:** registering linarith as an *unsafe*
solver makes it discharge conditional-rewrite side conditions inside
`Traverse` **and** serve as final solver for unsafe-mode residual
goals.  It will *not* be a final solver under `{safe=true}`
invocations (clasimp's safe asm-full-simp, aesop normalisation) unless
also added to the safe list — a real decision (resolved by D62/§6.2 of
the plan: unsafe only, HOL parity).

## 2. Looper hook

Type: `string * (simpset -> tactic)` (`simpLib.sml:112, 150`).

Registration (`simpLib.sig:157-159`, `:105`): `add_looper`
(replaces in place by name — `update_looper`, `simpLib.sml:540-543`),
`del_looper` (warns if absent, `simpLib.sml:611-613`), `set_looper`,
`looper_ss`.

Loopers run only at the tactic layer — after rewriting, only if no
final solver applied.  `looper_tac` (`simpLib.sml:1413-1423`) filters
by `excl_loopers`, applies `looper ss g` with the invocation simpset,
converts `Conv.UNCHANGED` to `NO_TAC`, and takes `FIRST`.  Successful
looper rounds are bounded by the simpset `limit` via `bounded_looper`
(`simpLib.sml:1425-1435`).  A looper must fail when inapplicable.
After a looper fires, the whole strategy recurses on every subgoal.

## 3. `cond_depth`

- Field: `cond_depth : int option` in `strategy_data`
  (`simpLib.sml:154`) and `Traverse.traverse_data`
  (`Traverse.sig:145`).
- Setter `set_cond_depth` (`simpLib.sig:169`, impl `simpLib.sml:603`);
  event `SET_COND_DEPTH_EVENT` (`simpLib.sml:134`).
- Default on a simpset: `NONE` (`empty_strategy`,
  `simpLib.sml:352-354`).
- Effect: `GEN_TRAVERSE_WITH_CONTEXT` dynamically binds the global
  `Cond_rewr.stack_limit` with `Lib.with_flag` for the whole traversal
  when `SOME` (`Traverse.sml:379-400`).  Global default:
  `val stack_limit = ref 4` (`Cond_rewr.sml:11`).  `COND_REWR_CONV`
  fails when `length stack + length conditions > !stack_limit`
  (`Cond_rewr.sml:154-156`).
- Precedent: clasimp and aesop both use 40
  (`clasimpLib.sml:19`, `aesopData.sml:60`).

## 4. The splitter

### 4.1 Public signature — `src/simp/src/splitLib.sig` (verbatim)

```sml
signature splitLib =
sig
  include Abbrev
  val SPLIT_CONV        : thm list -> conv
  val SPLIT_ASM_TAC     : thm list -> tactic
  val SPLIT_TAC         : thm list -> tactic
  val mk_asm_split      : thm -> thm
  val type_split_of     : hol_type -> thm
  val type_asm_split_of : hol_type -> thm
  val type_split_rules  : hol_type -> thm list
  val split_thms        : unit -> thm list
  val named_split_thms  : unit -> (string * thm) list
  val is_asm_split      : thm -> bool
  val split_thm_name    : thm -> string
end
```

### 4.2 Split rule shape

`rule_parts` (`splitLib.sml:24-49`) enforces: no hypotheses;
conclusion after `strip_forall` is `P (c a1 ... an) = <rhs>`; `P` a
variable universally quantified anywhere in the prefix
(`selftest.sml:1570-1575`); `P : ty -> bool`; the redex head a
constant.  `asm = is_neg rhs` classifies as assumption-split rule.
Canonical form (`selftest.sml:1578-1581`):

```
|- !P b x y. P (if b then x else y) <=> (b ==> P x) /\ (~b ==> P y)
```

### 4.3 Registration: `[split]` ThmSetData settype

`splitLib.sml:100-117`: collision guard (raise if settype/attribute
`"split"` exists), then `ThmSetData.export_with_ancestry
{settype="split", ...}` over a `thm Symtab.table` keyed by
`KernelSig.name_toString`; `apply_split_delta` validates via
`is_asm_split` on add (`splitLib.sml:92-98`); `named_split_thms`/
`split_thms` accessors; `remove_name` (83-90) accepts both `Thy$Name`
and bare names via `ThmSetData.toKName`.  In the current core build no
theorem in `src/` carries `[split]` except two theory tests; real
splitting today comes from the TypeBase datatype path.

### 4.4 `Split` marker and `add_split`/`del_split`

`simpLib.Split = markerLib.Split` (`simpLib.sig:91`,
`simpLib.sml:1221`).  `process_tags` turns `Split th` into
`add_split (destSplit th)` on the invocation simpset
(`simpLib.sml:1297-1298`).  `add_split th` (`simpLib.sml:621-624`)
registers a *looper* named `"split <dbname>"`/`"split_asm <dbname>"`
with body `K (splitLib.SPLIT_TAC [th])` — the name comes from
`split_thm_name` (DB reverse lookup, `splitLib.sml:62-81`), so an
anonymous theorem cannot be added this way.  `del_split` deletes both
names quietly (`simpLib.sml:626-636`).

### 4.5 TypeBase cache

`splitLib.sml:144-180`: `type_split_cache : type_splits Symtab.table
Sref.t` keyed by `Thy$Tyop`; `split = TypeBase.case_pred_imp_of`,
`asm_split = TypeBasePure.case_elim_of`, `rules = [split,
mk_asm_split asm_split]`.  `type_split_rules ty` returns that pair.

### 4.6 `SPLIT_TAC`/`SPLIT_CONV`/`SPLIT_ASM_TAC` semantics

- `SPLIT_CONV thms` (`splitLib.sml:369`): analyses rules once into a
  `cmap` (`cmap_of_rules`, keyed by head constant × type shape ×
  asm-flag); per term `scan` collects `split_pack`s, sorts by
  `pack_le` (fewest binders, shortest path, leftmost —
  `splitLib.sml:310-319`), applies the first pack that succeeds.
  Exactly one split per invocation (`selftest.sml:1612-1617`).
  Binder-correct: a redex referring to a bound variable is split at
  the innermost bool-typed body (`splitLib.sml:247-274`); all
  alpha-equivalent occurrences replaced simultaneously
  (`splitLib.sml:330-348`).
- `SPLIT_ASM_TAC` (`splitLib.sml:401-423`): first assumption
  containing an asm-split head, rewritten via `asm_eq` (scan on
  `mk_neg asm`, `clean_asm_eq` cancels the outer negations,
  `splitLib.sml:377-392`), `STRIP_ASSUME_TAC`ed in place.
- `SPLIT_TAC` (`splitLib.sml:426-431`):
  `CHANGED_TAC (CONV_TAC (split_conv cmap)) ORELSE
   CHANGED_TAC (split_asm_tac cmap)` — conclusion first; shared cmap.

### 4.7 `split_ss` and the splitter looper

`simpLib.sml:692-730`: `split_ss = named_merge_ss "split"
[looper_ss ("splitter", splitter_looper), rewrites [cases_simp]]`.
`splitter_looper` = persistent `[split]` rules (filtered by
`excl_loopers` under `"split <n>"`/`"split_asm <n>"` names) +
TypeBase rules for datatypes whose case constant occurs fully applied
(`applied_arities`, `simpLib.sml:646-690`; exclusions
`"split.case Thy$Tyop"`), run through `splitLib.SPLIT_TAC`.

### 4.8 Programmatic reuse for linarith pre-splitting: YES

Everything a linarith preprocessor needs is public and independent of
any simpset: rules need only be proved and passed as `thm list` —
no `[split]` registration, no DB name, no simpset.  Entry points:
`SPLIT_CONV` (wrap with `REPEATC`; raises
`HOL_ERR "SPLIT_CONV" "no applicable split rule"` at the fixpoint),
`SPLIT_TAC`/`SPLIT_ASM_TAC` (hoist the constructed tactic once —
`SPLIT_TAC` re-analyses rules per call; caching discipline as in
`aesopRule.sml:266-296`), `mk_asm_split`/`is_asm_split`
(`split_rule_pair` pattern, `aesopRule.sml:239-262`),
`type_split_rules`.

Caveats: conclusion rules with conjunctive RHS need `mk_asm_split` for
the assumption side; `scan` requires the redex's enclosing context to
be bool-typed at the root or innermost binder body
(`splitLib.sml:262-272`) — satisfied for arithmetic goals; rules are
matched by head constant and type shape (`same_key`/`candidates`,
`splitLib.sml:184-230`), so per-type rules coexist.

## 5. SSFRAG record and reducer packaging

### 5.1 Internal record — `simpLib.sml:103-117` (Phase-S extended)

```sml
datatype ssfrag = SSFRAG_CON of {
    name           : string option,
    convs          : tagged_convdata list,
    rewrs          : (thname option * thm) list,
    ac             : (thm * thm) list,
    filter         : (controlled_thm -> controlled_thm list) option,
    dprocs         : Traverse.reducer list,
    congs          : thm list,
    relsimps       : relsimpdata list,
    loopers        : (string * (simpset -> tactic)) list,
    unsafe_solvers : Traverse.ssolver list,
    safe_solvers   : Traverse.ssolver list,
    congprocs      : {name : string, relation : term,
                      proc : Opening.congproc} list }
```

The public constructor `SSFRAG` still takes only the original seven
fields (`simpLib.sig:66-73`; impl `simpLib.sml:162-168`); the extended
fields are reachable via `looper_ss`/`solver_ss`/`safe_solver_ss`/
`congproc_ss`/`dproc_ss`/`relsimp_ss` + `merge_ss`/`named_merge_ss`.
`merge_ss` (`simpLib.sml:294-309`) concatenates field-wise and
composes `filter`s with `oo`.

### 5.2 Reducer packaging — no `mk_reducer`

`Traverse.sig:67-88`:

```sml
datatype reducer = REDUCER of {
       name : string option,
       initial: context,                        (* context = exn *)
       addcontext : context * thm list -> context,
       apply: {solver:term list -> term -> thm,
               conv: term list -> term -> thm,
               context: context,
               stack:term list,
               relation : (term * (term -> thm))} -> conv }
val dest_reducer : reducer -> {...}
val addctxt      : thm list -> reducer -> reducer
```

Dispatch priority (`Traverse.sml:336-358`): rewriters are
high-priority (each node before descent); dprocs are low-priority,
tried after descent and only if the high-priority phase changed
nothing — decision procedures effectively see terms bottom-up
(`notes.md:264-277`).

## 6. `numSimps.ARITH_ss`/`CTXT_ARITH`/`Cache` — the pattern

File: `src/num/arith/src/numSimps.sml` (interface `numSimps.sig`).

Layering: `ARITH_ss = named_merge_ss "ARITH" [ARITH_RWTS_ss,
ARITH_DP_ss]` (`numSimps.sml:518`); `ARITH_DP_FILTER_ss fil`
(`numSimps.sml:497-504`) is a plain `SSFRAG` with one conv
(`MUL_CANON_CONV` keyed on `x * y`) and
`dprocs = [ARITH_REDUCER fil]`.

The reducer (`numSimps.sml:477-491`): private context is a local
exception carrying `thm list` (the SML existential hack,
`Traverse.sig:19`); `addcontext` splits conjunctions and keeps only
theorems the procedure can use (`is_arith_thm`,
`numSimps.sml:338-343`: requires `is_arith (concl thm)`, rejects
positive universals via `contains_forall true`,
`numSimps.sml:314-327`, requires hypotheses or a ground conclusion);
`apply` ignores everything except `#context` and calls
`CACHED_ARITH`.

The cache (`numSimps.sml:462-475`):

```sml
val (CACHED_ARITH,arith_cache) =
  RCACHE {capacity=2000, per_key_cap=50} (dp_vars, check, CTXT_ARITH)
```

`Cache.sig:43-60`: `CACHE`/`RCACHE` take capacity info + (relevance
check ×) worker `thm list -> conv`; failures are cached too (a success
is reusable if `prev << curr` context; a failure if `curr << prev`);
LRU over keys; per-key list bounded.  `RCACHE`'s extra argument is a
DP-variable extractor (`dp_vars`, `numSimps.sml:410-460`) used to
split the context into connected components by shared variables so
irrelevant hypotheses are stripped before the failure check.  Reset:
`clear_arith_caches` (`numSimps.sml:521`, `numSimps.sig:18,21`).

`CTXT_ARITH` (`numSimps.sml:352-395`), `ctxt = thm list`: bool-typed
`is_arith` goals build `list_mk_imp(map concl thms, gl)`, call
`ARITH`, and re-`MP` the context in — returning
`EQT_INTRO`/`EQF_INTRO` (try-positive-then-negative at 365-371);
`:num`-typed subterms get linear reduction/`ADDR_CANON_CONV`.

Direct transposition recipe for a type-generic linarith reducer:
`is_linarith`(_thm) admission filters parameterised by the registered
instances; `CTXT_LINARITH : thm list -> conv`;
`RCACHE (linarith_vars, check, CTXT_LINARITH)` with `linarith_vars` =
decomp atoms (generic `dp_vars`); `LINARITH_REDUCER` +
`LINARITH_DP_ss`; solver via `mk_tactic_solver`/`solver_ss` or a
hand-rolled `ssolver`; `clear_linarith_caches` mirror.  Pre-splitting
belongs inside `LINARITH_TAC`, not as a looper, keeping it off
`SIMP_CONV`'s critical path.
