# Phase 4 task progress

## 1. Task status

- TASK_01 — done (verified 2026-07-29)
- TASK_02 — done (verified 2026-07-29)
- TASK_03 — done (verified 2026-07-29)
- TASK_04 — done (verified 2026-07-29; focused/reduced gates pass)
- TASK_05 — done (verified 2026-07-29; focused/reduced gates pass)
- TASK_06 — done (re-verified 2026-07-29; focused selftest, pedant,
  diff, and reduced build pass)
- TASK_07 — done (re-verified 2026-07-29; all focused/reduced gates pass)
- TASK_08 — done (re-verified 2026-07-29; focused Holmake/selftest,
  theory-test compile, pedant, diff, and reduced build pass)
- TASK_09 — done (re-verified 2026-07-29; focused/reduced gates pass)
- TASK_10 — done (re-verified 2026-07-29; focused Holmake/selftests,
  h4pedant, diff check, and reduced build pass)
- TASK_11 — unblocked (not started)
- TASK_12 — blocked (needs 11)
- TASK_13 — blocked (needs 08, 09, 11)
- TASK_14 — blocked (needs 10, 12, 13)
- TASK_15 — blocked (needs 14)
- TASK_16 — blocked (needs 06, 12)
- TASK_17 — blocked (needs 07, 10, 15, 16)
- TASK_18 — unblocked (not started)
- TASK_19 — blocked (needs 17, 18)
- TASK_20 — blocked (needs 17)
- TASK_21 — blocked (needs 19, 20)

## 2. Next unblocked task

TASK_11.

## 3. Completion log

- TASK_01 — landed 2026-07-29: HolLex digit-leading values and unsafe claset priority parsing; focused/theory tests and reduced build pass.
- TASK_02 — landed 2026-07-29: Forward/Norm kinds, schema-v2 codec, routing isolation, canonical ext_info, and declaration ordering; focused tests and reduced build pass.
- TASK_03 — landed 2026-07-29: New-kind attributes and v1/v2 theory reload tests; focused/theory tests and reduced build pass.
- TASK_04 — landed 2026-07-29: Aesop target/hypothesis candidate index with ordering and maintenance tests; focused/reduced gates pass.
- TASK_05 — landed 2026-07-29: Wrapper-free standard rule steps, differential tests, and non-consuming elimination replay; focused/reduced gates pass.
- TASK_06 — landed 2026-07-29: Six-table claset store absorption with conflict diagnostics and golden merge tests; re-verified against the task specification with all gates passing.
- TASK_07 — landed 2026-07-29: Norm/Forward/SForward markers with classical pass-through and round-trip tests; all focused/reduced gates pass.
- TASK_08 — landed 2026-07-29: aesop_simp settype, derived simpset cache, trace registration, scaffolding, and theory reload tests; re-verified with focused/reduced gates passing.
- TASK_09 — landed 2026-07-29: aesop rule model, claset assembly, apply/constructors/simp builders, closers, and safe-order scaffold; focused/reduced gates pass.
- TASK_10 — landed 2026-07-29: Forward/destruct, cases, tactic, and conclusion/assumption split builders with indexing, replay, and all focused/reduced gates passing.
