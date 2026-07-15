# Phase 0 task index

Derived from `.agent-files/PLAN_phase_0.md` §9 (2026-07-15).  Plan task T5
is split into TASK_05/TASK_06 (rule model vs. derived rules) so each task
fits comfortably in one agent's 200k context window; all other plan tasks
map one-to-one.

Every task file carries its own Context, spec references, constraints, and
acceptance criteria.  Common gate for all tasks:
`bin/build -t --seq=tools/sequences/upto-auto` green.

| Task | File | Plan § | Depends on |
|---|---|---|---|
| TASK_01 build skeleton | `TASK_01_build_skeleton.md` | §2 (T1) | — |
| TASK_02 clasetMarker theory | `TASK_02_claset_marker_theory.md` | §6.4 (T2) | 01 |
| TASK_03 NTactical | `TASK_03_ntactical.md` | §3 (T3) | 01 |
| TASK_04 clasetNet | `TASK_04_claset_net.md` | §4 (T4) | 01 |
| TASK_05 rule model + canonical form | `TASK_05_claset_rules_model.md` | §5.1–5.2 (T5a) | 01 |
| TASK_06 five derived rules | `TASK_06_derived_rules.md` | §5.3 (T5b) | 05 |
| TASK_07 clasetLib value | `TASK_07_clasetlib_value.md` | §6.1, §6.6 (T6) | 03, 04, 06 |
| TASK_08 clasetLib persistence + attributes | `TASK_08_clasetlib_state.md` | §6.2–6.3 (T7) | 07 |
| TASK_09 markers + process_claset_tags | `TASK_09_markers.md` | §6.4 (T8) | 02, 07 |
| TASK_10 TypeBase hook | `TASK_10_typebase_hook.md` | §6.5 (T9) | 08 |
| TASK_11 seed theory | `TASK_11_seed_theory.md` | §7 (T10) | 06, 08 |
| TASK_12 theory_tests | `TASK_12_theory_tests.md` | §8 (T11) | 08, 10, 11 |
| TASK_13 bookkeeping + full gate | `TASK_13_bookkeeping.md` | §9 (T12) | 01–12 |

Parallelism notes: after TASK_01, tasks 02/03/04/05 are independent;
after TASK_07, tasks 08 and 09 are independent.
