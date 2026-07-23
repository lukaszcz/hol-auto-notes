# TASK_23 — Pelletier corpus + `BLAST_TAC` solving selftests (§8.3.1)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phases
1–2 (`.agent-files/PLAN_phase_1_2.md`) build the classical reasoner in
`src/auto/classical/` and `src/auto/blast/` on top of the Phase-0
claset infrastructure (`src/auto/rules/`): a shared typed-metavariable
search engine (store, unifier, goals, step cascade, replay, drivers),
public tactics `SAFE_TAC`/`CLARIFY_TAC`/`FAST_TAC`/…/`DEEPEN_TAC`,
and a faithful port of Isabelle's blast (`BLAST_TAC`).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Status: COMPLETED/RECLOSED; current at `f4fc8be66`

All 48 Pelletier problems are present.  Public production
`Tactical.VALID (BLAST_TAC [])` proves 48/48 under the unchanged maximum
depth 20 and 30-second `Timeout.apply`; the asserted
`pelletier_expected_failures` list is empty.  No exception or report
citation is needed.

Reviewed commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1` implements centralized,
capture-safe expansion of persistent metavariable bindings and exact
stored-rule replay.  It has no recognition or fallback shortcut.  Its
regressions exercise exact capture-safe replay through all 16 public
stored-rule APIs.

The accepted committed-state evidence is attempt-04:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
```

Its 47-entry package manifest digest is
`805cb6086f5fb65e0869dfd73722c9296cb0ec467fc150e8c410fe9d4e7e9c52`.
Its frozen plan and post-run identities bind exact commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`.

Fresh configure, exact `upto-auto`, direct Blast levels 1 and 2,
h4pedant and the committed-state full gate pass.  Both Blast runs record
exactly 48 unique Pelletier successes out of 48.  The exact `upto-auto`
disclosure is one expected `suspFastTheory ... F-CHEAT`, zero `CHEATED`
and zero `Saved CHEAT`.  The separate full-build classification is recorded
in `PLAN.md` §11.

Candidate 05 remains historical pre-commit functional evidence.  Its
accepted patch identity is preserved in the governing plans, but current
task acceptance rests on attempt-04.

TASK_23 was first reclosed at `5bc674569` and remains closed at
`f4fc8be66`.  The original `c7f72c445` M1 record improved only three of
six workloads; the verified 1,818-entry `5bc674569` package separately
measured all six and closed M1 under its original milestone-local
criterion.  Attempt-04 is functional/gate evidence, not a current-revision
performance measurement.  Performance at `f4fc8be66` is not claimed; that
transparent limitation is a non-blocking follow-up and does not affect M1
or this task's closure.

### Reopening history

This task was reopened on 2026-07-19 because its earlier completion figures
were produced by goal recognition, not proof search:
`tableauLib.blast_preprocess` / `halting_preprocess` closed several corpus
goals by rewriting them to `T` from seed theorems holding their statements,
or by `ACCEPT_TAC` on an `aconv` match.  Both were removed.  The honest
post-removal baseline was 42/48, and the later `7ea3b07fa` state was 46/48
with P34 and P45 asserted expected failures.  Those historical failures did
not satisfy criterion 3.  The later `5bc674569` and current
`f4fc8be66` evidence supersede that status, not the incident record.

## Objective

Plan T21, first half (§8.3.1): the full Pelletier corpus in HOL4 form
and the `BLAST_TAC []` solving suite.

## Spec

Read first: `PLAN_phase_1_2.md` §8.3 (preamble + item 1, 6);
`.agent-files/research/phase12-blast-port.md` §9;
`src/meson/test/selftest.sml` (the `M`/`Mfail` driver model);
the TASK_16 corpus block in `src/auto/classical/selftest.sml`
(translations to adapt — keep numbering consistent).

1. Author HOL4 translations of Pelletier 1–46 plus 52 and 62 in
   `src/auto/blast/selftest.sml` (or a corpus support file in the
   same directory), numbered and delimited; adapt TASK_16's
   translations where they exist, author the rest fresh from the
   standard formulations (the report §9 lists the exact set and any
   translation subtleties).
2. Driver in the meson-selftest shape: `BLAST_TAC []` solves each
   problem under `Tactical.VALID`, within per-goal time budgets;
   solved-goal counts asserted (regression = failure).
3. Never prune goals to make the gate pass: a problem blast cannot
   yet solve is a bug to fix (module + failing-first regression) or —
   only if the report documents it as out of scope for Isabelle's
   blast too — an explicit expected-failure entry with the citation.
4. If the full corpus is too slow for the default gate, the fast
   subset runs by default and the exhaustive corpus sits behind a
   higher `HOLSELFTESTLEVEL` (§8.3.6) — counts asserted in both
   modes.

## Acceptance criteria

1. All corpus problems present; `BLAST_TAC []` solves the asserted
   set; `Holmake` + `./selftest.exe` green in `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Expected-failure entries (if any) carry report citations.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns.

## Dependencies

TASK_22 (TASK_16 advised for translation reuse).
