# Phase 1–2 task index

Tasks implementing `.agent-files/PLAN_phase_1_2.md` (classical step
tactics, search drivers, BLAST; `src/auto/classical/` +
`src/auto/blast/`).  Mapping to the plan's §9 table: T11 is split
into TASK_11+12 (replay core vs. D24 materialization); T14 into
TASK_15+16 (engine tests vs. Pelletier strength floor); T21 into
TASK_23+24 (corpus vs. regressions); the blast build skeleton moves
from T1 into TASK_18.  Each task is sized for one agent in a
200k-token context window.

## Phase 1

| Task | Title | Plan ref | Depends on |
|---|---|---|---|
| [TASK_01](TASK_01.md) | classical skeleton, build wiring, `searchHeap` | T1, §2 | — |
| [TASK_02](TASK_02.md) | `clasetMeta` store | T2, §3.1 | 01 |
| [TASK_03](TASK_03.md) | `clasetUnify` + golden battery | T3, §3.2, §8.2.1 | 02 |
| [TASK_04](TASK_04.md) | `clasetGoal` + size_of amendment | T4, §3.3, §11.1 | 03 |
| [TASK_05](TASK_05.md) | `clasetStep` match mode (safe/clarify) | T5, §3.4 | 04 |
| [TASK_06](TASK_06.md) | `classicalLib` slice 1 (`SAFE_TAC` …) | T6, §4 | 05 |
| [TASK_07](TASK_07.md) | Phase-1 selftest suite | T7, §8.1 | 06 |
| [TASK_08](TASK_08.md) | Phase-1 + deferred Phase-0 docfiles | T8, §4 | 06 |
| [TASK_09](TASK_09.md) | **Phase-1 gate** `bin/build -F -t` | T9, §8.4 | 01–08 |

## Phase 2

| Task | Title | Plan ref | Depends on |
|---|---|---|---|
| [TASK_10](TASK_10.md) | `clasetStep` unify mode | T10, §3.4 | 09 |
| [TASK_11](TASK_11.md) | `clasetReplay` core + vocabulary | T11 (part), §3.5 | 10 |
| [TASK_12](TASK_12.md) | D24 materialization + wrapper steps | T11 (part), §3.3/§3.5 | 11 |
| [TASK_13](TASK_13.md) | `clasetSearch` drivers + D25 pruning | T12, §3.6 | 12 |
| [TASK_14](TASK_14.md) | `classicalLib` slice 2 (D26 surface) | T13, §5 | 13 |
| [TASK_15](TASK_15.md) | Engine/driver selftests | T14 (part), §8.2.2–4 | 14 |
| [TASK_16](TASK_16.md) | `FAST_TAC` Pelletier strength floor | T14 (part), §8.2.5 | 14 |
| [TASK_17](TASK_17.md) | `REV_DUP_ELIM_RULE` in `clasetRules` | T15, §6.3, §11.2 | 09 |
| [TASK_18](TASK_18.md) | blast skeleton + `blastTerm` | T16, §6.1 | 09 |
| [TASK_19](TASK_19.md) | Translation, typargs, `blastRule` | T17, §6.2–6.3 | 17, 18 |
| [TASK_20](TASK_20.md) | `blastSearch` tableau engine | T18, §6.4 | 19 |
| [TASK_21](TASK_21.md) | Reconstruction on the engine (D23) | T19, §6.5 | 12, 20 |
| [TASK_22](TASK_22.md) | `tableauLib` surface + config | T20, §6.6 | 21 |
| [TASK_23](TASK_23.md) | Pelletier corpus + BLAST solving tests | T21 (part), §8.3.1 | 22 |
| [TASK_24](TASK_24.md) | BLAST depth/set/robustness regressions | T21 (part), §8.3.2–6 | 23 |
| [TASK_25](TASK_25.md) | Phase-2 docfiles (drivers + BLAST) | T22, §5–6 | 14, 22 |
| [TASK_26](TASK_26.md) | PLAN.md decision/status records | T-book | 15, 16, 24, 25 |
| [TASK_27](TASK_27.md) | **Phase-2 gate** `bin/build -F -t` | T-fin, §8.4 | all |

Parallelism notes: within Phase 1 the chain 01→…→07 is serial
(each module consumes the previous); TASK_08 can run alongside
TASK_07.  After the TASK_09 gate, the classical chain (10→…→16) and
the blast chain (17→18→19→20) can proceed in parallel until TASK_21
joins them (needs 12 and 20).  TASK_25 can run alongside TASK_23/24.
Tasks touching the same selftest.sml (classical: 10–16; blast: 18–24)
should not run concurrently with each other within a chain.
