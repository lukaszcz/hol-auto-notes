# Plan: remove the M1/M2 timing/diagnostic instrumentation tower

Date: 2026-07-23.  Branch: `isabelle-tactics`.  Parent plan: `PLAN.md`
§6 (classical/blast) and §14 (M1/M2 record).

## 0. Precondition (owner decision to record before executing)

The tower is the measurement apparatus for the **M1** (wall-clock) and
**M2** (perturbation/profiling) milestones, both **closed** (PLAN.md §14:
M1 closed line 1249, M2 closed by D35 line 1244; Phases 1/2 complete line
1261). No planned phase consumes it (Phase 3 `PLAN_phase_3.md` §2/§14
freeze lists reference only production APIs; Phase 8 benchmarking uses
end-to-end selftest wall-clock, PLAN.md §11 line 849).

The **one** live thread is the recorded, explicitly non-blocking M1
follow-up — *"current-revision performance is not claimed"* for head
`f4fc8be66` (PLAN.md line 1254). Removing the tower forecloses re-measuring
that at the tower's fine granularity (internal phase/clock/allocation
breakdown). Precondition to record: **the owner accepts dropping that
fine-grained re-measurement** (coarse end-to-end wall-clock, which Phase 8
uses anyway, remains available). If instead the capability must be kept,
use the *collapse-to-parameterized-monitor* refactor (a separate plan), not
this removal.

The archived evidence under `.agent-files/benchmarks/{m1,m2,m2-*}/`
(gitignored) names these functions in prose READMEs; after removal those
become dangling textual references — harmless (archival, not code), noted
in Task 6.

## 1. The critical boundary — what is tower vs what is production

The token **"measured"/"Measured" is overloaded across two unrelated
families**, and the split is *by subtree*:

### PRESERVE — do NOT touch (production cooperative interruptibility)

`tableauLib.tryIt` is a **listed production entry point** and it reaches
the blast measured search:
`tryIt` (`blast/tableauLib.sml:197`) → `blastSearch.debugGoal`
(`blastSearch.sml:2521`) → `searchGoalMeasured` (`:2504`) → the `On` arm of
`runTerms` (`:1466–1582`) → **all** the `*Measured` checkpoint-threaded
workers in `blastSearch`, `blastRule`, and `blastTerm`. The in-file comment
at `blastSearch.sml:2530–2533` and `blastRule.sig:48–59` confirm the
checkpoint/monitor is the cooperative-interruption path.

Therefore **entirely off-limits**:
- `blast/blastRule.sml` — every `*Measured` (`containsZeroMeasured`,
  `cachedMeasured`, `acquireMeasured`, `safeRulesMeasured`,
  `unsafeRulesMeasured`, …) and the `monitor` type. **Nothing to remove.**
- `blast/blastTerm.sml` — every `*Measured`/`*_measured`
  (`aconvMeasured`, `unifyMeasured` (**it lives here, not `clasetNet`**),
  `normMeasured`, `clearToMeasured*`, …). **Nothing to remove.**
- `blast/blastSearch.sml` — `searchGoalMeasured`, `debugGoal`, the `On`
  arm, all blastSearch-local `*Measured` workers. **Keep** (see §3 for the
  one 5-line unused wrapper and the optional phase-field cleanup).
- `blast/tableauLib.sml` — `run_statistics` and friends are the
  **production** `BLAST_TAC` trace-≥2 statistics path. **Nothing to
  remove.**
- Classical production step/replay/search API: `clasetStep.{try_rule,
  exact_rule_results, direct_step, blast_rule_step, blast_rule_step_at}`,
  `clasetMeta.{norm,bind,bind_ty,is_eigen,register_eigen,inst_types,…}`,
  `clasetUnify.{unify,unify_types,norm_type}`, all of `clasetReplay`,
  `clasetSearch`, `clasetGoal`, `classicalLib`. **Keep.**

Also note (name traps the executor must respect): the cut line in each
tower module sits one declaration below a same-prefixed production export
— e.g. `clasetMeta` production `bind`/`register_eigen` vs tower
`bind_diagnostic`/`register_eigen_diagnostic`; `clasetStep`
`measured_rule_checkpoint` is **tower** despite the "checkpoint" in its
name (it polls the tower monitor, not production interruption).

### REMOVE — the tower

Two disjoint pieces, both consumed *only* by `selftest.sml` (and, before
removal, by each other):
1. **Classical timing/diagnostic tower** — clasetStep + clasetUnify +
   clasetMeta. No production classical entry references any of it
   (grep-verified: `classicalLib.sml`, `clasetReplay.sml`,
   `clasetSearch.sml`, `clasetGoal.sml` contain zero
   `measured|timed|diagnostic|checkpoint` references).
2. **Blast reconstruction tower** — `blastReconstruct` measured/timed
   clones only. (The blast *search* measured path is PRESERVE, above.)

## 2. Exact removal inventory (grep-verified)

| Module | `.sml` REMOVE ranges | `.sig` REMOVE range | ~`.sml` lines |
|---|---|---|---|
| `classical/clasetStep` | `861–1308`, `2143–3557` | `51–410` | 1863 |
| `blast/blastReconstruct` | `140–2894` | `14–401` | 2755 |
| `classical/clasetUnify` | `196–1241` (to EOF) | `22–158` | 1046 |
| `classical/clasetMeta` | `521–972` | `37–53` | 452 |
| `blast/blastSearch` | `searchTermsMeasured` `2499–2503` only | `174–177` only | 5 |

Boundary confirmations (spot-checked):
- `clasetStep.sml`: production `exact_rule_results` block ends `:859`;
  tower opens `datatype measured_rule_kind` `:861`; tower closes `:3557`;
  production `blast_disch_step` resumes `:3559`. `.sig`: tower comment
  `:51`, opens `:55`, closes `timed_rule_trace_allocations_v4` `:410`,
  production `blast_disch_step` `:412`.
- `blastReconstruct.sml`: production `reconstruct`/`reconstructWith`
  `:134–138`; tower opens `datatype step_kind` `:140`; closes `:2894`;
  production `accept` `:2895`. `.sig` tower `:14–401`; production
  `reconstruct`/`reconstructWith` `:10–11`, `searchGoal`… `:405–411`.
- `clasetUnify.sml`: tower opens `datatype timed_phase` `:196` and runs to
  EOF (`1241`); production `unify` `:91`, `unify_types` `:49` stay.
- `clasetMeta.sml`: tower opens `datatype diagnostic_phase` `:521`; closes
  `:972`; production `ground_types` resumes `:973`.

Total: **~6,116 `.sml` lines + ~900 `.sig` lines + selftest blocks** (§4).

Removal must be **atomic per module**: `.sml` range + matching `.sig`
range + that module's selftest references, in one task, so no intermediate
state has a `.sig`/`.sml` mismatch or a dangling selftest reference.

## 3. `blastSearch` — the two subtle items

1. **`searchTermsMeasured` (`:2499–2503`, sig `:174–177`)** — a thin
   `pterm`-list sibling of `searchGoalMeasured` with **no production
   caller** (selftest only). It is *not* timing tower and shares the
   PRESERVE `On`-path infrastructure. Remove only the unused wrapper +its
   sig line + its selftest references; **do not** touch `searchGoalMeasured`
   or the `On` arm.
2. **Phase-counter fields / `phase_statistics`** — `phase_statistics`
   (type `:1380`, `zero_phase_statistics` `:1394`, `phaseResult` `:1551`)
   and the phase-counter fields embedded in the shared `statistics` record
   (`cooperative_checkpoints`, `candidate_rules_enumerated`,
   `rule_unification_attempts/successes`, …). These are **produced** by the
   production-reachable `On` arm but **consumed by no production caller**
   (`debugGoal` discards `#statistics` `:2527`; `searchGoalWithStats`
   leaves them zero; `tableauLib` reads only the core stats). They are
   test-only, but woven into the shared production `statistics` record and
   the `On` arm's plumbing.
   **Decision (recommended: DEFER).** Stripping them touches production
   plumbing and forces deleting/rewiring the blast phase-counter selftests
   (`1912`, `1971`) for a few dozen lines of field cleanup. Keep them for
   now; record as an optional follow-up. This plan removes only the cleanly
   severable pieces. (Owner may opt in to the strip as a separate task.)

## 4. Selftest handling — DELETE vs REWIRE

For each tower removal, its selftest consumers split into two kinds. The
**REWIRE** ones are the single biggest risk: they assert *production*
correctness but currently route it through a tower entry, so they must be
re-pointed at the production API, **not deleted** (deleting them silently
drops real coverage).

### `classical/selftest.sml`
- **DELETE** (pure counter/clock/trace assertions): groups at `~189`,
  `~373` (clasetMeta diagnostic traces); `~414`, `~2030` (clasetUnify timed
  clock/identity); `~4980`, `~5034`, `~5091`, `~5147`, `~5203`, `~5259`,
  `~5352`, `~5449`, `~5492` (clasetStep timed/measured counters).
- **REWIRE to production** (keep the correctness assertion, drop the
  counter half; re-point at `blast_rule_step`/`blast_rule_step_at` /
  `unify`):
  - `~1421` "ordinary and timed unifiers have table-driven branch parity"
    → keep the `unify` side, drop `unify_timed`.
  - `~4807` "measured exact rules preserve intro and elim sequence order"
    and the record/`valid_open_replay` block to `~4977` → production step
    record.
  - `~5549` "measured exact-rule observations and outputs are
    deterministic" → production determinism check.
  - `~7190` "selected exact rule has ordinary and timed-family parity" →
    keep ordinary, drop timed.

### `blast/selftest.sml`
- **DELETE** (measured/timed reconstruction counters/timing): groups at
  `~3815`, `~3913`, `~3944`, `~4017`; and the timed-detailed / v2 / v3 / v4
  / bounded-v4 groups `~4167, 4242, 4400, 4477, 4572, 4647, 4709, 4771,
  4840, 4919, 4962, 5035, 5095, 5228, 5299, 5356, 5458, 5508, 5619, 5670,
  5726, 5821`.
- **REWIRE to `reconstructWith`** (kernel-validity / parity asserted
  through a measured entry — keep the `Tactical.VALID` / residual-`aconv`
  half, drop the counter half):
  - `~3357` "static-prefix tableau has all reconstruction API parity"
  - `~3799` "reconstruction goldens cover T2 and T3 under Tactical.VALID"
  - `~3854` "measured close-contradiction has exact kernel-valid parity"
  - `~4058` "detailed stored replay has exact completed parity…"
  - `~4311` "timed-v2 reconstruction is … API-equivalent"
- **KEEP untouched**: the blast measured-*search* interruptibility groups
  (`~1065, 1118, 1190, 1226, 1262, 1482, 1532, 1610, 1703, 1912, 1971,
  2041, 2069, 2097, 2195, 2382, 2419` and `blastTerm.clearTo` `141/159`) —
  they test PRESERVE cooperative-stop/rollback behavior, not the tower.
  (Only affected if the §3.2 phase-field strip is later opted into.)

Line numbers are pre-removal anchors; the executor greps the group label
to locate each, since earlier deletions shift later numbers.

## 5. Removal order (each task independently builds + gates)

The tower is a closed dependency DAG:
`blastReconstruct.measured → clasetStep.measured/timed →
clasetUnify.timed → clasetMeta.diagnostic`. Remove **top-down** (a consumer
before its producer) so every intermediate state compiles — after each
step the next layer down is left consumed only by selftest, which that
step's task deletes/rewires in the same commit.

## 6. Task breakdown

Per-task gate: `Holmake` + `./selftest.exe` in the touched `src/auto`
directory, then `bin/build -t --seq=tools/sequences/upto-auto`;
`tools/h4pedant` on the touched dirs. Each task is one atomic commit
(`.sml` + `.sig` + selftest together).

| # | Task |
|---|---|
| 0 | Record the §0 precondition (owner). Confirm `git grep` shows no non-selftest caller of any REMOVE symbol (re-verify at execution time; the tree may have moved). |
| 1 | **blastReconstruct tower**: delete `.sml:140–2894`, `.sig:14–401`; delete the `blast/selftest.sml` reconstruction-counter groups (§4); **rewire** `~3357, 3799, 3854, 4058, 4311` to `reconstructWith`. Gate. |
| 2 | **clasetStep tower**: delete `.sml:861–1308` + `2143–3557`, `.sig:51–410`; delete the clasetStep counter groups; **rewire** `~4807, 5549, 7190` to production step API. (blastReconstruct.measured — its only non-test consumer — is already gone from Task 1.) Gate. |
| 3 | **clasetUnify timed**: delete `.sml:196–1241`, `.sig:22–158`; delete `~414, 2030`; **rewire** `~1421` to `unify`. (clasetStep.timed gone from Task 2.) Gate. |
| 4 | **clasetMeta diagnostic**: delete `.sml:521–972`, `.sig:37–53`; delete `~189, 373`. (clasetUnify.timed gone from Task 3.) Gate. |
| 5 | **blastSearch `searchTermsMeasured`**: delete `.sml:2499–2503`, `.sig:174–177`, and its selftest refs. Gate. (Independent; may land any time.) |
| 6 | Housekeeping: annotate the `.agent-files/benchmarks/*/README.md` that name removed functions with a one-line "function removed 2026-07-xx; see git history" note (gitignored evidence, optional but keeps the archive honest). Update `PLAN.md` §14 with a short "tower removed at commit …; M1 fine-grained re-measurement capability retired per §0" note. |
| 7 | Phase gate: `bin/build -F -t` green (the known pre-existing `src/probability/real_borelTheory in_borel_measurable_inv` failure is the documented exception, PLAN.md §11). Record in `PLAN.md` §11 gate record. |

## 7. Interaction with `PLAN_blast_linear.md`

Both plans touch `blast/blastRule.sml`. The inventory resolves that plan's
open Task 0: **`cachedMeasured` is PRESERVE** (production interruptibility),
so it stays and must receive the same Option-A bucketing fix as `cached`.
Sequencing: this removal touches `blastReconstruct`/`blastSearch` in the
blast subtree but **not** `blastRule` (all blastRule `*Measured` are
PRESERVE), so the two plans do not collide in `blastRule` and may proceed
in either order. Land whichever is ready; no coordination beyond the
already-recorded Task-0 answer.

## 8. Risks

1. **Deleting production interruptibility by mistake.** The blast
   `*Measured` family looks like tower but is production (§1). Mitigation:
   the removal ranges in §2 name only `blastReconstruct` + the 5-line
   `searchTermsMeasured` in the blast subtree; `blastRule`/`blastTerm`/the
   `On` arm are explicitly out of scope. Task 0 re-verifies no non-selftest
   caller.
2. **Silent coverage loss via deleted REWIRE tests.** §4 lists the exact
   correctness-through-tower tests; each must be re-pointed, not deleted.
   Mitigation: per-task the executor greps every deleted group label and
   classifies before removing; a rewired test must still pass
   `Tactical.VALID` / residual-goal assertions against the production
   entry.
3. **`.sig`/`.sml` mismatch mid-removal.** Mitigation: atomic per-module
   commits (§2), each independently gated.
4. **Phase-field entanglement in `blastSearch`.** Deferred by §3.2 to avoid
   touching shared production plumbing; not in this plan's scope.
5. **Foreclosing M1 re-measurement.** §0 precondition; if the owner wants
   the capability, switch to the collapse refactor instead of removal.

## 9. Interfaces / freeze impact

This removes exported `.sig` entries, but **no later phase depends on
them**: `PLAN_phase_3.md` §14 freeze list and §2 dependency table name only
production APIs; Phase 8 benchmarking uses selftest wall-clock (PLAN.md
§11). The production signatures of `clasetStep`, `clasetUnify`,
`clasetMeta`, `blastReconstruct`, `blastSearch`, `blastRule`, `blastTerm`,
`tableauLib`, `classicalLib` are unchanged. No `PLAN.md` freeze decision is
violated; the tower entries were never in a freeze list.
