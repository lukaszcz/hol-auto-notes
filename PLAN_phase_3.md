# Phase 3 implementation plan — clasimp layer (`src/auto/clasimp/`)

Date: 2026-07-19.  **Revised 2026-07-24** against the delivered tree at
commit `5a1dee9f9` (see §0.2).  Branch: `isabelle-tactics`.  Parent
plan: `PLAN.md` §7.

Port of `Provers/clasimp.ML` semantics over the delivered Phase-0/1/2
classical stack and the delivered Phase-S simplifier: `AUTO_TAC`,
`FORCE_TAC`, `FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`,
`CLARSIMP_TAC`, the `[iff]` attribute, and the `Simp`/`Iff` markers.

All `file.ML:line` references resolve against `.agent-files/sources/`
(mirror-isabelle `f7e02b7e1f31`).  All `src/…:line` references were
re-verified at `5a1dee9f9` on 2026-07-24.  Line-level groundwork:

- `research/phase3-isabelle-clasimp.md` — verified clasimp.ML semantics
  (supersedes the parent plan's §7 sketch in three details, see §1.1).
- `research/phase3-hol4-substrate-classical.md` — delivered
  `src/auto/rules` + `src/auto/classical` + `src/auto/blast` surfaces
  (written pre-D38: read its `fast_tac`-style names as `CS_FAST_TAC`,
  §0.2).
- `research/phase3-simp-substrate.md` — delivered Phase-S `simpLib`
  surface, `srw_ss` machinery, attribute plumbing.
- `research/isabelle-classical-reasoner.md` §§4–6 (pre-existing).

## 0. Owner decisions

### 0.1 Taken for this phase

D28–D34 recorded in `PLAN.md` §2 (2026-07-19); D36–D37 taken at this
revision and recorded in `PLAN.md` §2 (2026-07-24).  D28, D32,
D33 and D34 are restated here **as amended by D36**.

| # | Decision |
|---|---|
| D28 | **Clasimpset**: the stateful clasimp tactics use a cached derived value of `srw_ss()` (`BasicProvers.make_simpset_derived_value`) with the layer configuration applied on top: `cond_depth` 40, the safe-solver stack (§4.2), and `split_ss` (splitter looper).  Context-explicit `CS_*` forms (D36) exist for all tactics.  D19 is not violated: no distribution simpset changes; the clasimpset is layer-local. |
| D29 | **`[iff]` persistence**: a clasimp-owned `ThmSetData.export_with_ancestry` settype `"iff"`.  The delta carries only ADD/RM of the source theorem — the declaration is the single source of truth; both derived views (claset rules, simpset rewrite) are recomputed by the apply hook on every load (`clasetLib.augment_claset` + `BasicProvers.augment_srw_ss`).  Removal is function-based (RM delta), per D12.  The claset `cdelta` v1 schema and the rules/⊥simp layering are untouched. |
| D30 | **Uniform insertion semantics** (revises the Phase-2 plain-theorem convention; freeze amendment): an unmarked theorem in any `src/auto` tactic's `thm list` argument is **inserted into the goal as an assumption** — the exact analogue of Isabelle's chained-fact channel (`using th by auto`), and of HOL4's prover-family habit (`metis_tac`, `PROVE_TAC`).  Each engine then consumes premises natively (simp rewrites with them, classical search matches/eliminates on them, blast makes them branch formulas).  Explicit roles go through markers.  `classicalLib` and `tableauLib` are refactored from plain-as-unsafe-intro to insertion; the marker vocabulary gains `Simp th` and `Iff th`. |
| D31 | **Safe asm-full-simp**: `GEN_GLOBAL_SIMP_TAC` changes signature to take `simp_mode` as its first argument, exactly mirroring `GEN_SIMP_TAC`'s D16 shape (Phase-S freeze amendment; fixes the delivered gap vs `PLAN_phase_S.md` §12's consumption map).  `global_simp_tac` and all other existing entry points keep their signatures via `{safe = false}`.  Clasimp's asm-full-simp is `GEN_GLOBAL_SIMP_TAC` at the D17 mut_impc-parity configuration (`concl_in_fixpoint = true`, `imp_rebuild = true`). |
| D32 | **Bounded depth search**: `classicalLib` additively exports the previously-private saturate + `DEPTH_SOLVE` + replay recipe as `CS_DEPTH_SOLVE_TAC : {dup : bool} -> int -> claset -> ntactic` (Phase-2 freeze amendment); `{dup = false}` is Isabelle's `nodup_depth_tac`, `{dup = true}` is `depth_tac`.  `classicalLib`'s internal uses are refactored onto the same export. |
| D33 | **`AUTO_TAC`'s blast leg**: `tableauLib` additively exports a raw claset-explicit fixed-depth tableau entry `CS_BLAST_DEPTH_TAC : claset -> int -> tactic` — no iterative deepening, no marker/insertion preprocessing — used by `AUTO_TAC`'s inner loop (Phase-2 freeze amendment).  The public `BLAST_TAC`/`BLAST_DEPTH_TAC` packaging is unchanged. |
| D34 | **Names**: module `clasimpLib` in `src/auto/clasimp/`; tactics `AUTO_TAC`, `AUTO_DEPTH_TAC`, `FORCE_TAC`, `FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`, `CLARSIMP_TAC` (all re-verified collision-free by whole-tree grep, 2026-07-24).  Failure semantics: `AUTO_TAC`/`CLARSIMP_TAC` fail exactly when they change nothing (D27 semantics = Isabelle's method-level `CHANGED_PROP`); the FORCE family must close the goal. |
| D36 | *(2026-07-24)* **Context-explicit naming**: the `CS_` prefix denotes a context-explicit entry point across the whole layer, whether the context is a claset or a claset/simpset pair.  Phase 3 therefore exports `CS_AUTO_TAC`, `CS_FORCE_TAC`, `CS_FASTFORCE_TAC`, `CS_SLOWSIMP_TAC`, `CS_BESTSIMP_TAC`, `CS_CLARSIMP_TAC` (all `… -> claset -> simpset -> tactic`), and D32/D33 export `CS_DEPTH_SOLVE_TAC`/`CS_BLAST_DEPTH_TAC`.  This supersedes the lowercase forms named in D28/D32/D33/D34 and brings Phase 3 under the `src/auto/CLAUDE.md` naming rule and D38. |
| D37 | *(2026-07-24)* **Simp-wrapper combinators**: Isabelle's `addss`/`addSss` are named `add_simp_wrapper` / `add_safe_simp_wrapper` (§5), matching the delivered `clasetLib.add_unsafe_wrapper` / `add_safe_wrapper` pair.  The wrapper **slot strings** stay Isabelle's (`"asm_full_simp_tac"`, `"safe_asm_full_simp_tac"`) so the port stays greppable against `clasimp.ML:44–54`. |

Two decisions from the Phase-1/2 code review (`PLAN_review_phase_1_2.md`,
where they are D-R1 and D-R2) bear on this phase and were recorded in
`PLAN.md` §2 at this revision:

- **D38** (= D-R1): the claset-explicit layer of `classicalLib` is
  uppercase `CS_*_TAC`; there is no lowercase Isabelle-alias layer.
  (Delivered: `classicalLib.sig:22–38`.)
- **D39** (= D-R2): cold-path `Measured` twins are unified on a
  `checkpoint` parameter; hot-path twins (`blastTerm`, `blastSearch`
  inner loops) are kept with differential drift tests.  Phase 3 adds
  **no** new twins: `CS_BLAST_DEPTH_TAC` reuses
  `tableauLib.run_depths`.

### 0.2 What changed under the plan between 2026-07-19 and 2026-07-24

The Phase-3 substrate moved; every item below is reflected in the
sections that follow.

1. **D38 rename** (`5a1dee9f9`): `classicalLib`'s `safe_tac`,
   `clarify_tac`, `fast_tac`, `slow_tac`, `best_tac`, `first_best_tac`,
   … are now `CS_SAFE_TAC`, `CS_CLARIFY_TAC`, `CS_FAST_TAC`,
   `CS_SLOW_TAC`, `CS_BEST_TAC`, `CS_FIRST_BEST_TAC`, …  The lowercase
   names survive only as module-private bindings
   (`classicalLib.sml:107–232`).  §§2, 3.2, 7 updated; D36 extends the
   convention to this phase.
2. **Shared marker predicate** (`c2cbebf0c`, `PLAN_marker_fix.md`, and
   review finding F2): `markerLib.is_generic_simp_marker` is the single
   vocabulary (`markerLib.sig:54`), now covering `AC`, `Cong`, `Split`,
   `Excl`, `ExclSF`, `FRAG`, `Req0`, `ReqD`, bounded rewrites
   (`Once`/`Ntimes`), `NoAsms`, `IgnAsm` and `Abbr`; and
   `markerLib.dest_generic_simp_wrapper` unwraps the content-bearing
   ones.  §6's marker list is corrected accordingly.
3. **`Abbr` at the tactic layer** (F2): `classicalLib.public`
   (`classicalLib.sml:258`) and `tableauLib.BLAST_TAC`/
   `BLAST_DEPTH_TAC` (`tableauLib.sml:189,200`) wrap their theorem-list
   entry points in `markerLib.ABBRS_THEN`.  Clasimp's entry points do
   the same (§6).
4. **A private `blast_depth_tac` already exists** in `tableauLib.sml`
   (`:183`, `int -> thm list -> tactic`), so D33's export is renamed
   (D36) rather than colliding; the export is a thin
   `run_depths`-with-fixed-depth call (§3.3).
5. **Replay failure now backtracks** (F4, `classicalLib.sml:115–133`):
   `replay_node`/`replay_step` catch `HOL_ERR`, trace on the
   `"classical"` key, and return `seq.empty`, so `solve` proceeds to
   the next engine solution.  D32's export inherits this for free.
6. **Recorded hyp-subst split** (F1): `blast_hyp_subst_step_at` takes
   `{equality : int, changed : bool list}` (`clasetStep.sig:55–56`) —
   no Phase-3 consequence beyond not reintroducing a recomputed split.
7. **M1/M2 instrumentation tower removed** (`199dfe4cd`…`52a267058`):
   Phase 3 must not reference the retired diagnostic APIs; §10's
   budgets are coarse end-to-end selftest wall-clock, per `PLAN.md`
   §11.
8. **Build is fully green**: the `src/probability`
   `in_borel_measurable_inv` failure was repaired at `65250f8c3`
   (`PLAN.md` §11, 2026-07-22 record), and the pre-existing
   `cv_compute/automation` `CHEATED` selftest was closed at
   `f667a716d`.  Task 13's gate expectation (§12) is now a clean
   `bin/build -F -t` with **no** known exceptions.
9. **Substrate corrections** found at re-verification: `split_ss` lives
   in `simpLib` (`simpLib.sig:162`), not `splitLib`; the safe-solver
   setter is `simpLib.set_safe_solvers` (`:166`), not
   `add_safe_solvers`; the unsafe-wrapper application geometry is at
   `clasetStep.sml:1817–1866`, not the line range the 2026-07-19 draft
   cited, and standalone `inst*/unsafe/dup` step exports are
   wrapper-free (§5.1).

## 1. Scope

Delivered by this phase:

1. Cross-module amendments (§3): `simpLib` mode parameter (D31),
   `classicalLib.CS_DEPTH_SOLVE_TAC` (D32),
   `tableauLib.CS_BLAST_DEPTH_TAC` (D33), layer-wide insertion refactor
   (D30), `Simp`/`Iff` marker constructors.
2. The clasimpset (§4) with the safe-solver stack.
3. `add_simp_wrapper`/`add_safe_simp_wrapper` (§5).
4. The six tactics plus depth-parameterized and `CS_*` forms (§7).
5. `[iff]` attribute, `remove_iff`, `Iff`/`Simp` markers (§8).
6. TypeBase completion deferred from Phase 0: constructor intros (§9).
7. Selftests, Docfiles, build wiring.

Out of scope: the aesop engine (Phase 4), any default/distribution
simpset change (Phase 9), seeding beyond what §8–§9 derive (Phase 8).

### 1.1 Corrections to the parent plan's §7 sketch

Verified against `clasimp.ML` (details in
`research/phase3-isabelle-clasimp.md`); the port follows the source, not
the sketch:

1. **`force`**: the simp-extended claset passed to `clarify_tac` is
   *inert* there — clarify consults only safe wrappers and
   `add_simp_wrapper` installs an unsafe wrapper
   (`clasimp.ML:167–173`).  The simp step is `IF_UNSOLVED` with the
   *plain* simpset.  We port literally (still passing the extended
   claset to clarify, documenting the inertness).
2. **`[iff]`**: safe-vs-unsafe is decided *solely* by premise count
   (`nprems = 0`), uniformly across all branches; the equivalence case
   adds an (intro, **dest**) pair — dest, not elim — with the major
   premise rotated to the front; the simpset add happens in **every**
   branch (`clasimp.ML:87–98`).  There is no non-safe `iff'` variant.
3. **`auto`** has a fifth step, `prune_params_tac` (cosmetic removal of
   unused goal parameters, `clasimp.ML:158`), and `TRY` around both safe
   passes.  HOL4 goals carry no meta-bound parameter prefix, so step 5
   is vacuous here and is dropped, with a note in the documentation.

## 2. Grounding: what exists and is used as-is

Verified at `5a1dee9f9`, 2026-07-24.

| Delivered asset | Where | Used for |
|---|---|---|
| `ntactic`/`wrapper`, `LIFT`/`DETERM`/`NORELSE`/`NAPPEND`/`NCHANGED` | `NTactical.sig:9–19` | wrapper composition (§5) |
| claset values, `add_safe_wrapper`/`add_unsafe_wrapper` (named slots, newest innermost), `the_claset`, `augment_claset` | `clasetLib.sig:46–51`, `:29,34` | §5, `[iff]` hook |
| wrapper application geometry (D24), corrected: swrappers wrap the safe and clarify cascades (`clasetStep.sml:1757–1763`) and hence every safe saturation; uwrappers wrap `general_step`'s combined inst+unsafe rung (`:1822–1826`) and `depth_step`'s branching rung (`:1852–1856`), **not** `depth_step`'s inst0 closers and **not** the standalone `inst*/unsafe/dup` step exports (`:1768–1774`) | `clasetStep.sml` | matches `classical.ML:713–719` for the rungs Phase 3 uses — nothing to change |
| `clasetStep.depth_step : claset -> claset_part -> int -> step` | `clasetStep.sig:62` | the `{dup}` distinction of D32 |
| `CS_SAFE_TAC`/`CS_CLARIFY_TAC`/`CS_FAST_TAC`/`CS_SLOW_TAC`/`CS_BEST_TAC`/`CS_FIRST_BEST_TAC : claset -> ntactic` | `classicalLib.sig:22–37` | FORCE/FASTFORCE/SLOWSIMP/BESTSIMP bodies |
| `solve` + `replay_node` with backtracking-on-replay-failure (F4) | `classicalLib.sml:115–133,190–195` | D32 export |
| `tableauLib.run_depths` (claset in, depth schedule in) | `tableauLib.sml:110–176` | D33 export |
| rule kit (`MAKE_ELIM_RULE`, `CLASSICAL_RULE`, `SWAP_INTRO_RULE`, `DUP_*`) | `clasetRules.sig:32–37` | `[iff]` derivations |
| `GEN_SIMP_TAC : simp_mode -> simpset -> thm list -> tactic`, `set_safe_solvers`, `mk_tactic_solver`, `set_cond_depth`, `split_ss` | `simpLib.sig:221–222,162,166,169,171` | clasimpset + safe simp |
| `GEN_GLOBAL_SIMP_TAC` mut_impc controls (D17) | `simpLib.sig:241–244` | asm-full-simp (§4.3) |
| `srw_ss()`, `augment_srw_ss`, `make_simpset_derived_value` | `BasicProvers.sig:21,31,56`; impl `.sml:1223–1245,1364` | clasimpset (§4.1), `[iff]` hook |
| `markerLib.is_generic_simp_marker`, `dest_generic_simp_wrapper`, `ABBRS_THEN` | `markerLib.sig:54` and impl `:143,157,375` | §6 argument processing |
| ThmSetData settype pattern incl. collision guard | `splitLib.sml:100–114` model | `[iff]` registration (§8) |
| `register_tyinfo_contribution` | `clasetLib.sig:97` | §9 |

Isabelle reference points for the scripts: `clasimp.ML:44–54`
(wrappers), `119–121` (clarsimp), `128–143` (nodup_depth_tac),
`147–161` (auto), `167–180` (force/fastforce/slowsimp/bestsimp),
`87–112, 188–195` (iff); `classical.ML:713–732` (depth_tac);
`simplifier.ML:361` + `simpdata.ML:146–151` (safe_asm_full_simp);
`HOL.thy` Clasimp instantiation via `simpdata.ML:174–184`.

## 3. Cross-module amendments (land first, each with its own gate)

### 3.1 `simpLib`: mode-parameterized global simp (D31)

New signature (replacing, not alongside):

    val GEN_GLOBAL_SIMP_TAC :
      simp_mode -> xsimptac_config -> simpset -> thm list -> tactic

- Semantics of the mode: identical to D16's on `GEN_SIMP_TAC` — the
  flag selects only the final-solver stack for tactic-level residue
  (`final_solver_tac`); traversal side-condition solving stays on the
  unsafe list; loopers still run.  In the global entry, the mode applies
  to every constituent simp invocation's *final* solving (assumption
  passes and conclusion pass alike), which is exactly Isabelle's
  `safe_asm_full_simp_tac` = same rewriting, different terminal solver
  (`simplifier.ML:361`, solver policy `simplifier.ML:327`).
- `global_simp_tac` keeps its signature, delegating with
  `{safe = false}` — zero behavior change for `gvs`/`gs` and every
  in-tree caller.  Callers re-verified 2026-07-24: the definition and
  `global_simp_tac` (`simpLib.sml:1673,1787`) and
  `src/simp/src/selftest.sml` (18 call sites, all through the local
  `xcfg` helper) — nothing else in `src/`, `examples/`, `Manual/` or
  `tools/`.
- Selftests: existing global-simp tests updated mechanically (extend
  `xcfg` to emit the mode, defaulting to `{safe = false}`); new tests:
  safe mode leaves a goal unsolved that the unsafe final solver would
  close by instantiation, and safe mode still discharges rewrite side
  conditions using the unsafe list.
- `PLAN_phase_S.md` §12 gains an amendment note (this decision).

### 3.2 `classicalLib`: `CS_DEPTH_SOLVE_TAC` export (D32, D36)

    val CS_DEPTH_SOLVE_TAC :
      {dup : bool} -> int -> clasetLib.claset -> NTactical.ntactic

Semantics = the delivered private recipe generalized.  `bounded_depth`
(`classicalLib.sml:219–230`) already is Isabelle's `depth_tac` shape —
safe-step saturation, then `clasetSearch.DEPTH_SOLVE` over
`clasetStep.depth_step cs part bound` — but hard-wires
`clasetLib.dup_part cs`.  The refactor parameterizes the part:
`{dup = true}` → `dup_part`, `{dup = false}` → `unsafe_part`
(`clasetLib.sig:59–60`); the export is
`solve (bounded_depth {dup} cs bound)`, so kernel replay (with F4's
backtracking on replay failure) is shared, not copied.  `CS_DEEPEN_TAC`
is refactored onto the same helper at `{dup = true}` — one
implementation, no copies.  Depth counts unsafe expansions only;
uwrappers apply at the branching rung only (already the delivered
`depth_step` geometry, §2).

### 3.3 `tableauLib`: raw fixed-depth entry (D33, D36)

    val CS_BLAST_DEPTH_TAC : clasetLib.claset -> int -> tactic

Single tableau search at exactly the given resource bound: literally
`run_depths cs (SOME depth) (fn _ => NONE)` — no `DEEPEN`, no
`depth_limit` consultation (so F3's negative-limit semantics do not
apply), no marker processing, no `ABBRS_THEN`, no insertion (the caller
supplies a finished claset and has already inserted its facts).  It is
the analogue of `Blast.depth_tac ctxt m` as used by `mk_auto_tac`
(`clasimp.ML:152`).  Untranslatable goals and search failure = ordinary
tactic failure (Isabelle returns `Seq.empty`, `blast.ML:1276–1277`).
Reconstruction and PROOF-FAILED backtracking behave as in `BLAST_TAC`.
The delivered module-private `blast_depth_tac : int -> thm list ->
tactic` (`tableauLib.sml:183`) is the *theorem-list* entry behind
`BLAST_DEPTH_TAC` and is unrelated; both are retained, and the private
one keeps its name (no clash under D36).

### 3.4 Layer-wide insertion refactor (D30)

The plain-theorem path is centralized in `clasetLib`
(`add_plain_theorems` / `invocation_claset`, `clasetLib.sml:864–898`),
consumed by `classicalLib.invocation_claset` (`:251`) and
`tableauLib.invocation_claset` (`:20`).  D30 therefore lands in one
place plus two call sites:

- `clasetLib.invocation_claset` changes to

      val invocation_claset : claset -> thm list -> claset * thm list

  (the `{prefix}` argument, `add_plain_theorems`, `next_extra_name`
  and the `__classical_extra_N` / `__blast_extra_N` naming disappear
  with it): it applies `process_claset_tags` and returns the tagged
  claset together with the facts the caller must insert.
- The leftovers are filtered by a new `clasetLib` helper

      val invocation_facts : thm list -> thm list

  which unwraps content-bearing generic wrappers with
  `markerLib.dest_generic_simp_wrapper` (so `FAST_TAC [Once th]`
  inserts `th`) and drops the inert generic controls recognized by
  `markerLib.is_generic_simp_marker` — the F2 treatment, moved from
  rule-building to fact-building, with the vocabulary still owned by
  `markerLib`.
- `classicalLib.public_raw` and `tableauLib`'s entry points insert the
  resulting facts as assumptions of the goal before the engine runs
  (validation via `PROVE_HYP`, i.e. standard `ASSUME_TAC` plumbing; the
  theorem is inserted as-is, universally closed, matching Isabelle's
  fact insertion).  For blast, inserted facts become branch formulas
  through the normal `fromSubgoal` translation — strictly the natural
  channel.
- Marker processing (`process_claset_tags`) is otherwise unchanged;
  the explicit-role channel is markers.
- Phase-1/2 selftests that relied on plain-as-intro are updated to
  `Intro th`, and the F2 tests that assert generated rule names
  (`__classical_extra_0`) are re-expressed against insertion (audit
  during the task; expected a handful plus the F2 pair).
- Docfiles for the Phase-1/2 tactics updated to document insertion.

### 3.5 Marker constructors `Simp`, `Iff` (D30, freeze amendment)

Added to the marker theory in `src/auto/rules` (`clasetMarkerScript`),
alongside the existing six + `Del`: `Simp : bool -> bool` (use only
as a simpset addition), `Iff : bool -> bool` (per-invocation iff: feed
the temporary claset *and* the temporary simpset through the §8
decision tree), with the `OpenTheoryMap` `Unwanted.id` registrations the
existing constructors carry, and `clasetLib` wrappers/destructors
`Simp`/`Iff`/`destSimp`/`destIff` mirroring the delivered
`Intro`/`destIntro` pattern (`clasetLib.sig:70–84`).  `rules/` only
defines the constructors (it stays independent of `src/simp`);
interpretation lives in `clasimpLib`'s argument processor (§6).
`clasetLib.invocation_facts` raises a clear error on `Simp`/`Iff`
(reached only from `classicalLib`/`tableauLib`, which have no simpset),
rather than silently inserting the marked theorem.

## 4. The clasimpset (D28)

### 4.1 Definition

`clasimpLib` keeps a private derived value

    val clasimp_ss : unit -> simpLib.simpset

built with `BasicProvers.make_simpset_derived_value` (stale-flag cached;
recomputed only when `srw_ss` changes) as:

    srw_ss()
      |> simpLib.set_cond_depth 40      (* layer convention, PLAN.md §5.5 *)
      |> (fn ss => ss ++ simpLib.split_ss)  (* splitter looper, cases_simp *)
      |> simpLib.set_safe_solvers safe_solver_stack

Notes:
- Isabelle's `auto` simpset has the splitter installed by default
  (`simpdata.ML:153–184`); `AUTO_TAC`'s simp therefore splits `if`/
  `case` while plain `SIMP_TAC (srw_ss())` does not.  This is the
  intended layer-vs-distribution difference (D19 untouched); documented
  prominently in the `AUTO_TAC` Docfile.
- `[simp]`, TypeBase rewrites (via `tyi_to_ssdata`,
  `BasicProvers.sml:1243–1245`), and Phase-3 `[iff]` all reach
  `clasimp_ss` automatically because they feed `srw_ss`.

### 4.2 The safe-solver stack

Port of HOL's safe solver (`simpdata.ML:146–151`): a `mk_tactic_solver`
lift of FIRST of — assumption *matching* (goal α-equal to an
assumption), reflexivity matching (`x = x`), `TrueI`-style matching
(`T`), and contradiction from an assumption matching `F`.  No
metavariable instantiation, no resolution against arbitrary premises.
Installed with `set_safe_solvers` (the whole safe list is replaced, so
the stack is exactly this port); the unsafe list keeps the delivered
default behavior.

### 4.3 The two simp tactics of the phase

    (* asm_full_simp_tac analogue, mut_impc parity (D17/D31) *)
    fun asm_full_simp ss ths =
      GEN_GLOBAL_SIMP_TAC {safe = false}
        {base = <strip/elimvars/droptrues/oldestfirst config mirroring
                 gvs-family defaults, reviewed at implementation>,
         concl_in_fixpoint = true, imp_rebuild = true} ss ths

    fun safe_asm_full_simp ss ths =
      GEN_GLOBAL_SIMP_TAC {safe = true} { ...same config... } ss ths

The `base : simptac_config` field values (`{strip, elimvars, droptrues,
oldestfirst}`, `simpLib.sig:235–236`) are fixed in the first
implementation task by reading each flag against Isabelle's
`asm_full_simp_tac` semantics (mutual assumption rewriting, assumptions
decomposed per `mksimps_pairs`) and recorded in the module as the one
shared constant; they are an engine-faithfulness matter, not a tuning
knob, so no owner decision is needed.

## 5. `add_simp_wrapper` / `add_safe_simp_wrapper` (D37; port of
`clasimp.ML:44–54`)

    val add_simp_wrapper :
      simpLib.simpset -> clasetLib.claset -> clasetLib.claset
    val add_safe_simp_wrapper :
      simpLib.simpset -> clasetLib.claset -> clasetLib.claset

- `add_simp_wrapper ss` = `add_unsafe_wrapper ("asm_full_simp_tac", w)`
  where `w step = NAPPEND (NCHANGED (LIFT (asm_full_simp ss [])), step)`
  — full simp offered as a backtrackable alternative *before* every
  unsafe step (Isabelle's `addbefore`; `APPEND'` composition).
- `add_safe_simp_wrapper ss` =
  `add_safe_wrapper ("safe_asm_full_simp_tac", w)` where
  `w step = NORELSE (step, NCHANGED (LIFT (safe_asm_full_simp ss [])))`
  — safe simp tried when ordinary safe steps fail (Isabelle's
  `addSafter`; `ORELSE'` composition).
- Slot names match Isabelle for greppability (D37); re-adding
  overwrites the slot (delivered claset semantics).

### 5.1 Where the wrappers actually fire (delivered geometry)

Re-verified at `5a1dee9f9`; this is what the §7 scripts rely on:

- **Safe wrappers** wrap `safe_cascade` and `clarify_cascade`
  (`clasetStep.sml:1757–1763`), hence `CS_SAFE_TAC`, `CS_CLARIFY_TAC`,
  and every internal safe saturation — including the saturation inside
  `general_step` and `depth_step`.  `add_safe_simp_wrapper` therefore
  reaches exactly the steps `CLARSIMP_TAC` and `AUTO_TAC`'s step 4 need.
- **Unsafe wrappers** wrap `general_step`'s combined inst+unsafe rung
  (`:1822–1826`, i.e. `clasetStep.step`/`slow_step`, hence
  `CS_FAST_TAC`, `CS_SLOW_TAC`, `CS_BEST_TAC`, `CS_FIRST_BEST_TAC`)
  and `depth_step`'s branching rung (`:1852–1856`, hence
  `CS_DEPTH_SOLVE_TAC`).  They do **not** wrap `depth_step`'s inst0
  closers, nor the standalone `inst0/instp/inst/unsafe/dup` step
  exports (`:1768–1774`, `no_wrappers`).  No Phase-3 script uses those
  standalone steps, so `add_simp_wrapper` fires wherever the port
  requires.
- Wrapper results are lifted back into engine nodes by `wrapped_step`
  (`:1703–1755`): a wrapper-produced goal list is `unrender`ed and
  recorded with its own validation, so a simp step inside search
  replays through the kernel like any other recorded step.
- These wrappers run on materialized goals (metavariables rendered as
  rigid frees by `clasetGoal.render`): the simp tactic can never
  instantiate engine metavariables — precisely Isabelle's
  rewriter-level guarantee.  The recorded Phase-3 *option* of
  solver-level instantiation
  (`research/phase12-classical-search-port.md` §4.3) is **not**
  exercised in this phase; it remains a recorded option for the
  Phase-8 benchmark review.

## 6. Argument processing

One processor in `clasimpLib`, shared by all six tactics.  Every
theorem-list entry point is wrapped in `markerLib.ABBRS_THEN`
(as `classicalLib.public` and `tableauLib` already do, §0.2.3), so
`Abbr` is honored before anything below runs.

1. Partition the `thm list`, in this order:
   - `Simp th` → simpset addition; `Iff th` → per-invocation iff (both
     stores, §8 decision tree, temporary);
   - claset markers (`SIntro`…`Dest`, `Del`) → temporary claset via
     `clasetLib.process_claset_tags`;
   - anything satisfying `markerLib.is_generic_simp_marker` → passed
     through **unchanged** to the simp invocations (this is the
     delivered vocabulary: `Cong`, `Split`, `AC`, `Excl`, `ExclSF`,
     `FRAG`/`SF`, `Req0`, `ReqD`, bounded `Once`/`Ntimes`, `NoAsms`,
     `IgnAsm`; `Abbr` is already consumed).  Note the deliberate
     asymmetry with §3.4: clasimp has a simpset, so it must **not**
     unwrap content-bearing wrappers — `Once th` is a simp control
     here, whereas `classicalLib`/`tableauLib`, having no simpset,
     unwrap and insert the payload.
   - **plain theorems → inserted as assumptions first** (D30).
2. The resulting `(claset, simpset)` pair parameterizes the script; the
   insertion happens once, before step 1 of each script, so inserted
   facts are visible to every phase (simp passes, safe steps, search,
   blast) — Isabelle's chained-fact order (`SIMPLE_METHOD'` inserts
   before the method body).

This gives `AUTO_TAC [th1, Simp th2, SIntro th3, Iff th4, Split th5]`
as the analogue of `using th1 by (auto simp: th2 intro!: th3 iff: th4
split: th5)`.

## 7. The tactics

All uppercase `thm list -> tactic` forms read `the_claset()` and
`clasimp_ss()` at application time.  Context-explicit forms (D36):

    val CS_AUTO_TAC      : {blast : int, depth : int}
                           -> clasetLib.claset -> simpLib.simpset -> tactic
    val CS_FORCE_TAC     : clasetLib.claset -> simpLib.simpset -> tactic
    val CS_FASTFORCE_TAC : clasetLib.claset -> simpLib.simpset -> tactic
    val CS_SLOWSIMP_TAC  : clasetLib.claset -> simpLib.simpset -> tactic
    val CS_BESTSIMP_TAC  : clasetLib.claset -> simpLib.simpset -> tactic
    val CS_CLARSIMP_TAC  : clasetLib.claset -> simpLib.simpset -> tactic

(Deterministic tactics, not `ntactic`s: each either fails or commits —
auto/clarsimp by D27 change-or-fail, the FORCE family by must-close.
The nondeterministic engine remains reachable through `classicalLib`'s
`CS_*` forms plus `add_simp_wrapper`.)

### 7.1 `AUTO_TAC` (port of `mk_auto_tac`, `clasimp.ML:147–161`)

For a single HOL4 goal, with `cs' = add_simp_wrapper ss cs`:

    1  asm_full_simp ss                       (* may be a no-op        *)
    2  THEN TRY (safe pass: DETERM (CS_SAFE_TAC cs))
    3  THEN (on every remaining subgoal)
         TRY (CS_BLAST_DEPTH_TAC cs m         (* m = 4 default        *)
              ORELSE DETERM (CS_DEPTH_SOLVE_TAC {dup=false} n cs'))
                                              (* n = 2 default        *)
    4  THEN TRY (safe pass:
                 DETERM (CS_SAFE_TAC (add_safe_simp_wrapper ss cs)))
    overall: fail iff nothing changed (D27 / CHANGED_PROP).

Adaptation notes, each verified:

- Isabelle's step 3 is `REPEAT_DETERM (FIRSTGOAL (blast ORELSE'
  CHANGED o nodup_depth_tac …))`.  Both legs are solve-or-fail
  (`depth_tac` closes the selected goal completely or fails —
  `classical.ML:713–719`; blast likewise), so the only work the
  `REPEAT`/`FIRSTGOAL` loop does beyond one pass per subgoal is
  re-trying goals whose schematic variables were instantiated by
  solving *other* goals.  HOL4 kernel subgoals cannot share
  metavariables, so one `TRY(…)` per subgoal is exactly equivalent;
  the `CHANGED` guard is subsumed by solve-or-fail.  This equivalence
  argument is recorded as a comment in the source.
- Step 5 (`prune_params_tac`) is vacuous in HOL4 (§1.1.3) — dropped.
- `AUTO_DEPTH_TAC {blast : int, depth : int} : thm list -> tactic`
  exposes the two bounds; `AUTO_TAC = AUTO_DEPTH_TAC {blast = 4,
  depth = 2}` (Isabelle defaults, PLAN.md §11 numeric-defaults record).
  The record form (rather than a bare pair) keeps the two bounds
  distinguishable at call sites, matching `CS_DEEPEN_TAC {start}`.
- Idempotence (up to blast instantiations, `clasimp.ML:145–146`) is a
  selftest property (§10).

### 7.2 `FORCE_TAC` (port of `force_tac`, `clasimp.ML:167–173`)

With `cs' = add_simp_wrapper ss cs`, on a single goal:

    DETERM (CS_CLARIFY_TAC cs')   (* simp wrapper inert here — documented *)
    THEN asm_full_simp ss         (* skipped when already solved          *)
    THEN on every remaining subgoal: DETERM (CS_FIRST_BEST_TAC cs')
    overall: fail unless zero subgoals remain.

(`IF_UNSOLVED` is automatic in HOL4 — solved goals produce no
subgoals for the subsequent `THEN`.)

### 7.3 `FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`
(`clasimp.ML:178–180`)

    CS_FASTFORCE_TAC cs ss = must_close (DETERM (CS_FAST_TAC cs'))
    CS_SLOWSIMP_TAC  cs ss = must_close (DETERM (CS_SLOW_TAC cs'))
    CS_BESTSIMP_TAC  cs ss = must_close (DETERM (CS_BEST_TAC cs'))

with `cs' = add_simp_wrapper ss cs`, where `must_close t` fails unless
`t` leaves no subgoals (the delivered search drivers already
solve-or-fail; `must_close` is a documented guard, not new search
semantics).

### 7.4 `CLARSIMP_TAC` (port of `clarsimp_tac`, `clasimp.ML:119–121`)

    safe_asm_full_simp ss
    THEN (on every resulting subgoal)
         DETERM (CS_CLARIFY_TAC (add_safe_simp_wrapper ss cs))
    overall: fail iff nothing changed (D27; Isabelle's method is
    CHANGED_PROP oo clarsimp_tac).

The manual's caveat that a premise splitter in the simpset can still
split the subgoal (`Generic.thy:1624–1626`) carries over verbatim
(the clasimpset contains `split_ss`) and goes into the Docfile.

## 8. `[iff]` (D29; port of `clasimp.ML:87–112, 188–195`)

### 8.1 The decision tree

One function, shared by the attribute, the `Iff` marker and the
TypeBase hook.

For theorem `th`, normalized by `SPEC_ALL`; let `n` = number of
antecedents of the implicational form; `safe = (n = 0)`:

| Shape of conclusion | Claset contribution | Simpset contribution |
|---|---|---|
| `A ⇔ B` (bool equality) | intro = iffD2-half (`(A⇔B) ⇒ B ⇒ A` composed with `th`), dest = iffD1-half, major premise rotated first (Isabelle `rotate_prems n`); both safe iff `n = 0` | `th` as rewrite |
| `¬A` | elim via the `NOT_ELIM` composition (Isabelle `notE`); safe iff `n = 0` | `th` (rewrites to `A = F`) |
| other `A` | intro = `th`; safe iff `n = 0` | `th` (rewrites to `A = T`) |

Derivations use the delivered `clasetRules` kit plus `EQ_IMP_RULE`;
the standard swapped/dup variants then arise inside `clasetLib.add_*`
as for any rule.  There is no `iff?` analogue (it targets Isabelle's
Pure `Context_Rules`, which has no HOL4 counterpart) and no separate
unsafe-only variant (none exists upstream).

### 8.2 Persistence and surface

- Settype `"iff"` via `ThmSetData.export_with_ancestry`, registered in
  `clasimpLib` following the `splitLib.sml:100–114` pattern (including
  the registration-collision guard).  Neither an `"iff"` settype nor an
  `iff` attribute exists in the tree today (verified 2026-07-24).
  Apply hook: run §8.1, push the claset half through
  `clasetLib.augment_claset`, the simpset half through
  `BasicProvers.augment_srw_ss` (one small ssfrag per delta).
- Attribute: `Theorem foo[iff]`.  Removal:
  `val remove_iff : string -> unit` writing the RM delta; the hook
  retracts both halves (claset removal by the derived-rule names it
  created; simpset removal via the delta-replayed `srw_ss` state).
- Per-invocation: the `Iff th` marker applies §8.1 to the temporary
  claset/simpset pair only (no persistence).
- Recorded caveat: claset candidate ordering breaks ties by declaration
  recency; `[intro]` and `[iff]` live in different delta streams, so
  the *relative* recency of an iff and an intro declared in the same
  theory may permute on reload — a tie-break-only divergence from
  Isabelle's single-context ordering.  If Phase-8 benchmarks ever show
  sensitivity, a global declaration counter shared by the streams is
  the remedy (its own decision then).

## 9. TypeBase completion (deferred from Phase 0)

Phase 0 seeds distinctness (safe elim) and injectivity (safe dest) and
`srw_ss` already carries the datatype rewrites (`tyi_to_ssdata`).  The
missing piece is exactly the intro halves that the `[iff]` treatment of
injectivity yields: for each constructor `C`, the safe intro
`x₁ = y₁ ⇒ … ⇒ C x̄ = C ȳ`.  `clasimpLib` registers its own TypeBase
contribution (hook + one-shot catch-up sweep, same pattern as the
delivered rules/ hook — `clasetLib.register_tyinfo_contribution`
(`clasetLib.sig:97`) is frozen and suffices) adding those intros;
nothing already-seeded is duplicated (claset dedup by rule name).
Case-split theorems stay with `[split]` (Phase S); nchotomy/cases
remain for the aesop cases-builder (Phase 4).

## 10. Selftests (`src/auto/clasimp/selftest.sml`)

Per `src/auto/CLAUDE.md`: successes through `Tactical.VALID`, exact
residues asserted for non-closing tactics, negative cases, no state
left behind, expected failures asserted as failures, and no goal closed
by recognition.

1. Unit: marker/argument processor (each marker kind; plain-thm
   insertion visible in residue; `Once th` reaching the simpset in
   clasimp but being unwrapped-and-inserted by `FAST_TAC`;
   `Simp`/`Iff` rejection by classical-only tactics; `Abbr` honored).
2. Wrapper: goals solvable only via `add_simp_wrapper` inside search
   (Isabelle's motivating shapes); `add_safe_simp_wrapper` residue
   safety (no instantiation of engine metavariables — rigid-render
   guard test).
3. Scripts: per-tactic goal batteries translated from the Isabelle
   regression corpus (`auto`, `force`, `fastforce`, `clarsimp`
   examples), plus HOL4-native set/list/option goals; FORCE-family
   must-close negative tests; AUTO/CLARSIMP change-or-fail tests.
4. AUTO idempotence: `AUTO_TAC` residue re-run is a no-op on a corpus
   without blast instantiations.
5. `[iff]`: derivation table cases (all six shape×conditional
   combinations); persistence round-trip in `clasimp/theory_tests/`
   (export, reload, both stores populated; `remove_iff` retracts both;
   child-theory visibility and diamond merge, as `rules/theory_tests/`
   does).
6. TypeBase: constructor intros present for a datatype defined *after*
   load and one from the catch-up sweep.
7. Amended modules: §3.1 safe-mode tests (in `src/simp` selftest),
   §3.2 `CS_DEPTH_SOLVE_TAC` dup/nodup divergence test (a goal solvable
   only with duplication fails at `{dup=false}`), §3.3 a
   `CS_BLAST_DEPTH_TAC` bound test, §3.4 insertion regression across
   the Phase-1/2 suites.

## 11. Documentation

`help/Docfiles` for the six tactics and their `CS_*` forms,
`AUTO_DEPTH_TAC`, `add_simp_wrapper`/`add_safe_simp_wrapper`,
`[iff]`/`remove_iff`, `Simp`/`Iff` markers; new pages for
`classicalLib.CS_DEPTH_SOLVE_TAC` and `tableauLib.CS_BLAST_DEPTH_TAC`;
updates to the Phase-1/2 tactic Docfiles (insertion semantics) and
`BLAST_TAC`'s (unchanged public behavior; cross-reference the raw
entry).  The `AUTO_TAC` entry documents: clasimpset = `srw_ss` +
splitter + depth-40 side conditions; the splitting difference vs
`SIMP_TAC (srw_ss())`; residue semantics; depth parameters.

## 12. Task breakdown

Dependency order; per-task gate `bin/build -t --seq=tools/sequences/
upto-auto` plus `Holmake` + `./selftest.exe` in each touched directory,
and `tools/h4pedant/h4pedant` on touched directories.

| # | Task |
|---|---|
| 01 | `simpLib` mode parameter (D31): signature change, internal callers, `xcfg`-based selftest update, new safe-mode tests, `PLAN_phase_S.md` §12 amendment note |
| 02 | `classicalLib.CS_DEPTH_SOLVE_TAC` (D32/D36): export + `bounded_depth`/`CS_DEEPEN_TAC` refactor + selftests |
| 03 | Insertion refactor (D30): `clasetLib.invocation_claset`/`invocation_facts` + `classicalLib` + `tableauLib` + Phase-1/2 selftest and Docfile updates |
| 04 | `tableauLib.CS_BLAST_DEPTH_TAC` (D33/D36) + selftests |
| 05 | `Simp`/`Iff` marker constructors in `rules/` (theory + `clasetLib` wrappers/destructors) + rejection path in `invocation_facts` |
| 06 | `src/auto/clasimp/` scaffold: Holmakefile (`hol.state0` heap, `selftest.exe`, `HOLSELFTESTLEVEL` tee), `theory_tests/` subdir, build-sequence entries (`tools/sequences/upto-auto`: `src/auto/clasimp` after `src/auto/blast`, plus a `!src/auto/clasimp/theory_tests` line — a leading `!` raises the selftest level at which the directory is built, `tools/build/buildutils.sml:188–192` — mirroring the delivered `!src/auto/rules/theory_tests`, and the same in `tools/sequences/more-theories`; `src/parallel_builds/core/Holmakefile` `SRCRELNAMES` line 5 alongside `auto/rules auto/classical auto/blast` — note `rules/theory_tests` is deliberately *not* in `SRCTESTDIRS`, so `clasimp/theory_tests` is not either), clasimpset + safe-solver stack |
| 07 | `add_simp_wrapper`/`add_safe_simp_wrapper` (D37) + argument processor |
| 08 | `FASTFORCE_TAC`/`SLOWSIMP_TAC`/`BESTSIMP_TAC` + `CLARSIMP_TAC` + `CS_*` forms + selftests |
| 09 | `AUTO_TAC`/`AUTO_DEPTH_TAC` + `FORCE_TAC` + `CS_*` forms + selftests |
| 10 | `[iff]`: decision tree, settype, attribute, `remove_iff`, `Iff` marker wiring, persistence selftests |
| 11 | TypeBase completion (§9) + selftests |
| 12 | Docfiles (§11) |
| 13 | Phase gate: full `bin/build -F -t`, expected **fully green** — the `src/probability` `in_borel_measurable_inv` failure was repaired at `65250f8c3` and the `cv_compute/automation` `CHEATED` selftest closed at `f667a716d`, so there is no longer a known exception; also record zero `F-CHEAT`/`CHEATED` and the h4pedant result in `PLAN.md` §11 |

## 13. Risks

1. **Insertion refactor regressions** (D30): Phase-1/2 selftest goals
   that leaned on plain-as-intro change behavior, and the F2 tests that
   assert generated `__classical_extra_N` names lose their subject.
   Mitigation: task 03 audits and converts call sites to `Intro th`,
   re-expresses the F2 assertions against insertion, and the full
   suites gate the change in isolation before clasimp lands.
2. **Safe-solver misport**: too-strong a safe solver reintroduces
   instantiation (unsound for `add_safe_simp_wrapper`'s purpose), too
   weak loses parity.  Mitigation: matching-only implementation +
   the §10.2 rigid-render guard test.
3. **`asm_full_simp` base-config fidelity** (§4.3): wrong
   `simptac_config` flags diverge from `mksimps`-style assumption
   decomposition.  Mitigation: flag-by-flag comparison recorded in the
   module comment; mutual-simplification selftests ported from the
   Phase-S D17 battery.
4. **Wrapper-lifted simp cost** inside `CS_DEPTH_SOLVE_TAC` (render →
   simp → unrender per unsafe step alternative).  Mitigation: `NCHANGED`
   prunes no-op simp branches (as upstream's `CHANGED`); Phase-8
   wall-clock benchmarks arbitrate further tuning.  Note the M1/M2
   instrumentation tower is retired (§0.2.7), so diagnosis uses coarse
   end-to-end selftest timings only.
5. **`[iff]` cross-stream ordering** (§8.2 caveat): tie-break-only;
   monitored via Phase-8 parity suite.
6. **Wrapper geometry assumptions** (§5.1): the port's correctness
   depends on which rungs apply wrappers, which is engine-internal and
   was already mis-cited once in the 2026-07-19 draft.  Mitigation: the
   §10.2 wrapper tests assert the *behavior* (goals solvable only via
   the wrapper at each of the safe, clarify, unsafe and depth rungs),
   so a future geometry change turns the suite red rather than silently
   weakening `AUTO_TAC`.

## 14. Interfaces later phases rely on (freeze list)

Frozen at Phase 3 completion (changes require an owner decision):
`clasimpLib`'s public signature (six tactics + `AUTO_DEPTH_TAC`, the
`CS_*` context-explicit forms, `add_simp_wrapper`/
`add_safe_simp_wrapper`, `clasimp_ss`, `remove_iff`); the `"iff"`
settype name, delta semantics, and §8.1 derivation table; the
`Simp`/`Iff` marker semantics; the layer-wide insertion convention
(D30) together with the amended
`clasetLib.invocation_claset : claset -> thm list -> claset * thm list`
and `clasetLib.invocation_facts`; and the amended signatures
`GEN_GLOBAL_SIMP_TAC : simp_mode -> xsimptac_config -> simpset ->
thm list -> tactic`, `classicalLib.CS_DEPTH_SOLVE_TAC`, and
`tableauLib.CS_BLAST_DEPTH_TAC`.
