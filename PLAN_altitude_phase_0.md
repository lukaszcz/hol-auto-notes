# Plan (phase 0): Build claset markers on markerTheory/markerLib

Date: 2026-07-15.  Branch: `isabelle-tactics` (off `origin/develop`).
Scope: `src/auto/rules/clasetMarkerScript.sml`, `src/auto/rules/clasetLib.sml`,
and (depending on the owner decision below) `src/marker/markerScript.sml`,
`src/marker/markerLib.{sig,sml}`.

The `/simplify` altitude pass found that the claset library clones
HOL4's existing theorem-marker infrastructure (`src/marker`) into a
private parallel copy instead of building on it.  This plan removes the
duplication at the correct depth.

Line references are against the current tree.

---

## 1. The duplication

There are **two** distinct marker idioms in `src/marker`, and the claset
library re-implements **both** privately.

### 1a. Bool-identity marker (wrap a `bool` theorem in a tag, strip it back)

markerLib, hard-wired to one constant:

```sml
(* src/marker/markerScript.sml:114 *)
val Cong_def = new_definition("Cong_def", ``Cong (x:bool) = x``);
(* src/marker/markerLib.sml:77,79 *)
fun Cong th   = EQ_MP (SYM (SPEC (concl th) markerTheory.Cong_def)) th;
fun unCong th = PURE_REWRITE_RULE [Cong_def] th;
```

clasetLib, generic combinator + six constants:

```sml
(* src/auto/rules/clasetLib.sml:612-618 *)
fun mk_thm_marker def th = EQ_MP (SYM (SPEC (concl th) def)) th
fun dest_thm_marker marker def th =
  (if same_const marker (rator (concl th)) then SOME (PURE_REWRITE_RULE [def] th)
   else NONE) handle HOL_ERR _ => NONE
(* :621-644 : mk_marker_const "clasetMarker" + SIntro/Intro/SElim/Elim/SDest/Dest *)
```

`mk_thm_marker`/`dest_thm_marker` are **exactly the generic form of
`Cong`/`unCong`** that markerLib never factored out (markerLib only has the
`Cong`-specialised versions).  clasetLib's dest is the richer, guarded
variant (returns `NONE` when the head is not the expected marker), which is
what any general consumer wants.

### 1b. Name-carrying tag (`C (v:'a) = T`, read the variable's name back)

markerLib, with a **generic combinator already written**:

```sml
(* src/marker/markerScript.sml:115 *)
val Exclude_def = new_definition("Exclude_def", "Exclude (x:'a) = T");
(* src/marker/markerLib.sml:80-104 *)
fun genmktagged th nm = let val v = mk_var(nm, alpha) in EQT_ELIM (SPEC v th) end
fun gendest_tagged t th =
    let val c = concl th val f = rator c
    in if same_const t f then SOME (#1 (dest_var (rand c))) else NONE end
       handle HOL_ERR _ => NONE
val Excl     = genmktagged markerTheory.Exclude_def
val destExcl = gendest_tagged Excl_t
```

clasetLib, hand-inlined clone:

```sml
(* src/auto/rules/clasetMarkerScript.sml:14 *)
val Del_def = new_definition("Del_def", ``Del (x:'a) = T``);
(* src/auto/rules/clasetLib.sml:646-658 *)
fun Del name = let val marker_name = mk_var (name, alpha)
               in EQT_ELIM (SPEC marker_name clasetMarkerTheory.Del_def) end
fun destDel th = ... if same_const Del_t (rator tm) then SOME (#1 (dest_var (rand tm))) ...
```

`Del`/`destDel`/`Del_def` is a **semantic clone of `Excl`/`destExcl`/
`Exclude_def`** — same definition, same "exclude a rule by name" meaning,
same read-the-var-name destructor.  markerLib's `genmktagged`/
`gendest_tagged` are the generic combinators; clasetLib inlined them.

### 1c. Consequence: two disjoint marker families + a missing OpenTheory map

- `markerTheory` is the shared home for theorem-tag constants (`AC`,
  `Cong`, `Exclude`, `ExcludeFrag`, `FRAG`, `Req0`, `ReqD`, …), consumed by
  `simpLib`/`BasicProvers` through the identical `EQ_MP/SYM/SPEC` +
  `PURE_REWRITE_RULE` idiom.  The new `clasetMarker` theory is a second,
  disjoint family a reader/tool must now know about.
- `markerScript.sml:120` maps `Cong` to OpenTheory `Unwanted.id`
  (markers must vanish under OpenTheory export).  The six `clasetMarker`
  constants have **no** such mapping — any theory exporting a claset marker
  through OpenTheory would leak an unmapped constant.  Building on
  `markerTheory` closes this gap for free.

---

## 2. Owner decision — where do the six kind-constants live?

**DECIDED (2026-07-16, owner): Option A.**  Keep a slim `clasetMarker`
theory for the six constants and consume markerLib's combinators for all
plumbing.  Option B is recorded as an owner-approved follow-up only.

The generic-combinator duplication (§1a/§1b combinators, and the `Del`≈`Excl`
clone) is removed with **no** base-theory change.  `SIntro/Intro/SElim/Elim/
SDest/Dest` stay defined in `src/auto/rules/clasetMarkerScript.sml`.

- **Option A (chosen) — keep a small `clasetMarker` theory for the six
  constants, but consume markerLib's combinators.**  Low blast radius (no
  rebuild of everything downstream of `src/marker`).  `clasetMarker` shrinks
  to six `new_definition`s and their OpenTheory maps; all plumbing comes
  from markerLib.
- **Option B (deferred, needs base-theory sign-off) — move the six
  constants into `markerTheory`, delete `clasetMarkerScript.sml` entirely.**
  Single home for every theorem-tag constant; matches the finding's "built
  on markerTheory" literally.  But `markerTheory` is a very early base
  theory (`src/marker`), so this rebuilds a large swath of the tree.

Steps 1–3 below are the whole of phase 0 under Option A; Step 4 follows the
**Option A** path.  The Option B path in Step 4 is retained only as the
follow-up sketch.

---

## 3. Implementation

### Step 1 — export the generic combinators from markerLib

`genmktagged`/`gendest_tagged`/`mk_marker_const` already exist in
`markerLib.sml` (`:80-104`) but are **not** in `markerLib.sig` (the sig
exports only `Cong`, `unCong`, `Excl`, `destExcl`, `destExclSF`).  Add the
generic bool-marker combinator (the generalisation of `Cong`/`unCong` that
clasetLib currently owns) and publish the tag combinators.

`src/marker/markerLib.sml` — add near `Cong`/`unCong` (`:77`):

```sml
(* Generic bool-identity marker: wrap/strip an arbitrary  C (x:bool) = x  *)
fun genCong def th = EQ_MP (SYM (SPEC (concl th) def)) th
fun genUnCong t def th =
  (if same_const t (rator (concl th)) then SOME (PURE_REWRITE_RULE [def] th)
   else NONE) handle HOL_ERR _ => NONE
```

Re-express the existing specialisations in terms of them (optional, but
proves the generalisation is faithful):

```sml
fun Cong th   = genCong markerTheory.Cong_def th
fun unCong th = valOf (genUnCong (mk_marker_const "Cong") markerTheory.Cong_def th)
```
(keep `unCong` total as today — it currently rewrites unconditionally; the
`valOf` is only illustrative, prefer leaving `unCong` untouched and adding
`genUnCong` alongside.)

`src/marker/markerLib.sig` — add:

```sml
val mk_marker_const : string -> term
val genmktagged     : thm -> string -> thm
val gendest_tagged  : term -> thm -> string option
val genCong         : thm -> thm -> thm
val genUnCong       : term -> thm -> thm -> thm option
```

### Step 2 — rewrite `clasetLib` marker plumbing to consume markerLib

Replace `clasetLib.sml:612-658` with calls into markerLib:

```sml
open markerLib   (* or qualified markerLib.* below *)

fun mk_marker_const name = markerLib.mk_marker_const ... (* see Step 4 *)

val SIntro = genCong clasetMarkerTheory.SIntro_def   (* Option A: still clasetMarker *)
val Intro  = genCong clasetMarkerTheory.Intro_def
...  (* SElim/Elim/SDest/Dest likewise *)

val destSIntro = genUnCong SIntro_t clasetMarkerTheory.SIntro_def
...

(* name-carrying "exclude a rule by name" tag: reuse markerTheory.Exclude *)
val Del     = markerLib.Excl        (* was clasetLib.Del      *)
val destDel = markerLib.destExcl    (* was clasetLib.destDel  *)
```

Delete clasetLib's private `mk_thm_marker`, `dest_thm_marker`, `Del`,
`destDel`, and the `Del_t` const.  `process_claset_tags` (`:683`) already
calls `destDel`; it now resolves to `markerLib.destExcl`, same
`string option` result.

### Step 3 — drop `Del` from `clasetMarker`

Remove `Del_def` from `clasetMarkerScript.sml:14` (now `markerTheory.Exclude`
is used).  Verify no `.dat`/theory consumer references `clasetMarker$Del`.

### Step 4 — the six kind-constants (per §2 decision)

- **Option A:** leave `SIntro_def … Dest_def` in `clasetMarkerScript.sml`
  (`:7-12`); add the missing OpenTheory maps so they vanish on export,
  mirroring `markerScript.sml:120`:

  ```sml
  val _ = OpenTheoryMap.OpenTheory_const_name
    {const = {Thy = "clasetMarker", Name = "SIntro"}, name = (["Unwanted"], "id")};
  (* … Intro, SElim, Elim, SDest, Dest … *)
  ```
  Keep `mk_marker_const name = prim_mk_const {Thy = "clasetMarker", Name = name}`
  in clasetLib for the six constants.

- **Option B (owner-approved follow-up):** move the six `new_definition`s
  and their OpenTheory maps into `src/marker/markerScript.sml` (beside
  `Cong_def`/`Exclude_def`), export their `_def`s and `mk_…`/`dest…`
  wrappers from markerLib, delete `clasetMarkerScript.sml` and its
  `Holmakefile` entry, and drop the `clasetMarker` dependency from
  `clasetLib`.  Rebuild everything downstream of `src/marker`.

---

## 4. Risks

- **Ordering / dependency:** `clasetLib` already depends on `boolLib`
  (transitively on `markerTheory`/`markerLib`), so consuming markerLib adds
  no new cross-band dependency for Option A.  Option B edits a base theory —
  wide rebuild, owner sign-off required.
- **`unCong` totality:** do **not** change `markerLib.unCong`'s existing
  unconditional-rewrite behaviour; add `genUnCong` alongside rather than
  redefining `unCong` through it.  simpLib/BasicProvers depend on the
  current `unCong`.
- **OpenTheory:** adding the `Unwanted.id` maps is behaviour-affecting only
  for OpenTheory export of theories that persist claset markers — a strict
  improvement (today they would leak).

## 5. Validation
- `selftest.sml:1339+` round-trips every marker
  (`SIntro/Intro/…/Dest` via `genCong`+`genUnCong`, and `Del`/`destDel` via
  `Excl`/`destExcl`); must pass unchanged with the new implementations.
- Rebuild `src/marker` selftest (markerLib changes) and `src/auto/rules`
  selftest.
- `bin/build -t --seq=tools/sequences/upto-auto` for the cross-theory
  `theory_tests/` and (Option B) the wider rebuild.
- `h4pedant` clean; no TABs, < 80 columns.

## 6. Definition of done
- clasetLib owns **no** marker combinators — `mk_thm_marker`/
  `dest_thm_marker`/`Del`/`destDel` deleted, all plumbing via markerLib.
- `Del` gone; excludes go through `markerTheory.Exclude`.
- OpenTheory maps present for every claset marker constant.
- Both selftests green; `theory_tests/` reconstruction green.
- Option B recorded as an owner-decision follow-up if not taken now.
