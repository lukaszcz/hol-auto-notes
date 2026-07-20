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
- TASK_23 — done
- TASK_24 — done
- TASK_25 — done
- TASK_26 — done
- TASK_27 — done

## Next unblocked task

None — all tasks complete.

## Completion log

- TASK_01 — completed and verified against its acceptance criteria.
- TASK_02 — completed and verified against its acceptance criteria.
- TASK_03 — completed and verified against its acceptance criteria.
- TASK_04 — completed and verified against its acceptance criteria.
- TASK_05 — completed and verified against its acceptance criteria.
- TASK_06 — completed and verified against its acceptance criteria.
- TASK_07 — completed and verified against its acceptance criteria.
- TASK_08 — reverified against its task file; doc processing, AliasGen, and style checks pass.
- TASK_09 — Phase-1 gate recorded; pre-existing full-build failure and clean h4pedant result verified.
- TASK_10 — completed and verified: Holmake/selftest, upto-auto build, and h4pedant pass.
- TASK_11 — completed and verified against its task file: Holmake/selftest, upto-auto build, and h4pedant pass.
- TASK_12 — completed and verified against its task file: Holmake/selftest, upto-auto build, and h4pedant pass.
- TASK_13 — completed and verified against its task file: Holmake/selftest, upto-auto build, and h4pedant pass.
- TASK_14 — completed and verified: all driver smoke/regression tests, Holmake, upto-auto, and h4pedant pass, including safe saturation before DEEPEN.
- TASK_15 — completed and verified: all three driver-test groups pass, with upto-auto and h4pedant clean.
- TASK_17 — completed and verified against TASK_17.md: additive export, golden tests, Holmake, baseline upto-auto gate, and h4pedant pass.
- TASK_16 — reverified against TASK_16.md: reusable 20-problem FAST_TAC corpus, per-goal budgets/count, Holmake/selftest, upto-auto, and h4pedant pass.
- TASK_18 — completed and verified against TASK_18.md: blast skeleton, private prototerm/trail unifier, unit selftests, upto-auto, and h4pedant pass.
- TASK_19 — reverified against TASK_19.md: Holmake/selftest, upto-auto, and h4pedant pass.
- TASK_20 — completed and verified 2026-07-18 against TASK_20.md/blast.ML: search clause mapping, six search-only goldens, Holmake/selftest, upto-auto, and h4pedant pass.
- TASK_21 — reverified 2026-07-18 against TASK_21.md and current sources: T1–T6 reconstruction, Tactical.VALID, backtracking, clean failure, Holmake, selftests, upto-auto, and h4pedant pass.
- TASK_22 — reverified 2026-07-18 after reopening: public blast tactics, configuration, markers, tryIt, traces/stats, Holmake/selftest, upto-auto, and h4pedant pass.
- TASK_23 — **REOPENED 2026-07-19.**  The previous "all 48 solve" claim was false: seven corpus problems were closed by `blast_preprocess` rewriting them to `T` from seed theorems containing their statements, not by search.  Preprocessor and seeds removed; honest baseline is 42/48 with 34, 38, 41, 42, 43, 45 asserted expected failures.  Completion requires solving them by search — see PLAN_phase_1_2_green.md.
- TASK_24 — **REOPENED 2026-07-19.**  Same cause as TASK_23.  Halting II was closed by `halting_preprocess` recognising the goal and returning a metis-proved theorem, not by blast.  Honest baseline: Table-1 6/9 (34@7, 38@4, 43@5 open), set problems 4/4, Halting II unsolved — all asserted expected failures.  See PLAN_phase_1_2_green.md.
- TASK_25 — completed and verified: all driver and BLAST docfiles, AliasGen, doc processing, cross-references, and style checks pass.
- TASK_26 — completed and verified against TASK_26.md: PLAN.md records D21–D27, delivered Phase-1/2 trees and deviations, and the Phase-2 freeze amendments.
- TASK_27 — completed and verified against TASK_27.md: the Phase-2 full-build gate recorded the pre-existing probability failure; classical and BLAST h4pedant checks are clean.

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
