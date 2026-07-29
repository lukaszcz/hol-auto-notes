# Phase 4 task index

Source plan: `.agent-files/PLAN_phase_4.md` (task numbers Txx below
refer to its §11 breakdown; oversized plan tasks are split so each
task fits a single 200k-context agent run).

| Task | Title | Plan | Depends on |
|------|-------|------|------------|
| TASK_01 | HolLex attribute values + unsafe-attr percent parsing | T01 | — |
| TASK_02 | `clasetRules` schema v2 core (kinds/codec/routing) | T02a | — |
| TASK_03 | New-kind attributes + cross-version theory_tests | T02b | 01, 02 |
| TASK_04 | Aesop index in `CS` + candidate entry points | T03 | 02 |
| TASK_05 | `clasetStep.rule_step` + differential tests | T04 | — |
| TASK_06 | `clasetMeta.absorb` | T05 | — |
| TASK_07 | Markers `Norm`/`Forward`/`SForward` | T06 | — |
| TASK_08 | `aesopData` settype + derived simpset + scaffolding | T07 | — |
| TASK_09 | `aesopRule` core + apply/constructors/simp builders | T08a | 02, 04, 05, 08 |
| TASK_10 | Builders: forward/destruct, cases, tactic, splits | T08b | 05, 07, 09 |
| TASK_11 | `aesopTree` core: nodes, states, clusters, priorities | T09a | 06, 09 |
| TASK_12 | `aesopTree` copying + golden tests | T09b | 11 |
| TASK_13 | `aesopNorm` fixpoint + built-in chain | T10 | 08, 09, 11 |
| TASK_14 | `aesopSearch` part 1: loop + safe phase | T11a | 10, 12, 13 |
| TASK_15 | `aesopSearch` part 2: unsafe phase, limits, termination | T11b | 14 |
| TASK_16 | Proof extraction and replay | T12 | 06, 12 (15 for e2e) |
| TASK_17 | `aesopLib` surface + argument pipeline | T13a | 07, 10, 15, 16 |
| TASK_18 | Seed percent pass | T13b | 01, 02 |
| TASK_19 | Selftest completion: strength smoke set + §9 sweep | T14a | 17, 18 |
| TASK_20 | Docfiles + build-sequence integration | T14b | 17 |
| TASK_21 | Phase gate: full build + freeze/register records | T15 | 19, 20 |

Initially unblocked: TASK_01, TASK_02, TASK_05, TASK_06, TASK_07,
TASK_08.

Every task additionally gates on: focused `Holmake` + `selftest.exe`
in touched directories, `tools/h4pedant`, `git diff --check`, and
`bin/build -t --seq=tools/sequences/upto-auto` (full `bin/build -F -t`
only at TASK_21).
