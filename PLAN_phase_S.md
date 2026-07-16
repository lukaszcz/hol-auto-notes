# Phase S implementation plan — simplifier upgrades (`src/simp/src/`, in place)

Date: 2026-07-16.  Refines `PLAN.md` §5.  Branch `isabelle-tactics`.

All Isabelle citations resolve against `.agent-files/sources/` (commit
`f7e02b7e1f31`); HOL4 citations against this worktree.  Every
infrastructure claim below was verified by reading the cited source;
the line-level analysis lives in four research reports written for this
phase (all under `.agent-files/research/`, treated as verified):

- `phaseS-isabelle-splitter.md` — `Provers/splitter.ML` algorithm + HOL4 mapping
- `phaseS-isabelle-simploop.md` — subgoaler/solver/looper wiring, `mut_impc`
- `phaseS-simplib-compat.md` — repo-wide compatibility survey
- `phaseS-hol4-splitting-idioms.md` — existing HOL4 split theorems and idioms

Governing constraint (PLAN §5, D5): **all defaults preserve current
behavior**; the full-distribution build is the regression gate for every
step.

## 0. Owner decisions taken for this phase (2026-07-16)

Asked and decided one-by-one, extending the §2 record of `PLAN.md`
(recorded there by T12):

| # | Decision |
|---|---|
| D14 | **Loop hook surface**: all existing simpLib tactic entry points (`SIMP_TAC`, `ASM_SIMP_TAC`, the `FULL_SIMP_TAC` family, `global_simp_tac` — hence bossLib `simp`/`fs`/`gvs`) honor loopers and final solvers stored in the simpset.  Default lists are empty, so distribution behavior is unchanged until a simpset carries them.  `SIMP_CONV`/`SIMP_RULE`/`SIMP_PROVE` never run loopers or final solvers (conversions cannot split goals — the same layering as Isabelle, where `loop_tacs` is never read by the rewriting core, `phaseS-isabelle-simploop.md` §4.c). |
| D15 | **Solver architecture**: faithful single-type port.  One named, conversion-level solver type used at both seams — side-condition residues inside the engine (always the *unsafe* list, as in Isabelle even for safe variants) and the residual goal after rewriting at the tactic layer (safe or unsafe list by mode).  Two named lists (safe/unsafe) on the simpset; separately settable *subgoaler* whose default is the current recursive traversal, so the default pipeline is extensionally today's `EQT_ELIM ∘ trav`.  Requires a `context_thms` accumulation in the traversal state (the analogue of Isabelle's `prems`, `raw_simplifier.ML:279,490–494`).  A `mk_tactic_solver` adapter lifts tactics.  Reducer/`REDUCER` interfaces stay untouched. |
| D16 | **Safe-simp mode**: an invocation-mode record on a generic entry point (`simptac_config` precedent), not a simpset transformer and no `SAFE_*` name family yet.  Verified semantics ported exactly: the safe flag only selects the safe final-solver list; side-condition proving stays unsafe and loopers still run (`simplifier.ML:318–329`). |
| D17 | **`mut_impc` realization** (revises the "in-engine" wording of PLAN §5.7): tactic-level, via the `global_simp_tac` machinery — add `mut_impc`-style change counting with provably-fixed-tail skipping, a conclusion-in-fixpoint flag, and an implication-rebuild flag; existing entries (`gvs`/`gs`/…) keep their exact current semantics (new behavior is opt-in by config).  In-engine `mut_impc` is explicitly out of scope, recorded as a benchmark-gated revisit at Phase 8: if Isabelle-translated goals show gaps attributable to in-engine mutuality (inside `SIMP_RULE`, under binders, nested implications), an engine port becomes its own planned item. |
| D18 | **Splitter congruence policy**: keep HOL4's strong congruences.  `COND_CONG` stays; case branches keep being descended as today; `split_ss` adds only the splitter looper and the `cases_simp` analogue `⊢ (b ==> t) /\ (~b ==> t) <=> t` to collapse trivial splits.  Divergence from Isabelle's weak-cong pairing (`if_weak_cong [cong]`, `HOL.thy:1462–1465`) is deliberate (strength-first) and documented; the Phase 8 benchmarks arbitrate, retuning is a recorded option. |
| D19 | **`[split]` placement**: the whole `[split]` machinery lands in `src/simp` — `splitLib`, the ThmSetData settype `"split"` with its `[split]` attribute, the `Split` marker, the TypeBase-driven per-datatype split-theorem cache, and `split_ss`.  No default simpset consumes any of it in Phase S. |
| D20 | **Names**: module `splitLib` (own module in `src/simp/src`, not folded into simpLib); `SPLIT_TAC`, `split_ss`, marker `Split th`, attribute/settype `split`.  All collision-checked 2026-07-16 (only shadow: a script-local `SPLIT_TAC` in `examples/machine-code/hoare-triple/set_sepScript.sml:60`, unaffected). |

## 1. Scope

Phase S delivers, in `src/simp/src` (plus one additive marker constant in
`src/marker`):

1. Engine hooks in `Traverse`: context-theorem accumulation, solver
   stacks, settable subgoaler — defaults extensionally identical to today.
2. Configurable limits: per-simpset side-condition depth (`stack_limit`
   override) and settable term order for permutative rewriting.
3. Tactic-layer loop: loopers + final solvers + safe mode, honored by all
   existing simp tactics (D14).
4. `splitLib`: the Isabelle splitter (conclusion and assumption splits),
   `[split]` set + attribute, `Split` marker, TypeBase case-split cache,
   `split_ss`, `SPLIT_TAC`.
5. Congruence procedures exposable through fragments (`congproc_ss`).
6. `mut_impc`-parity upgrade of the `global_simp_tac` engine (D17).
7. Selftests (including splitter cases ported from Isabelle's
   documentation and an `RW_TAC` if-splitting parity suite), Docfiles,
   build-gate runs.

Explicitly out of scope: enabling any of it in `srw_ss`/`bool_ss` or any
distribution simpset (promotion, PLAN §11); in-engine `mut_impc` (D17);
`split!`/`add_split_bang` (needs Phase 1's `SAFE_TAC`; the looper API
accommodates it — §6.6); any change to `RW_TAC`/`SRW_TAC` (parity is a
benchmark obligation, not a code change); Isabelle's bottom-up/skeleton
optimizations (not in PLAN §5's item list; D5 allows them only where
behavior-preserving — separate work if ever).

## 2. Files, layering, compatibility rules

```
src/marker/markerScript.sml     -- + Split marker constant (additive)
src/marker/markerLib.{sig,sml}  -- + mk/dest support
src/simp/src/
  Traverse.{sig,sml}            -- context_thms, solver/subgoaler seam, td fields
  Cond_rewr.{sig,sml}           -- overridable stack_limit / term order refs
  splitLib.{sig,sml}            -- NEW: splitter core, [split] set, TypeBase cache
  simpLib.{sig,sml}             -- simpset fields, setters, loop, markers, ssfrags
  congLib.sml                   -- mechanical update to new traverse_data fields
  selftest.sml                  -- extended
help/Docfiles/                  -- new entries (§9)
```

Module DAG: `splitLib` sits **below** `simpLib` (it needs only
`Conv`/`Drule`/`TypeBase`/`ThmSetData`/`markerLib`, not simpsets), so
`simpLib.process_tags` can consume the `Split` marker and export
`add_split`/`split_ss` without a circularity.  Build order permits this:
`src/simp/src` builds after `src/1` (ThmSetData/ThmAttribute/TypeBase)
and `src/marker` (`tools/sequences/base-hol:7,14`); all datatypes are
defined later, so case splits flow through TypeBase lookups at use time.

Compatibility rules (from `phaseS-simplib-compat.md`, binding for every
task):

1. `ssfrag` and `simpset` are abstract (`simpLib.sig:63,127`) — internal
   fields are free.  The public `SSFRAG` record (7 fields) is **frozen**:
   88 record-literal call sites in-tree.  Extension route = internal
   `SSFRAG_CON` fields + additive smart constructors, the exact precedent
   of `relsimps` (`simpLib.sml:94–113`).
2. `simptac_config` is **frozen** (≈10 record-literal sites outside
   simpLib: bossLib, arithmeticScript, pred_set scripts, selftest).  New
   flags go in a new extended record (§7).
3. `Traverse.REDUCER` and the reducer `apply`-argument record are
   **frozen** (13 constructor sites, 7 exhaustive apply-arg patterns
   tree-wide).  New engine data threads through `traverse_data` (record
   type; the only external construction site is `congLib.sml:273–277`,
   fixed in T2) and through the *behavior* of the already-passed
   `solver`/`conv` closures.
4. `Cond_rewr.stack_limit : int ref` stays exported with default 4 (4
   setter sites under `examples/`, Manual references); the simpset field
   overrides it dynamically (§3.3).
5. `simpLib.remove_simps`/`simpLib.exclude_ssfrags` names/types are
   pinned by `tools/parsing` attribute support.
6. New simpset fields must be preserved by the history-rebuild paths
   (`remove_ssfrags`/`exclude_ssfrags` → `build_from_history`,
   `simpLib.sml:676–734`), exactly as `limit`/`excluded` are today.

## 3. Engine changes (`Traverse`, `Cond_rewr`)

### 3.1 Context-theorem accumulation

`TSTATE` (`Traverse.sml:57–62`) gains `context_thms : thm list`;
`add_context` (`Traverse.sml:79–108`) appends the incoming `thms` (the
same list it already distributes to reducers — goal assumptions and
congruence-rule assumptions).  This is Isabelle's `prems` field
(`raw_simplifier.ML:279`, fed at `1332–1333`), the prerequisite for
solvers that reason from context (`phaseS-isabelle-simploop.md` §4.a).
Cost: one cons list, no copying; invisible to all existing code.

### 3.2 Solver stacks and subgoaler

New public types in `Traverse`:

```sml
type simp_prover_ctxt =
     {stack        : term list,          (* side-condition stack, as today *)
      context_thms : thm list,           (* §3.1 *)
      recurse      : term -> thm}        (* |- c = c' : recursive equality
                                            simplification with current
                                            context, stack pre-applied *)
type ssolver   = {name : string, solve : simp_prover_ctxt -> term -> thm}
                                         (* solve proves the term: |- c *)
type subgoaler = simp_prover_ctxt -> term -> thm     (* |- c = c' *)
```

`traverse_data` (`Traverse.sml:302–306`) gains four fields:

```sml
{ ..., subgoaler : subgoaler option,       (* NONE = #recurse *)
       solvers   : ssolver list,           (* engine seam: unsafe list *)
       cond_depth: int option,             (* §3.3; NONE = !stack_limit *)
       term_ord  : (term * term -> order) option }   (* §3.4 *)
```

(`congLib.sml:273–277` updated to pass the four `NONE`/`[]` defaults.)

`ctxt_solver` (`Traverse.sml:241–246`) is refactored to the faithful
pipeline (semantics of `solve_all_tac`, `simplifier.ML:312–316`, adapted
to the conversion world per `phaseS-isabelle-simploop.md` §4.b):

```
solve stack c =
  let eq  = subgoaler {stack, context_thms, recurse} c   (* |- c = c' *)
      c'  = rhs eq
  in  if c' = T then EQT_ELIM eq
      else case first (fn s => total (#solve s pctxt) c') solvers of
             SOME th' => EQ_MP (SYM eq) th'              (* |- c *)
           | NONE => fail
```

with the existing limit save/restore on failure (`Traverse.sml:242–245`)
preserved around the whole pipeline.  With `subgoaler = NONE` and
`solvers = []` this is literally today's `EQT_ELIM (trav …)` — the
default-equivalence selftest (T1) proves it on golden cases.  The
engine seam always receives the **unsafe** list (D16/D15;
`simplifier.ML:327` — even Isabelle's safe variants prove side
conditions unsafely).  Solver exceptions other than `HOL_ERR` propagate
(as reducer exceptions do today).

### 3.3 Per-simpset side-condition depth

`COND_REWR_CONV` keeps reading `!stack_limit` (`Cond_rewr.sml:153`).
`TRAVERSE` dynamically binds it: when `cond_depth = SOME n`, the
traversal body runs under an exception-safe save/set/restore of
`Cond_rewr.stack_limit` (the `Lib.with_flag` idiom already used for
`track_rewrites`, `simpLib.sml:1000–1005`).  Nesting is well-defined
(inner `TRAVERSE` re-binds and restores); `NONE` leaves the ref alone,
so the `examples/` setters keep working.  simpLib exposes
`set_cond_depth : int -> simpset -> simpset` (§4.2).  Defaults: every
existing entry point keeps 4; the Phase 3 layer simpsets set 40
(Isabelle's code default, `raw_simplifier.ML:433`) — per PLAN §11
"Numeric defaults".

### 3.4 Settable term order

Same mechanism: `Cond_rewr` gains
`val term_ord : (term * term -> order) ref` initialized to
`ac_term_ord` (`Cond_rewr.sml:91`), read at the permutative-rule guard
(`Cond_rewr.sml:163`); `TRAVERSE` binds it from the `term_ord` field;
simpLib exposes `set_term_ord`.  Bounded (`Once`/`Ntimes`) rewrites keep
bypassing the guard (`Cond_rewr.sml:163–168` `bounded` flag).  The
default order is unchanged (its comment already warns behavior depends
on it, `Cond_rewr.sml:16–30`).

## 4. simpset/ssfrag surface (`simpLib`)

### 4.1 New internal simpset fields

```sml
SS of { ... (* existing seven fields *),
        loopers        : (string * (simpset -> tactic)) list,
        unsafe_solvers : Traverse.ssolver list,
        safe_solvers   : Traverse.ssolver list,
        subgoaler      : Traverse.subgoaler option,
        cond_depth     : int option,
        term_ord       : (term * term -> order) option,
        excl_loopers   : string Binaryset.set }  (* per-invocation Del, §6.5 *)
```

Loopers are a named alist with Isabelle's semantics
(`raw_simplifier.ML:861–875`): `add_looper` updates-or-adds by name,
`del_looper` removes by name (warning if absent), `set_looper` replaces
the list with a singleton; application order = registration order
(earliest first — `FIRST'` over `rev`, `raw_simplifier.ML:419–420`).
The looper receives the invocation simpset (the analogue of Isabelle's
looper `ctxt` argument, needed by `split!` later).

### 4.2 Setters (all `X -> simpset -> simpset`, names checked free)

`add_looper`, `del_looper`, `set_looper`; `add_unsafe_solver`,
`add_safe_solver`, `set_unsafe_solvers`, `set_safe_solvers`,
`remove_solver (* by name, both lists *)`; `set_subgoaler`,
`set_cond_depth`, `set_term_ord`; plus
`mk_tactic_solver : string * tactic -> Traverse.ssolver` — the adapter:
`TAC_PROOF((map concl context_thms? [], c), tac)` is wrong for
hypotheses, so it proves `([], c)` after `PROVE_HYP`-threading the
context: concretely, run the tactic on the goal
`(map concl context_thms, c)` via `TAC_PROOF` and discharge with
`PROVE_HYP` over `context_thms` — the result `|- c` may retain hyps that
are hyps of context theorems, which the engine's `MP` plumbing already
tolerates (context assumptions arrive as `[a] |- a`,
`phaseS-isabelle-simploop.md` §4.a).

### 4.3 Fragment support (SSFRAG public record frozen)

Internal `SSFRAG_CON` gains `loopers`, `unsafe_solvers`, `safe_solvers`,
`congprocs` fields (empty in the public `SSFRAG` constructor and all
existing smart constructors).  New additive constructors:

```sml
val looper_ss      : string * (simpset -> tactic) -> ssfrag
val solver_ss      : Traverse.ssolver -> ssfrag          (* unsafe list *)
val safe_solver_ss : Traverse.ssolver -> ssfrag
val congproc_ss    : {name : string, relation : term,
                      proc : Opening.congproc} -> ssfrag
```

`congproc_ss` closes the "congprocs not exposable through SSFRAG" gap
(PLAN §1.2 item 2): the fragment's congprocs are merged into the
simpset's travrules at `++` exactly where theorem congs are converted
today (`simpLib.sml:669–671` `mk_travrules`), keyed to the given
relation.  Names allow future removal; Phase S provides addition only
(removal of congprocs is not needed by any planned phase and the
travrules representation has no name index — recorded as a
non-requirement rather than half-built).

`++` merges the new fields (loopers: update-by-name, later fragment
wins; solvers: append, dedup by name; subgoaler/cond_depth/term_ord are
simpset-level only — fragments deliberately cannot set them, since they
are global strategy, not composable content).  History rebuild
(`build_from_history`) replays fragment-carried items via `ADDFRAG` and
explicitly preserves the six simpset-level fields the way `limit` and
`excluded` are preserved today (`simpLib.sml:692–734`) — compat rule 6.

### 4.4 Introspection and the `simp only:` analogue

`pp_simpset` prints looper and solver names (mirroring
`simplifier.ML:302–304`).  New

```sml
val clear_rules : simpset -> simpset
```

with exactly `clear_simpset`'s semantics (`raw_simplifier.ML:333–335,
408–410`; `phaseS-isabelle-simploop.md` §5): clears the net, congs,
dprocs, relsimps and **loopers**; keeps `mk_rewrs`, `term_ord`,
`subgoaler`, `cond_depth` and both **solver** lists.  (`SIMP_TAC
(clear_rules ss) [ths]` is then the `simp only:` idiom.)

## 5. Tactic layer

### 5.1 The loop

Port of `generic_simp_tac`/`simp_loop_tac` (`simplifier.ML:318–329`;
verified shape in `phaseS-isabelle-simploop.md` §4.c):

```sml
type simp_mode = {safe : bool}
val GEN_SIMP_TAC : simp_mode -> simpset -> thm list -> tactic

fun main ss g =
  (rewr_tac ss                       (* CONV_TAC-style; never fails *)
   THEN (solve_tac ORELSE TRY (loop_tac THEN_LT ALLGOALS (main ss)))) g
```

- `rewr_tac` = the existing conversion application
  (`markerLib.process_taclist_then` + `CONV_TAC o SIMP_CONV`,
  `simpLib.sml:893–896`), closing the goal when it rewrites to `T`.
- `solve_tac` = try each solver of the **safe list if `#safe mode`,
  unsafe list otherwise** (D16) on the residual conclusion, with
  `context_thms` = the same theorem list the engine invocation saw
  (ASSUMEd assumptions unless `NoAsms`, plus user theorems); a solver
  result `|- w'` with hyps ⊆ asl closes the goal via `ACCEPT_TAC`
  after `PROVE_HYP`/itlist `ADD_ASSUM` reconciliation.
- `loop_tac` = first applicable looper (registration order), each
  applied to the invocation simpset; a looper must fail (not raise
  `UNCHANGED`) when inapplicable so the `TRY` terminates the loop with
  the rewritten goal (Isabelle's exact contract,
  `simplifier.ML:328`).
- Loopers excluded per-invocation (`excl_loopers`, §6.5) are skipped.

With empty loopers and solvers, `main` β-reduces to today's
`CONV_TAC o SIMP_CONV` — the D14 zero-change guarantee, locked by
selftests running the existing suite through the new path.

Rewiring (D14): `ASM_SIMP_TAC ss = GEN_SIMP_TAC {safe=false} ss`;
`SIMP_TAC` prepends `NoAsms` as today; the `FULL_SIMP_TAC` family and
`global_simp_tac` get the loop through their final goal-directed step
(their per-assumption `SIMP_RULE` passes stay conversion-only —
assumption *splitting* arrives via the split-asm looper acting on the
goal, §6.3).  `SIMP_PROVE`/`SIMP_CONV`/`SIMP_RULE` unchanged.

### 5.2 Marker processing

`process_tags` (`simpLib.sml:834–857`) additionally recognizes:

- `Split th` → `add_split th` on the invocation simpset (§6.4);
- `Excl "name"` → in addition to its current net/dproc filtering, if
  `name` matches a looper or solver name it is removed for the
  invocation, and names of the form `split <thy$nm>` are added to
  `excl_loopers` for the splitter to honor (§6.5).  Both are additive:
  no existing `Excl` string can match (no loopers/solvers exist today).

The `Split` marker constant is added to `markerScript.sml` following the
`Cong` thm-carrying pattern (`markerLib.sml:77`), with
`markerLib.Split/destSplit`; re-exported as `simpLib.Split` beside
`Cong`/`AC`/`Excl` (`simpLib.sig:89–95`).

## 6. `splitLib` — the splitter

Port of `Provers/splitter.ML` per `phaseS-isabelle-splitter.md`
(sections cited as §n below refer to that report).

### 6.1 Split rules

Shape `⊢ P (c a1 … an) = rhs` with `P` a (universally quantified)
bool-valued variable — e.g. `list`'s
`⊢ f (list_CASE l n c) <=> (l = [] ==> f n) /\ !h t. l = h::t ==> f (c h t)`.
The assumption-variant is detected syntactically: rhs headed by
negation (`splitter.ML:58–64`).  Malformed rules raise a clear error at
registration (not at use).  Rules are indexed by the head constant `c`
with its type shape — the cmap of `splitter.ML:66–81`; keying includes
(const, asm-flag, type shape) to avoid wrongly merging type instances
(§5.4).

### 6.2 `SPLIT_CONV : thm list -> conv` (conclusion splits)

The `meta_iffD`/lift-theorem/`infer_instantiate` machinery collapses in
HOL4 (§4.1): a conversion *is* "prove `w = ?rhs`".  Algorithm for one
invocation (§4.2, §4.4):

1. **Scan** `w` for `Const`-headed applications matching a rule pattern
   first-order (`match_term` on `list_comb (c, take n args)` plus a
   type-instance check on `c`); reject partial applications; for a
   redex referencing bound variables, require the *innermost referenced
   binder's* body to be bool (`type_test`, `splitter.ML:163–168`) — the
   rule carried over verbatim.  Collect packs
   `(rule, #binders-to-enter, path)`.
2. **Order** packs by `(#binders, path length)` ascending — outermost
   first (`splitter.ML:279–281`).  Divergence (decided here,
   strength-first per §4.4): instead of Isabelle's
   first-pack-only-no-backtracking (whose rejected-pack-shadows-later-
   rules behavior is a known quirk), iterate packs in order until one
   applies.  Still exactly one split per successful invocation.
3. **Navigate** to the innermost referenced binder's body with
   `RATOR_CONV`/`RAND_CONV`/`ABS_CONV` composition (bound variables
   become genuine frees under `ABS_CONV`; escape is impossible by
   construction, §4.2).
4. **Apply**: build the context `P0 = λa. body[redex ↦ a]` replacing
   **all** alpha-equivalent occurrences (§5.7 — replacing only one can
   loop); instantiate the split theorem by `match_term` on the
   `c`-application (types) + `SPECL`-style instantiation of `P0` and the
   argument variables; beta-reduce both sides
   (`LAND_CONV BETA_CONV THENC RAND_CONV (TOP_DEPTH_CONV BETA_CONV)`).
   Never solve for `P` by higher-order matching (§4.1 note (i)).

Result `|- w = rhs'`; applied via `CONV_TAC` at the tactic layer.
Failure (no rule, no admissible pack, match failure) is a clean
`HOL_ERR` — the looper-termination contract (§6 of the report).

### 6.3 `SPLIT_ASM_TAC : thm list -> tactic` (assumption splits)

Per §4.3, without the contraposition dance: select the first assumption
containing a key constant of an asm-variant rule (syntactic occurrence,
matching Isabelle's selection and its documented limitations —
`splitter.ML:394,401`); instantiate the asm rule against the negated
assumption to derive the disjunctive form
`|- A = (Q1 /\ A1) \/ … \/ (Qk /\ Ak)` (double negations introduced by
the context instantiation cleaned with `NOT_CLAUSES`/`DE_MORGAN_THM` —
forget this and every asm split leaves `¬¬` junk, §5.9); pop the
assumption and `STRIP_ASSUME_TAC (EQ_MP eq (ASSUME A))` — HOL4's
`STRIP_ASSUME_TAC` performs the whole `disjE`/`conjE`/`exE` flattening,
yielding one subgoal per case with case condition and instantiated
hypothesis assumed (assumption proliferation is inherent and matches
Isabelle, `Generic.thy:1114–1118`).

### 6.4 Registration surface and the looper

```sml
(* splitLib *)
val SPLIT_CONV    : thm list -> conv
val SPLIT_ASM_TAC : thm list -> tactic
val SPLIT_TAC     : thm list -> tactic   (* one step: concl rules first,
                                            then asm rules; CHANGED *)
val type_split_of     : hol_type -> thm  (* cached, §6.5 *)
val type_asm_split_of : hol_type -> thm
(* [split] set *)
val split_thms    : unit -> thm list     (* current persistent set *)
(* simpLib *)
val add_split     : thm -> simpset -> simpset
val del_split     : string -> simpset -> simpset
val split_ss      : ssfrag
```

- `add_split th` inspects the rule (asm-variant by rhs shape, §6.1) and
  installs a named looper `split <thy$name>` / `split_asm <thy$name>`
  wrapping `SPLIT_TAC [th]` — one looper per rule, Isabelle's exact
  device (`splitter.ML:441–453`), giving `del_split` and
  `clear_rules`-drops-splits for free.
- The `[split]` persistent set: `ThmSetData.export_with_ancestry`
  (settype `"split"`) — plain ADD/REMOVE suffices since a split rule
  carries no extra metadata (asm-routing is syntactic); this gives the
  `Theorem foo[split]` attribute and `temp_add_split`-style functions
  by the standard mechanism.  Settype and attribute names verified
  unclaimed (`phaseS-hol4-splitting-idioms.md` §5).
- `split_ss` = one fragment containing (a) the **stateful splitter
  looper** named `"splitter"`, which at invocation consults the current
  `[split]` set *plus* TypeBase case-splits for the case constants
  actually occurring in the goal (the `RW_TAC` precedent of reading
  TypeBase at call time, `BasicProvers.sml:877–878`) — this reproduces
  Isabelle's per-datatype automatic `t.split` declaration without
  persisting derived theorems (the clasetLib rule, PLAN_phase_0 §6.5);
  and (b) the rewrite `⊢ (b ==> t) /\ (~b ==> t) <=> t` (D18's
  `cases_simp` analogue), derived at load time from
  `SPECL [b,t,t] COND_EXPAND_IMP` (`boolScript.sml:2511`) and `COND_ID`
  — no theory change.  `if` needs no special case: `bool` is a TypeBase
  datatype whose case constant is `COND`
  (`phaseS-hol4-splitting-idioms.md` §1b/§7).

### 6.5 TypeBase splits and exclusion

`type_split_of` derives the split theorem via
`Prim_rec.prove_case_ho_imp_thm` — already the exact Isabelle shape
(`src/1/Prim_rec.sml:2028–2043`, surfaced as
`TypeBase.case_pred_imp_of`); `type_asm_split_of` returns the stored
`case_elim` tyinfo field.  Both are cached per `(thy, tyop)` in an
`Sref` dictionary (the derivation re-proves on every call otherwise —
report §7 cost note); the cache is lazily filled by lookup, so no
TypeBase update hook is required for correctness (types defined later
are found later).

Per-invocation exclusion: the splitter looper skips rules whose looper
name is in `excl_loopers` (populated by `Excl "split thy$nm"`, §5.2)
and case constants of types listed there as `Excl "split.case ty"`.

### 6.6 `split!`

`add_split_bang` chains a classical `safe_tac` after each split
(`splitter.ML:447–451`) — Phase 1 territory.  The looper type already
passes the simpset, and the Phase 3 layer will register
`split! <name>` loopers composing `SPLIT_TAC [th] THEN_LT ALLGOALS (TRY
SAFE_TAC)`.  Nothing to build now; recorded so the API is not
accidentally narrowed.

## 7. `mut_impc` parity — `global_simp_tac` upgrade (D17)

Baseline (verified, `phaseS-isabelle-simploop.md` §3.6): the
`global_simp_tac` pass structure (`simpLib.sml:964–994`) is already a
mutual fixpoint (each assumption simplified with all others,
`rpt CHANGED_TAC` outer loop).  Phase S adds, behind a new config:

```sml
type xsimptac_config =
     {base : simptac_config, concl_in_fixpoint : bool, imp_rebuild : bool}
val GEN_GLOBAL_SIMP_TAC : xsimptac_config -> simpset -> thm list -> tactic
```

1. **Change counting** (unconditional — a pure cost improvement with
   identical results): port `mut_impc`'s `changed`/`k` schedule
   (`raw_simplifier.ML:1384–1415`): track the index of the last changed
   assumption per pass; on the next pass skip the provably-fixed tail
   (assumptions after the last change that were already re-simplified
   against the final rule set).  Replaces the current
   detect-termination-by-a-full-no-op-pass.
2. **`concl_in_fixpoint`** (flag, default `false`): bring the conclusion
   into the fixpoint — simplify it each pass with all assumptions in
   context, so a conclusion change that produces new rewriting
   opportunities re-triggers assumption passes (Isabelle simplifies the
   conclusion after the premise fixpoint and lets `rebuild` restart,
   `raw_simplifier.ML:1387–1390`).
3. **`imp_rebuild`** (flag, default `false`): the `rebuild` analogue
   (`raw_simplifier.ML:1360–1373`): after the fixpoint, for each
   assumption `a` (innermost first) attempt rewriting the `DISCH`ed form
   `a ==> w'` with implication-lhs rules from the simpset; on a hit,
   undischarge and restart the whole fixpoint.  This is the only piece
   with no current HOL4 counterpart; it is flag-guarded because its
   value is speculative (report §4.d) and its cost is a per-assumption
   conversion attempt.

`global_simp_tac cfg = GEN_GLOBAL_SIMP_TAC {base = cfg,
concl_in_fixpoint = false, imp_rebuild = false}` — existing entries
(`gvs`/`gs`/`gns`/`rgs`, `bossLib.sml:402–409`) are extensionally
unchanged except for the pass schedule (same results, fewer
re-simplifications; locked by selftests comparing outcomes on golden
goals).  Phase 3's wrappers consume `GEN_GLOBAL_SIMP_TAC` with the
flags on — the `asm_full_simp_tac` analogue used by `AUTO_TAC`
(`clasimp.ML:147–161`).  Benchmark-gated in-engine revisit recorded in
PLAN §11 by T12.

## 8. Selftests

Extend `src/simp/src/selftest.sml` (testutils conventions:
`tprint`+`require_msg`, `convtest`, `shouldfail`, `exit_count0` —
survey §9), grouped:

1. **Default equivalence**: golden conditional-rewriting and
   side-condition cases run identical through old/new engine paths
   (empty hooks); the pre-existing selftest corpus passes unmodified —
   the D14 zero-change lock.
2. **Solver seam**: a toy unsafe solver discharging a side condition the
   recursive simplifier cannot (e.g. a `DECIDE`-backed arithmetic
   condition via `mk_tactic_solver`); safe/unsafe list selection under
   `{safe = true/false}`; context_thms visibility (solver proves a
   condition from an assumption); limit save/restore on solver failure.
3. **cond_depth**: a conditional-rule chain of depth 10 that fails at
   the default 4 and succeeds with `set_cond_depth 40` (the
   Isabelle-parity scenario motivating PLAN §5.5); `examples/`-style
   global-ref setting still honored when the field is `NONE`.
4. **term_ord**: an ordered-rewriting case whose normal form flips under
   a custom order; `Once` bypass unaffected.
5. **Loopers**: a toy looper (splitting a marker conjunction) exercising
   restart-on-every-subgoal, `TRY` termination, name
   add/del/replace, `clear_rules` dropping loopers but keeping solvers.
6. **Splitter**: if-splits (incl. under `!` binders and with the redex
   referencing bound variables), datatype case splits (`list`,
   `option`, a locally defined datatype), all-occurrences semantics,
   pack ordering, asm splits with `¬¬` cleanup, `cases_simp` collapse,
   `Split th` marker and `[split]` attribute round-trip
   (theory_tests-style if needed), `Excl` exclusion; ported examples
   from Isabelle's Generic.thy splitter documentation; **RW_TAC
   parity**: a suite of goals `RW_TAC` solves via `IF_CASES_TAC` that
   `SIMP_TAC (bool_ss ++ split_ss)` must also solve (PLAN §5.2).
7. **congproc_ss**: a procedural congruence registered through a
   fragment reproduces a theorem-cong behavior; merge across `++`.
8. **GEN_GLOBAL_SIMP_TAC**: the report's §3.5 mutuality examples
   (`{P a, a = b} ⊢ Q`; the three-premise chain), identical results with
   change counting on golden goals, `concl_in_fixpoint` and
   `imp_rebuild` behaviors, `gvs`-defaults regression.
9. **congLib**: compile + a smoke test (it has none today).

Gates: `bin/build -t --seq=tools/sequences/upto-parallel` per task;
full `bin/build -F -t` at phase completion, recorded in PLAN §11's gate
record (T12).  `tools/h4pedant` clean (no tabs/trailing whitespace,
<80 cols).

## 9. Documentation

User-facing additions get `help/Docfiles` entries (Phase S has a real
user surface, unlike Phase 0): `splitLib.SPLIT_TAC`,
`simpLib.split_ss`, `simpLib.add_split`, `simpLib.Split`, the `[split]`
attribute (documented on the SPLIT_TAC page), `simpLib.add_looper`
family, `simpLib.add_unsafe_solver` family, `simpLib.set_cond_depth`,
`simpLib.set_term_ord`, `simpLib.clear_rules`,
`simpLib.GEN_GLOBAL_SIMP_TAC`.  `SPLIT_TAC`'s page cross-references
`blastLib.BBLAST_TAC`-style disambiguation is not needed, but it does
cross-reference `Cases_on`/`CASE_TAC` (the global-splitting
alternatives) and notes the one `examples/` local shadow.
`src/simp/src/notes.md` updated with the new engine seams.

## 10. Task breakdown (dependency order)

| # | task | notes |
|---|---|---|
| T1 | `Traverse`: `context_thms` + solver/subgoaler pipeline, defaults identical; selftest group 1–2 | §3.1–3.2; the delicate kernel-plumbing task — golden tests first |
| T2 | `traverse_data` v2 fields, `Cond_rewr` refs + dynamic binding, `congLib` update; selftest groups 3–4 | §3.3–3.4, §2 rule 3 |
| T3 | simpset fields, setters, fragment constructors, merge/rebuild/`pp`, `clear_rules`; selftest bits of groups 2,5,7 | §4; compat rules 1,6 |
| T4 | tactic-layer loop, `GEN_SIMP_TAC {safe}`, rewire entry points; selftest group 5 | §5.1; D14/D16 |
| T5 | `Split` marker (markerScript/markerLib/simpLib re-export) | §5.2; additive theory change, early because everything rebuilds after it |
| T6 | `splitLib` core: cmap, `SPLIT_CONV`, `SPLIT_TAC`; selftest group 6 (concl part) | §6.1–6.2 |
| T7 | `SPLIT_ASM_TAC`; selftest group 6 (asm part) | §6.3 |
| T8 | `[split]` set + attribute, TypeBase cache, `add_split`/`del_split`/`split_ss`, `process_tags` integration, `cases_simp` derivation, exclusion plumbing; selftest group 6 (integration + RW_TAC parity) | §6.4–6.5; needs T3–T7 |
| T9 | `GEN_GLOBAL_SIMP_TAC` (change counting + flags); selftest group 8 | §7; independent of T5–T8 |
| T10 | `congproc_ss` travrules merge; selftest group 7 | §4.3; needs T3 |
| T11 | Docfiles, `notes.md`, h4pedant pass | §9 |
| T12 | `PLAN.md` record updates: §2 table D14–D20, §5 status, §11 micro-decisions + benchmark-gated in-engine `mut_impc` revisit + gate record | bookkeeping |
| T13 | full `bin/build -F -t` gate | must be green before Phase S is declared done |

Estimated new/changed code: ~1.6–2 kLoC SML (Traverse ~250, simpLib
~500, splitLib ~700, global upgrade ~200, marker ~30, congLib ~15) +
~0.9 kLoC tests.

## 11. Phase-S-specific risks

1. **Silent behavior drift in the engine refactor** (T1/T2): the
   solver-pipeline factoring must be extensionally identical with empty
   hooks — including the limit save/restore and `UNCHANGED`
   propagation subtleties (`Traverse.sml:158–178`).  Mitigation: the
   default-equivalence suite lands *before* the refactor; full builds
   per task; the existing 490-line selftest is the canary.
2. **Splitter corner cases**: the report's §5 list (all-occurrences,
   ordering, `¬¬` cleanup, type-instance keying, one-split-per-round
   termination) is transcribed into targeted tests before the algorithm
   lands; divergences from Isabelle (pack iteration, strong congs) are
   deliberate and documented, not accidental.
3. **Looper non-termination** in user hands (split rhs reintroducing the
   redex): same exposure as Isabelle; mitigated by `cases_simp`, the
   one-split-per-round + restart structure, and the simpset `limit`
   field which now also bounds looper rounds (the loop checks it).
4. **Dynamic-binding reentrancy** (§3.3–3.4): nested `TRAVERSE` with
   different `cond_depth`/`term_ord` — exception-safe save/restore
   tested explicitly, including a solver that itself calls `SIMP_CONV`.
5. **`context_thms` growth**: pathological congruence nesting makes the
   list long; it is cons-only and consulted lazily by solvers, but the
   selftest includes a perf smoke (deep `let`/`==>`-nest) compared
   against HEAD timings.
6. **congLib drift**: it duplicates engine wiring; T2 updates it and
   adds its first smoke test so future field additions fail loudly.

## 12. Interfaces later phases rely on (freeze list)

Frozen at Phase S completion (changes require an owner decision):
`Traverse.simp_prover_ctxt`/`ssolver`/`subgoaler` types;
`simp_mode`/`GEN_SIMP_TAC`; the looper contract (name-keyed,
`simpset -> tactic`, fail-when-inapplicable, restart semantics);
`mk_tactic_solver`; `add_split`/`del_split`/`split_ss`/`SPLIT_TAC` and
the `Split` marker; the `[split]` settype/attribute;
`xsimptac_config`/`GEN_GLOBAL_SIMP_TAC`; `set_cond_depth` (and the
layer-sets-40 convention); `clear_rules` semantics.  Everything else
(SSFRAG_CON internals, cmap representation, caches) is private to
`src/simp`.

Phase 3 consumption map (for orientation): `AUTO_TAC`'s simp wrappers =
`GEN_SIMP_TAC`/`GEN_GLOBAL_SIMP_TAC` with `{safe = true}` variants
(addSss, `clasimp.ML:46–54`) and `{safe = false}` (addss); layer
simpsets = `srw_ss() ++ split_ss` + `set_cond_depth 40` + solver
registrations; Phase 5 registers lin-arith once via
`solver_ss`/`add_unsafe_solver` (the `lin_arith.ML:947–949` analogue).
