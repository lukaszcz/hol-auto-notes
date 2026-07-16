# Phase S task index

Tasks implementing `.agent-files/PLAN_phase_S.md` (simplifier upgrades,
`src/simp/src/`).  Mapping to the plan's §10 table: T1 is split into
TASK_01+02 (tests-first lock, then the delicate engine refactor); T8 is
split into TASK_09+10 (registration/cache/fragment vs. marker/exclusion
integration + parity suites).  Each task is sized for one agent in a
200k-token context window.

| Task | Title | Plan ref | Depends on |
|---|---|---|---|
| [TASK_01](TASK_01.md) | Default-equivalence golden selftest suite | T1 (part), §8.1, §11.1 | — |
| [TASK_02](TASK_02.md) | Traverse: `context_thms` + solver/subgoaler pipeline | T1, §3.1–3.2 | 01 |
| [TASK_03](TASK_03.md) | `traverse_data` fields, `Cond_rewr` refs, congLib | T2, §3.3–3.4 | 02 |
| [TASK_04](TASK_04.md) | simpLib fields/setters/fragments/`clear_rules`/pp/rebuild | T3, §4 | 03 |
| [TASK_05](TASK_05.md) | `Split` marker constant | T5, §5.2 | — |
| [TASK_06](TASK_06.md) | Tactic loop `GEN_SIMP_TAC`, entry-point rewiring | T4, §5.1 | 04 |
| [TASK_07](TASK_07.md) | splitLib core: cmap, `SPLIT_CONV`, `SPLIT_TAC` (concl) | T6, §6.1–6.2 | — (05 advised) |
| [TASK_08](TASK_08.md) | `SPLIT_ASM_TAC` | T7, §6.3 | 07 |
| [TASK_09](TASK_09.md) | `[split]` set/attribute, TypeBase cache, `split_ss` | T8 (part), §6.4–6.5 | 04, 06, 07, 08 |
| [TASK_10](TASK_10.md) | `process_tags` `Split`/`Excl`, exclusion, parity tests | T8 (part), §5.2, §6.5 | 05, 06, 09 |
| [TASK_11](TASK_11.md) | `GEN_GLOBAL_SIMP_TAC` (`mut_impc` parity) | T9, §7 | 06 |
| [TASK_12](TASK_12.md) | `congproc_ss` travrules merge | T10, §4.3 | 04 |
| [TASK_13](TASK_13.md) | Docfiles, `notes.md`, h4pedant | T11, §9 | 09–12 |
| [TASK_14](TASK_14.md) | `PLAN.md` record updates | T12 | 13 |
| [TASK_15](TASK_15.md) | Full build gate `bin/build -F -t` | T13 | all |

Parallelism notes: TASK_05 and TASK_07 can start immediately alongside
TASK_01; TASK_11 and TASK_12 are independent of the splitter chain
(07–10).  All tasks touching `simpLib.sml` (04, 06, 09, 10, 11, 12)
should be serialized to avoid merge conflicts.
