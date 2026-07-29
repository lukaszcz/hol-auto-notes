# Phase 4 task progress

## 1. Task status

- TASK_01 — done (verified 2026-07-29)
- TASK_02 — done (verified 2026-07-29)
- TASK_03 — done (verified 2026-07-29)
- TASK_04 — done (verified 2026-07-29; focused/reduced gates pass)
- TASK_05 — done (verified 2026-07-29; focused/reduced gates pass)
- TASK_06 — done (re-verified 2026-07-29; focused selftest, pedant,
  diff, and reduced build pass)
- TASK_07 — unblocked (not started)
- TASK_08 — unblocked (not started)
- TASK_09 — blocked (needs 02, 04, 05, 08)
- TASK_10 — blocked (needs 05, 07, 09)
- TASK_11 — blocked (needs 06, 09)
- TASK_12 — blocked (needs 11)
- TASK_13 — blocked (needs 08, 09, 11)
- TASK_14 — blocked (needs 10, 12, 13)
- TASK_15 — blocked (needs 14)
- TASK_16 — blocked (needs 06, 12)
- TASK_17 — blocked (needs 07, 10, 15, 16)
- TASK_18 — blocked (needs 01, 02)
- TASK_19 — blocked (needs 17, 18)
- TASK_20 — blocked (needs 17)
- TASK_21 — blocked (needs 19, 20)

## 2. Next unblocked task

TASK_07 (also unblocked now: TASK_08).

## 3. Completion log

- TASK_01 — landed 2026-07-29: HolLex digit-leading values and unsafe claset priority parsing; focused/theory tests and reduced build pass.
- TASK_02 — landed 2026-07-29: Forward/Norm kinds, schema-v2 codec, routing isolation, canonical ext_info, and declaration ordering; focused tests and reduced build pass.
- TASK_03 — landed 2026-07-29: New-kind attributes and v1/v2 theory reload tests; focused/theory tests and reduced build pass.
- TASK_04 — landed 2026-07-29: Aesop target/hypothesis candidate index with ordering and maintenance tests; focused/reduced gates pass.
- TASK_05 — landed 2026-07-29: Wrapper-free standard rule steps, differential tests, and non-consuming elimination replay; focused/reduced gates pass.
- TASK_06 — landed 2026-07-29: Six-table claset store absorption with conflict diagnostics and golden merge tests; re-verified against the task specification with all gates passing.
