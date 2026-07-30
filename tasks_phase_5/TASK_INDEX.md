# Phase 5 task index — generic linear arithmetic (`src/auto/linarith/`)

Derived from `.agent-files/PLAN_phase_5.md` §10 (T1–T10), with the
oversized plan tasks split so each fits a single 200k-context agent:
plan-T4 → TASK_04+TASK_05, plan-T5 → TASK_06+TASK_07, plan-T6 →
TASK_08+TASK_09, plan-T9 → TASK_12+TASK_13+TASK_14.

Every task ends green on `bin/build -t --seq=tools/sequences/upto-auto`
and commits its work.  Progress tracking: `PROGRESS.md` (same dir).

| Task | Title | Plan task | Depends on |
|---|---|---|---|
| [TASK_01](TASK_01.md) | Decisions in PLAN.md, CLAUDE.md fixes, core skeleton + build wiring | T1 | — |
| [TASK_02](TASK_02.md) | `linarithSolve`: datatypes, FM core, `prove`; unit tests | T2 | 01 |
| [TASK_03](TASK_03.md) | `linarithData`: records, registry, settypes, config, trace; theory_tests | T3 | 01 |
| [TASK_04](TASK_04.md) | `linarithDecomp`: registry-driven decomp/demult/poly | T4a | 02, 03 |
| [TASK_05](TASK_05.md) | `linarithSeedScript` num lemmas/seeds + num instance kit | T4b | 03, 04 |
| [TASK_06](TASK_06.md) | `linarithReplay` 1: `mkthm` + atom generalization; golden tests | T5a | 02–05 |
| [TASK_07](TASK_07.md) | `linarithReplay` 2: forward prover + tactic replay | T5b | 06 |
| [TASK_08](TASK_08.md) | `linarithLib` 1: `SIMPLE_LINARITH_TAC`, `PROVE`/`CONV`, num registration | T6a | 07 |
| [TASK_09](TASK_09.md) | `linarithLib` 2: D59 pipeline, `LINARITH_TAC`/`CFG_`, num battery | T6b | 08 |
| [TASK_10](TASK_10.md) | `LINARITH_ss`, `"lin_arith"` solver, cache; reducer tests | T7 | 09 |
| [TASK_11](TASK_11.md) | D56 wiring: clasimp + aesop | T8 | 10 |
| [TASK_12](TASK_12.md) | Instances dir wiring + `linarithInstScript` (int/real/rat lemmas) | T9a | 09 |
| [TASK_13](TASK_13.md) | `intLinarith`/`realLinarith`/`ratLinarith` + instance selftests | T9b | 12, 10 |
| [TASK_14](TASK_14.md) | Vendor `Arith_Examples.thy`; strength suite | T9c | 13 |
| [TASK_15](TASK_15.md) | Docfiles, consumer audit, phase gate `bin/build -F -t` | T10 | 11, 14 |

Notes on ordering: TASK_02 and TASK_03 are independent after TASK_01,
but tasks are expected to run one at a time (they share
`selftest.sml` and build files); the listed dependencies are the hard
ones.  TASK_12 could start after TASK_09 while TASK_10/11 are in
flight, but the sequential order 01→15 is safe and recommended.
