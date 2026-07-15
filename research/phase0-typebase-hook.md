# TypeBase hook mechanism (Phase 0 planning report)

> Research report, 2026-07-15.  One of four reports produced by parallel
> research agents during the Phase 0 planning round (see `README.md`),
> underlying `../PLAN_phase_0.md` §6.5.  HOL4 citations refer to this
> repository (worktree `isabelle-tactics`, HEAD `af5d4a63f`).

Context: planning a new library that will, for every datatype,
automatically add distinctness/injectivity theorems (and later
case-split theorems) to a new rule database.  All facts verified against
the sources.

## 0. Where TypeBase lives

`TypeBase` and `TypeBasePure` live in **`src/1/`**, not `src/coretypes/`:
- `src/1/TypeBase.sig` / `.sml`
- `src/1/TypeBasePure.sig` / `.sml`

`src/coretypes/` contains pair/sum/option/one theories and `DefnBase`, no
TypeBase.

Build order: `src/1` is in `tools/sequences/kernel:39`; then in
`tools/sequences/base-hol`: `src/compute/src` (line 1), `src/simp/src`
(14), `src/basicProof` (18), `src/coretypes` (22), `src/boss` (57).  So a
new library using the hook can live anywhere at/after `src/1`; to
*consume* `simpLib.tyi_to_ssdata` it must be after `src/simp/src`.

## 1. The hook and enumeration API

**Hook registration** — `src/1/TypeBase.sig:23`:
```
val register_update_fn : (tyinfo -> tyinfo) -> unit
```
Implementation `src/1/TypeBase.sml:94-99`:
```
val update_fns = ref ([]:(tyinfo -> tyinfo) list)
fun register_update_fn f = (update_fns := !update_fns @ [f])
fun apply_update_fns tyi = list_compose (!update_fns) tyi
```
Semantics: it is a *transformer pipeline*, not a pure listener — hooks run
in registration order (`list_compose`, TypeBase.sml:15) on every tyinfo
entering the **global** typebase, and their return value is what gets
stored.  A pure listener returns the tyinfo unchanged
(`fn tyi => (side_effect tyi; tyi)` — the pattern used by all clients
below).  Firing site is `apply_to_global` (TypeBase.sml:102-103):
```
fun apply_to_global tyi tyb =
    TypeBasePure.insert tyb (apply_update_fns $ tweak_tyi tyi)
```
which is reached from `write`/`export` (TypeBase.sml:124-125) and from
theory-load delta replay (see §2).  Hooks do **not** fire retroactively
for types already in the base at registration time — hence the catch-up
sweep.

**Enumeration (catch-up sweep)** — `src/1/TypeBase.sig:22`:
```
val elts : unit -> tyinfo list        (* TypeBase.sml:130: listItems o theTypeBase *)
```
plus `theTypeBase : unit -> typeBase` (sig:14) with
`TypeBasePure.listItems : typeBase -> tyinfo list` (TypeBasePure.sig:113)
and `TypeBasePure.fold` (sig:104).  Per-type lookup:
`fetch : hol_type -> tyinfo option` (sig:20),
`read : {Thy,Tyop} -> tyinfo option` (sig:21).  To mutate-and-persist a
single type's tyinfo there is
`general_update : hol_type -> (tyinfo -> tyinfo) -> unit` (sig:81,
sml:321-331; it calls `export`).

## 2. Persistence: how the hook fires on theory reload

TypeBase's global DB is an `AncestryData.fullmake` instance
(TypeBase.sml:107-122) with `tag = "TypeBase"`,
`sexps = {dec = fromSEXP, enc = toSEXP}`,
`apply_to_global = apply_to_global`, `thy_finaliser = NONE`.
`TypeBase.export tyis` = `write tyis` + `record_delta` per tyinfo
(TypeBase.sml:125), so each tyinfo is serialised into the theory file as a
`"TypeBase.deltas"` ThyDataSexp segment.

On loading a theory, `AncestryData`'s `parent_onload` replays the stored
deltas and feeds each through `delta_side_effects`; with
`thy_finaliser = NONE` that is exactly (`src/parse/AncestryData.sml:277-279`):
```
fun delta_side_effects thyname ds =
    case thy_finaliser of
        NONE => List.app (update_global_value o apply_to_global) ds
```
So **every tyinfo loaded from a theory file goes through
`apply_update_fns`**, i.e. hooks registered before the theory is loaded
fire exactly as for freshly defined datatypes.  (Overview of this
mechanism: AncestryData.sig:150-169.)  Hooks are registered by top-level
`val _ = ...` in the library's structure body, so they are installed the
moment the library is loaded; anything loaded earlier must be caught up
via `TypeBase.elts()`.

`Datatype` completes the definition-side flow:
`src/datatype/Datatype.sml:713` calls `TypeBase.export tyinfos` (and line
716 additionally calls `computeLib.write_datatype_info` directly —
historically redundant with computeLib's hook).

## 3. Concrete existing clients (all three in-tree users)

1. **BasicProvers CASE_SIMP cache** —
   `src/basicProof/BasicProvers.sml:695-727`.  `case_rws tyi` collects
   `case_def_of`, `distinct_of`, `one_one_of` (699-705); the cache is
   seeded with a catch-up sweep
   `List.concat (map case_rws (TypeBase.elts ()))` (line 707); the hook is
   line 716:
   ```
   val _ = TypeBase.register_update_fn (fn tyinfo => (update_cache tyinfo;tyinfo))
   ```
   This is the closest template for the planned library: catch-up sweep +
   listener hook + a mutable rule store.

2. **srw_ss (stateful simpset)** —
   `src/basicProof/BasicProvers.sml:1244-1249`:
   ```
   fun update_fn tyi =
     augment_srw_ss ([simpLib.tyi_to_ssdata tyi] handle HOL_ERR _ => [])
   val () = TypeBase.register_update_fn (fn tyi => (update_fn tyi; tyi))
   ```
   `simpLib.tyi_to_ssdata : tyinfo -> ssfrag` is at
   `src/simp/src/simpLib.sig:110` (impl simpLib.sml:1011).  Catch-up here
   is lazy: the simpset's `init_state` (BasicProvers.sml:1141-1150) folds
   `add_simpls` over `tyinfol()` =
   `TypeBasePure.listItems (TypeBase.theTypeBase())` (line 977) when
   `srw_ss()` is first demanded.

3. **computeLib** — `src/compute/src/computeLib.sml:385`:
   ```
   val _ = TypeBase.register_update_fn (fn tyi => (write_datatype_info tyi; tyi))
   ```
   `add_datatype_info` (lines 358-380) pulls `size_of0`, `encode_of0`,
   case rewrites and convs from `simpls_of` into `the_compset`.  (Note:
   `[compute]`-attributed equations use a separate ThmSetData exporter at
   computeLib.sml:392ff; only datatype case/size equations come via the
   TypeBase hook.)

4. (Also `src/Boolify/src/Encode.sml:255` — an example of a *transforming*
   hook: `TypeBase.register_update_fn define_and_add_encode` actually
   modifies the tyinfo.)

## 4. Relevant tyinfo accessors (TypeBasePure.sig, exact lines)

- `distinct_of : tyinfo -> thm option` — sig:67 (NONE for
  single-constructor types; conjunction of `~(C1 ... = C2 ...)`)
- `one_one_of : tyinfo -> thm option` — sig:68 (NONE for enumerations;
  constructor injectivity)
- `nchotomy_of : tyinfo -> thm` — sig:66 (the exhaustion/cases theorem,
  `!x. (?a. x = C1 a) \/ ...`)
- `case_def_of : tyinfo -> thm` — sig:63; `case_cong_of : tyinfo -> thm`
  — sig:62; `case_const_of : tyinfo -> term` — sig:61
- `case_eq_of : tyinfo -> thm` — sig:64 (`(case x of ...) = v <=>
  disjunction` — what `TypeBase.CaseEq/AllCaseEqs` return,
  TypeBase.sig:64-66, sml:216-227)
- `case_elim_of : tyinfo -> thm` — sig:65 (higher-order
  `P (case x of ...) <=> disjunction`; surfaced as
  `CasePred/AllCasePreds`, TypeBase.sml:239-260)
- `constructors_of : term list` — sig:58;
  `destructors_of`/`recognizers_of : thm list` — sig:59-60
- `axiom_of`/`induction_of : thm` — sig:56-57 (`_of0` shared_thm variants
  sig:78-79)
- `simpls_of : tyinfo -> simpfrag` — sig:72
  (`{rewrs : thm list, convs : convdata list}`);
  `gen_std_rewrs : tyinfo -> thm list` — sig:38 (the "standard"
  boolTheory-style rewrites added by `add_std_simpls`, sig:39)
- Records: `fields_of` sig:69, `accessors_of` sig:70, `updates_of` sig:71
- Identity: `ty_of` sig:53, `ty_name_of : tyinfo -> string * string`
  sig:54
- Extensibility slot: `extra_of`/`put_extra`/`add_extra :
  ThyDataSexp.t list` — sig:76, 97-98

Derived on demand at TypeBase level (TypeBase.sig:73-77, sml:229-237):
`case_rand_of`, `case_pred_disj_of`, `case_pred_imp_of` (proved via
`Prim_rec.prove_case_rand_thm` etc. from `case_def` + `nchotomy`, not
stored).  Note `TypeBase.distinct_of`/`one_one_of` at the hol_type level
(TypeBase.sig:35,39) strip the option and raise on NONE (sml:166-169); on
raw tyinfos use the option-returning TypeBasePure versions.

**Caveat for non-datatypes**: tyinfos made by `mk_nondatatype_info`
(TypeBasePure.sig:44-49) lack case/distinct/one-one fields — accessors
like `case_def_of` raise `HOL_ERR` on them, so a hook should wrap accesses
in `Lib.total` (as `case_rws` and `AllCaseEqs` do).
