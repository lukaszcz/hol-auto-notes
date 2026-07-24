# PLAN_review_phase_1_2 — code-review findings and fix plans

Review of branch `isabelle-tactics` (HEAD `f667a716d`) against
`origin/isabelle-tactics`, run 2026-07-24 via the workflow-backed
/code-review at high effort (32 agents; 26 candidates independently
verified; 19 upheld, grouped by root cause into 10 findings; 7 refuted).

Scope of the diff: 92 files — `src/auto/{rules,classical,blast}`,
`src/marker`, `src/simp` touch-ups, and new `help/Docfiles` pages.

## Owner decisions recorded (settled; do not re-litigate)

Recorded in `PLAN.md` §2 on 2026-07-24 as **D38** (= D-R1) and **D39**
(= D-R2).

- **D-R1** (finding 5): the lowercase claset-explicit layer is renamed
  to uppercase `CS_*_TAC` (`CS_SAFE_TAC`, `CS_FAST_TAC`, ...).  The
  claset-parameterized entry points stay public; docfiles renamed.
- **D-R2** (finding 6): unify the *cold-path* Measured twins on a
  checkpoint parameter; keep the *hot-path* twins (blastTerm and
  blastSearch inner loops) and add differential drift tests for them.

## Findings overview

| # | Sev | Location | Issue |
|---|-----|----------|-------|
| 1 | correctness | blastSearch.sml:1171 | engine subst model vs replay changed/unchanged split can diverge |
| 2 | correctness | markerLib.sml:141 (+clasetLib.sml:873) | marker vocabulary incomplete; Once/Req0 theorems dropped, NoAsms/Abbr become junk rules |
| 3 | correctness | tableauLib.sml:191 | negative depth_limit contradicts its docfile |
| 4 | correctness (PLAUSIBLE) | classicalLib.sml:121 | replay failure aborts search instead of backtracking |
| 5 | cleanup | classicalLib.sig:22 | lowercase Isabelle-alias layer violates naming rule |
| 6 | cleanup | blastRule.sml:283 (+blastTerm.sml:549) | hand-maintained Measured twin towers |
| 7 | cleanup | clasetGoal.sml:91 (+379, clasetMeta.sml:373) | uncached recomputation on node rebuild/compare |
| 8 | cleanup | clasetReplay.sml:835 | quadratic replay-script append / length |
| 9 | cleanup | clasetStep.sml:30 (+clasetUnify:14, clasetSearch:165, clasetGoal:46, clasetStep:501) | duplicated normalize/nth1 helpers |
| 10 | cleanup | blastReconstruct.sml:145 (+searchHeap.sig) | dead exported blast driver + unused heap ops |

---

## F1 — engine substitution model diverges from replay ordering

**Location**: `src/auto/blast/blastSearch.sml:1171` (`subEntry` inside
`equalTrackedSubst`; twin at `equalTrackedSubstMeasured` ~1190) vs
`src/auto/classical/clasetReplay.sml:535` (`BLAST_HYP_SUBST_TAC_AT`).

**Problem**.  After an equality substitution the engine reorders its
assumption model as `changed @ unchanged`, classifying each entry with
the *step-time* substitution (`substAtomic` leaves unbound metavariables
untouched).  Replay recomputes the same split on *grounded* assumptions
with `Term.subst` (`affected`, clasetReplay.sml:548-549).  If a
metavariable is bound after the substitution step to a term mentioning
the replaced atom, the two classifications disagree, the model and
replay assumption orders diverge, and every later recorded exact
assumption position selects the wrong occurrence.  Strict replay then
rejects a found tableau proof (PROOF_FAILED / "no reconstructible
proof").  The same mechanism affects the classical engine: search-time
`clasetStep.sml:1121` calls `BLAST_HYP_SUBST_TAC_AT` on rendered goals
(metas rendered as marked frees), replay re-runs it grounded.

**Fix: record the split; replay obeys the record.**  The step-time
classification becomes the single source of truth; replay stops
recomputing it.

1. `clasetReplay`: extend the hyp-subst replay action (grounded at
   clasetReplay.sml:750) from `position` to
   `{position : int, changed : bool list}` — the mask over the
   assumption list *after* deleting the equality, `true` = goes to the
   changed prefix.
2. `BLAST_HYP_SUBST_TAC_AT` takes the mask: partition `remaining` by
   mask (length mismatch → HOL_ERR); still `map substituted` over
   `changed @ unchanged`; validation unchanged (the child is
   constructed explicitly, so any permutation of the same multiset is
   valid, and `restore_target`/normalization checks are unaffected).
   Keep a compute-mode variant that derives the mask with the current
   `affected` test *and returns it*, for callers that decide at search
   time (`BLAST_HYP_SUBST_TAC` first-fit; clasetStep search step).
3. `clasetStep.sml:1121`: use the mask-returning variant; store the
   mask it actually used in the recorded action.
4. `blastSearch.equalTrackedSubst`: the `subEntry` fold already
   computes the model split; derive the mask in `remaining` order and
   thread it into the recorded proof step so grounding produces the
   mask-carrying action.  Apply identically in
   `equalTrackedSubstMeasured` (hot-path twin — both copies, see D-R2).
5. Audit that no other consumer relies on replay recomputing the split.

**Tests** (failing-first, `src/auto/blast/selftest.sml`): engine-level
scenario via `blastReconstruct.searchGoal` with a claset whose unsafe
rule binds a metavariable, after a hyp-subst step, to a term containing
the substituted image, followed by a step consuming an assumption by
exact position.  Assert the goal is proved (currently: reconstruction
failure).  Mirror a classical-side case in
`src/auto/classical/selftest.sml` if constructible.  Full corpus stays
green (upto-auto gate).

---

## F2 — simp-marker vocabulary incomplete; theorems dropped or junked

**Location**: `src/marker/markerLib.sml:141`
(`is_generic_simp_marker`); consumer
`src/auto/rules/clasetLib.sml:870-881` (`add_plain_theorems`).
`is_generic_simp_marker` has exactly one consumer today (clasetLib), so
extending it is safe.

**Problem**, two halves:
- The predicate's contract ("complete vocabulary") is violated: it
  omits `NoAsms`, `IgnAsm`, `Abbr`.  `FAST_TAC [markerLib.NoAsms, th]`
  installs `|- marker$NoAsms` as junk unsafe intro
  `__classical_extra_0`, shifting auto-generated names of genuine
  extras; the control silently does nothing.
- Content-*bearing* wrappers are dropped wholesale:
  `add_plain_theorems` skips any thm for which the predicate holds, and
  the predicate holds for `Req0`/`ReqD`/`Once`/`Ntimes` wrappers — so
  `FAST_TAC [Once th]` silently loses `th` entirely.

**Fix**:

1. `markerLib`: extend `is_generic_simp_marker` with `NoAsms` (concl
   aconv `NoAsms_t`), `IgnAsm` (head `IgnAsm_t`), and `Abbr` (reuse the
   internal `is_abbr`, markerLib.sml:352).  Keep the sig comment
   honest.
2. `markerLib`: add `dest_generic_simp_wrapper : thm -> thm option`
   returning the payload for the content-bearing wrappers
   (`dest_Req0`, `dest_ReqD`, `BoundedRewrites.DEST_BOUNDED`), applied
   repeatedly until fixpoint — the vocabulary stays in markerLib per
   its own comment ("consumers do not need to duplicate it").
3. `clasetLib.add_plain_theorems`: first unwrap via
   `dest_generic_simp_wrapper` (payload becomes a plain unsafe intro
   as any leftover theorem does); only then skip the remaining, purely
   inert controls (AC/Cong/Split/Excl/ExclSF/FRAG/NoAsms/IgnAsm/Abbr) —
   silent pass-through, consistent with the existing Cong/Excl
   treatment and the comment at clasetLib.sml:867-869.
4. Honor `Abbr` at the tactic layer (decided here as the dominating
   option — strictly stronger, mirrors `simpLib`'s use of
   `markerLib.ABBRS_THEN`): wrap the theorem-list entry points in
   `classicalLib` (`public`) and `tableauLib` (`BLAST_TAC`,
   `BLAST_DEPTH_TAC`) with `markerLib.ABBRS_THEN`, so
   `FAST_TAC [Abbr`x`, th]` unabbreviates `x` before search.  `Abbr`
   thms then never reach `invocation_claset`; the predicate extension
   remains as defense for other consumers.

**Tests** (failing-first, `src/auto/rules/selftest.sml` +
`src/auto/classical/selftest.sml`): (a) `FAST_TAC [Once th]` proves a
goal needing `th`; (b) `FAST_TAC [markerLib.NoAsms, th]` — inspect
`rules_of (invocation_claset ...)`: no marker-headed rule, genuine
extra still named `__classical_extra_0`; (c) `Abbr` scenario: goal with
an `Abbrev (x = e)` assumption closed by `FAST_TAC [Abbr`x`]` where the
unabbreviated goal is provable and the abbreviated one is not reached.

---

## F3 — negative depth_limit contradicts its documentation

**Location**: `src/auto/blast/tableauLib.sml:188-195`;
`help/Docfiles/tableauLib.depth_limit.smd:14-15`.

**Problem**.  `limit < 0` maps the initial depth to `NONE`;
`run_depths`'s `search NONE = NONE` short-circuits before *any* engine
work, so `BLAST_TAC` always raises.  The docfile claims "built-in
preprocessing can still solve a goal".

**Fix: align the doc to the code** (decided here: there is no
preprocessing-only entry in `run_depths` — everything happens inside
`blastSearch.searchGoal` — and `depth_limit := 0` already provides the
minimal depth-0-only run; inventing a preprocessing-only code path has
no use case).  Rewrite the docfile sentence: a negative value makes
`BLAST_TAC` fail outright without invoking the engine; use `0` for the
minimal single-depth run.

**Tests** (`src/auto/blast/selftest.sml`): with save/restore of the
ref — `depth_limit := ~1` makes `BLAST_TAC []` raise HOL_ERR even on a
trivial goal; `depth_limit := 0` still closes a depth-0-provable goal.

---

## F4 — classical drivers abort on first non-replayable solution

**Location**: `src/auto/classical/classicalLib.sml:115-129`
(`replay_node`, `replay_step`), consumed by `solve` (:179) and all
drivers.  Verdict PLAUSIBLE: the mechanism is confirmed (REPLAY_TAC's
HOL_ERR at clasetReplay.sml:1046 propagates uncaught through `seq.bind`
and `DETERM`); the trigger requires an engine/replay divergence such as
F1.

**Fix**.  In `replay_node`, evaluate
`clasetReplay.REPLAY_TAC grounded original` under a `HOL_ERR` handler:
on failure emit a message on the `"classical"` trace key ("kernel
replay failed for an engine solution; backtracking: <origin.message>")
and return `seq.empty`, so `seq.bind` proceeds to the next engine
solution.  Overall tactic failure then means *no* solution replayed —
matching blast, which routes replay failure through PROOF_FAILED back
into search.  The trace keeps divergences visible instead of silently
eaten (they always indicate an engine/replay bug worth reporting).
Apply the same handling to `replay_step` (STEP_TAC family).

**Tests**: no honest reproducible trigger exists once F1 is fixed, and
manufacturing one would mean a test-only seam into internals (out per
project rules).  Covered by: F1's failing-first test exercising the
pre-fix path, and the existing suites confirming no behavior change for
replayable solutions.

---

## F5 — lowercase Isabelle-alias layer (D-R1: rename to CS_*_TAC)

**Location**: `src/auto/classical/classicalLib.sig:22-38` and impl;
16 `help/Docfiles/classicalLib.*_tac.smd` pages.

**Fix** per D-R1:

1. Rename in sig + impl: `safe_tac` → `CS_SAFE_TAC`, `clarify_tac` →
   `CS_CLARIFY_TAC`, `safe_step_tac` → `CS_SAFE_STEP_TAC`,
   `clarify_step_tac` → `CS_CLARIFY_STEP_TAC`, `step_tac` →
   `CS_STEP_TAC`, `slow_step_tac` → `CS_SLOW_STEP_TAC`,
   `inst_step_tac` → `CS_INST_STEP_TAC`, `fast_tac` → `CS_FAST_TAC`,
   `slow_tac` → `CS_SLOW_TAC`, `best_tac` → `CS_BEST_TAC`,
   `slow_best_tac` → `CS_SLOW_BEST_TAC`, `first_best_tac` →
   `CS_FIRST_BEST_TAC`, `astar_tac` → `CS_ASTAR_TAC`,
   `slow_astar_tac` → `CS_SLOW_ASTAR_TAC`, `deepen_tac` →
   `CS_DEEPEN_TAC`.  Types unchanged (`claset -> ntactic`).
2. Private helpers that are not exported (`safe_saturate`,
   `step_ntactic`, `replay_step`, drivers) keep lowercase — the rule
   governs the public API.
3. Rename the 16 docfiles (`classicalLib.safe_tac.smd` →
   `classicalLib.CS_SAFE_TAC.smd`, ...) and fix their bodies and
   See-also cross-links, including links *from* the uppercase pages.
4. Update `src/auto/classical/selftest.sml` references; grep the whole
   tree (incl. `Manual/`) for remaining `classicalLib.<lowercase>`
   references.

**Tests**: build + existing suites (pure rename).

---

## F6 — Measured twin towers (D-R2: unify cold, drift-test hot)

**Location**: twin pairs across `blastRule.sml` (translator,
convertIntro, copyRules, cached), `blastTerm.sml`, `blastSearch.sml`,
`clasetRules.sml`, `clasetLib.sml`, `clasetNet.sml`.

**Fix** per D-R2:

1. **Unify cold paths** (per-invocation setup/translation, not
   per-inference): `blastRule.translator{,Measured}`,
   `convertIntro{,Measured}`, `copyRules{,Measured}`,
   `cached{,Measured}`; `clasetRules.canonical_form_of_measured`;
   the `clasetLib` and `clasetNet` twins.  Each becomes one
   implementation taking `checkpoint : unit -> unit`; unmeasured
   callers pass `fn () => ()`.  Preserve observable claset behavior
   (rules_of order, exact candidate-query sequences — CLAUDE.md
   constraint); the no-op parameter must not change results, only
   remove the twin.
2. **Keep hot-path twins**: `blastTerm` term-operation cores
   (incr_boundvars, loose_bnos, subst_bound, varOccur, ...) and the
   `blastSearch` inner search loop (incl. `equalTrackedSubst` — F1
   edits both copies).
3. **Drift tests** for the remaining twins
   (`src/auto/blast/selftest.sml`): differential run of the existing
   benchmark corpus through `searchGoal` and `searchGoalMeasured`
   (no-op stop predicate), asserting identical solved sets and
   identical recorded proofs; plus per-pair unit checks of the
   remaining `blastTerm` twins on the existing test formulas.  Any
   future divergence turns the suite red.
4. Sanity: existing time-budget selftests bound any perf regression
   from the cold-path unification (expected: none — cold paths).

---

## F7 — uncached recomputation on node rebuild and compare

**Location**: `src/auto/classical/clasetGoal.sml:91-160` (make_node and
the set_* rebuilders), `:375-383` (equal/compare),
`src/auto/classical/clasetMeta.sml:373` (listed_as_eigen).

**Fix**:

1. `set_level`, `set_binding_marks`, `record_step` construct the
   `Node` record directly, reusing the existing `size`, `store`, and
   `avoids` fields — their goals and store are unchanged, so the
   cached values remain valid (this is the entire point of the
   invariant; add a comment stating it).  `set_goals`/`set_store`
   keep going through `make_node`.
2. Memoize `canonical_rendering`: add a `rendering : term option ref`
   field filled on first use (nodes are otherwise immutable; Moscow
   ML-compatible).  `equal` keeps its `size` fast path.
3. `clasetMeta`: replace the linear `listed_as_eigen` scan (whole
   eigens dict, `inst_types` per entry, per query) with a name-keyed
   lookup: `#eigens` as `Redblackmap` from variable name to entries;
   a query instantiates only the queried variable and the same-name
   bucket.  Semantics preserved: `same_var` compares
   `inst_types`-normalized vars, and distinct-typed same-name eigens
   stay distinguishable inside the bucket.

**Tests**: behavior-preserving; existing classical suites plus the
strength benchmarks' time budgets (upto-auto gate) are the guard.

---

## F8 — quadratic replay-script bookkeeping

**Location**: `src/auto/classical/clasetReplay.sml:835` (`append`),
`:868` (`script_length`, aliased to `length`, used per candidate via
`clasetGoal.replay_length` in `clasetStep.wrapped_step` :1772-1773).

**Fix**.  `Script` is internal to clasetReplay; extend its
representation to
`Script {roots, length : int, open_paths : int list list}`:

- `length`: incremented by one per `append`; `script_length` returns
  it — O(1) for the `wrapped_step` comparisons.
- `open_paths`: the open (NONE) slots' child-index paths in
  left-to-right traversal order — exactly the order `fill_option`
  enumerates.  `append` for target n looks up the n-th path, descends
  directly (O(depth)), and splices the new record's own open child
  slots' paths in place of the consumed entry, preserving order.
  `open_goals` becomes `List.length open_paths`.
- `empty count` initializes `[ [0], ..., [count-1] ]` paths.

All observable behavior (targets, ordering, errors on bad targets) is
unchanged; the "does not identify an open goal" error becomes an
out-of-range check on `open_paths`.

**Tests**: internal representation — per project rules, test through
specified behavior: existing replay suites plus F1's new scenarios;
strength-benchmark time budgets bound the win/regression.

---

## F9 — duplicated private helpers across claset modules

**Location**: verbatim copies of `normalize_conv`, `normalize_thm`,
`normalize_rule_thm`, `split_imp_prefix`, `normalize_assumption`,
`nth1`/`delete_nth`, `term_size` in `clasetReplay.sml`,
`clasetStep.sml` (:30-60 and ~:501), `clasetUnify.sml`,
`clasetSearch.sml`, `clasetGoal.sml:46`.

**Fix**.  New leaf module `src/auto/classical/clasetNorm.{sml,sig}`
(depends only on Conv/Drule/Term — below clasetMeta in the dependency
order, avoiding cycles) holding the one copy of each helper; `nth1` /
`delete_nth` parameterized by origin (module, function) for the HOL_ERR
messages so existing error origins are preserved.  All five modules
drop their copies and reference `clasetNorm`.  The search/replay
normalization pipeline being *one* definition removes the
drift-into-replay-failure risk outright.  (Helpers needing
`clasetMeta.norm`, e.g. `normalize_term`, stay where they are — only
the store-independent helpers move.)

**Tests**: pure refactor; suites + upto-auto gate.

---

## F10 — dead exported blast driver and unused heap ops

**Location**: `src/auto/blast/blastReconstruct.sig:19-23`
(`deepenGoal`, `DEPTH_TAC`, `DEEPEN_TAC` — zero callers; they bypass
`invocation_claset`, statistics, and `depth_limit` handling, i.e. a
weaker prover under a near-identical name);
`src/auto/classical/searchHeap.sig` (`min`, `delete_min`, `size`
unused — used ops are `empty`, `add`, `is_empty`, `delete_all_min`).

**Fix**:

1. Delete `blastReconstruct.deepenGoal`, `DEPTH_TAC`, `DEEPEN_TAC`
   from sig and impl.  Keep `blastReconstruct.searchGoal` (heavily
   used by selftest) and `reconstructWith`.  `blastSearch.deepenGoal`
   keeps its selftest caller and its documented legacy status — leave
   it.  Re-verify zero callers by grep at implementation time; check
   no docfile documents the removed names.
2. Trim `searchHeap.sig` (and impl) to the used operations.

**Tests**: build + suites (dead-code removal).

---

## Refuted candidates (for the record — do not act on these)

1. `clasetStep.sml:1045` hyp-subst action mismatch — VAR_EQ_TAC
   handles the reflexive-equality case the scenario required.
2. `clasetStep.sml:117` raw Subscript escape — every call site is
   range-guarded before calling `nth1`/`delete_nth`.
3. `clasetLib.sml:214` update_alist order flip — tyinfo registration
   order change has no observable effect on rules_of order or
   candidate indices.
4. `clasetLib.sml:813` Del no longer aliasing Excl — intended, tested
   specification of this branch; deletion path has a replacement.
5. `src/simp/src/selftest.sml:2104` lost plain-theorem coverage —
   selftest:1450 still passes plain theorems through the same path.
6. `clasetLib.sml:777` default_goal_size metric change —
   `claset_config.size_of` is not used for best-first weighting.
7. `clasetRules.sml:127` measured canonicalizer re-implementation —
   deliberate (documented) and no constructible divergence; subsumed
   by F6's D-R2 treatment.

## Implementation order and gates

1. **F2 + F3** (small, independent; failing-first tests).
2. **F1**, then **F4** (F4's handler lands after F1's test exists so
   the pre-fix reproduction is exercised once).
3. **F9** (shared module) before **F7 + F8** (same files, less churn).
4. **F5 + F10** (renames / deletions, independent).
5. **F6** last (largest churn; drift tests close it out).

Gates: `Holmake` + `./selftest.exe` in the touched directory while
editing; `bin/build -t --seq=tools/sequences/upto-auto` after each
numbered group; `bin/build -F -t` at the end (phase boundary).  Style:
no tabs, no trailing whitespace, < 80 columns (`tools/h4pedant`).
