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

- [TASK_01](TASK_01.md): classical skeleton, build wiring and
  `searchHeap`; T1, §2; no dependency.
- [TASK_02](TASK_02.md): `clasetMeta` store; T2, §3.1; depends on 01.
- [TASK_03](TASK_03.md): `clasetUnify` and golden battery; T3, §3.2,
  §8.2.1; depends on 02.
- [TASK_04](TASK_04.md): `clasetGoal` and `size_of` amendment; T4, §3.3,
  §11.1; depends on 03.
- [TASK_05](TASK_05.md): `clasetStep` match mode; T5, §3.4; depends on 04.
- [TASK_06](TASK_06.md): `classicalLib` slice 1; T6, §4; depends on 05.
- [TASK_07](TASK_07.md): Phase-1 selftests; T7, §8.1; depends on 06.
- [TASK_08](TASK_08.md): Phase-1 and deferred Phase-0 docfiles; T8, §4;
  depends on 06.
- [TASK_09](TASK_09.md): Phase-1 `bin/build -F -t` gate; T9, §8.4;
  depends on 01–08.

## Phase 2

- [TASK_10](TASK_10.md): `clasetStep` unify mode; T10, §3.4; depends on 09.
- [TASK_11](TASK_11.md): `clasetReplay` core and vocabulary; part of T11,
  §3.5; depends on 10.
- [TASK_12](TASK_12.md): D24 materialization and wrappers; part of T11,
  §3.3/§3.5; depends on 11.
- [TASK_13](TASK_13.md): `clasetSearch` drivers and D25 pruning; T12, §3.6;
  depends on 12.
- [TASK_14](TASK_14.md): `classicalLib` slice 2; T13, §5; depends on 13.
- [TASK_15](TASK_15.md): engine and driver selftests; part of T14, §8.2.2–4;
  depends on 14.
- [TASK_16](TASK_16.md): `FAST_TAC` Pelletier floor; part of T14, §8.2.5;
  depends on 14.
- [TASK_17](TASK_17.md): `REV_DUP_ELIM_RULE`; T15, §6.3, §11.2; depends
  on 09.
- [TASK_18](TASK_18.md): blast skeleton and `blastTerm`; T16, §6.1;
  depends on 09.
- [TASK_19](TASK_19.md): translation, typargs and `blastRule`; T17,
  §6.2–6.3; depends on 17 and 18.
- [TASK_20](TASK_20.md): `blastSearch`; T18, §6.4; depends on 19.
- [TASK_21](TASK_21.md): D23 reconstruction; T19, §6.5; depends on 12
  and 20.
- [TASK_22](TASK_22.md): `tableauLib` surface and configuration; T20, §6.6;
  depends on 21.
- [TASK_23](TASK_23.md): Pelletier corpus and BLAST tests; part of T21,
  §8.3.1; depends on 22.
- [TASK_24](TASK_24.md): depth, set and robustness regressions; part of T21,
  §8.3.2–6; depends on 23.
- [TASK_25](TASK_25.md): Phase-2 docfiles; T22, §5–6; depends on 14 and 22.
- [TASK_26](TASK_26.md): plan decision/status records; T-book; depends on
  15, 16, 24 and 25.
- [TASK_27](TASK_27.md): Phase-2 `bin/build -F -t` gate; T-fin, §8.4;
  completed/reclosed at `f4fc8be66`; depends on all preceding tasks.

All TASK_01–TASK_27 are closed.  The final requirement audit is
`../PLAN_phase_1_2_green.md` §6; no Phase-1/2 task remains pending.

Parallelism notes: within Phase 1 the chain 01→…→07 is serial
(each module consumes the previous); TASK_08 can run alongside
TASK_07.  After the TASK_09 gate, the classical chain (10→…→16) and
the blast chain (17→18→19→20) can proceed in parallel until TASK_21
joins them (needs 12 and 20).  TASK_25 can run alongside TASK_23/24.
Tasks touching the same selftest.sml (classical: 10–16; blast: 18–24)
should not run concurrently with each other within a chain.
