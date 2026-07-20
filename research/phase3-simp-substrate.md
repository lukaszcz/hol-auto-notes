# Phase 3 research: the Phase-S simplifier substrate

Verified against the working tree at `worktrees/isabelle-tactics`
(branch `isabelle-tactics`, post-Phase-S, post-Phase-1/2).  All
citations are `file:line` in this worktree.

## 0. Prominent gaps / corrections to the Phase-3 sketch

1. **`GEN_GLOBAL_SIMP_TAC` has NO safe-simp mode.**
   `xsimptac_config = {base : simptac_config, concl_in_fixpoint : bool,
   imp_rebuild : bool}` (`src/simp/src/simpLib.sig:241-243`,
   `simpLib.sml:1505-1506`) — there is no `safe` field, and the
   conclusion tactic inside `GEN_GLOBAL_SIMP_TAC` hard-codes
   `{safe=false}` (`simpLib.sml:1623-1624`:
   `gen_simp_tac thl' {safe=false} ss []`).  The Phase-S plan's
   consumption map (PLAN_phase_S.md:646-648) says Phase 3's simp
   wrappers are "`GEN_SIMP_TAC`/`GEN_GLOBAL_SIMP_TAC` with
   `{safe = true}` variants" — for the global entry point that variant
   **does not exist yet**.  Phase 3 must either add a mode field to
   `xsimptac_config` (an owner decision: it is on the §12 freeze list,
   PLAN_phase_S.md:641) or restrict safe-simp to the goal-directed
   `GEN_SIMP_TAC`.
2. **No `[iff]` attribute exists anywhere.**  The only `"iff"` string
   in the sources is an unrelated Z3 parser token
   (`src/HolSmt/Z3_ProofParser.sml:181`).  `[iff]` is green-field.
3. **One attribute name = one function pair.**
   `ThmAttribute.register_attribute` maps a name to a single
   `attrfuns = {localf, storedf}` record; re-registration *replaces*
   the old functions with a warning (`src/1/ThmAttribute.sml:92-112`).
   So "[iff] calls two registered functions" is not a thing the
   registry provides — but an `attrfun` is arbitrary code, so a single
   registered `[iff]` can update both stores itself (§6 below).
4. **`GEN_SIMP_TAC` does not consume `Req0`/`ReqD`.**  Those markers
   are consumed by `markerLib.mk_require_tac` wrappers, which
   `FULL_SIMP_TAC`-family and `GEN_GLOBAL_SIMP_TAC` have
   (`simpLib.sml:1479-1486`, `1616`) but bare
   `GEN_SIMP_TAC`/`ASM_SIMP_TAC`/`SIMP_TAC` do not
   (`simpLib.sml:1416-1421`).  Phase-3 entry points that accept thm
   lists should wrap `mk_require_tac` themselves (as
   `BasicProvers.sml:1099,1305` do).

## 1. simpLib public API (src/simp/src/simpLib.sig)

### 1.1 Invocation-mode record (D16)

```
type simp_mode = {safe : bool}                          (* sig:221 *)
val GEN_SIMP_TAC : simp_mode -> simpset -> thm list -> tactic   (* sig:222 *)
```
Definition sites: `simpLib.sml:1328` (type), `1416` (`GEN_SIMP_TAC
mode = gen_simp_tac [] mode`).  Entry points accepting it: **only
`GEN_SIMP_TAC`** (and the internal `gen_simp_tac extra_context mode`,
`simpLib.sml:1385`).  Derived entry points fix the mode:
- `ASM_SIMP_TAC ss = GEN_SIMP_TAC {safe=false} ss` (`simpLib.sml:1418`)
- `SIMP_TAC ss ths = ASM_SIMP_TAC ss (markerLib.NoAsms::ths)` (`1420`)
- `FULL_SIMP_TAC` family uses `ASM_SIMP_TAC` for the goal
  (`simpLib.sml:1474`), so always unsafe.
- `GEN_GLOBAL_SIMP_TAC` hard-codes `{safe=false}` (`1624`).

### 1.2 Solver stacks

Types (in `src/simp/src/Traverse.sig`):
```
type simp_prover_ctxt =
     {stack : term list, context_thms : thm list, recurse : term -> thm}
                                                     (* Traverse.sig:90-93 *)
type ssolver = {name : string, solve : simp_prover_ctxt -> term -> thm}
                                                     (* Traverse.sig:94-95 *)
type subgoaler = simp_prover_ctxt -> term -> thm     (* Traverse.sig:96 *)
```
Simpset-level API (`simpLib.sig:163-171`):
```
val add_unsafe_solver  : Traverse.ssolver -> simpset -> simpset
val add_safe_solver    : Traverse.ssolver -> simpset -> simpset
val set_unsafe_solvers : Traverse.ssolver list -> simpset -> simpset
val set_safe_solvers   : Traverse.ssolver list -> simpset -> simpset
val remove_solver      : string -> simpset -> simpset   (* removes from BOTH lists *)
val set_subgoaler      : Traverse.subgoaler -> simpset -> simpset
val mk_tactic_solver   : string * tactic -> Traverse.ssolver
```
Implementations: `simpLib.sml:595-616` (all go through the
event-sourced `strategy_op`, so simpset history replay is preserved,
`simpLib.sml:562-591`).  `remove_solver` filters both lists by name
(`580-584`).  `set_*_solvers` dedups by name.  Solvers are name-keyed:
`add_solver` replaces an existing solver of the same name.

`mk_tactic_solver (name,tac)` (`simpLib.sml:732-739`): proves the goal
`(map concl context_thms, c)` with `TAC_PROOF` and discharges the
hypotheses with `PROVE_HYP` over `context_thms` — this is the adapter
Phase 3 uses to install classical tactics as simpset solvers.

Fragment-level constructors (`simpLib.sig:106-107`): `solver_ss :
Traverse.ssolver -> ssfrag` (unsafe list), `safe_solver_ss` (safe
list); ssfrags carry `unsafe_solvers`/`safe_solvers` fields merged on
`++` (`simpLib.sml:113-114`, `306-307`).

### 1.3 Loopers and splitLib integration

API (`simpLib.sig:157-162`):
```
val add_looper : string * (simpset -> tactic) -> simpset -> simpset
val del_looper : string -> simpset -> simpset
val set_looper : string * (simpset -> tactic) -> simpset -> simpset
val add_split  : thm -> simpset -> simpset
val del_split  : string -> simpset -> simpset
val split_ss   : ssfrag
```
plus `looper_ss : string * (simpset -> tactic) -> ssfrag` (sig:105).

Contract (frozen, PLAN_phase_S.md:637-639): name-keyed; a looper is
`simpset -> tactic` that fails (or raises `Conv.UNCHANGED`, converted
to `NO_TAC` at `simpLib.sml:1361-1371`) when inapplicable.  In
`gen_simp_tac` the loop is
`rewr_tac THEN (solve_tac ORELSE TRY (loop_tac THEN_LT ALLGOALS (recur main)))`
(`simpLib.sml:1395-1408`): after rewriting, final solvers are tried
first; if they fail, the first applicable looper runs and the whole
simp restarts on every resulting subgoal.  Looper rounds are bounded
by the simpset `limit` field (`bounded_looper`, `simpLib.sml:1373-1383`;
`rounds = ref (getlimit ss)`, `1388`).

`add_split th` registers looper `"split <name>"` or `"split_asm
<name>"` running `splitLib.SPLIT_TAC [th]` (`simpLib.sml:618-624`);
`del_split` deletes both candidate names (`626-636`).  `split_ss` is
the named fragment `"split"` = `looper_ss ("splitter",
splitter_looper)` + the `cases_simp` rewrite (`simpLib.sml:728-730`).
`splitter_looper` (`692-716`) applies the persistent `[split]` theorem
set (`splitLib.named_split_thms`, `src/simp/src/splitLib.sml:116`) plus
per-goal datatype case splits (`case_types`, `simpLib.sml:671-690`),
honoring the `excl_loopers` exclusion set.  `Excl` names of the forms
`"split <nm>"`, `"split_asm <nm>"`, `"split.case <ty>"` are routed to
looper exclusion by `process_tags` (`simpLib.sml:1261-1288`).

splitLib public surface: `src/simp/src/splitLib.sig:1-31`
(`SPLIT_CONV`, `SPLIT_ASM_TAC`, `SPLIT_TAC`, `mk_asm_split`,
`type_split_rules`, `split_thms`/`named_split_thms`, `is_asm_split`,
`split_thm_name`).

### 1.4 cond_depth and term_ord

```
val set_cond_depth : int -> simpset -> simpset      (* sig:169; sml:603 *)
val set_term_ord : (term * term -> order) -> simpset -> simpset
                                                    (* sig:170; sml:604 *)
```
Both are strategy events; `Traverse` threads them dynamically:
`cond_depth` overrides `Cond_rewr.stack_limit` (default `4`,
`src/simp/src/Cond_rewr.sml:11`) via `with_option_flag` for the
duration of the traversal (`src/simp/src/Traverse.sml:368-375`).  The
Phase-S freeze list records the "layer sets 40" convention for Phase-3
layer simpsets (PLAN_phase_S.md:641-642, 648-650).

Also relevant: `clear_rules : simpset -> simpset` (sig:172,
sml:1118-1135) — drops rewrites/dprocs/**loopers** but keeps both
solver lists, subgoaler, cond_depth, term_ord (loopers cleared at
`1134`).

### 1.5 ssfrag record

Public constructor `SSFRAG` takes only
`{name, convs, rewrs, ac, filter, dprocs, congs}`
(`simpLib.sig:66-73`); the extended fields are reachable through
dedicated constructors: `looper_ss`, `solver_ss`, `safe_solver_ss`,
`congproc_ss : {name : string, relation : term, proc :
Opening.congproc} -> ssfrag` (sig:105-109).  Internally `SSFRAG_CON`
carries `relsimps, loopers, unsafe_solvers, safe_solvers, congprocs`
in addition (`simpLib.sml:103-116`); `merge_ss` concatenates all of
them (`295-308`).  SSFRAG internals are declared private by the freeze
list (PLAN_phase_S.md:642-644).

Registration of named frags for `SF`/`ExclSF`: `register_frag`,
`lookup_named_frag`, `all_named_frags` (sig:82-84).

### 1.6 Marker vocabulary accepted in simp thm lists

Three processing layers:

1. `markerLib.process_taclist_then_recur` (entered at
   `simpLib.sml:1413`; decoder `dest_tacmarked`,
   `src/marker/markerLib.sml:659-699`): **`NoAsms`**,
   **`IgnAsm`pat``**, **`Abbr"v"`** (runs `UNABBREV_TAC` as a
   pretactic), assumption-label references, plain theorems.
2. `process_tags` (`simpLib.sml:1231-1292`): **`Cong`** (`1233`),
   **`Split`** (`1234`), **`AC`** (`1235`), **`Excl "name"`** and
   **`ExclSF "fragname"`** (`1236`, extractor `1196-1204`), **`SF
   frag`** (via `FRAG` marker, extractor `1206-1216`; `SF` itself at
   `1218-1229` auto-registers unknown named frags with a warning).
   Excl names are tried in order as: rewrite removal (`-*`), looper
   deletion, solver removal, splitter exclusion (`1265-1288`).
3. Rewrite-bounding markers **`Once`**/**`Ntimes`**
   (`src/1/BoundedRewrites.sig:11-12`) are consumed when theorems are
   turned into rewrites, e.g. `dest_tagged_rewrite` in
   `rewriter_for_ss.addcontext` (`simpLib.sml:1146`).
4. **`Req0`/`ReqD`** are consumed only by `mk_require_tac`-wrapped
   entry points (`markerLib.sml:139-153`): the `FULL_SIMP_TAC` family
   (`simpLib.sml:1479-1486`), `GEN_GLOBAL_SIMP_TAC`
   (`simpLib.sml:1616`), and BasicProvers'
   `SRW_TAC`/`PRIM_SRW_TAC`-based entries
   (`src/basicProof/BasicProvers.sml:1099,1305`).  **Not** by bare
   `SIMP_TAC`/`ASM_SIMP_TAC`/`GEN_SIMP_TAC` (§0.4).

Marker constructors re-exported by simpLib: `Cong, Split, AC, Excl,
ExclSF, Req0, ReqD, SF` (`simpLib.sig:90-97`; values bound at
`simpLib.sml:1182-1188`, `1218`).

## 2. asm_full_simp_tac analogue

### 2.1 FULL_SIMP_TAC (single pass)

`simpLib.sml:1466-1487`.  `GEN_FULL_SIMP_TAC` folds over the
assumption list: `simp_asm (t, l') = SIMP_RULE ss (l' @ thms) t :: l'`
(`1469`) — each assumption **is** simplified using the
already-simplified earlier assumptions (plus the user's theorems), the
results are re-assumed (with stripping in the `FULL_SIMP_TAC` variant,
`STRIP_ASSUME_TAC'`, `1457`), the originals dropped (`1470-1471`,
`drop`), and finally the goal is simplified with `ASM_SIMP_TAC ss l`
(`1474`), i.e. using all resulting assumptions as context.  So: yes,
assumptions simplify each other, but only in **one ordered pass** —
an earlier assumption is never revisited after a later one changes,
and there is no fixpoint.  `REV_FULL_SIMP_TAC` runs the pass in the
other order (`1476-1482`); `NO_STRIP_*` variants skip stripping
(`1484-1486`).

### 2.2 GEN_GLOBAL_SIMP_TAC / global_simp_tac (D17, mutual fixpoint)

Signatures (`simpLib.sig:235-246`):
```
type simptac_config =
     {strip : bool, elimvars : bool, droptrues : bool, oldestfirst : bool}
val psr : simptac_config -> simpset -> tactic          (* pop-simp-rotate *)
val allasms : simptac_config -> simpset -> tactic
type xsimptac_config =
     {base : simptac_config, concl_in_fixpoint : bool, imp_rebuild : bool}
val GEN_GLOBAL_SIMP_TAC : xsimptac_config -> simpset -> thm list -> tactic
val global_simp_tac : simptac_config -> simpset -> thm list -> tactic
```
`global_simp_tac cfg = GEN_GLOBAL_SIMP_TAC {base=cfg,
concl_in_fixpoint=false, imp_rebuild=false}` (`simpLib.sml:1716-1718`)
— i.e. the pre-existing `gvs`/`gs` semantics; the two new flags are
opt-in (D17, PLAN.md:125).

Mechanics (`simpLib.sml:1543-1714`):
- **Change counting / fixed-tail skipping**: `counted_psr`
  (`1546-1575`) pops one assumption, simplifies it against the
  remaining assumptions + user thms (`SIMP_RULE ss (asms @
  extra_context)`, `1555`) and records `{changed, structural}`
  (`structural` = the strip/elimvar constructor produced a different
  goal shape than plain re-assumption, `1570-1572`).  `counted_pass`
  (`1577-1612`) walks all assumptions, maintaining `k` (a countdown:
  once `k` reaches 0 the remaining provably-fixed tail is only
  *rotated*, not re-simplified, `1586-1591`) and `last` (index of the
  last change).
- **Fixpoint**: `fixpoint`/`after_pass` (`1651-1686`): if a pass made
  a structural change → full restart (`fixpoint ~1`); if only ordinary
  changes → restart with `k = #last` so the unchanged tail is skipped;
  otherwise finish with the conclusion.
- **`concl_in_fixpoint`**: the conclusion is simplified *inside* the
  loop (`after_pass`, `1669-1683`) — a changed conclusion re-triggers
  the assumption fixpoint.  With the flag off, the conclusion is
  simplified once at the end (`final_conclusion`, `1688-1694`) using
  `gen_simp_tac thl' {safe=false} ss []` (`1623-1624`).
- **`imp_rebuild`**: `find_rebuild` (`1635-1649`) re-forms
  `a ==> (… ==> concl)` implications from successive assumptions and
  tries a root rewrite (`Traverse.ROOT_REWRITE`, `1625-1626`,
  `Traverse.sig:150-152`); on success it `MP_TAC`s the assumptions,
  applies the equation, re-strips, and restarts the fixpoint
  (`1696-1708`).  This is the `mut_impc` congruence-position parity.
- Wrapping: `mk_require_tac (ABBRS_THEN (LLABEL_RES_THEN …))`
  (`1616-1618`), and user thms go through `process_tags` then become
  simpset rewrites (`ss1 ++ rewrites thl'`, `1621-1622`).

**Fidelity verdict**: Isabelle's `asm_full_simp_tac` (one pass,
each assumption simplified with the preceding ones, then the
conclusion) corresponds to `FULL_SIMP_TAC`; full `mut_impc`-style
mutual simplification is `GEN_GLOBAL_SIMP_TAC` with
`concl_in_fixpoint=true, imp_rebuild=true`.  The natural Phase-3
full-simp wrapper is the latter — but note §0.1: it cannot yet run in
safe mode.

## 3. The stateful simpset (BasicProvers)

Location: `src/basicProof/BasicProvers.sml:1119-1398`; exported
surface `src/basicProof/BasicProvers.sig:21-45`.

- **Read**: `srw_ss : unit -> simpset` (`BasicProvers.sml:1251-1253`)
  — forces lazy initialisation (`init_state`, `1141-1150`) and returns
  the current global simpset value.  Simpsets are immutable values, so
  per-invocation augmentation is naturally non-destructive:
  `srw_ss() ++ frag`, `srw_ss() && thms` (`&&` runs `process_tags`
  first, `simpLib.sml:1306-1309`), `-* names`,
  `remove_ssfrags`/`exclude_ssfrags`.  (`diminish_srw_ss`
  (`1230-1235`) is **destructive/global** — not the per-invocation
  tool.)
- **Feeding it**: the state is an
  `AncestryData`/`ThmSetData.export_with_ancestry` store with
  `settype = "simp"` (`1206-1215`).  `export_rewrites`
  (`1312-1317`) records `ADD` deltas + updates the global value;
  `delsimps` (`1319-1321`) records `REMOVE`s.  The `[simp]` attribute
  is auto-registered by `export_with_ancestry`
  (`src/1/ThmSetData.sml:294-296`) and lands in the same delta stream.
  A theory's adds are finalised into one named ssfrag per theory
  (`finaliser` → `named_rewrites_with_names thyname`, `1190-1204`),
  which is what makes `ExclSF "thyname"` and `thy_ssfrag`
  (`1327-1337`) work.
- **Scoped global modification**: `with_simpset_updates f g x`
  (`1255-1264`) temporarily replaces the global value (used by the
  `exclude_simps`/`exclude_frags` tactic modifiers, `1381-1398`).
- **Derived-value cache with staleness**: `make_simpset_derived_value
  : (simpset -> 'a -> 'a) -> 'a -> {get, set}` (`1364-1379`) — a
  stale-flag registered in `stale_flags` (`1168-1170`) is set by every
  global update (`notify`, `updnote_global_value`, `1216`).  This is
  the ready-made mechanism for Phase 3 to keep a *clasimpset* (claset
  + srw_ss combination) cached and automatically rebuilt when `[simp]`
  changes.
- **Logged updates for non-delta changes**: `logged_update` /
  `logged_addfrags` / `apply_logged_updates`
  (`1266-1295`, sig:42-45) replay arbitrary `simpset -> simpset`
  functions in theory-topological order.

### 3.1 Can src/auto depend on BasicProvers/bossLib?

Yes.  Build order: `tools/sequences/upto-auto` is
`kernel; core-theories; src/auto/rules; src/auto/classical;
src/auto/blast; !src/auto/rules/theory_tests` (`upto-auto:1-6`), and
`core-theories` includes `base-hol` whose sequence reaches `src/boss`
and then `[poly]bin/hol` (`tools/sequences/base-hol:55-60`, comment:
"Up to this point is needed for hol (which loads bossLib)").  All
three `src/auto/*/Holmakefile`s already declare `HOLHEAP =
$(HOLDIR)/bin/hol.state0`, the heap created at the `bin/hol` step
(`tools-poly/build.sml:137-148`), which is *after* `src/boss` — so
`bossLib`, `BasicProvers`, `simpLib` are all available both in the
heap and sigobj.  Current `src/auto` code does not yet reference them
(opens are `Abbrev HolKernel boolLib` etc.,
`src/auto/rules/clasetLib.sml:4`, `src/auto/classical/classicalLib.sml:4`),
but nothing in the stratification prevents it.  Caveat: `src/auto`
sits in the middle Holmake band (needs `--holstate=bin/hol.state0`
for manual `Holmake` runs, per CLAUDE.md), which is consistent.

## 4. PLAN_phase_S.md §12 freeze list (verbatim substance)

`.agent-files/PLAN_phase_S.md:633-651`.  Frozen at Phase-S completion
(changes require an owner decision):

- `Traverse.simp_prover_ctxt` / `ssolver` / `subgoaler` types;
- `simp_mode` / `GEN_SIMP_TAC`;
- the looper contract (name-keyed, `simpset -> tactic`,
  fail-when-inapplicable, restart semantics);
- `mk_tactic_solver`;
- `add_split` / `del_split` / `split_ss` / `SPLIT_TAC` and the `Split`
  marker; the `[split]` settype/attribute;
- `xsimptac_config` / `GEN_GLOBAL_SIMP_TAC`;
- `set_cond_depth` (and the layer-sets-40 convention);
- `clear_rules` semantics.

Everything else (SSFRAG_CON internals, cmap representation, caches) is
private to `src/simp`.  The Phase-3 consumption map
(PLAN_phase_S.md:646-651): AUTO_TAC's simp wrappers =
`GEN_SIMP_TAC`/`GEN_GLOBAL_SIMP_TAC` with `{safe=true}` (addSss) and
`{safe=false}` (addss); layer simpsets = `srw_ss() ++ split_ss` +
`set_cond_depth 40` + solver registrations; Phase 5 registers
lin-arith once via `solver_ss`/`add_unsafe_solver`.  (See §0.1 for the
global-safe gap.)

## 5. Attribute machinery for [iff]

- **Registration** (`src/1/ThmAttribute.sig:4-16`):
  `attrfun = {name, attrname, args : string list, thm} -> unit`;
  `attrfuns = {localf : attrfun, storedf : attrfun}`;
  `register_attribute : string * attrfuns -> unit`.  One record per
  name; duplicate registration replaces with a warning
  (`ThmAttribute.sml:101-109`).  `storedf` fires for
  `Theorem foo[attr]`-style stored theorems, `localf` for
  `[local]`-marked / non-stored uses.
- **Set persistence** (`src/1/ThmSetData.sig`):
  - `new_exporter {settype, efns = {add, remove}}` (sig:15-17) — the
    simple hook form; `add`/`remove` are arbitrary code, called both
    at declaration time and at theory-load replay
    (`ThmSetData.sml:123-229`; attribute auto-registered at
    `228-230`).
  - `export_with_ancestry {settype, delta_ops}` (sig:26-33) — the
    merge-aware form used by `"simp"` (`BasicProvers.sml:1206-1215`)
    and `"split"` (`src/simp/src/splitLib.sml:100-114`, including the
    guard that the settype/attribute is not already taken,
    `splitLib.sml:100-104`).  Attribute auto-registered at
    `ThmSetData.sml:294-296`.
- **Two stores from one attribute**: the registry cannot fan one
  attribute out to two registered functions (§0.3), but the
  `apply_delta`/`apply_to_global`/`efns` code of a *single* `[iff]`
  settype may update both the claset and a simpset ssfrag in one
  delta application — atomically per theorem, and replayed
  consistently on theory load because both updates derive from the
  same persisted delta stream.  Precedents in-repo for
  attribute-adjacent multi-effects: `IndDefLib` registers both an
  `export_with_ancestry` set and a separate `new_exporter`
  (`src/IndDef/IndDefLib.sml:96,138`); `computeLib`
  (`src/compute/src/computeLib.sml:393`) and `transferLib`
  (`src/transfer/transferLib.sml:774-788`) show the `new_exporter`
  hook pattern.  Recommended shape for `[iff]`: its own settype
  (`export_with_ancestry`, value = whatever pair of stores Phase 3
  maintains), with the `"iff"` name guarded exactly as
  `splitLib.sml:100-104` does for `"split"`.
- Note `reserve_word` (`ThmAttribute.sig:16`, sml:67-79) exists for
  attributes handled specially by other machinery; not needed for a
  normal registered attribute.

## 6. What safe-simp mode actually changes (delivered D16 semantics)

`gen_simp_tac` (`simpLib.sml:1385-1414`) per invocation:

1. **Rewriting is identical in both modes.**  `rewr_tac = CONV_TAC
   (SIMP_CONV invocation_ss …)` (`1395-1398`); `SIMP_CONV` builds its
   traversal from `traversedata_for_ss`, whose `solvers` field is
   **always `#unsafe_solvers strategy`** (`simpLib.sml:1175`) — i.e.
   side-condition solving inside the rewriter is unaffected by the
   mode, exactly as D16 specifies (PLAN_phase_S.md:29; the engine seam
   always gets the unsafe list, PLAN_phase_S.md:169).
2. **Only the final-solver step is mode-sensitive.**
   `final_solver_tac` (`simpLib.sml:1341-1359`): `if #safe mode then
   #safe_solvers s else #unsafe_solvers s` (`1344-1345`); each solver
   gets `{stack=[], context_thms, recurse=QCONV (SIMP_CONV ss
   context_thms)}` and must prove the goal's conclusion exactly
   (alpha-checked, `1352-1353`; hypotheses reconciled against the
   assumption list and any solver-introduced hypothesis is an error,
   `reconcile_hyps`, `1330-1339`).
3. **Loopers still run in both modes**: `solve_tac ORELSE TRY
   (loop_tac THEN_LT ALLGOALS (recur main))` (`1405-1407`), with
   rounds bounded by the simpset limit (`1373-1383`, `1388`).

So for Phase 3: "safe-simp" = `GEN_SIMP_TAC {safe=true} ss thl` over a
simpset whose safe-solver list has been populated (e.g. via
`safe_solver_ss` / `add_safe_solver` / `set_safe_solvers` with
`mk_tactic_solver` around safe claset steps).  An empty safe list
makes the final-solver step a no-op (`FIRST []` fails), leaving
rewriting + loopers — which is the correct degenerate behaviour.
