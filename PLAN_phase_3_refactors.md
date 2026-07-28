# Phase 3 refactor plan — `/simplify` findings deferred from the clasimp pass

Date: 2026-07-27.  Branch: `isabelle-tactics`.  Parent plan:
`PLAN_phase_3.md` (amends D28–D30, D37).

The `/simplify` pass over `origin/isabelle-tactics...HEAD` (16 commits,
the clasimp layer) applied the mechanical cleanups directly and
deferred four items as owner decisions.  Those decisions are now taken
(D40–D43, §0.1) and this plan implements them.

All `src/…:line` references were verified on 2026-07-27 against the
tree *after* the `/simplify` fixes landed (§6).  Line numbers in
`clasimpLib.sml` therefore differ from those in `PLAN_phase_3.md`.

---

## 0. Owner decisions

### 0.1 Taken 2026-07-27 (record in `PLAN.md` §2 as D40–D43)

| # | Decision |
|---|---|
| **D40** | **`[iff]` installs into `srw_ss` exactly as the `simp` settype does.**  The `"iff"` settype gains a `thy_finaliser` that batches one theory's deltas into a single `simpLib.named_rewrites_with_names <thyname>` fragment plus `BasicProvers.temp_delsimps` for the retractions, replacing one `named_rewrites` fragment and one `diminish_srw_ss` call per declaration.  The rewrite carries the declaring theorem's kernel name, so `Excl`, `delsimps` and `temp_delsimps` reach `[iff]` rewrites exactly as they reach `[simp]` ones.  This is a deliberate capability addition, consistent with the parity goal. |
| **D41** | **The iff rule derivation belongs to the rules layer.**  `iff_declaration`'s rule half moves into `clasetLib` as `iff_rules`; `clasetLib.injectivity_contribution` registers **both** halves of each injectivity conjunct; `clasimpLib`'s `clasimp-constructor-intros` contribution and the shared `clasetLib.tyinfo_stem` export are withdrawn.  **Consequence, accepted**: the base claset gains the safe constructor-intro rules, so `CS_SAFE_TAC`/`CS_CLARIFY_TAC`/`BLAST_TAC` become correspondingly stronger and exact-residue assertions in `classical/selftest.sml` and `blast/selftest.sml` move. |
| **D42** | **One argument classifier in `clasetLib`.**  `classify_simp_args` performs the single traversal over the simp-marker vocabulary; `invocation_facts` and `clasimpLib.process_clasimp_args` both consume it and keep their own layer policy (§3.2).  The two hardcoded `Simp`/`Iff` rejection arms collapse into one data-driven check. |
| **D43** | **`add_simp_wrapper` carries the simp-control list.**  `clasimpLib.add_simp_wrapper : simpset -> thm list -> claset -> claset` (likewise `add_safe_simp_wrapper`); the `_with` suffix and the `[]`-defaulting pair disappear.  Callers pass `[]` explicitly. |

### 0.2 Decided in this plan (not owner-level)

- **The six `CS_*`/public tactic pairs stay written out.**  Each is a
  documented public entry point with its own Docfile; a generator would
  hide the surface it exists to expose.  The duplicated name literals
  are the error-message text and are kept.
- **`Simp`/`Iff` stay in `clasetMarkerScript.sml`.**  Their meaning is
  simpset-side, but `clasetLib` must `destSimp`/`destIff` them to
  reject them, and the rules layer may not depend on `src/simp`
  (`src/auto/rules/Holmakefile` has no `INCLUDES`).  Under D42 the
  rejection is data-driven, so the placement no longer costs anything.
- **`distinct_elim_rule` / `distinctness_contribution` are untouched.**
  There is no duplication there — `clasimpLib` never derives
  distinctness rules.  D41 is scoped to injectivity.
- **The `theory_tests` fragment-name helpers move to a shared support
  module**, not to a new `clasimpLib` export (§2.4).  Test-only
  convention should not widen a public signature.
- **Selftest ergonomics**: make the four wrapper-rung tests
  table-driven and add the `local_clasimp` / `probe_goal` helpers,
  following the shape the `force_*` batteries already use.
- **`ListPair.allEq` stays.**  It is the established convention across
  the pre-existing `src/auto` selftests; converting to
  `Portable.list_eq` is a directory-wide change, out of scope.

### 0.3 Correction to the review that produced this plan

The `/simplify` altitude finding claimed `process_clasimp_args`
"diverges" from `invocation_facts` by not calling
`markerLib.dest_generic_simp_wrapper`.  **That claim is wrong and D42
must not act on it.**  Verified at `markerLib.sml:143-174`:
`dest_generic_simp_wrapper` unwraps `Req0`/`ReqD`/`BOUNDED` to their
payload, and `is_generic_simp_marker` covers those same wrappers.  So

- a simpset-less engine *must* unwrap (`Once th` is useful to
  `CS_SAFE_TAC` only as the bare fact `th`), and
- a simpset-carrying engine *must not* (`Once th` has to reach
  `asm_full_simp`'s `process_tags` still wrapped, or the bound is
  lost).

Both layers are already correct.  D42 therefore shares only the
*traversal and vocabulary dispatch*; the unwrap/reject policy stays per
layer (§3.2).

---

## 1. Already applied (context — no work here)

The `/simplify` pass landed these on the branch; every task below
assumes them:

- `clasetLib.INSERT_FACTS_TAC` (`clasetLib.sml:899`), consumed by
  `tableauLib.invoke`, `tableauLib.tryIt`, `classicalLib.public_raw`,
  `clasimpLib.process_clasimp_args`.
- `clasetLib.tyinfo_stem` and `clasetLib.normalise_rule_name` exported;
  the `clasimpLib` copies deleted.  **D41 withdraws the `tyinfo_stem`
  export again** (§2.2).
- The redundant `retract_iff_declaration` on every install removed
  (`clasimpLib.sml:234-254`), guarded by `Symtab.defined db`.
- `must_close` → `Tactical.check_delta`; `undisch` → `Lib.funpow …
  Drule.UNDISCH`; `foldr DISCH` → `Lib.itlist DISCH`; `Lib.enumerate` →
  `Lib.mapi`; the three-way argument accumulator → a `List.foldl`
  classifier; the per-rule `simpLib.++` fold → one `rewrites` call.
- `tools/sequences/more-theories`: the redundant `src/auto/clasimp`
  line dropped (it is in `SRCRELNAMES`).

---

## 2. D40 — batch and name the `[iff]` simpset view

### 2.1 Current mechanism and its three costs

`clasimpLib.sml:192-276`.  Each declaration becomes its own ssfrag
`__clasimp_iff_<Thy$Name>` pushed with `BasicProvers.augment_srw_ss`;
retraction is `BasicProvers.diminish_srw_ss`; `thy_finaliser = NONE`.

1. `AncestryData` applies deltas one at a time when there is no
   finaliser (`src/parse/AncestryData.sml:277-279`:
   `List.app (update_global_value o apply_to_global) ds`).  One global
   mutation and one permanent `ADDFRAG` history entry per iff theorem
   per load.  Both neighbours batch: `BasicProvers.finaliser`
   (`BasicProvers.sml:1190`) and `clasetLib.batch_finaliser`
   (`clasetLib.sml:593`).
2. `diminish_srw_ss0` (`BasicProvers.sml:1231`) calls `init_state`
   unconditionally and `simpLib.remove_ssfrags` (`simpLib.sml:1061`)
   rebuilds the simpset from its whole history via
   `build_from_history`.  `temp_delsimps0` (`BasicProvers.sml:1237`)
   has a lazy path and reaches `-*` (`simpLib.sml:404`), which only
   filters the net and dprocs.
3. `named_rewrites` yields `(NONE, thm)` pairs, so the rewrite has no
   `thname`.  `Excl "Thy.name"` resolves via `process_tags` →
   `result -* [name]` → `filter_net_by_names` (`simpLib.sml:384`),
   which matches on `thname`.  `[iff]` rewrites are therefore not
   excludable today; `[simp]` ones are.

### 2.2 Target

Replace `install_persistent_iff` / `retract_iff_declaration` /
`apply_iff_to_global` with a finaliser-shaped pair:

```sml
(* delete key for simpLib: "Thy.Name" (simpLib convention).
   db key and claset rule names stay "Thy$Name" (clasetLib
   convention).  The two namespaces are deliberately distinct. *)
fun simp_delete_key (kname : KernelSig.kernelname) =
  #Thy kname ^ "." ^ #Name kname

fun iff_finaliser {thyname} deltas db = ...
```

**Finaliser semantics** (last declaration for a name wins within a
theory; specify and test this):

1. `touched` = the kernel names appearing in `deltas`.
2. `stale` = `touched` filtered by `Symtab.defined db` — names with a
   live view inherited from an ancestor, or re-declared in this
   theory.  Emit `BasicProvers.temp_delsimps (map simp_delete_key
   stale)` and one `clasetLib.augment_claset` composing
   `remove_iff_rules` over them.
3. `live` = for each touched name, its final state in `deltas`
   (`ADD th` → install `th`; `REMOVE` → nothing).
4. Emit **one** `simpLib.named_rewrites_with_names thyname
   [(kname, rewrite), …]` fragment for `live`, pushed with one
   `augment_srw_ss`; and **one** `clasetLib.augment_claset` composing
   every `add_rule` for `live`.
5. Return `List.foldl apply_iff_delta db deltas` — the db update is
   unchanged, so `theory_tests`' db-level expectations do not move.

Steps 2 and 4 are ordered deletes-then-adds, which is why step 3 must
resolve intra-theory sequences first.  (Upstream `BasicProvers.finaliser`
emits adds-then-removes and accepts the resulting remove-then-add
anomaly; we do not need to inherit that.)

`apply_iff_to_global` stays for the interactive path (a `Theorem…[iff]`
in the current theory, and `remove_iff`), keeping the
`Symtab.defined db` guard already applied, but switching its retraction
from `diminish_srw_ss` to `temp_delsimps` and its installation to a
one-element `named_rewrites_with_names` fragment named for the current
theory.

`iff_fragment_name` (`clasimpLib.sml:192`) is deleted — fragments are
now named per theory, not per declaration.

### 2.3 What this buys

- One fragment and one history entry per *theory*, not per theorem.
- Retraction never forces the SRW simpset and never replays history.
- `simp [Excl "myThy.my_iff_thm"]`, `delsimps` and `temp_delsimps`
  reach `[iff]` rewrites.

### 2.4 Test consequences

`__clasimp_iff_<name>` disappears, so the four copies of the
fragment-name probe must go:

- `src/auto/clasimp/selftest.sml:289-291` (`has_iff_fragment`)
- `theory_tests/iffRoundTripBaseScript.sml:16-19` (`has_fragment`)
- `theory_tests/iffRoundTripChildScript.sml:16-19` (idem)
- `theory_tests/iffDiamondChildScript.sml:16-19` (idem)

Each is paired with a `has_rule` copy (e.g.
`iffRoundTripBaseScript.sml:11-15`) over the claset side, which is
unaffected by D40 but should move into the same support module.

Replace with a shared `theory_tests/iffTestSupport.sml` exporting
`has_iff_rewrite : string -> bool` and `has_iff_rules : string -> bool`,
the former implemented over the rewrite's `thname`
(`simpLib.frag_rewrites` / the net), **not** over `ssfrag_names_of`,
plus the same helpers inlined once in `clasimp/selftest.sml`.  Add the
Holmakefile dependency.

Unaffected: `"__clasimp_iff_arg_"` (`clasimpLib.sml:307`) names the
*temporary* claset rules derived from an `Iff th` tactic argument.  It
is a claset rule-name prefix, not a fragment name, and D40 does not
touch it.

New tests:

- `Excl "<thy>.<name>"` disables an `[iff]` rewrite for one invocation
  and leaves the claset rules in place.
- `delsimps` on an `[iff]` name removes the rewrite persistently.
- A theory declaring N iff theorems contributes **one** entry to
  `ssfrag_names_of (srw_ss())` (the batching assertion).
- Declare-then-`remove_iff` within one theory: the child theory sees
  neither view (the intra-theory ordering rule, §2.2 step 3).

### 2.5 Docfiles

`help/Docfiles/clasimpLib.iff.smd` — the "declaration is inherited …
views are rebuilt when declarations are replayed" paragraph gains a
sentence that the simpset view is an ordinary named rewrite, reachable
by `Excl`/`delsimps` under the theorem's `Thy.name`.
`clasimpLib.remove_iff.smd` — cross-reference `delsimps` as the
simpset-only alternative.

---

## 3. D41 — move the iff rule derivation into `clasetLib`

### 3.1 Current duplication

- `clasimpLib.iff_declaration` (`clasimpLib.sml:83-141`) returns
  `{rules : (rulespec * (string * thm)) list, rewrite : thm}`.  **No
  simpLib type occurs in it**, so the rules/⊥simp layering does not
  block the move.
- `clasetLib.iff_dest_rule` (`clasetLib.sml:669`) is the dest half of
  the same derivation, reached through `canonical_rule` +
  `fresh_outer_vars` rather than `SPEC_ALL` + `rotate_major` +
  `GEN_ALL`.  Both are private to `clasetLib.sml` — verified no other
  caller in `src/auto`.
- `clasimpLib.constructor_intro_contribution` (`clasimpLib.sml:143-169`)
  runs the *full* derivation for every injectivity conjunct of every
  datatype, then `List.filter`s the dest half away because
  `clasetLib.injectivity_contribution` (`clasetLib.sml:702`) already
  produced it.  That is a 2× overpay on every claset catch-up sweep
  (`collect_typebase_rules`, `clasetLib.sml:510`), and it is the only
  reason `tyinfo_stem` had to become shared API.

### 3.2 Target

1. Move the rule half verbatim into `clasetLib` as

   ```sml
   val iff_rules : string -> thm -> (rulespec * (string * thm)) list
   ```

   carrying `rotate_major`, `undisch_prems` and the three-way
   conclusion analysis unchanged.
2. `clasimpLib.iff_declaration name th =
   {rules = clasetLib.iff_rules name th, rewrite = Drule.SPEC_ALL th}`
   — the exported record shape and `clasimpLib.sig:16-20` are
   unchanged.
3. Rewrite `injectivity_contribution` to call `iff_rules (stem ^ i)`
   and keep **both** halves.  Delete `iff_dest_rule`.
4. Delete `clasimpLib.constructor_intro_contribution` and its
   `register_tyinfo_contribution` call (`clasimpLib.sml:170-172`);
   withdraw `clasetLib.tyinfo_stem` from the signature and make it
   private again.

### 3.3 Consequences to absorb

- **Rule names change**: the injectivity dest rule goes from
  `__claset_tyinfo_<thy>_<tyop>_inject_<i>` to
  `…_inject_<i>_dest`, and the intro half is `…_inject_<i>_intro`
  (which is what clasimp already produced).  `rules/selftest.sml` and
  `clasimp/selftest.sml:355-380` assert on these names.
- **The base claset gains safe constructor intros.**  This is the
  accepted D41 cost.  Expect movement in the exact-residue assertions
  of `classical/selftest.sml` and `blast/selftest.sml`.  Per
  `src/auto/CLAUDE.md`, residues are *specified* behaviour: each moved
  assertion must be re-derived and justified in the commit message as
  a strength gain, never loosened to make the gate pass.
- **Verify the dest halves agree.**  `iff_dest_rule` and `iff_rules`'
  dest branch handle variables differently (`canonical_rule` +
  `fresh_outer_vars` vs `SPEC_ALL` + `GEN_ALL`).  Before deleting
  `iff_dest_rule`, add a temporary differential check over
  `TypeBase.elts ()` asserting `canonical_rule`-equality of the two
  dest rules for every injectivity conjunct in the built theories; keep
  it as a permanent selftest if it is cheap, otherwise delete it once
  green and record the result here.

  **Result (2026-07-27):** the initial verbatim move exposed a binder-order
  difference (`∀x x'. INL x = INL x' ⇒ x = x'` versus the reversed
  generalisation order).  `iff_rules` now preserves source binder order
  before generalising remaining conclusion-only variables.  The permanent
  `rules/selftest.sml` differential check passes over every injectivity
  conjunct in `TypeBase.elts ()`.

### 3.4 Docfiles

`help/Docfiles/clasetLib.smd` — the TypeBase-contribution description
gains the constructor-intro half.  Audit
`help/Docfiles/classicalLib.SAFE_TAC.smd` (it already mentions
constructors) and the `tableauLib.BLAST_TAC.smd` strength notes.

---

## 4. D42 — one argument classifier

### 4.1 Target

In `clasetLib`:

```sml
type simp_arg_split =
  {simp_rules : thm list,       (* destSimp payloads *)
   iff_rules : thm list,        (* destIff payloads *)
   simp_controls : thm list,    (* generic markers, still wrapped *)
   rest : thm list}
val classify_simp_args : thm list -> simp_arg_split
```

One traversal, order preserved within each bucket, no unwrapping.

Consumers keep their own policy (§0.3):

- `invocation_facts` (`clasetLib.sml:870`) — unwrap each argument with
  `markerLib.dest_generic_simp_wrapper` **first**, then classify, then
  raise if `simp_rules` or `iff_rules` is non-empty (**keep the two
  distinct messages**: `classical/selftest.sml:1980`'s
  `tactic_error_message` asserts them), discard `simp_controls`, return
  `rest`.
- `clasimpLib.process_clasimp_args` (`clasimpLib.sml:286`) — classify
  the raw list; iff rules into `base_cs` via `add_iff_declaration`;
  `process_claset_tags rest iff_cs`; `simp_controls` straight through
  to the body as `simp_args`.  This preserves today's
  iff-before-claset-tags insertion order, which the claset candidate
  tie-break depends on.

Delete `clasimpLib`'s private `classify` (`clasimpLib.sml:289-295`) and
`clasetLib`'s `reject_simpset_marker` arms.

### 4.2 Notes

- `process_claset_tags` (`clasetLib.sml:851`) passes unrecognised
  markers through to its leftovers, so the relative order of tag
  processing and simp classification is immaterial to correctness; both
  call sites nevertheless keep their current order so that rule
  insertion order — which *is* observable — does not move.
- `clasetLib.sig:94`'s `invocation_facts` export gains its first
  external justification only if a future engine needs it; it stays
  exported as the documented companion to `invocation_claset`.  If the
  differential work in §3.3 finds no user by the end of this plan,
  drop it from the signature.

---

## 5. D43 — `add_simp_wrapper` carries the control list

`clasimpLib.sml:56-81`: rename `add_simp_wrapper_with` →
`add_simp_wrapper` and `add_safe_simp_wrapper_with` →
`add_safe_simp_wrapper`; delete the two `[]`-defaulting wrappers.
Update `clasimpLib.sig:9-12` to
`simpLib.simpset -> thm list -> clasetLib.claset -> clasetLib.claset`.

Internal call sites (`auto_with`, `force_with`, `search_with_simp`,
`clarsimp_with`) already pass `simp_args`, so they only lose the
`_with` suffix.

Docfiles: `help/Docfiles/clasimpLib.add_simp_wrapper.smd:5-6` and
`clasimpLib.add_safe_simp_wrapper.smd:6` — new signature, plus a
sentence and an example showing `Excl`/`Cong`/`SF` reaching the
embedded simp step.  Selftest: extend the wrapper-rung battery
(§0.2) with one case passing a non-empty control list and asserting it
takes effect.

---

## 6. Task order and gates

Independent items first, the claset-perturbing one last.

| # | Task | Touches |
|---|---|---|
| T1 | D43 wrapper API + Docfiles + selftest control case | `clasimp/{clasimpLib.sig,clasimpLib.sml,selftest.sml}`, 2 Docfiles |
| T2 | Selftest ergonomics (§0.2): table-driven wrapper rungs, `local_clasimp`/`probe_goal` | `clasimp/selftest.sml` |
| T3 | D42 classifier | `rules/clasetLib.{sig,sml}`, `clasimp/clasimpLib.sml` |
| T4 | D40 finaliser + named rewrites + `temp_delsimps` retraction | `clasimp/clasimpLib.sml` |
| T5 | D40 test support module + new tests + Docfiles | `clasimp/theory_tests/*`, `clasimp/selftest.sml`, 2 Docfiles |
| T6 | D41 move `iff_rules`, both injectivity halves, differential check | `rules/clasetLib.{sig,sml}`, `clasimp/clasimpLib.sml` |
| T7 | D41 fallout: re-derive moved residue assertions | `classical/selftest.sml`, `blast/selftest.sml`, `rules/selftest.sml`, `clasimp/selftest.sml`, `clasetLib.smd` |

**Gate after each task** — in the changed directory:

    Holmake && ./selftest.exe

**`Holmake` alone is not a gate here.**  `src/auto/classical`,
`src/auto/blast` and `src/auto/clasimp` have no theory script, so
`Holmake` exits 0 on a type error; the error only surfaces when
`selftest.exe` loads.  (This bit during the `/simplify` pass:
`Drule.UNDISCH` mis-spelled as `UNDISCH` compiled "clean".)
`src/auto/rules` fails loudly because `clasetSeedScript.sml` forces it.

**Gate after T3, T5 and T7**:

    bin/build -t --seq=tools/sequences/upto-auto

plus `Holmake` in `rules/theory_tests` and `clasimp/theory_tests`.

**Gate before the plan is done**: `bin/build -F -t` (Docfile changes
and the base-claset change under D41 both warrant it).

---

## 7. Risks

- **T6 is the one that can go long.**  If the moved residue
  assertions turn out to be *weakenings* rather than strength gains in
  any case, stop and report — D41 is then wrong and B2 (derivation
  moves, registration stays in clasimp) is the fallback.  Do not
  adjust an assertion to keep the gate green.
- **T4 intra-theory ordering** (§2.2 step 3) is the subtle part.  The
  `iffDiamond*` and `iffRoundTrip*` scenarios cover ancestry but not
  declare-then-remove inside one theory; that test is new and should be
  written first.
- **`temp_delsimps` records a `DELETE_EVENT` in the simpset history**
  (`simpLib.sml:404-412`).  Repeated add/remove cycles grow the history
  on the delete side, so it is a smaller leak, not zero.  Acceptable:
  `remove_iff` is a rare interactive operation, and the batching in
  T4 removes the per-declaration growth that matters.
- **D40 changes an existing named-fragment convention.**  Verified
  2026-07-27: `grep -rn __clasimp_iff_ src/ help/ tools/` hits only the
  four test copies listed in §2.4, `clasimpLib.sml:192`
  (`iff_fragment_name`, deleted by T4) and `clasimpLib.sml:307` (the
  unrelated `_arg_` rule prefix).  Nothing outside `src/auto/clasimp`
  depends on the convention.
