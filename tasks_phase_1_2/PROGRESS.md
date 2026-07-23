# Phase 1–2 progress

## Task status

- TASK_01 — done
- TASK_02 — done
- TASK_03 — done
- TASK_04 — done
- TASK_05 — done
- TASK_06 — done
- TASK_07 — done
- TASK_08 — done
- TASK_09 — done
- TASK_10 — done
- TASK_11 — done
- TASK_12 — done
- TASK_13 — done
- TASK_14 — done
- TASK_15 — done
- TASK_16 — done
- TASK_17 — done
- TASK_18 — done
- TASK_19 — done
- TASK_20 — done
- TASK_21 — done
- TASK_22 — done
- TASK_23 — **done/reclosed; current at `f4fc8be66`**: 48/48, expected
  list `[]`
- TASK_24 — **done/reclosed at `f4fc8be66`**: 9/9 Table 1, 4/4 sets,
  Halting II and robustness all pass
- TASK_25 — done
- TASK_26 — done
- TASK_27 — **done/reclosed at `f4fc8be66`**: committed-state full gate,
  h4pedant and PLAN §11 record pass

## Final status

All TASK_01–TASK_27, M1–M5 and the Phases 1/2 Green plan are complete.
There is no pending next task for this phase.  Accepted attempt-04 runs the
exact direct suites, `upto-auto`, `upto-parallel`, style/hygiene checks and
the final committed-state `bin/build -F -t`; the requirement audit is
`../PLAN_phase_1_2_green.md` §6.

M1 is closed under its original explicit milestone-local criterion:
behaviour preservation and measured improvement on all six workloads.
The verified `5bc674569` package has a 1,818-entry manifest, six `>=30s`
censored baselines, and all 18 exact kernel-valid public-production runs
below `3.544s`.  Attempt-04 contains no performance run for the newer
replay patch.  Performance at `f4fc8be66` is not claimed.  That transparent
limitation is a non-blocking follow-up.

M2 is closed under the 2026-07-23 owner decision because 48/48 Pelletier,
9/9 Table 1, 4/4 sets and Halting II now pass.  The kernel profiler remains
unavailable because `perf_event_paranoid` cannot be lowered; that is an
environmental disclosure, not an open blocker.

## Completion log

- TASK_01 — completed and verified against its acceptance criteria.
- TASK_02 — completed and verified against its acceptance criteria.
- TASK_03 — completed and verified against its acceptance criteria.
- TASK_04 — completed and verified against its acceptance criteria.
- TASK_05 — completed and verified against its acceptance criteria.
- TASK_06 — completed and verified against its acceptance criteria.
- TASK_07 — completed and verified against its acceptance criteria.
- TASK_08 — reverified against its task file; doc processing, AliasGen, and
  style checks pass.
- TASK_09 — Phase-1 gate recorded; pre-existing full-build failure and clean
  h4pedant result verified.
- TASK_10 — completed and verified: Holmake/selftest, upto-auto build, and
  h4pedant pass.
- TASK_11 — completed and verified against its task file: Holmake/selftest,
  upto-auto build, and h4pedant pass.
- TASK_12 — completed and verified against its task file: Holmake/selftest,
  upto-auto build, and h4pedant pass.
- TASK_13 — completed and verified against its task file: Holmake/selftest,
  upto-auto build, and h4pedant pass.
- TASK_14 — completed and verified: all driver smoke/regression tests,
  Holmake, upto-auto, and h4pedant pass, including safe saturation before
  DEEPEN.
- TASK_15 — completed and verified: all three driver-test groups pass, with
  upto-auto and h4pedant clean.
- TASK_17 — completed and verified against TASK_17.md: additive export,
  golden tests, Holmake, baseline upto-auto gate, and h4pedant pass.
- TASK_16 — reverified against TASK_16.md: reusable 20-problem FAST_TAC
  corpus, per-goal budgets/count, Holmake/selftest, upto-auto, and h4pedant
  pass.
- TASK_18 — completed and verified against TASK_18.md: blast skeleton,
  private prototerm/trail unifier, unit selftests, upto-auto, and h4pedant
  pass.
- TASK_19 — reverified against TASK_19.md: Holmake/selftest, upto-auto, and
  h4pedant pass.
- TASK_20 — completed and verified 2026-07-18 against TASK_20.md/blast.ML:
  search clause mapping, six search-only goldens, Holmake/selftest,
  upto-auto, and h4pedant pass.
- TASK_21 — reverified 2026-07-18 against TASK_21.md and current sources:
  T1–T6 reconstruction, Tactical.VALID, backtracking, clean failure,
  Holmake, selftests, upto-auto, and h4pedant pass.
- TASK_22 — reverified 2026-07-18 after reopening: public blast tactics,
  configuration, markers, tryIt, traces/stats, Holmake/selftest, upto-auto,
  and h4pedant pass.
- TASK_23 — **REOPENED 2026-07-19.**  The previous "all 48 solve" claim
  was false: seven corpus problems were closed by `blast_preprocess`
  rewriting them to `T` from seed theorems containing their statements, not
  by search.  Preprocessor and seeds removed; the honest baseline is 42/48
  with 34, 38, 41, 42, 43 and 45 asserted expected failures.  Completion
  requires remaining search work or an explicit owner-approved exception;
  see `PLAN_phase_1_2_green.md`.
- TASK_24 — **REOPENED 2026-07-19.**  Same cause as TASK_23.  Halting II
  was closed by `halting_preprocess` recognising the goal and returning a
  metis-proved theorem, not by blast.  Honest baseline: Table 1 is 6/9
  (34@7, 38@4 and 43@5 open), set problems are 4/4, and Halting II is
  unsolved; the three open Table-1 rows and Halting II, but not the passing
  4/4 set suite, are asserted expected failures.  See
  `PLAN_phase_1_2_green.md`.
- TASK_23 — **POST-REOPENING PROGRESS 2026-07-21 at `7ea3b07fa`; still
  REOPENED.**  General replay repairs make P38, P41, P42 and P43 kernel-valid
  without recognition.  The achieved count is 46/48; P34 and P45 remain
  asserted expected failures under the unchanged 30-second per-goal budget.
  P34 is an Isabelle Table-1 problem, and no report citation establishes P45
  as out of scope; those failures do not satisfy TASK_23's unchanged
  criterion 3.
- TASK_24 — **POST-REOPENING PROGRESS 2026-07-21 at `7ea3b07fa`; still
  REOPENED.**  At that point Table 1 was 8/9 with P34@7 an asserted
  expected failure; the set problems were 4/4.  Halting II remained an
  asserted expected timeout at depth 7 under the unchanged 120-second
  budget.  TASK_24's unchanged all-groups-passing criteria were not met.
  The later M5 gates changed no count or budget.
- TASK_25 — completed and verified: all driver and BLAST docfiles, AliasGen,
  doc processing, cross-references, and style checks pass.
- TASK_26 — completed and verified against TASK_26.md: PLAN.md records
  D21–D27, delivered Phase-1/2 trees and deviations, and the Phase-2 freeze
  amendments.
- TASK_27 — completed and verified against TASK_27.md: the Phase-2 full-build
  gate recorded the pre-existing probability failure; classical and BLAST
  h4pedant checks are clean.
- M5 initial gate chronology — at `7ea3b07fa`, the per-directory gates passed
  with rules 77 `OK`, classical 168 `OK` and blast 193 `OK`, and the source
  recognition audit was clean.  The first clean `upto-auto` integration gate
  passed, but explicit `bin/build -F -t` failed reproducibly at
  `src/probability/real_borelTheory`, theorem
  `in_borel_measurable_inv`.
- M5 simplifier repair — the failure came from a general earlier defect that
  installed supplied global rewrites statically and per traversal.  A naive
  dynamic-only candidate refreshed `Once` across assumption/conclusion
  traversals.  Commit `65250f8c38f59a46f4350cc33e837b3de2508bf3`
  (`Preserve global bounded rewrite lifetimes`) uses invocation-shared bounded
  controls and marker-adjusted local simpsets, separates reducer/solver
  contexts, preserves marker and solver/dproc theorem context, and adds
  failing-first regressions.  No probability proof, recognition mechanism,
  benchmark count or budget changed.
- M5 — **HISTORICAL CLEAN GATES 2026-07-22 at `65250f8c3`.**  A fresh detached
  worktree and fresh configuration passed status 0 in 18.17s; `upto-auto`
  passed status 0 in 9m41.26s and explicit `bin/build -F -t` passed status 0
  in 15m53.50s, both builds ending `Hol built successfully.`  The full build
  reported `real_borelTheory` `OK` in 14s; its direct log/signature save and
  export `in_borel_measurable_inv`.  At that revision the M5 gates were
  complete, but the whole plan and Phases 1/2 remained incomplete under the
  then-unmet M1 and task criteria.  M2's conditional/environment-limited
  conclusions remain unchanged, with no retroactive evidence-selected
  optimization claim.
- M5 final evidence — the audited package at
  `/tmp/isabelle-tactics-task7f-20260720-root/task16_clean_full_gates_fresh/`
  preserves original logs and direct probability artifacts.  Its final clean
  rereview manifest, `metadata/evidence-checksums.txt`, has 45 entries, passes
  checksum verification, and hashes to
  `a6dde0623911ee486494b341ba9845c928f8fd1787c230b57134c95ae62e916b`.
  The successful `upto-auto` gate includes expected
  `suspFastTheory ... F-CHEAT` and zero `CHEATED` results.  The successful
  full gate includes the classified intentional pre-existing upstream
  `src/num/theories/cv_compute/automation ... CHEATED` result (three
  `Saved CHEAT` entries from unchanged source) and zero `F-CHEAT` results.
  Historical transcripts did not independently capture `TMPDIR`; the empty
  task `TMPDIR` postflight is corroboration only.  Main tracked/index state
  was clean at `65250f8c3`, with `.agent-files` ignored and untracked.
- M1 — **FINAL REMEASUREMENT 2026-07-22 at `5bc674569`.**  Public production
  `Tactical.VALID (BLAST_TAC [])` retains maximum depth 20 and the 30-second
  `Timeout.apply`.  Baseline `be308c56d` has P34/P38/P41/P42/P43/P45 each
  right-censored at `>=30s`.  Three current kernel-valid samples are P34
  `1.329700/1.320911/1.316835`, P38 `.099931/.100237/.100036`, P41
  `.009163/.009141/.009075`, P42 `.010805/.010697/.010773`, P43
  `.033935/.033627/.033786`, and P45 `3.543755/3.530560/3.470660` seconds.
  Strict interval separation meets M1 on all six; no censored ratio is
  computed.  The reviewed package is in this directory:

  ```text
  /tmp/isabelle-tactics-task7f-20260720-root/task22_m1_final_measurement_fresh/
  ```

  Its final 1,818-entry manifest digest
  is `fa9bc5a1a98be7d09522f1c8d8c2100d18a73e4078987a5314a062784a161571`.
- TASK_23 — **COMPLETED/RECLOSED 2026-07-22 at `5bc674569`.**  Honest
  production proof search is 48/48 with `pelletier_expected_failures = []`.
  Reviewed M1, selftest, h4pedant, recognition/shortcut, seed-guard,
  integrated and full-gate evidence satisfies every unchanged criterion;
  no owner exception is used.
- TASK_24 — **HISTORICAL 2026-07-22 at `5bc674569`; still REOPENED.**
  At that point Table 1 was 9/9 with
  `table1_expected_failures = []`, sets were 4/4, and robustness was green.
  Halting II remained an asserted expected failure at depth 7/120 seconds.
  The green level-2 process executed that attempt and asserted the expected
  non-solve; it did not make the Halting group pass.  The unchanged
  all-groups-passing criterion was unmet; no owner exception was claimed.
- M5 — **HISTORICAL GATES 2026-07-22 at `5bc674569`.**  The wholly
  fresh v2 package
  `/tmp/isabelle-tactics-task7f-20260720-root/task23_final_clean_gates_fresh/`
  records configure 17.79 s, prerequisite
  setup 206.35 s, rules 15.54/12.08 s, classical `.19`/16.21 s, blast
  `.20`/20.69 s, level 2 141.20 s, `upto-auto` 244.10 s terminal success,
  and full gate 989.25 s terminal success.  Its final reviewed live seal is
  395 entries with digest
  `2d66cab8b9db6c8a5e2c345a89c0ca2755b4a4d35cebc45cab9dedb2d507d3bc`;
  its inventory is 394 entries with digest
  `786c8d9c2f763ee342eaaee8c5f79659be0433013cc00d4f43ccc4445b8b3812`.
  Production audits, seed guard and h4pedant are green, and intentional
  CHEAT classifications remain disclosed.  No top-level v2 driver was
  retained, so whole-schedule enforcement is not independently proven;
  named wrapper intervals do not overlap, but unrecorded activity in gaps is
  not excluded.  Process snapshots are scoped; copied probability/CHEAT
  artifacts are post-run corroboration, while the full log proves
  `real_borelTheory` `OK`.  The old first attempt is rejected for
  `0.497043743` s setup overlap.  No `/tmp/Holmakefile` nonmutation claim is
  made.
- Current source — reviewed commit
  `f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1` centralizes capture-safe
  persistent-metavariable expansion and exact replay.  It has no
  recognition or fallback shortcut.  Tests cover all 16 public stored-rule
  APIs.
- Historical pre-commit evidence — candidate 05 remains accepted only as
  the functional patch record.  Its manifest digest is
  `95be727c037229af3514a85d2e2f11ea56b76cdf19b84c1aa5e5372c58322d07`.
  It freezes the exact patch against parent `d90554b5f`; the reviewed commit
  contains that patch.
- Accepted committed-state evidence — attempt-04 under
  `task34c_hardened_final_gates_fresh/` tests exact `f4fc8be66`.  All
  18 commands exit 0 in 1799.992895 s.  The semantic audit, 32,933-entry
  tested-tree inventory and 47-entry package manifest pass; their digests
  are recorded in `../PLAN_phase_1_2_green.md` §6.
- Current suites — exact `upto-auto`, `upto-parallel`, direct
  Rules/Classical, Blast levels 1 and 2, h4pedant, diff/hygiene and the
  full gate pass.  Both Blast levels have exactly 48/48 unique Pelletier,
  9/9 unique Table 1 and 4/4 unique set successes.  Level 2 has exactly
  one kernel-valid Halting II `OK`.  Expected corpus failures are zero.
- TASK_23 — **CURRENT: COMPLETED.**  Its 48/48 corpus criterion remains met.
- TASK_24 — **COMPLETED/RECLOSED 2026-07-23 at `f4fc8be66`.**  Table 1,
  sets, Halting II and robustness all pass without an exception.
- M2 — **CLOSED by owner decision 2026-07-23.**  The owner required the
  complete suite and Halting II to pass because `perf_event_paranoid` cannot
  be lowered.  Those conditions pass.  No profiler samples or lower setting
  are claimed.
- Current gate disclosure — exact `upto-auto` has one expected
  `suspFastTheory ... F-CHEAT`, zero `CHEATED` and zero `Saved CHEAT`.
  The distinct full gate has zero `F-CHEAT`, one intentional pre-existing
  `cv_compute/automation ... CHEATED`, and exactly three separately
  hash-bound `Saved CHEAT` theorem names.
- M1 — **CLOSED.**  Its original explicit criterion required behaviour
  preservation and measured improvement on all six workloads, not a rerun
  after every later patch.  The verified `5bc674569` package has six
  `>=30s` censored baselines and all 18 exact kernel-valid production runs
  below `3.544s`.  Attempt-04 has no `f4fc8be66` performance run, so
  current performance is not claimed; this is a non-blocking follow-up.
- TASK_27 — **COMPLETED/RECLOSED 2026-07-23 at `f4fc8be66`.**  The full
  gate is terminally green, h4pedant is clean, and `PLAN.md` §11 records
  the gate.
- Phase 1/2 current conclusion — **COMPLETE.**  The final audit finds no
  unmet criterion and no pending next task.

### Integrity note (2026-07-19)

TASK_23/TASK_24 were marked complete on numbers produced by goal
recognition rather than proof search.  The governing rule is now in
`src/auto/CLAUDE.md` (Testing Guidelines) and PLAN_phase_1_2.md §8.3:
a benchmark goal is closed by search, never by recognition; unreached
goals are asserted expected failures, never silent passes.  When
re-verifying a strength task, confirm that the tactic path from goal
to `QED` contains no step that could match the goal's *statement* --
check preprocessors, rewrite lists and seed theories, not just the
reported count.
