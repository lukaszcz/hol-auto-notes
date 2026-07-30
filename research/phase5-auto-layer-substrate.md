# `src/auto` layer substrate for Phase 5 (linarith)

> Research report, 2026-07-30, Phase 5 planning round (prior to owner
> decisions D59–D62 and `../PLAN_phase_5.md`).  HOL4 citations refer
> to worktree HEAD `7a8a286b5`.  Produced by a survey agent; findings
> verified against the working tree.

## 1. The D28 clasimp cache

`src/auto/clasimp/clasimpLib.sml:8-27` — the whole cache:

```sml
val safe_solver =
  simpLib.mk_tactic_solver
    ("clasimp safe",
     Tactical.FIRST
       [Tactical.FIRST_ASSUM Tactic.ACCEPT_TAC,
        Tactic.REFL_TAC,
        Tactic.ACCEPT_TAC boolTheory.TRUTH,
        Tactical.FIRST_ASSUM Tactic.CONTR_TAC])

fun derive_clasimp_ss ss _ =
  ss
  |> simpLib.set_cond_depth 40
  |> (fn ss' => simpLib.++ (ss', simpLib.split_ss))
  |> simpLib.set_safe_solvers [safe_solver]

val {get = clasimp_ss, set = _} =
  BasicProvers.make_simpset_derived_value
    derive_clasimp_ss simpLib.empty_ss
```

Exported (`clasimpLib.sig:10,12`): `safe_solver : Traverse.ssolver`,
`clasimp_ss : unit -> simpLib.simpset`.  Base = `srw_ss()` supplied by
the deriver's caller; **no unsafe solvers are set today** — the
linarith solver would be the first entry in that slot, added as one
extra pipe stage at `clasimpLib.sml:17-21`.

Invalidation — `BasicProvers.sml:1364-1378`
(`make_simpset_derived_value`, sig at `BasicProvers.sig:56-57`) with
the global stale-flag list `BasicProvers.sml:1168-1170` (`notify()` on
every `srw_ss` mutation).  The cache is lazily rebuilt on the next
`clasimp_ss()` after any `srw_ss` change — but it is **blind to
changes in any other settype the deriver reads**; aesop added a
generation counter for exactly that (§2).  A linarith solver that
reads `[arith]` dynamically at invocation avoids needing one.

Dependency direction: clasimp would gain `INCLUDES +=
$(HOLDIR)/src/auto/linarith`, so linarith must not depend on clasimp.

## 2. `aesopData.aesop_ss` (D50)

`src/auto/aesop/aesopData.sml` (88 lines);
`aesopData.sig:5`: `val aesop_ss : unit -> simpLib.simpset`.

- Lines 8-24: `aesop_simp_generation : int Sref.t`;
  `apply_aesop_simp_delta` (ADD-only, REMOVE raises);
  `apply_aesop_simp_to_global` bumps the generation.
- Lines 26-46: collision guard + `export_with_ancestry
  {settype = "aesop_simp", ...}`; `aesop_simp_rewrites () =
  #get_global_value aesop_simp_data ()`.
- Lines 48-63: the derived cache —

```sml
type cached_simpset = {generation : int, simpset : simpLib.simpset}

fun derive_aesop_ss ss _ : cached_simpset =
  {generation = Sref.value aesop_simp_generation,
   simpset =
     ss
     |> simpLib.set_cond_depth 40
     |> simpLib.set_safe_solvers [clasimpLib.safe_solver]
     |> (fn ss' =>
          simpLib.++ (ss', simpLib.rewrites (aesop_simp_rewrites ())))}
```

  (base = `srw_ss()`; **no `split_ss`**).
- Lines 65-83: two-level invalidation — the `BasicProvers` stale flag
  covers `srw_ss` changes; the generation number covers
  `[aesop_simp]` changes, compared on every `aesop_ss()` call.
- Lines 85-86: trace registration `("aesop", aesop_trace, 3)`.

Consumers: `aesopLib.sml:225,234` (tactics), `aesopRule.sml:331-341`
(`simp_rule` builds `aesop_ss() ++ rewrites simp_rules`).

Linarith enters at `aesopData.sml:56-63` (one pipe stage for the
unsafe solver).  Caveats: (a) do not put linarith in
`set_safe_solvers` — norm rules must stay ≤ 1 subgoal and
deterministic; the unsafe slot already serves side conditions in
safe-mode invocations (D15); (b) if `[arith]` facts were *baked into*
`aesop_ss`, `cached_simpset` would need an arith generation field —
avoided by the dynamic-solver design.  `aesopData` already depends on
`clasimpLib` (`aesop/Holmakefile:2-6`), so a linarith include added to
clasimp is automatically visible to aesop.

## 3. ThmSetData fact-set pattern (to copy for `"arith"`)

Closest analogue for an additive fact list: `aesop_simp`
(`aesopData.sml:26-46`) — collision guard first (layer convention,
mirrored from splitLib), then `export_with_ancestry`, then a
`#get_global_value` accessor.

Keyed variant supporting REMOVE: `[split]`
(`splitLib.sml:92-117`) over `thm Symtab.table` keyed by
`persistent_name = KernelSig.name_toString` (`splitLib.sml:60`), with
`remove_name` (83-90) accepting `Thy$Name` and bare names via
`ThmSetData.toKName`, and shape validation (`is_asm_split`) on ADD.

Third shape: clasimp's `[iff]` (`clasimpLib.sml:297-320`) uses
`thy_finaliser = SOME iff_finaliser` because derived views (claset +
simpset) are recomputed per theory batch — only needed if `[arith]`
derived non-trivial views (it does not).

Mechanics (`src/1/ThmSetData.sig`): `setdelta = ADD of thname * thm |
REMOVE of string` (:8); `'value ops` record (:26-30);
`export_with_ancestry` (:31-33) returning an
`AncestryData.fullresult` (`src/parse/AncestryData.sig:8-16`:
`merge`, `DB`, `get_deltas`, `record_delta`, `parents`,
`set_parents`, `get_global_value`, `update_global_value`);
`current_data`/`theory_data`/`all_set_types` (:19-24).

**The attribute is auto-registered** from the settype name
(`ThmSetData.sml:293-296`), so settype `"arith"` gives `[arith]` for
free — but `store_attrfun`/`local_attrfun` (:269-285) **reject
attribute arguments**; an `[arith=n]` surface would need the
hand-rolled path (`clasetLib.register_checked_rule_attribute`,
`clasetLib.sml:1002-1011`).

Manual retraction pattern (`clasimpLib.sml:349-355`):
`#record_delta data delta; #update_global_value data (apply delta)`.

Round-trip test scaffolding to copy:
`src/auto/aesop/theory_tests/aesopSimpRoundTripBaseScript.sml` and
`...ChildScript.sml`, plus `src/auto/aesop/selftest.sml:15-20`
(settype + attribute registration assertion).

## 4. Build integration

Three declaration points (aesop commit `406b4efd6` is the exact
template — it touched only Docfiles, `parallel_builds/core/
Holmakefile`, and `tools/sequences/upto-auto`):

1. `src/parallel_builds/core/Holmakefile:4-5` `SRCRELNAMES`
   (`bin/build -F` band; `INCLUDES = $(patsubst
   %,../../%,$(SRCRELNAMES))` line 25).
2. `tools/sequences/upto-auto` (kernel + core-theories + the five
   auto dirs + `!.../theory_tests` entries).
3. `tools/sequences/more-theories` (only `theory_tests` subdirs; main
   dirs come via `src/parallel_builds/core`).  Leading `!` = selftest
   level threshold (`tools/build/buildutils.sml:189-192`, consumed at
   :734-735): `!dir` builds only under `-t`, `!!dir` at level ≥ 2.

The uncommitted `tools-poly/build.sml` / `tools/build/build.sml`
changes in the worktree are the HolLex staleness guard — unrelated to
directory registration; **Phase 5 needs no `build.sml` change.**

Holmakefile shape (canonical: `src/auto/clasimp/Holmakefile`, 23
lines): `HOLHEAP = $(HOLDIR)/bin/hol.state0` pin; explicit
`INCLUDES`; `all: $(DEFAULT_TARGETS) selftest.exe`; hand-spelled `.uo`
deps; `$(HOLMOSMLC) -o $@ $<`; `ifdef HOLSELFTESTLEVEL` log block
(`$(tee ./selftest.exe 2>&1,$@)`); `EXTRA_CLEANS`.  `rules/` adds the
OpenTheory block (`ifeq ($(KERNELID),otknl)` → `%.ot.art` from
`*Script.sml`) — copy it wherever theory scripts ship.  No `OPTIONS`
anywhere in the layer.

Selftest log names per dir: rules `ntactical-selftest.log`, classical
`classical-selftest.log`, blast `blast-selftest.log`, clasimp
`clasimp-selftest.log`, aesop `aesop-selftest.log` (⇒ linarith:
`linarith-selftest.log`).  `bin/build -t` exports `HOLSELFTESTLEVEL`
(`buildutils.sml:1394-1398`).  `theory_tests/` subdirs: own
Holmakefile, `INCLUDES = ..`, `HOLHEAP` pin; `rules/theory_tests` also
runs phony driver EXEs (`reloadCheck.exe`/`stateReplayCheck.exe`) —
the pattern for fresh-process reload checks.

## 5. Marker vocabulary

Term-level markers: `src/auto/rules/clasetMarkerScript.sml:1-19`
(theory `clasetMarker[bare]`): `SIntro Intro SElim Elim SDest Dest
Simp Iff Norm Forward SForward` as `mk x = x` definitions, `Del` as
`Del (x:'a) = T`, each with an OpenTheory `Unwanted.id` mapping
(:21-53; `Del` none).

ML side: `clasetLib.sml:1052-1096` (constructors via
`markerLib.genCong`/`genUnCong`/`genmktagged`); public
`clasetLib.sig:115-139`.  Classification (D42) `clasetLib.sig:149-154`:

```sml
type simp_arg_split =
  {simp_rules : thm list, iff_rules : thm list,
   simp_controls : thm list, rest : thm list}
val classify_simp_args : thm list -> simp_arg_split
```

impl `clasetLib.sml:1145-1177` (order-preserving buckets).  Related:
`process_claset_tags` (`clasetLib.sml:1118-1143`, sig:141);
`aesop_markers`/`check_aesop_markers` (`clasetLib.sml:1179-1205`) —
**raises** `"<name> marker requires an Aesop-aware tactic"`; the
precedent for rejecting markers a tactic does not consume.
`invocation_claset` (sig:159); `INSERT_FACTS_TAC` (sig:167; facts land
at the most-recent end of the assumption list).

Recommendation adopted by the plan: `LINARITH_TAC : thm list ->
tactic` goes through the D30 uniform-insertion path with no new
`clasetMarker` constant; a new marker would require a theory change in
`rules/`, a `simp_arg_split` record change (signature-breaking for all
consumers), and a reject-list entry elsewhere.  The existing
`Split th` marker covers the per-invocation split-rule role.

## 6. Docfiles convention

Names: `<structure>.<identifier>.smd`; bare `<structure>.smd` for the
overview page; attribute pages under the owning structure
(`clasimpLib.iff.smd`).  Existing layer entries: `aesopLib.*` (6),
`clasimpLib.*` (tactics + `CS_*` + `iff`/`remove_iff` +
`add_simp_wrapper`/`add_safe_simp_wrapper`), `classicalLib.*`
(15 tactics + `CS_*` twins), `tableauLib.*` (5), `clasetLib.smd` +
one per marker.

Required structure (from `clasetLib.Simp.smd`,
`aesopLib.AESOP_TAC.smd`): line 1 verbatim
`>>__ Parse.temp_set_grammars $ valOf $ grammarDB {thyname="hol"};`;
`## \`<identifier>\``; a ```` ```hol4 ```` block with the fully
qualified type (or declaration form for attributes); a 72-hyphen rule;
one-sentence summary; body; `### Failure`; `### Example`
(```` ```hol4 ````); `### See also` with
``[`structure.name`](#structure.name)`` links.  No build registration
needed (`help/Docfiles/` has no Holmakefile).

## 7. Dependency stratification — verified verdict

Rule (`src/auto/CLAUDE.md:69-73`, PLAN §3 constraint 3): layer code
depends only on libraries built before `src/boss`; `rules/` must not
depend on `src/simp`.

Actual `INCLUDES` today: rules — none (sigobj only); classical —
rules + `src/metis`; blast — rules + classical; clasimp — rules,
classical, blast, `src/simp/src`; aesop — those four + clasimp.

Sequence positions: `src/simp/src` at `base-hol:14`, `src/marker` :7,
`src/basicProof` :18, `src/num/arith/src` :36 (numSimps/Cache/Arith —
pre-boss), `src/boss` :57.  **`src/integer`, `src/real`,
`src/rational` appear in NO sequence file** — only as `SRCRELNAMES`
entries (`parallel_builds/core/Holmakefile:12,16,22`), i.e. the
`more-theories` band, strictly after `src/boss`, in the same parallel
bag as `src/auto/*`.  `src/rational/Holmakefile:1` INCLUDES
`../integer ../res_quan/src ../sort`; `src/real` pulls `../integer
../hol88 ../pred_set/src/more_theories ../res_quan/src ../rational
../algebra`.

Verdict: under `bin/build -F` an `INCLUDES` edge from
`src/auto/linarith` to `src/integer` would happen to resolve (Holmake
orders within the parallel bag), but under the routine
`bin/build -t --seq=tools/sequences/upto-auto` gate those directories
are not built at all — a hard no, independent of the stated
constraint.  Hence the split adopted by D60: engine + registry +
`LINARITH_ss` + solver + num instance in `src/auto/linarith`
(`INCLUDES` limited to `src/auto/rules`, `src/simp/src`; num arith
modules are in sigobj by that band); int/real/rat instances in a
separate parallel-band directory registering into the live registry at
load, creating no compile-time edge from the core engine to
`integerTheory` — which is exactly what keeps promotion a sequence
edit.  For D56, `src/auto/linarith` must be inserted into `upto-auto`
**before `src/auto/clasimp`** (clasimp gains the linarith include).

## 8. `src/auto/CLAUDE.md` staleness

Line 63 of `src/auto/CLAUDE.md` still describes `linarith/` as
"generic linear arith, ARITH_TAC registry", and lines for
`presburger/` and `algebra/` survive — all stale w.r.t. D55/D57/D58;
Phase 5 updates them (plan §9).
