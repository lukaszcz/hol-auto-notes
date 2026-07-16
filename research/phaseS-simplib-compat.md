# Phase S research: simpLib extension compatibility survey

Scope: entire repository (`src/`, `examples/`, `tools/`, `Manual/`, `help/`)
as of branch `isabelle-tactics` (worktree
`/home/lukasz/dev/HOL/worktrees/isabelle-tactics`).  All line numbers refer
to that tree.  Goal: determine the least-breakage routes for the planned
Isabelle-parity extensions (loopers, safe/unsafe solver stacks, subgoaler,
side-condition depth limit, settable permutative term order, congprocs via
SSFRAG, new ssfrag fields) under the constraint that existing code keeps
compiling and behaving identically.

---

## 1. Current datatype definitions and what the signature exposes

### ssfrag (src/simp/src/simpLib.sml:94-103)

```sml
datatype ssfrag = SSFRAG_CON of {
    name     : string option,
    convs    : tagged_convdata list,
    rewrs    : (thname option * thm) list,
    ac       : (thm * thm) list,
    filter   : (controlled_thm -> controlled_thm list) option,
    dprocs   : Traverse.reducer list,
    congs    : thm list,
    relsimps : relsimpdata list
}
```

Eight fields internally.  The *public* constructor is a plain function
(simpLib.sml:109-113) taking a **7-field record** (no `relsimps`; `convs`
is `convdata list`, wrapped into `tagged_convdata` with `thypart = NONE`;
`congs` are normalised via `normCong`):

```sml
fun SSFRAG {name,convs,rewrs,ac,filter,dprocs,congs} = SSFRAG_CON {...}
```

**Important precedent:** `relsimps` was added to `SSFRAG_CON` *without*
changing the public `SSFRAG` record — this is exactly the extension
pattern to reuse.

### simpset (src/simp/src/simpLib.sml:251-260)

```sml
datatype simpset =
     SS of {mk_rewrs    : (controlled_thm -> controlled_thm list),
            history     : history_item list,
            initial_net : net,
            dprocs      : reducer list,
            travrules   : travrules,
            limit       : int option,
            excluded    : string Binaryset.set}
```

with `history_item = ADDFRAG of ssfrag | DELETE_EVENT of string list |
ADDWEAKENER of weakener_data` (simpLib.sml:247-249).

### What simpLib.sig exposes

- `structure simpLib :> simpLib` — **opaque** ascription (simpLib.sml:11).
- `type ssfrag` — **abstract** (simpLib.sig:63).
- `type simpset` — **abstract** (simpLib.sig:127).
- `SSFRAG` exported as a function taking the exact record
  (simpLib.sig:65-72):
  `{name : string option, convs : convdata list,
    rewrs : (thname option * thm) list, ac : (thm * thm) list,
    filter : (controlled_thm -> controlled_thm list) option,
    dprocs : Traverse.reducer list, congs : thm list}`.
- **Yes, `Traverse.reducer` is exposed** in the public API: in the
  `dprocs` field (sig:71), in `dproc_ss : Traverse.reducer -> ssfrag`
  (sig:99), in `weakener_data = Travrules.preorder list * thm list *
  Traverse.reducer` (sig:128), and in
  `traversedata_for_ss : simpset -> Traverse.traverse_data` (sig:155).
  So the `Traverse` record types are part of simpLib's public contract.
- Neither `SSFRAG_CON` nor `SS` is exported; **no destructor for either
  type is exported** (only accessors `frag_rewrites`, `frag_name`,
  `ssfrags_of`, `ssfrag_names_of`, `ssf_upd_rewrs`, `partition_ssfrags`).

---

## 2. SSFRAG construction sites (counts)

Tree-wide grep for `SSFRAG` (`*.sml` + `*.sig`): **130 lines** total.
After removing simpLib.sml itself, the unrelated
`BasicProvers.srw_update` constructor `ADD_SSFRAG`
(src/basicProof/BasicProvers.sig:40, .sml:1119,1138,1180-1182,1199,1226),
one comment (src/sort/permLib.sig:105), and the three composition
*rebindings* (`val SSFRAG = register_frag o simpLib.SSFRAG`:
src/num/arith/src/numSimps.sml:59, src/real/realSimps.sml:20,
src/simp/src/boolSimps.sml:27 — these do not take a record but forward
to the public function):

**88 record-literal application sites of the public `SSFRAG` function:
53 in `src/` (20 files) + 35 in `examples/` (24 files).**
Every one of these breaks if a field is added to the public record
(SML records are not extensible; a missing field in a record expression
is a type error).

src/ files (53 sites):
- src/simp/src/boolSimps.sml — 14 (lines 30,54,88,121,127,165,191,285,303,330,336,376,385,393)
- src/num/arith/src/numSimps.sml — 7 (62,159,498,509,609,622,647)
- src/real/realSimps.sml — 7 (22,68,376,618,887,955,1228)
- src/metis/normalForms.sml — 5 (217,251,280,1561,1622)
- src/pred_set/src/pred_setSimps.sml — 3 (19,28,69)
- src/bag/bagSimps.sml — 3 (10,78,139)
- src/sort/permLib.sml — 2 (680,686)
- 1 each: src/quantHeuristics/quantHeuristicsLibSimple.sml:339,
  src/num/theories/arithmeticScript.sml:5288,
  src/res_quan/src/res_quanLib.sml:414,
  src/pattern_matches/constrFamiliesLib.sml:20,
  src/integer/intReduce.sml:76, src/integer/int_arithScript.sml:872,
  src/integer/intSimps.sml:273, src/real/RealField.sml:619,
  src/pred_set/src/pred_setScript.sml:189,
  src/simp/src/combinSimps.sml:5, src/simp/src/pureSimps.sml:6,
  src/datatype/DatatypeSimps.sml:389.

examples/ files (35 sites): dev/sw (5 across mechReasoning.sml,
ARMCompositionScript.sml, working/0.1/{mechReasoning,ARMComposition},
working/0.2/{simplifier,ARMComposition}), dev/booth/boothScript.sml,
elliptic/{subtypeTools.sml:440, fieldTools.sml:990,1154,1216,
elliptic_exampleScript.sml:386}, machine-code/hoare-triple/helperLib.sml:248,
algorithms/unification/triangular/nominal/ntermLib.sml:6,15,
arm/arm6-verification/{armLib.sml:20, correctness/iclass_compLib.sml:42,110},
arm/v4/armLib.sml:19,58, HolCheck/commonTools.sml:44,52,60,
lambda/barendregt/{reductionEval.sml:70,87,128,268, chap2Script.sml:563},
pgcl/src/{wpTools.sml:158, posrealTools.sml:44,132},
miller/{formalize/extra_pred_setTools.sml:39, prob/prob_diceScript.sml:43,
prob/prob_canonTools.sml:12},
separationLogic/src/vars_as_resourceFunctor.sml:3837.

Smart-constructor call sites (lines mentioning them outside simpLib,
`src/`+`examples/`+`tools/`; includes a few sig/comment mentions, so
read as ~counts): `rewrites` ≈ 460, `merge_ss` 64, `std_conv_ss` 37,
`conv_ss` 32, `ac_ss` 30, `named_rewrites` 15, `rewrites_with_names` 7,
`type_ssfrag` 7, `dproc_ss` 3 (src/quantHeuristics/quantHeuristicsLibBase.sml:3004,
src/pattern_matches/patternMatchesLib.sml:42, src/simp/src/SatisfySimps.sml:16),
`relsimp_ss` 2, `empty_ssfrag` 1 (BasicProvers.sml:1129).
I.e. smart-constructor usage dwarfs raw-record usage overall, but the
88 raw-record sites are the compatibility constraint.

---

## 3. Pattern-matching / destructuring of ssfrag/simpset outside simpLib

**None possible and none exists.**  Both types are abstract behind the
opaque signature, so no code outside simpLib.sml can mention
`SSFRAG_CON` or `SS`.  All external access goes through exported
accessors; the complete list of users:

- `frag_rewrites`: src/string/stringSimps.sml:8,
  examples/HolCheck/stringBinTree.sml:45,
  examples/HolCheck/commonTools.sml:32.
- `remove_ssfrags`: src/basicProof/BasicProvers.sml:1233,
  src/pattern_matches/patternMatchesLib.sml:197,
  src/simp/src/selftest.sml:175,323,336,340.
- `exclude_ssfrags`: src/basicProof/BasicProvers.sml:1389, and the
  parser tools generate the *name* `simpLib.exclude_ssfrags` /
  `simpLib.remove_simps` when expanding `[exclude_frags]` /
  `[exclude_simps]` attributes: tools/parsing/AttributeSyntax.sml:50,
  tools/parsing/HolParserOld.sml:77,369,
  tools/parsing/HOLSourceExpand.sml:65 (see §11).
- `register_frag` / `lookup_named_frag` / `all_named_frags`: 9 external
  lines, e.g. numSimps.sml:59,506, realSimps.sml:20,
  boolSimps.sml:27,153,355, SatisfySimps.sml:16,
  src/probability/extrealSimps.sml:15,
  examples/l3-machine-code/arm8/asl-equiv/l3_equivalenceLib.sml:420.
- `ssfrags_of`, `frag_name`, `partition_ssfrags`, `ssf_upd_rewrs`:
  **no users outside simpLib.sml**.
- congLib does **not** destructure simpsets: it only calls
  `traversedata_for_ss` (congLib.sml:272).

Consequence: any new ssfrag/simpset field is invisible to all external
code as long as accessor behaviour is preserved.

---

## 4. Direct users of Traverse outside simpLib

### congLib (src/simp/src/congLib.sml, read in full — 342 lines)

congLib is a second front-end to the same traversal engine, for
simplification up to arbitrary preorders.  It:

- `open ... simpLib Trace Traverse Opening Travrules Cond_rewr` (l.13-15).
- Defines its own fragment/set datatypes `congsetfrag = CSFRAG of
  {rewrs, relations, dprocs : Traverse.reducer list, congs}` (l.193-197)
  and `congset = CS of {cong_reducer : Traverse.reducer, limit,
  relations, dprocs, travrules : travrules list}` (l.201-206) — these
  mirror ssfrag/simpset but are entirely separate; **no SIMPSET/SS use**.
- Builds a `REDUCER` from scratch (`cong_reducer`, l.132-165) with an
  exhaustive `apply {solver,conv,context,stack,relation}` pattern (l.155).
- **Destructures the `REDUCER` record**: `reducer_addRwts (REDUCER
  {name,addcontext,apply,initial})` (l.168-169) and
  `eq_reducer_wrapper (... REDUCER data)` (l.172-190), which also
  *re-constructs* the apply-argument record literal
  `{solver=..., conv=..., context=..., stack=..., relation=...}`
  (l.179-181).
- `CONGRUENCE_SIMP_QCONV` (l.260-280) is the engine-wiring duplicate:
  it calls `traversedata_for_ss ss` (l.272), wraps the simpset's
  rewriters and dprocs with `eq_reducer_wrapper`, prepends its own
  `cong_reducer`, and builds a **`traverse_data` record literal**
  `{rewriters, dprocs, relation, limit, travrules}` (l.273-277) passed
  to `TRAVERSE` (l.279).

So congLib will need the same hook threading as simpLib's own
`traversedata_for_ss`/`SIMP_QCONV` (simpLib.sml:778-785), and it breaks
on: (i) any field added to `Traverse.traverse_data`, (ii) any field
added to the `REDUCER` record, (iii) any field added to the
apply-argument record.

### traverse_data (src/simp/src/Traverse.sig:126-130)

Transparent type: `{rewriters, limit : int option, dprocs, travrules,
relation}`.  Constructed outside Traverse only in simpLib.sml:779-783
and congLib.sml:273-277.  `TRAVERSE` destructures it at Traverse.sml:308.
`traversedata_for_ss` is exported by simpLib (sig:155); its only user
in the whole tree is congLib.sml:272.

### REDUCER constructors in the tree (complete list)

Definition: Traverse.sig:67-76 (fields `name`, `initial`, `addcontext`,
`apply : {solver, conv, context, stack, relation} -> conv`), plus
`dest_reducer` (sig:78-86) and `addctxt` (sig:88).

src/ (11 constructor sites):
- src/simp/src/simpLib.sml:773 (`rewriter_for_ss`) and the relsimp
  `mk_reducer` (~l.560-585, apply pattern at l.572)
- src/simp/src/congLib.sml:162, 169, 189
- src/simp/src/SatisfySimps.sml:6-14 (exported as
  `SATISFY_REDUCER : Traverse.reducer`, SatisfySimps.sig:3)
- src/num/arith/src/numSimps.sml:487 (`NUM_ARITH_DP`)
- src/integer/intSimps.sml:267
- src/real/realSimps.sml:611 (`REAL_ARITH_DP`)
- src/bag/bagSimps.sml:132 (`SBAG_SOLVER`)
- src/sort/permLib.sml:659, 669
- src/quantHeuristics/quantHeuristicsLibBase.sml:2990
- src/pattern_matches/patternMatchesLib.sml:42 (file `open Traverse` at l.11)

examples/ (2): examples/elliptic/subtypeTools.sml:428,
examples/logic/temporal_deep/.../temporal_deep_simplificationsLib.sml:100.

computeLib: **no Traverse usage** (congLib opens computeLib, not the
reverse).

### apply-argument record: who breaks if it gains a field

Exhaustive record patterns (break): simpLib.sml:572,767 (internal),
congLib.sml:155,177 (+ literal 179-181),
patternMatchesLib.sml:39, temporal_deep_simplificationsLib.sml:99,
subtypeTools.sml:405 (`{context, solver = _, conv = _, relation = _,
stack = _}`).

Selector style `#context args` (safe under field addition, since the
record type is fixed by the `reducer` datatype): numSimps.sml:489,
intSimps.sml (same idiom), realSimps.sml:613, bagSimps.sml:135,
permLib.sml:663-675, quantHeuristicsLibBase.sml:2995,
SatisfySimps.sml:12.

---

## 5. Direct users of Cond_rewr

`open Cond_rewr`: src/simp/src/simpLib.sml:16, src/simp/src/congLib.sml:15.
Qualified `Cond_rewr.` uses: src/simp/src/pureSimps.sml:12
(`filter = SOME Cond_rewr.mk_cond_rewrs` in `PURE_ss`),
src/simp/src/selftest.sml:236-274 (`mk_cond_rewrs` unit tests), and the
`stack_limit` sites below.

### stack_limit

- Defined: src/simp/src/Cond_rewr.sml:11 — `val stack_limit = ref 4;`
- **Exported**: src/simp/src/Cond_rewr.sig:45 — `val stack_limit : int ref`.
- **Read exactly once**: Cond_rewr.sml:153, inside `COND_REWR_CONV`
  (`if length stack + length conditions > (!stack_limit) then ...` —
  aborts deep side-condition stacks).
- **Setters in the distribution (4, all under examples/)**:
  - examples/arm/v7/arm_stepLib.sml:1248 and :1253 —
    `with_flag (Cond_rewr.stack_limit, 50)` (scoped set/restore)
  - examples/logic/ltl/generalHelpersScript.sml:967 —
    `val _ = Cond_rewr.stack_limit := 1`
  - examples/logic/ltl/concrwaa2gbaScript.sml:11 —
    `val _ = Cond_rewr.stack_limit := 2`
- Nothing in `src/` or `tools/` sets it.
- **Documented publicly**: Manual/Description/simplifier.smd:911 and
  help/Docfiles/bossLib.SIMP_CONV.smd:54 both describe
  `Cond_rewr.stack_limit` as the user-facing knob (also indexed in
  help/src-sml/index.txt:32852).

`COND_REWR_CONV` (the simp one, `string * thm -> bool -> ...`) is called
only from simpLib.sml:77 (`mk_rewr_convdata`).  The identically-named
functions in src/res_quan/src/Cond_rewrite.sml:254,
examples/machine-code/garbage-collectors/boolTools.sml:485,
examples/separationLogic/src/vars_as_resource*Functor.sml and
`ho_COND_REWR_CONV` in examples/miller are unrelated local definitions.
`IMP_EQ_CANON` and `QUANTIFY_CONDITIONS`: **no callers outside
Cond_rewr/simpLib**.  `ac_term_ord` (the term order the permutative-
rewrite work wants to make settable): no external callers; used inside
Cond_rewr.sml only.

---

## 6. Simpsets constructed NOT via mk_simpset/++

**None.**  The `SS` constructor is not exported, and grep for `\bSIMPSET\b`
over `src/`, `examples/`, `tools/` finds **zero** occurrences (the token
does not exist in the tree).  The only ground simpset values are
`empty_ss` (simpLib.sml:270-274) and everything built from it via
`mk_simpset`/`++`/`&&`/`-*`/`add_weakener`/`add_relsimp`/
`remove_ssfrags`/`exclude_ssfrags`/`limit`/`unlimit`.
pureSimps builds `pure_ss = mk_simpset [PURE_ss]` (pureSimps.sml:15).
congLib's `congset`/`CS` (congLib.sml:201-211) is a *different* type,
not a simpset.

---

## 7. The merge path and invariants for new fields

`op ++` (simpLib.sml:636-672):
1. Skips the whole add if the frag's name is in `excluded` (l.631-636).
2. `mk_rewrs = filter oo mk_rewrs'` — frag filter *composes onto* the
   simpset's rewrite-maker (l.641-643); order-sensitive.
3. Frag rewrs (+ AC pairs) are run through the **old** `mk_rewrs'`
   (l.644-646), turned into convdata and inserted into `initial_net`
   (l.647-648).
4. dprocs: existing simpset dprocs get the frag's rewrs as extra context
   via `Traverse.addctxt`, then frag dprocs are appended, then relsimp
   reducers (l.654-656) — "provided dprocs are assumed already primed".
5. travrules merged: `merge_travrules (travrules :: mk_travrules
   relations congs :: reltravs)` (l.669-670).
6. `history = ADDFRAG f :: history` (l.664); `limit` and `excluded`
   are copied through unchanged.

`mk_simpset = foldl (fn (f,ss) => ss ++ f) empty_ss` (l.674).

**Rebuild path** (critical invariant for new fields):
`build_from_history` (l.676-685) replays `history` from `empty_ss`;
`remove_ssfrags` (l.692-706) and `exclude_ssfrags` (l.721-734) filter
the history and rebuild, then **explicitly restore the two fields not
represented in history**: `|> fupdlimit (fn _ => limit) |> setexcluded
excluded`.  Any new simpset field must either (a) be reconstructible
from history replay, or (b) get the same explicit save/restore in
`remove_ssfrags`, `exclude_ssfrags` (and consideration in
BasicProvers' `diminish_srw_ss`, which goes through `remove_ssfrags`).
`merge_ss` (l.196-207) flattens each ssfrag field across the list and
composes filters with `oo`; a new ssfrag field needs a merge rule here,
plus copy-through in `name_ss` (l.148-150) and `ssf_upd_rewrs`
(l.117-124), and defaults in the ~9 internal `SSFRAG_CON` literal sites
(l.110, 121, 149, 153, 159, 163, 167, 171, 175, 197).

Simpset record literal/pattern sites inside simpLib.sml that a new
simpset field must touch: l.264-268 (`ssupd_net`), 270-274 (`empty_ss`),
319-329 (`-*`), 392-396 (`fupdlimit`), 423-429 (`add_weakener`),
636-672 (`++`), 687-690 (`setexcluded`), 778-783
(`traversedata_for_ss`).  All internal-only.

---

## 8. Persistence / rebuilding (srw_ss)

`BasicProvers` (src/basicProof/BasicProvers.sml:1119-1249):
- `srw_state = simpset * bool * srw_update list` (l.1120) where
  `srw_update = ADD_SSFRAG of simpLib.ssfrag | REMOVE_RWT of string`
  (l.1119); base simpset `initial_simpset = bool_ss ++ COMBIN_ss ++
  NORMEQ_ss ++ ABBREV_ss ++ LABEL_CONG_ss ++ HIDE_ss` (l.1123-1127).
- Persistence is via `ThmSetData.export_with_ancestry {settype = "simp",
  ...}` (l.1206-1215).  **Only deltas are written to theory files** —
  `ThmSetData.ADD` (a theorem name) / `ThmSetData.REMOVE` (a string).
  **Simpsets and ssfrags are never serialized.**  On theory load the
  simpset is rebuilt in-session by replaying deltas (`apply_delta`
  l.1132, `apply_srw_update` l.1138, `finaliser` l.1190 batches a
  theory's adds into one `named_rewrites_with_names thyname` frag,
  `init_state` l.1141 additionally folds in `tyinfol()` type-base frags).
- `augment_srw_ss` (l.1223-1228) appends frags; `diminish_srw_ss`
  (l.1230-1235) calls `simpLib.remove_ssfrags` — i.e. goes through the
  history-rebuild path of §7; `temp_delsimps` uses `-*`.
- TypeBase hook: `TypeBase.register_update_fn` (l.1249) adds
  `tyi_to_ssdata` frags on datatype declaration.
- There is no other serialization mechanism (nothing named
  `AugmentedFrag` exists in the tree).

Consequence: new fields survive theory export automatically (nothing to
serialize), provided `++`/`remove_ssfrags`/`exclude_ssfrags` preserve
them per §7.  If new state should *persist across theories* (e.g. a
theory sets a term order for srw_ss), that would need a new
ThmSetData-style delta type — out of scope for behaviour-identical
compat, but worth flagging.

---

## 9. Existing selftest coverage (src/simp/src/selftest.sml, 490 lines)

Conventions: `open testutils boolSimps`, `diemode := Remember failcount`
(l.5), final `exit_count0 failcount` (l.490).  Helpers used: `tprint` +
`require` / `require_msg` / `require_msgk` with `check_result`,
`shouldfail` (l.175), `convtest` (l.104), goal-printing helpers
`printgoal`/`printgoals` (l.365-371) with `VALID (... TAC ...)` for
tactic tests.  Built by src/simp/src/Holmakefile (`selftest.exe:
selftest.uo boolSimps.uo Cond_rewr.uo simpLib.uo`), run into
`simp-selftest.log` when `HOLSELFTESTLEVEL` is set.

What is covered: AC/permutative rewrite looping and argument
permutation (l.14-30); loop detection vs bound variables (l.104);
`remove_ssfrags` UNCHANGED behaviour (l.175); `Cond_rewr.mk_cond_rewrs`
canonisation incl. bounded/Abbrev markers (l.236-281); `-*` removal of
named rewrites/convs/frags by name incl. theory-qualified keys
(l.283-346); `ASM_SIMP_TAC pure_ss` behaviours (l.373-424); Excl/SF/
Req-marker tactic behaviour (l.425-489).  New engine features (loopers,
solvers, term order, depth limit) have an obvious home + house style
here; also note src/boss/theory_tests/exclArithBugScript.sml exercises
`exclude_ssfrags`/SF/`++` end-to-end.

---

## 10. Conclusions — least-breakage route per extension

### (a) New simpset fields (loopers, solver stacks, subgoaler, depth limit, term order)

**Safe as internal record fields.**  `simpset` is abstract
(simpLib.sig:127) behind an opaque ascription; zero external
destructuring exists (§3); nobody constructs `SS` outside simpLib (§6).
Work needed is purely internal: the 8 record sites listed in §7, plus a
decision per field on rebuild semantics (history-replayable vs
explicitly restored like `limit`/`excluded` in `remove_ssfrags`/
`exclude_ssfrags`).  Recommend modelling every new field on `limit`:
functional updaters (`fupdlimit` style), explicit restore in the two
rebuild functions, copied through `++`.
Caveat: if a new hook must reach the *traversal engine*, note that
`traversedata_for_ss : simpset -> Traverse.traverse_data` is public and
`traverse_data` is a transparent record (Traverse.sig:126-130).  Adding
a field there breaks exactly one in-tree constructor — congLib.sml:273
— which we control, but also any out-of-tree caller of `TRAVERSE`.
Acceptable; alternatively keep `traverse_data` unchanged and pass hooks
by pre-composing them into the `rewriters`/`dprocs` reducers.  Do NOT
add fields to the reducer `apply` argument record: that breaks 5
exhaustive patterns in-tree (§4) *and* every out-of-tree dproc — thread
per-traversal state some other way (e.g. extra reducer context, or a
scoped ref around `TRAVERSE`).

### (b) SSFRAG: record extension vs additive smart constructors

**Do not touch the public `SSFRAG` record — 88 in-tree call sites break
(53 src, 35 examples), plus all out-of-tree code.**  Follow the
`relsimps` precedent exactly: add fields to the internal `SSFRAG_CON`
(defaulting to empty in the public `SSFRAG` wrapper, simpLib.sml:109-113)
and expose additive smart constructors (`congproc_ss`, `looper_ss`,
`solver_ss`, ... following `relsimp_ss`/`dproc_ss` naming), plus merge
rules in `merge_ss` and consumption in `op ++`.  For congprocs
specifically: `congs : thm list` already exists; a *procedural*
congproc field (cf. `Opening.congproc`, used via
`wk_mk_travrules`/`mk_travrules`, simpLib.sml:404-420) is a new
`SSFRAG_CON` field + smart constructor + a `mk_travrules` variant that
accepts pre-built congprocs.  If a variant of the public `SSFRAG`
taking the extended record is wanted, add it under a new name
(e.g. `SSFRAG_EXT`) rather than changing `SSFRAG`.

### (c) stack_limit: global ref → per-simpset field

Keep `Cond_rewr.stack_limit` exactly as is (exported int ref,
Cond_rewr.sig:45) — it is documented in the Manual and help docs and
set by 4 example sites (§5); removing or repointing it is observable.
Migration: add a per-simpset `side_condition_limit : int option` field
(route (a)); at traversal entry (`SIMP_QCONV`/`traversedata_for_ss`
consumers), `NONE` ⇒ read `!Cond_rewr.stack_limit` (today's behaviour,
bit-for-bit), `SOME n` ⇒ use `n`.  Since the ref is read exactly once,
inside `COND_REWR_CONV` (Cond_rewr.sml:153), the cleanest threading is
either (i) parameterise `COND_REWR_CONV` with an optional limit and
default the current callers (only caller: simpLib.sml:77 — signature
change confined to Cond_rewr.sig + simpLib, but note Cond_rewr.sig's
`COND_REWR_CONV` is public; safer to add `COND_REWR_CONV_WITH_LIMIT`
and keep the old name as a wrapper), or (ii) scoped set/restore of the
ref around the traversal (matches the existing `with_flag` usage in
arm_stepLib; single-threaded HOL sessions make this sound today).
Who would notice a per-simpset override: nobody — the 4 setters set the
global, which remains the default; behaviour changes only for simpsets
that explicitly opt in.
The same pattern applies to the **term order**: `Cond_rewr.ac_term_ord`
has no external callers, so making the order a parameter of the rewrite
machinery (global-ref default = current `ac_term_ord`) is invisible.

---

## 11. Tooling / signature dependencies

- src/simp/src/Holmakefile: only builds `selftest.exe` against
  `simpLib.uo` — no signature pinning.
- **The quotation/attribute parser hard-codes simpLib identifiers**:
  `[exclude_simps]` → `simpLib.remove_simps`, `[exclude_frags]` →
  `simpLib.exclude_ssfrags` (tools/parsing/AttributeSyntax.sml:47-51,
  tools/parsing/HolParserOld.sml:77,369,
  tools/parsing/HOLSourceExpand.sml:65, documented in
  AttributeSyntax.sig:70).  These names (and their
  `string list -> simpset -> simpset` types) must not change.
- BasicProvers re-exports `++`, `&&`, simpset types etc.; bossLib
  re-exports further — additive sig changes are fine, renames are not.
- Manual/help documents `Cond_rewr.stack_limit` (§5) and the simpset
  API generally (Manual/Description/simplifier.smd) — additive changes
  need doc updates but break nothing.

## 12. Headline numbers

| item | count |
|---|---|
| Public `SSFRAG` record-literal call sites (break on field add) | **88** (53 src / 20 files; 35 examples / 24 files) |
| `SSFRAG` rebinding sites (`register_frag o SSFRAG`) | 3 |
| External ssfrag/simpset *destructuring* sites | **0** (types abstract) |
| `traversedata_for_ss` users outside simpLib | 1 (congLib.sml:272) |
| `Traverse.traverse_data` record literals outside Traverse | 2 (simpLib:779, congLib:273) |
| `REDUCER` constructor sites outside Traverse/simpLib | 13 (11 src, 2 examples) |
| Reducer-apply exhaustive record patterns (break on field add) | 7 (2 simpLib-internal, congLib×2, patternMatchesLib, temporal_deep, subtypeTools) |
| `Cond_rewr.stack_limit` setters in distribution | 4 (all examples/) |
| `Cond_rewr.stack_limit` read sites | 1 (Cond_rewr.sml:153) |
| Simpset constructors bypassing `mk_simpset`/`++` | 0 |
