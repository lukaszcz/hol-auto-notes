# Phase 3 implementation plan — clasimp layer (`src/auto/clasimp/`)

Date: 2026-07-19.  Branch: `isabelle-tactics`.  Parent plan: `PLAN.md` §7.

Port of `Provers/clasimp.ML` semantics over the delivered Phase-0/1/2
classical stack and the delivered Phase-S simplifier: `AUTO_TAC`,
`FORCE_TAC`, `FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`,
`CLARSIMP_TAC`, the `[iff]` attribute, and the `Simp`/`Iff` markers.

All `file.ML:line` references resolve against `.agent-files/sources/`
(mirror-isabelle `f7e02b7e1f31`).  Line-level groundwork for this plan:

- `research/phase3-isabelle-clasimp.md` — verified clasimp.ML semantics
  (supersedes the parent plan's §7 sketch in three details, see §1.1).
- `research/phase3-hol4-substrate-classical.md` — delivered
  `src/auto/rules` + `src/auto/classical` + `src/auto/blast` surfaces.
- `research/phase3-simp-substrate.md` — delivered Phase-S `simpLib`
  surface, `srw_ss` machinery, attribute plumbing.
- `research/isabelle-classical-reasoner.md` §§4–6 (pre-existing).

## 0. Owner decisions taken for this phase (2026-07-19)

Recorded in `PLAN.md` §2 as D28–D34; restated here in full:

| # | Decision |
|---|---|
| D28 | **Clasimpset**: the stateful clasimp tactics use a cached derived value of `srw_ss()` (`BasicProvers.make_simpset_derived_value`) with the layer configuration applied on top: `cond_depth` 40, the safe-solver stack (§4.2), and `split_ss` (splitter looper).  Lowercase claset-and-simpset-explicit forms exist for all tactics.  D19 is not violated: no distribution simpset changes; the clasimpset is layer-local. |
| D29 | **`[iff]` persistence**: a clasimp-owned `ThmSetData.export_with_ancestry` settype `"iff"`.  The delta carries only ADD/RM of the source theorem — the declaration is the single source of truth; both derived views (claset rules, simpset rewrite) are recomputed by the apply hook on every load (`clasetLib.augment_claset` + `BasicProvers.augment_srw_ss`).  Removal is function-based (RM delta), per D12.  The claset `cdelta` v1 schema and the rules/⊥simp layering are untouched. |
| D30 | **Uniform insertion semantics** (revises the Phase-2 plain-theorem convention; freeze amendment): an unmarked theorem in any `src/auto` tactic's `thm list` argument is **inserted into the goal as an assumption** — the exact analogue of Isabelle's chained-fact channel (`using th by auto`), and of HOL4's prover-family habit (`metis_tac`, `PROVE_TAC`).  Each engine then consumes premises natively (simp rewrites with them, classical search matches/eliminates on them, blast makes them branch formulas).  Explicit roles go through markers.  `classicalLib` and `tableauLib` are refactored from plain-as-unsafe-intro to insertion; the marker vocabulary gains `Simp th` and `Iff th`. |
| D31 | **Safe asm-full-simp**: `GEN_GLOBAL_SIMP_TAC` changes signature to take `simp_mode` as its first argument, exactly mirroring `GEN_SIMP_TAC`'s D16 shape (Phase-S freeze amendment; fixes the delivered gap vs `PLAN_phase_S.md` §12's consumption map).  `global_simp_tac` and all other existing entry points keep their signatures via `{safe = false}`.  Clasimp's asm-full-simp is `GEN_GLOBAL_SIMP_TAC` at the D17 mut_impc-parity configuration (`concl_in_fixpoint = true`, `imp_rebuild = true`). |
| D32 | **Bounded depth search**: `classicalLib` additively exports the previously-private saturate + `DEPTH_SOLVE` + replay recipe as `depth_solve_tac : {dup : bool} -> int -> claset -> ntactic` (Phase-2 freeze amendment); `{dup = false}` is Isabelle's `nodup_depth_tac`, `{dup = true}` is `depth_tac`.  `classicalLib`'s internal uses are refactored onto the same export. |
| D33 | **`AUTO_TAC`'s blast leg**: `tableauLib` additively exports a raw claset-explicit fixed-depth tableau entry `blast_depth_tac : claset -> int -> tactic` — no seed-rewrite preprocessing, no local elims, no iterative deepening — used by `AUTO_TAC`'s inner loop (Phase-2 freeze amendment).  The public `BLAST_TAC`/`BLAST_DEPTH_TAC` packaging is unchanged. |
| D34 | **Names**: module `clasimpLib` in `src/auto/clasimp/`; tactics `AUTO_TAC`, `AUTO_DEPTH_TAC`, `FORCE_TAC`, `FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`, `CLARSIMP_TAC` (all collision-checked free, 2026-07-19 whole-tree grep).  Failure semantics: `AUTO_TAC`/`CLARSIMP_TAC` fail exactly when they change nothing (D27 semantics = Isabelle's method-level `CHANGED_PROP`); the FORCE family must close the goal. |

## 1. Scope

Delivered by this phase:

1. Cross-module amendments (§3): `simpLib` mode parameter (D31),
   `classicalLib.depth_solve_tac` (D32), `tableauLib.blast_depth_tac`
   (D33), layer-wide insertion refactor (D30), `Simp`/`Iff` marker
   constructors.
2. The clasimpset (§4) with the safe-solver stack.
3. `addss`/`addSss` wrapper ports (§5).
4. The six tactics plus depth-parameterized and lowercase forms (§7).
5. `[iff]` attribute, `remove_iff`, `Iff`/`Simp` markers (§8).
6. TypeBase completion deferred from Phase 0: constructor intros (§9).
7. Selftests, Docfiles, build wiring.

Out of scope: the aesop engine (Phase 4), any default/distribution
simpset change (Phase 9), seeding beyond what §8–§9 derive (Phase 8).

### 1.1 Corrections to the parent plan's §7 sketch

Verified against `clasimp.ML` (details in
`research/phase3-isabelle-clasimp.md`); the port follows the source, not
the sketch:

1. **`force`**: the `addss`-extended claset passed to `clarify_tac` is
   *inert* there — clarify consults only safe wrappers and `addss`
   installs an unsafe wrapper (`clasimp.ML:167–173`).  The simp step is
   `IF_UNSOLVED` with the *plain* simpset.  We port literally (still
   passing the `addss`-claset to clarify, documenting the inertness).
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

| Delivered asset | Where | Used for |
|---|---|---|
| `ntactic`/`wrapper`, `NORELSE`/`NAPPEND`/`NCHANGED`/`LIFT`/`DETERM` | `src/auto/rules/NTactical.sig` | wrapper composition (§5) |
| claset values, `add_safe_wrapper`/`add_unsafe_wrapper` (named slots, newest innermost), `the_claset`, `augment_claset` | `src/auto/rules/clasetLib.sig:27–42` | `addss`/`addSss`, `[iff]` hook |
| wrapper application geometry (D24): swrappers inside every safe step; uwrappers around inst+unsafe rungs and `depth_step`'s branching rung, **not** its inst0 closers | `clasetStep.sml:1401–1567` | matches `classical.ML:713–719` — nothing to change |
| `clasetStep.depth_step : claset -> claset_part -> int -> step` | `clasetStep.sig:45–48` | the `{dup}` distinction of D32 |
| `safe_tac`/`clarify_tac`/`fast_tac`/`slow_tac`/`best_tac`/`first_best_tac : claset -> ntactic` | `classicalLib.sig:22–37` | FORCE/FASTFORCE/SLOWSIMP/BESTSIMP bodies |
| rule kit (`MAKE_ELIM_RULE`, `CLASSICAL_RULE`, `SWAP_INTRO_RULE`, `DUP_*`) | `clasetRules` | `[iff]` derivations |
| `GEN_SIMP_TAC : simp_mode -> simpset -> thm list -> tactic`, solver stacks, `mk_tactic_solver`, `set_cond_depth`, `split_ss` | `simpLib.sig` (Phase S) | clasimpset + safe simp |
| `GEN_GLOBAL_SIMP_TAC` mut_impc controls (D17) | `simpLib.sig:241–246` | asm-full-simp (§4.3) |
| `srw_ss()` (immutable snapshots), `augment_srw_ss`, `make_simpset_derived_value` | `BasicProvers.sig:31,56`, `.sml:1223–1379` | clasimpset (§4.1), `[iff]` hook |
| ThmSetData settype pattern incl. collision guard | `splitLib.sml:100–114` model | `[iff]` registration (§8) |

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
  in-tree caller (all external callers go through `global_simp_tac`;
  direct `GEN_GLOBAL_SIMP_TAC` callers are `simpLib.sml` internals and
  `src/simp/src/selftest.sml` only — verified by whole-tree grep,
  2026-07-19).
- Selftests: existing global-simp tests updated mechanically with
  `{safe = false}`; new tests: safe mode leaves a goal unsolved that the
  unsafe final solver would close by instantiation, and safe mode still
  discharges rewrite side conditions using the unsafe list.
- `PLAN_phase_S.md` §12 gains an amendment note (this decision).

### 3.2 `classicalLib`: `depth_solve_tac` export (D32)

    val depth_solve_tac :
      {dup : bool} -> int -> clasetLib.claset -> NTactical.ntactic

Semantics = the delivered private recipe generalized: build the engine
node from the (rendered) goal, then Isabelle's `depth_tac` recursion
(`classical.ML:713–719` / `clasimp.ML:136–141`): safe-step saturation
`THEN_ELSE` (recursive depth-solve of every child, ⟨inst0 closers⟩
`APPEND` (if bound > 0) ⟨wrapped instp+unsafe step, bound − 1⟩), where
the unsafe rung uses the dup netpair iff `dup = true`; complete solve
with kernel replay, else fail.  Depth counts unsafe expansions only;
uwrappers apply at the branching rung only (already the delivered
`depth_step` geometry).  `classicalLib`'s private `bounded_depth`/
`solve`/`replay_node` uses are refactored onto this export — one
implementation, no copies.

### 3.3 `tableauLib`: raw fixed-depth entry (D33)

    val blast_depth_tac : clasetLib.claset -> int -> tactic

Single tableau search at exactly the given resource bound (no
`DEEPEN`), no seed-rewrite preprocessing, no local elim additions —
the analogue of `Blast.depth_tac ctxt m` as used by `mk_auto_tac`
(`clasimp.ML:152`).  Untranslatable goals and search failure = ordinary
tactic failure (Isabelle returns `Seq.empty`, `blast.ML:1276–1277`).
Reconstruction and PROOF-FAILED backtracking behave as in `BLAST_TAC`.

### 3.4 Layer-wide insertion refactor (D30)

- `classicalLib` uppercase tactics and `tableauLib.BLAST_TAC`/
  `BLAST_DEPTH_TAC`: leftover unmarked theorems in the argument list are
  no longer converted to unsafe intros; they are inserted as assumptions
  of the goal before the engine runs (validation via `PROVE_HYP`, i.e.
  standard `ASSUME_TAC` plumbing; the theorem is inserted as-is,
  universally closed, matching Isabelle's fact insertion).  For blast,
  inserted facts become branch formulas through the normal
  `fromSubgoal` translation — strictly the natural channel.
- Marker processing (`process_claset_tags`) is otherwise unchanged;
  the explicit-role channel is markers.
- Phase-1/2 selftests that relied on plain-as-intro are updated to
  `Intro th` (audit during the task; expected a handful).
- Docfiles for the Phase-1/2 tactics updated to document insertion.

### 3.5 Marker constructors `Simp`, `Iff` (D30, freeze amendment)

Added to the marker theory in `src/auto/rules` (`clasetMarkerScript`),
alongside the existing six + `Del`: `Simp : thm -> thm` (use only
as a simpset addition), `Iff : thm -> thm` (per-invocation iff: feed
the temporary claset *and* the temporary simpset through the §8
decision tree).  `rules/` only defines the constructors (it stays
independent of `src/simp`); interpretation lives in `clasimpLib`'s
argument processor (§6).  `classicalLib`/`tableauLib` reject `Simp`/
`Iff` with a clear error (they have no simpset), rather than silently
ignoring them.

## 4. The clasimpset (D28)

### 4.1 Definition

`clasimpLib` keeps a private derived value

    val clasimp_ss : unit -> simpLib.simpset

built with `BasicProvers.make_simpset_derived_value` (stale-flag cached;
recomputed only when `srw_ss` changes) as:

    srw_ss()
      |> simpLib.set_cond_depth 40          (* layer convention, §5.5 of PLAN.md *)
      |> (fn ss => ss ++ splitLib.split_ss) (* splitter looper + cases_simp *)
      |> simpLib.add_safe_solvers safe_solver_stack

Notes:
- Isabelle's `auto` simpset has the splitter installed by default
  (`simpdata.ML:153–184`); `AUTO_TAC`'s simp therefore splits `if`/
  `case` while plain `SIMP_TAC (srw_ss())` does not.  This is the
  intended layer-vs-distribution difference (D19 untouched); documented
  prominently in the `AUTO_TAC` Docfile.
- `[simp]`, TypeBase rewrites (via `tyi_to_ssdata`,
  `BasicProvers.sml:1245`), and Phase-3 `[iff]` all reach `clasimp_ss`
  automatically because they feed `srw_ss`.

### 4.2 The safe-solver stack

Port of HOL's safe solver (`simpdata.ML:146–151`): a `mk_tactic_solver`
lift of FIRST of — assumption *matching* (goal α-equal to an
assumption), reflexivity matching (`x = x`), `TrueI`-style matching
(`T`), and contradiction from an assumption matching `F`.  No
metavariable instantiation, no resolution against arbitrary premises.
Registered as the clasimpset's safe list; the unsafe list keeps the
delivered default behavior.

### 4.3 The two simp tactics of the phase

    (* asm_full_simp_tac analogue, mut_impc parity (D17/D31) *)
    fun asm_full_simp ss ths =
      GEN_GLOBAL_SIMP_TAC {safe = false}
        {base = <droptrues/elimvars/strip config mirroring gvs-family
                 defaults reviewed at implementation, oldestfirst>,
         concl_in_fixpoint = true, imp_rebuild = true} ss ths

    fun safe_asm_full_simp ss ths =
      GEN_GLOBAL_SIMP_TAC {safe = true} { ...same config... } ss ths

The `base : simptac_config` field values are fixed in the first
implementation task by reading each flag against Isabelle's
`asm_full_simp_tac` semantics (mutual assumption rewriting, assumptions
decomposed per `mksimps_pairs`) and recorded in the module as the one
shared constant; they are an engine-faithfulness matter, not a tuning
knob, so no owner decision is needed.

## 5. `addss` / `addSss` (port of `clasimp.ML:44–54`)

    val addss  : simpLib.simpset -> clasetLib.claset -> clasetLib.claset
    val addSss : simpLib.simpset -> clasetLib.claset -> clasetLib.claset

- `addss ss` = `add_unsafe_wrapper ("asm_full_simp_tac", w)` where
  `w step = NAPPEND (NCHANGED (LIFT (asm_full_simp ss [])), step)` —
  full simp offered as a backtrackable alternative *before* every
  unsafe step (Isabelle's `addbefore`; `APPEND'` composition).
- `addSss ss` = `add_safe_wrapper ("safe_asm_full_simp_tac", w)` where
  `w step = NORELSE (step, NCHANGED (LIFT (safe_asm_full_simp ss [])))`
  — safe simp tried when ordinary safe steps fail (Isabelle's
  `addSafter`; `ORELSE'` composition).
- Slot names match Isabelle for greppability; re-adding overwrites the
  slot (delivered claset semantics).
- These wrappers run at the delivered D24 application points on
  materialized goals (metavariables rendered as rigid frees): the simp
  tactic can never instantiate engine metavariables — precisely
  Isabelle's rewriter-level guarantee.  The recorded Phase-3 *option*
  of solver-level instantiation
  (`research/phase12-classical-search-port.md` §4.3) is **not**
  exercised in this phase; it remains a recorded option for the
  Phase-8 benchmark review.

## 6. Argument processing

One processor in `clasimpLib`, shared by all six tactics:

1. Partition the `thm list`: `Simp th` → simpset additions;
   `Iff th` → per-invocation iff (both stores, §8 decision tree,
   temporary); claset markers (`SIntro`…`Dest`, `Del`) → temporary
   claset via `process_claset_tags`; simp-side markers
   (`Cong`, `Split`, `AC`, `Excl`, `ExclSF`, `SF`, `Once`, `Ntimes`)
   → passed through to the simp invocations; **plain theorems →
   inserted as assumptions first** (D30).
2. The resulting `(claset, simpset)` pair parameterizes the script; the
   insertion happens once, before step 1 of each script, so inserted
   facts are visible to every phase (simp passes, safe steps, search,
   blast) — Isabelle's chained-fact order (`SIMPLE_METHOD'` inserts
   before the method body).

This gives `AUTO_TAC [th1, Simp th2, SIntro th3, Iff th4, Split th5]`
as the analogue of `using th1 by (auto simp: th2 intro!: th3 iff: th4
split: th5)`.

## 7. The tactics

All uppercase forms are `thm list -> tactic`, reading `the_claset()`
and `clasimp_ss()` at application time.  Lowercase forms:

    val auto_tac      : {blast : int, depth : int}
                        -> clasetLib.claset -> simpLib.simpset -> tactic
    val force_tac     : clasetLib.claset -> simpLib.simpset -> tactic
    val fastforce_tac : clasetLib.claset -> simpLib.simpset -> tactic
    val slowsimp_tac  : clasetLib.claset -> simpLib.simpset -> tactic
    val bestsimp_tac  : clasetLib.claset -> simpLib.simpset -> tactic
    val clarsimp_tac  : clasetLib.claset -> simpLib.simpset -> tactic

(Deterministic tactics, not `ntactic`s: each either fails or commits —
auto/clarsimp by D27 change-or-fail, the FORCE family by must-close.
The nondeterministic engine remains reachable through `classicalLib`'s
lowercase forms plus `addss`.)

### 7.1 `AUTO_TAC` (port of `mk_auto_tac`, `clasimp.ML:147–161`)

For a single HOL4 goal, with `cs' = addss ss cs`:

    1  asm_full_simp ss                       (* may be a no-op        *)
    2  THEN TRY (safe pass: DETERM (safe_tac cs))
    3  THEN (on every remaining subgoal)
         TRY (blast_depth_tac cs m            (* m = 4 default        *)
              ORELSE DETERM (depth_solve_tac {dup=false} n cs'))
                                              (* n = 2 default        *)
    4  THEN TRY (safe pass: DETERM (safe_tac (addSss ss cs)))
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
- `AUTO_DEPTH_TAC (m, n) : thm list -> tactic` exposes the two bounds;
  `AUTO_TAC = AUTO_DEPTH_TAC (4, 2)` (Isabelle defaults, PLAN.md §11
  numeric-defaults record).
- Idempotence (up to blast instantiations, `clasimp.ML:145–146`) is a
  selftest property (§10).

### 7.2 `FORCE_TAC` (port of `force_tac`, `clasimp.ML:167–173`)

With `cs' = addss ss cs`, on a single goal:

    DETERM (clarify_tac cs')      (* addss inert here — documented    *)
    THEN asm_full_simp ss         (* skipped when already solved      *)
    THEN on every remaining subgoal: DETERM (first_best_tac cs')
    overall: fail unless zero subgoals remain.

(`IF_UNSOLVED` is automatic in HOL4 — solved goals produce no
subgoals for the subsequent `THEN`.)

### 7.3 `FASTFORCE_TAC`, `SLOWSIMP_TAC`, `BESTSIMP_TAC`
(`clasimp.ML:178–180`)

    fastforce_tac cs ss = must_close (DETERM (fast_tac (addss ss cs)))
    slowsimp_tac  cs ss = must_close (DETERM (slow_tac (addss ss cs)))
    bestsimp_tac  cs ss = must_close (DETERM (best_tac (addss ss cs)))

where `must_close t` fails unless `t` leaves no subgoals (the delivered
search drivers already solve-or-fail; `must_close` is a documented
guard, not new search semantics).

### 7.4 `CLARSIMP_TAC` (port of `clarsimp_tac`, `clasimp.ML:119–121`)

    safe_asm_full_simp ss
    THEN (on every resulting subgoal) DETERM (clarify_tac (addSss ss cs))
    overall: fail iff nothing changed (D27; Isabelle's method is
    CHANGED_PROP oo clarsimp_tac).

The manual's caveat that a premise splitter in the simpset can still
split the subgoal (`Generic.thy:1624–1626`) carries over verbatim
(clasimpset contains `split_ss`) and goes into the Docfile.

## 8. `[iff]` (D29; port of `clasimp.ML:87–112, 188–195`)

### 8.1 The decision tree (one function, used by attribute, marker, and TypeBase hook)

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
  `clasimpLib` following the `splitLib` pattern (including the
  registration-collision guard).  Apply hook: run §8.1, push the claset
  half through `clasetLib.augment_claset`, the simpset half through
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
delivered rules/ hook — `register_tyinfo_contribution` is frozen and
suffices) adding those intros; nothing already-seeded is duplicated
(claset dedup by rule name).  Case-split theorems stay with `[split]`
(Phase S); nchotomy/cases remain for the aesop cases-builder (Phase 4).

## 10. Selftests (`src/auto/clasimp/selftest.sml`)

1. Unit: marker/argument processor (each marker kind; plain-thm
   insertion visible in residue; `Simp`/`Iff` rejection by
   classical-only tactics).
2. Wrapper: goals solvable only via `addss` inside search (Isabelle's
   motivating shapes); `addSss` residue safety (no instantiation of
   engine metavariables — rigid-render guard test).
3. Scripts: per-tactic goal batteries translated from the Isabelle
   regression corpus (`auto`, `force`, `fastforce`, `clarsimp`
   examples), plus HOL4-native set/list/option goals; FORCE-family
   must-close negative tests; AUTO/CLARSIMP change-or-fail tests.
4. AUTO idempotence: `AUTO_TAC` residue re-run is a no-op on a corpus
   without blast instantiations.
5. `[iff]`: derivation table cases (all six shape×conditional
   combinations); persistence round-trip in a scratch theory
   (export, reload, both stores populated; `remove_iff` retracts both).
6. TypeBase: constructor intros present for a datatype defined *after*
   load and one from the catch-up sweep.
7. Amended modules: §3.1 safe-mode tests (in `src/simp` selftest),
   §3.2 `depth_solve_tac` dup/nodup divergence test (a goal solvable
   only with duplication fails at `{dup=false}`), §3.4 insertion
   regression across the Phase-1/2 suites.

## 11. Documentation

`help/Docfiles` for the six tactics, `AUTO_DEPTH_TAC`, `addss`/`addSss`,
`[iff]`/`remove_iff`, `Simp`/`Iff` markers; updates to the Phase-1/2
tactic Docfiles (insertion semantics) and `BLAST_TAC`'s (unchanged
public behavior; cross-reference the raw entry).  The `AUTO_TAC` entry
documents: clasimpset = `srw_ss` + splitter + depth-40 side conditions;
splitting difference vs `SIMP_TAC (srw_ss())`; residue semantics;
depth parameters.

## 12. Task breakdown (dependency order; per-task gate `bin/build -t --seq=tools/sequences/upto-auto`, h4pedant on touched dirs)

| # | Task |
|---|---|
| 01 | `simpLib` mode parameter (D31): signature change, internal callers, selftests, `PLAN_phase_S.md` §12 amendment note |
| 02 | `classicalLib.depth_solve_tac` (D32): export + internal refactor + selftests |
| 03 | Insertion refactor (D30): `classicalLib` + `tableauLib` + Phase-1/2 selftest/Docfile updates |
| 04 | `tableauLib.blast_depth_tac` (D33) + selftests |
| 05 | `Simp`/`Iff` marker constructors in `rules/` + rejection paths in classical/blast |
| 06 | `src/auto/clasimp/` scaffold: Holmakefile (hol.state0 heap, selftest.exe, HOLSELFTESTLEVEL tee), build-sequence entries (`tools/sequences/upto-auto`, `src/parallel_builds/core/Holmakefile` SRCRELNAMES), clasimpset + safe-solver stack |
| 07 | `addss`/`addSss` + argument processor |
| 08 | `FASTFORCE_TAC`/`SLOWSIMP_TAC`/`BESTSIMP_TAC` + `CLARSIMP_TAC` + selftests |
| 09 | `AUTO_TAC`/`AUTO_DEPTH_TAC` + `FORCE_TAC` + selftests |
| 10 | `[iff]`: decision tree, settype, attribute, `remove_iff`, `Iff` marker wiring, persistence selftests |
| 11 | TypeBase completion (§9) + selftests |
| 12 | Docfiles (§11) |
| 13 | Phase gate: full `bin/build -F -t`; record result in `PLAN.md` §11 gate record (the pre-existing `src/probability` `in_borel_measurable_inv` failure, reproduced at the Phase-1 base, is the known exception) |

## 13. Risks

1. **Insertion refactor regressions** (D30): Phase-1/2 selftest goals
   that leaned on plain-as-intro change behavior.  Mitigation: task 03
   audits and converts call sites to `Intro th`; the full suites gate
   the change in isolation before clasimp lands.
2. **Safe-solver misport**: too-strong a safe solver reintroduces
   instantiation (unsound for `addSss`'s purpose), too weak loses
   parity.  Mitigation: matching-only implementation + the §10.2
   rigid-render guard test.
3. **`asm_full_simp` base-config fidelity** (§4.3): wrong
   `simptac_config` flags diverge from `mksimps`-style assumption
   decomposition.  Mitigation: flag-by-flag comparison recorded in the
   module comment; mutual-simplification selftests ported from the
   Phase-S D17 battery.
4. **Wrapper-lifted simp cost** inside `depth_solve_tac` (render →
   simp → unrender per unsafe step alternative).  Mitigation: `NCHANGED`
   prunes no-op simp branches (as upstream's `CHANGED`); Phase-8
   wall-clock benchmarks arbitrate further tuning.
5. **`[iff]` cross-stream ordering** (§8.2 caveat): tie-break-only;
   monitored via Phase-8 parity suite.

## 14. Interfaces later phases rely on (freeze list)

Frozen at Phase 3 completion (changes require an owner decision):
`clasimpLib`'s public signature (six tactics + `AUTO_DEPTH_TAC`,
lowercase forms, `addss`/`addSss`, `clasimp_ss`, `remove_iff`); the
`"iff"` settype name, delta semantics, and §8.1 derivation table; the
`Simp`/`Iff` marker semantics; the layer-wide insertion convention
(D30); and the amended signatures
`GEN_GLOBAL_SIMP_TAC : simp_mode -> xsimptac_config -> simpset ->
thm list -> tactic`, `classicalLib.depth_solve_tac`, and
`tableauLib.blast_depth_tac`.
