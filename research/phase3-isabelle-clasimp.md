# Isabelle clasimp layer (auto / force / fastforce / clarsimp / [iff]) — research for HOL4 Phase 3

> Research report, 2026-07-19.  All cited Isabelle files are vendored
> at `../sources/src/` (mirror-isabelle, commit f7e02b7e1f31, same
> snapshot as the other reports).  Every claim below was verified
> against the vendored source text; line numbers refer to those files.

Isabelle sources read: `src/Provers/clasimp.ML` (233 lines, in
full), `src/Provers/classical.ML` (relevant regions: 513–732,
740–850), `src/HOL/Tools/simpdata.ML` (in full, 214 lines),
`src/Pure/simplifier.ML` (300–500), `src/Provers/blast.ML`
(1250–1310), `src/HOL/HOL.thy` (claset/simpset/blast setup regions),
`src/Doc/Isar_Ref/Generic.thy` (1375–1630), plus spot checks in
`src/Pure/search.ML`, `src/Pure/tactical.ML`, `src/Pure/bires.ML`,
`src/Pure/Isar/context_rules.ML`, `src/Provers/splitter.ML`.

---

## 1. The functor and its HOL instantiation

`clasimp.ML:8–16` — signature `CLASIMP_DATA` requires structures
`Splitter`, `Classical`, `Blast` and theorems `notE`, `iffD1`,
`iffD2`.  Note that `Simplifier` is *not* a functor parameter: the
functor body refers to the global `Simplifier` structure directly
(e.g. line 51).

HOL instantiates it in `simpdata.ML:174–184`:

```
structure Clasimp = Clasimp
(
  structure Simplifier = Simplifier
    and Splitter = Splitter
    and Classical  = Classical
    and Blast = Blast
  val iffD1 = @{thm iffD1}
  val iffD2 = @{thm iffD2}
  val notE = @{thm notE}
);
open Clasimp;
```

(The extra `Simplifier` component is harmless surplus over the
signature.)  `Blast` itself is instantiated in `HOL.thy:923–935`
(`val blast_tac = Blast.blast_tac`).  **Blast is a mandatory functor
argument — there is no code path in clasimp for "blast unavailable"**
(see §7 for how blast *failure* is handled).

## 2. addss / addSss — simp as classical wrapper

`clasimp.ML:44–54`:

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

There is **no `addXss`** in this snapshot (only `addSss` and
`addss`).  Exact slot semantics:

| combinator | wrapper slot | via | wrapper name | simp tactic | composition with step |
|---|---|---|---|---|---|
| `addSss` | **safe** wrapper (`swrappers`) | `Classical.addSafter` | `"safe_asm_full_simp_tac"` | `Simplifier.safe_asm_full_simp_tac` | `step ORELSE' (CHANGED o simp)` — simp tried only *after* the safe step fails |
| `addss` | **unsafe** wrapper (`uwrappers`) | `Classical.addbefore` | `"asm_full_simp_tac"` | `Simplifier.asm_full_simp_tac` | `(CHANGED o simp) APPEND' step` — simp is a *backtrackable alternative tried first* |

Loop protection is exactly `CHANGED o tac ctxt` (clasimp.ML:48) —
the wrapper fails unless simplification changes the proof state.
The wrapper closure ignores the runtime context (`fn _ =>`): the
simpset captured is the one at `addss`/`addSss` time.

Wrapper machinery (`classical.ML:555–565`):

```
(*compose a safe tactic alternatively before/after safe_step_tac*)
fun ctxt addSbefore (name, tac1) =
  ctxt addSWrapper (name, fn ctxt => fn tac2 => tac1 ctxt ORELSE' tac2);
fun ctxt addSafter (name, tac2) =
  ctxt addSWrapper (name, fn ctxt => fn tac1 => tac1 ORELSE' tac2 ctxt);

(*compose a tactic alternatively before/after the step tactic*)
fun ctxt addbefore (name, tac1) =
  ctxt addWrapper (name, fn ctxt => fn tac2 => tac1 ctxt APPEND' tac2);
fun ctxt addafter (name, tac2) =
  ctxt addWrapper (name, fn ctxt => fn tac1 => tac1 APPEND' tac2 ctxt);
```

So: **safe** wrappers compose with `ORELSE'` (deterministic
preference), **unsafe** wrappers with `APPEND'` (both alternatives
kept for backtracking).  Wrappers are named slots in an alist;
re-adding the same name overwrites with a warning
(`update_warn`, classical.ML:532–541) — hence the "only one simpset"
caution.  `appSWrappers`/`appWrappers` (classical.ML:529–530) fold
all registered wrappers over the base step tactic.

Where wrappers are consulted:

- `safe_step_tac` (classical.ML:581–588) and `clarify_step_tac`
  (616–623) apply `appSWrappers` — **safe wrappers only**.
- `step_tac` (649–650), `slow_step_tac` (654–655), `depth_tac`'s
  `slow_step_tac'` (713), and clasimp's `slow_step_tac'` (130–132)
  apply `appWrappers` — **unsafe wrappers only**.

Consequence worth remembering: `addss ctxt` has **no effect on
`clarify_tac`/`safe_tac`** (they only look at safe wrappers), and
`addSss ctxt` has no effect on the unsafe search steps.

## 3. `safe_asm_full_simp_tac` — what it actually is

Defined in **`src/Pure/simplifier.ML:361`** (not in
raw_simplifier.ML; raw_simplifier only has the solver plumbing):

```
350  val simp_tac = generic_simp_tac false (false, false, false);
354  val asm_full_simp_tac = generic_simp_tac false (true, true, true);
356  (*not totally safe: may instantiate unknowns that appear also in other subgoals*)
361  val safe_asm_full_simp_tac = generic_simp_tac true (true, true, true);
```

`generic_simp_tac safe mode` (simplifier.ML:318–329): the `safe`
boolean picks which *final solver list* is used to discharge the
subgoal after rewriting — `rev (if safe then solvers else
unsafe_solvers)` (line 323–324).  The mode triple `(true,true,true)`
is identical to `asm_full_simp_tac` (rewrite conclusion and
assumptions, use assumptions, mutual assumption simplification).
Crucially, the prover used for *conditional rewrite rule premises
during rewriting* is always the unsafe solver list (line 327:
`generic_rewrite_goal_tac mode (solve_all_tac unsafe_solvers)`);
only the terminal `solve_tac` differs.  So "safe" simp = same
rewriting, but the goal may only be *closed* by the safe solver.

HOL's solvers (`simpdata.ML`):

- `unsafe_solver_tac` (127–140): after stripping `simp_impliesI` by
  `match_tac`, `FIRST [resolve_tac (refl-thms @ prems), assume_tac,
  eresolve_tac FalseE] ORELSE (match_tac conjI THEN_ALL_NEW
  sol_tac)`.  Registered as solver `"HOL unsafe"` (142).
- `safe_solver_tac` (145–149): matching only — `match_tac
  (reflexive/TrueI/refl/prems)`, `eq_assume_tac`, `ematch_tac
  FalseE`.  Comment: "No premature instantiation of variables during
  simplification".  Registered `"HOL safe"` (151).
- Installed into `HOL_basic_ss` at 194–202 via
  `set_safe_solver`/`set_unsafe_solver`; theory simpset reset to
  `HOL_basic_ss` at `HOL.thy:1266–1269`, then the big `lemmas [simp]`
  block `HOL.thy:1416–1445`, `[cong] = imp_cong simp_implies_cong`
  (1447), `[split] = if_split` (1448), `HOL_ss` snapshot (1450).

## 4. The tactics

### 4.1 clarsimp_tac (clasimp.ML:119–121)

```
fun clarsimp_tac ctxt =
  Simplifier.safe_asm_full_simp_tac ctxt THEN_ALL_NEW
  Classical.clarify_tac (addSss ctxt);
```

Safe-solver full simp on the subgoal, then `clarify_tac` **with the
safe simp wrapper installed** on every resulting subgoal
(`THEN_ALL_NEW`).  Since `clarify_step_tac` applies `appSWrappers`
(classical.ML:616–623), each clarify step is
`base_clarify_step ORELSE' (CHANGED o safe_asm_full_simp)`.
`clarify_tac ctxt = SELECT_GOAL (REPEAT_DETERM (clarify_step_tac
ctxt 1))` (classical.ML:625).  The method wraps it in `CHANGED_PROP`
(clasimp.ML:230–231).

### 4.2 nodup_depth_tac (clasimp.ML:126–143)

```
(* a variant of depth_tac that avoids interference of the simplifier
   with dup_step_tac when they are combined by auto_tac *)
local
fun slow_step_tac' ctxt =
  Classical.appWrappers ctxt
    (Classical.instp_step_tac ctxt APPEND' Classical.unsafe_step_tac ctxt);
in
fun nodup_depth_tac ctxt m i st =
  SELECT_GOAL
    (Classical.safe_steps_tac ctxt 1 THEN_ELSE
      (DEPTH_SOLVE (nodup_depth_tac ctxt m 1),
        Classical.inst0_step_tac ctxt 1 APPEND COND (K (m = 0)) no_tac
          (slow_step_tac' ctxt 1 THEN DEPTH_SOLVE (nodup_depth_tac ctxt (m - 1) 1)))) i st;
end;
```

Identical shape to `Classical.depth_tac` (classical.ML:711–720)
except its `slow_step_tac'` uses `unsafe_step_tac` (plain unsafe
rules) where `depth_tac` uses `dup_step_tac` (duplicating versions
from `dup_netpair`, classical.ML:708–713).  I.e. **no premise
duplication** — the comment says this avoids simplifier
interference.  Depth `m` counts only unsafe (`slow_step'`) steps;
safe steps and `inst0` closures are free.  It solves the selected
subgoal completely or fails (`DEPTH_SOLVE` on every success path;
`inst0_step_tac` = assumption / contradiction / 0-premise safe rule
by *resolution*, classical.ML:633–636, closes the goal possibly
instantiating unknowns elsewhere).

Supporting definitions (classical.ML):

- `safe_steps_tac` (591–592): `REPEAT_DETERM1 o (fn i => COND
  (has_fewer_prems i) no_tac (safe_step_tac ctxt i))` — at least one
  safe step, deterministic.
- `safe_tac` (595): `REPEAT_DETERM1 (FIRSTGOAL (safe_steps_tac ctxt))`.
- `inst0_step_tac` (633–636), `instp_step_tac` (639–640),
  `inst_step_tac` (643), `unsafe_step_tac` (645–646).
- `step_tac` (649–650): `safe_tac ORELSE appWrappers (inst_step
  ORELSE' unsafe_step)`.
- `slow_step_tac` (654–655): same but `inst_step APPEND' unsafe_step`.

### 4.3 mk_auto_tac / auto_tac (clasimp.ML:145–161)

```
(*Designed to be idempotent, except if Blast.depth_tac instantiates variables
  in some of the subgoals*)
fun mk_auto_tac ctxt m n =
  let
    val main_tac =
      Blast.depth_tac ctxt m  (* fast but can't use wrappers *)
      ORELSE'
      (CHANGED o nodup_depth_tac (addss ctxt) n);  (* slower but more general *)
  in
    PARALLEL_ALLGOALS (Simplifier.asm_full_simp_tac ctxt) THEN
    TRY (Classical.safe_tac ctxt) THEN
    REPEAT_DETERM (FIRSTGOAL main_tac) THEN
    TRY (Classical.safe_tac (addSss ctxt)) THEN
    Simplifier.prune_params_tac ctxt
  end;

fun auto_tac ctxt = mk_auto_tac ctxt 4 2;
```

Step by step:

1. `PARALLEL_ALLGOALS (asm_full_simp_tac ctxt)` — asm-full simp on
   *every* subgoal.  `PARALLEL_ALLGOALS` is defined in upstream
   `Pure/goal.ML` as `PARALLEL_GOALS (ALLGOALS tac)`; the vendored
   `Pure/goal.ML` is a trimmed subset and **does not contain the
   definition**, so treat it semantically as `ALLGOALS tac` (with
   parallel evaluation of independent goals).  Per-goal failure
   semantics of `asm_full_simp_tac` on an unchanged goal therefore
   cannot be verified from the vendored subset; what is verifiable
   is that auto's first phase is asm-full simp over all subgoals,
   and overall progress is enforced only by the method-level
   `CHANGED_PROP` (see below).
2. `TRY (Classical.safe_tac ctxt)` — plain claset safe pass, **no
   simp wrapper**, over all subgoals (FIRSTGOAL-repeat inside
   `safe_tac`).
3. `REPEAT_DETERM (FIRSTGOAL main_tac)` — repeatedly find the first
   subgoal on which `main_tac` succeeds and commit to its first
   result (`REPEAT_DETERM` discards alternatives).  `main_tac` =
   `Blast.depth_tac ctxt m` (default m=4; a *single* fixed-depth
   blast run, **not** the iteratively-deepened `blast_tac`)
   `ORELSE'` `CHANGED o nodup_depth_tac (addss ctxt) n` (default
   n=2; unsafe-wrapper simp inside the search, no duplication).
   Both branches solve a whole subgoal when they succeed, so the
   loop peels off provable subgoals one at a time, left to right.
4. `TRY (Classical.safe_tac (addSss ctxt))` — final safe pass with
   the **safe** simp wrapper (`safe_step ORELSE' CHANGED o
   safe_asm_full_simp`).
5. `Simplifier.prune_params_tac ctxt` — rewrites with
   `triv_forall_equality` to drop redundant goal parameters
   (simplifier.ML:363–364).

Composition operators: exactly `THEN`, `TRY`, `REPEAT_DETERM`,
`FIRSTGOAL`, `ORELSE'`, `CHANGED`, `APPEND`/`APPEND'` (inside the
search), `THEN_ELSE`/`DEPTH_SOLVE`/`COND` (inside
`nodup_depth_tac`).  There is no `DETERM` at auto's top level;
determinism comes from `REPEAT_DETERM`, `TRY`, and
`safe_tac`'s `REPEAT_DETERM1`.

Method wrapping (clasimp.ML:217–221): `(auto)` =
`SIMPLE_METHOD o CHANGED_PROP o auto_tac`; `(auto m n)` =
`SIMPLE_METHOD (CHANGED_PROP (mk_auto_tac ctxt m n))`.  So the
*method* fails if the proof state is unchanged, but `auto_tac`
itself is a always-succeeding-ish composite of `TRY`s.

### 4.4 force_tac (clasimp.ML:166–173)

```
(* aimed to solve the given subgoal totally, using whatever tools possible *)
fun force_tac ctxt =
  let val ctxt' = addss ctxt in
    SELECT_GOAL
     (Classical.clarify_tac ctxt' 1 THEN
      IF_UNSOLVED (Simplifier.asm_full_simp_tac ctxt 1) THEN
      ALLGOALS (Classical.first_best_tac ctxt'))
  end;
```

- `clarify_tac ctxt'`: since `addss` installs an *unsafe* wrapper
  and clarify consults only safe wrappers, **the simp wrapper is
  inert during the clarify phase** (passing `ctxt'` there changes
  nothing vs `ctxt`).
- `IF_UNSOLVED` = `COND Thm.no_prems all_tac` (search.ML:55): skip
  the simp if clarify already closed the goal.  The simp uses the
  *plain* context.
- `ALLGOALS (first_best_tac ctxt')`: every remaining subgoal must be
  solved.  `first_best_tac` (classical.ML:670–672) =
  `Object_Logic.atomize_prems_tac THEN' SELECT_GOAL (BEST_FIRST
  (Thm.no_prems, Data.sizef) (FIRSTGOAL (step_tac ctxt)))` — best-
  first search whose step is `step_tac` on the first goal, and here
  `step_tac`'s unsafe part carries the `addss` wrapper
  (`(CHANGED o asm_full_simp) APPEND' (inst_step ORELSE'
  unsafe_step)`).
- The whole thing is under `SELECT_GOAL`, so force closes the
  selected subgoal completely or fails.

### 4.5 fast_force / slowsimp / bestsimp (clasimp.ML:176–180)

```
val fast_force_tac = Classical.fast_tac o addss;
val slow_simp_tac = Classical.slow_tac o addss;
val best_simp_tac = Classical.best_tac o addss;
```

with (classical.ML:661–680): `fast_tac` = atomize prems `THEN'`
`SELECT_GOAL (DEPTH_SOLVE (step_tac 1))`; `slow_tac` = same with
`slow_step_tac`; `best_tac` = `SELECT_GOAL (BEST_FIRST (no_prems,
sizef) (step_tac 1))`.  All three fail unless they solve the
subgoal; all three see the simp alternative through `appWrappers`
inside `step_tac`/`slow_step_tac`.

## 5. The [iff] machinery (clasimp.ML:57–114)

Attribute targets (clasimp.ML:61–79):

```
val safe_atts =
 {intro = Classical.safe_intro NONE,      (* Bires.intro_bang_kind *)
  elim = Classical.safe_elim NONE,
  dest = Classical.safe_dest NONE};
val unsafe_atts =
 {intro = Classical.unsafe_intro NONE, ...};   (* Bires.intro_kind etc. *)
val pure_atts =
 {intro = Context_Rules.intro_query NONE, ...}; (* Pure ? rules only *)
val del_atts =
 {intro = Classical.rule_del, elim = Classical.rule_del, dest = Classical.rule_del};
```

(`safe_intro` etc.: classical.ML:744–749; `NONE` = no explicit
weight.)

The decision tree (clasimp.ML:81–98), quoted in full because it is
the crux:

```
(*Takes (possibly conditional) theorems of the form A<->B to
        the Safe Intr     rule B==>A and
        the Safe Destruct rule A==>B.
  Also ~A goes to the Safe Elim rule A ==> ?R
  Failing other cases, A is added as a Safe Intr rule*)

fun iff_decl safe unsafe =
  Thm.declaration_attribute (fn th => fn context =>
    let
      val n = Thm.nprems_of th;
      val {intro, elim, dest} = if n = 0 then safe else unsafe;
      val zero_rotate = zero_var_indexes o rotate_prems n;
      val decls =
        [(intro, zero_rotate (th RS Data.iffD2)),
         (dest, zero_rotate (th RS Data.iffD1))]
        handle THM _ => [(elim, zero_rotate (th RS Data.notE))]
        handle THM _ => [(intro, th)];
    in fold (uncurry Thm.attribute_declaration) decls context end);
```

Semantics, precisely:

- Safety is decided **solely by `nprems_of th`**: `n = 0` →
  safe kinds; `n > 0` (conditional) → unsafe kinds.  This applies
  to *all* branches, so a conditional `¬A` becomes an **unsafe**
  elim, and a conditional plain `A` an **unsafe** intro.
- Branch 1 (iff): `th RS iffD2` gives `B ⟹ A` (after the theorem's
  own premises), `th RS iffD1` gives `A ⟹ B`.  `rotate_prems n`
  moves the theorem's `n` original premises *behind* the new major
  premise, so the rule matches on `B` (resp. `A`) first;
  `zero_var_indexes` normalizes.  Declared as (intro, dest) pair —
  the dest declaration makes it elim-usable via `make_elim`
  (Bires `dest` kind, bires.ML:117–121).
- Branch 2 (`¬A`, i.e. `RS iffD2/iffD1` raised `THM`): `th RS notE`
  gives `A ⟹ R`, declared elim.
- Branch 3 (plain `A`): declared intro as-is.
- SML `handle` chaining: the two handlers guard the *entire* list
  expression before them, in order, exactly as the comment says.

The public attributes (clasimp.ML:102–112):

```
val iff_add =
  Thm.declaration_attribute (fn th =>
    Thm.attribute_declaration (iff_decl safe_atts unsafe_atts) th #>
    Thm.attribute_declaration Simplifier.simp_add th);

val iff_add_pure = iff_decl pure_atts pure_atts;

val iff_del =
  Thm.declaration_attribute (fn th =>
    Thm.attribute_declaration (iff_decl del_atts del_atts) th #>
    Thm.attribute_declaration Simplifier.simp_del th);
```

Key facts:

- **The simpset addition happens in every case**, including the
  `¬A` and plain-`A` fallbacks (HOL's `mksimps`, simpdata.ML:125 +
  mk_eq, turns `¬A` into `A = False` and `A` into `A = True`).
- "Atomic": `iff_add` is a *single* declaration attribute that
  performs the claset declarations and then `simp_add` in one
  attribute application — one `[iff]` tag updates both databases;
  there is no separate transaction machinery beyond that.
- `iff_del` runs the same decision tree but with every slot mapped
  to `Classical.rule_del` (which deletes a rule from all claset
  classifications, classical.ML:751ff) and then `simp_del`.
- `iff_add_pure` (`[iff?]`) uses `Context_Rules.*_query` for both the
  safe and unsafe role — i.e. it only touches the Isabelle/Pure rule
  context (used by the `rule` method), and **does not touch the
  simpset** at all.
- There are **no `iff'`/"non-safe iff" variants** in this file; the
  only three attributes are `iff_add`, `iff_add_pure`, `iff_del`.

Attribute syntax (clasimp.ML:188–195): `iff` = `del ⇒ iff_del` |
`[add] ? ⇒ iff_add_pure` | `[add] ⇒ iff_add`.

## 6. Modifier syntax (cong/split/iff/simp/cla)

`clasimp.ML:200–209`:

```
val iff_modifiers =
 [iff_token -- Scan.option Args.add -- Args.colon >> K (Method.modifier iff_add ...),
  iff_token -- Scan.option Args.add -- Args.query_colon >> K (Method.modifier iff_add_pure ...),
  iff_token -- Args.del -- Args.colon >> K (Method.modifier iff_del ...)];

val clasimp_modifiers =
  Simplifier.simp_modifiers @ Splitter.split_modifiers @
  Classical.cla_modifiers @ iff_modifiers;
```

- `Simplifier.simp_modifiers` (simplifier.ML:461–468): `simp:`,
  `simp add:`, `simp del:`, `simp flip:`, `simp only:` (with
  `clear_simpset` init) plus `cong_modifiers` (456–459: `cong:`,
  `cong add:`, `cong del:`).
- `Splitter.split_modifiers` (splitter.ML:481–484): `split:`,
  `split!:`, `split del:`.
- `Classical.cla_modifiers` (classical.ML:809–816): `dest!:`,
  `dest:`, `elim!:`, `elim:`, `intro!:`, `intro:`, `del:`.
- `iff_modifiers`: `iff [add]:`, `iff [add]?:`, `iff del:`.

Method registration (clasimp.ML:214–231): `fastforce`, `slowsimp`,
`bestsimp`, `force` via `clasimp_method'` (=`SIMPLE_METHOD' o tac`
after `Method.sections clasimp_modifiers`); `auto` via
`auto_method` with optional `nat nat`; `clarsimp` =
`clasimp_method' (CHANGED_PROP oo clarsimp_tac)`.

This matches the documented rail grammar `clasimpmod`
(Generic.thy:1503–1507): `simp (|add|del|only)`, `cong (|add|del)`,
`split (|!|del)`, `iff (((|add) ?) | del)`, and the clamod
intro/elim/dest forms.

## 7. Blast in auto; behavior when blast fails

`Blast.depth_tac` (blast.ML:1279–1282) = `SELECT_GOAL (atomize_prems
THEN raw_blast ... lim)`.  `raw_blast` (1254–1277) ends with

```
handle PROVE => Seq.empty
  | TRANS s => (cond_tracing ... "Blast: " ^ s; Seq.empty);
```

so untranslatable goals (higher-order features etc., exception
`TRANS`) and failed searches both yield the empty result sequence —
an ordinary tactic *failure*, upon which auto's `ORELSE'` falls
through to `nodup_depth_tac`.  Reconstruction failures backtrack
internally (1264–1272, including `handle TERM _`).  By contrast
`blast_tac` (1284–1292) wraps `raw_blast` in `DEEPEN (1, lim)` with
configurable `depth_limit` (default 20 per Generic.thy:1536–1538) —
**auto does not use this**; it calls the single-depth `depth_tac`
with `m` (default 4) directly.  Structural availability: `Blast` is
a required functor argument (§1); clasimp has no conditional
compilation for its absence.

## 8. Documented user-facing semantics (Generic.thy)

- `[iff]` (1423–1432): "declares logical equivalences to the
  Simplifier and the Classical reasoner at the same time.
  Non-conditional rules result in a safe introduction and
  elimination pair; conditional ones are considered unsafe.  Rules
  with negative conclusion are automatically inverted (using
  ¬-elimination internally).  The ‘?’ version … declares rules to
  the Isabelle/Pure context only, and omits the Simplifier
  declaration."
- `auto` (1544–1554): "combines classical reasoning with
  simplification … intended for situations where there are a lot of
  mostly trivial subgoals; it proves all the easy ones, leaving the
  ones it cannot prove. … The optional depth arguments in (auto m n)
  refer to its builtin classical reasoning procedures: m (default 4)
  is for blast, which is tried first, and n (default 2) is for a
  slower but more general alternative that also takes wrappers into
  account."
- `force` (1556–1559): "intended to prove the first subgoal
  completely, using many fancy proof tools and performing a rather
  exhaustive search.  As a result, proof attempts may take rather
  long or diverge easily."
- `fastforce`/`slowsimp`/`bestsimp` (1575–1579): "like fast, slow,
  best, respectively, but use the Simplifier as additional wrapper.
  The name fastforce reflects the behaviour of this popular method
  better without requiring an understanding of its implementation."
- `clarsimp` (1624–1626): "acts like clarify, but also does
  simplification.  Note that if the Simplifier context includes a
  splitter for the premises, the subgoal may still be split."
- blast's limitation note (1518–1519): "It does not use the
  classical wrapper tacticals, such as the integration with the
  Simplifier of fastforce."

## 9. Corrections / refinements to the prior plan summary

The master-plan summary is broadly right; precise deltas:

1. **auto step 1 is `asm_full_simp_tac`** (assumptions used *and*
   rewritten), not merely "full-simp"; and it runs via
   `PARALLEL_ALLGOALS`.
2. Steps 2 and 4 are wrapped in `TRY`; step 4's claset is
   `addSss ctxt` (safe wrapper = `safe_asm_full_simp`), and there is
   a **fifth step**: `prune_params_tac` (drop redundant parameters).
   Also the *method* adds `CHANGED_PROP` on top.
3. auto's blast is `Blast.depth_tac` at fixed depth m=4 — a single
   run, no iterative deepening; the fallback branch is
   `CHANGED o nodup_depth_tac (addss ctxt) 2`, where the depth-2
   bound counts only unsafe steps and the simp wrapper is the
   *unsafe* (`APPEND'`-before) one.
4. **force**: the `addss` context passed to `clarify_tac` is inert
   (clarify reads only safe wrappers); the interior simp step is
   guarded by `IF_UNSOLVED` and uses the plain context; the search
   phase is `first_best_tac` (best-first over `FIRSTGOAL step_tac`),
   not plain `best_tac`; "must close" holds — `ALLGOALS
   first_best_tac` under `SELECT_GOAL`.
5. **clarsimp**: as summarized (`safe_asm_full_simp_tac THEN_ALL_NEW
   clarify_tac (addSss ctxt)`); here the safe wrapper *is* active
   because clarify consults safe wrappers.
6. **[iff]**: "¬A → safe elim" is only the unconditional case; the
   safe/unsafe choice is by `nprems_of = 0` and applies uniformly to
   all three branches (conditional ¬A → unsafe elim; conditional
   plain A → unsafe intro).  The simpset addition happens for every
   branch, not just equivalences.  The iff rules feed the claset as
   an (intro, **dest**) pair — dest, not elim, though dest is
   elim-resolved via `make_elim`.  `rotate_prems n` puts the new
   major premise first.  "Atomic" = one declaration attribute doing
   claset-then-simpset; `[iff del]` symmetrically removes from both.
7. `safe_asm_full_simp_tac` lives in `Pure/simplifier.ML:361`; it
   differs from `asm_full_simp_tac` **only** in using the safe
   solver list to close goals (HOL: matching against
   refl/TrueI/prems, `eq_assume_tac`, `ematch FalseE` — no
   resolution, no instantiation of unknowns).
8. There is no `addXss` and no non-safe `iff'` attribute variant in
   this snapshot.
