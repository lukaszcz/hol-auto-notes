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

## Status: REOPENED 2026-07-19

This task was previously marked complete on figures produced by goal
recognition, not proof search: `tableauLib.blast_preprocess` /
`halting_preprocess` closed several corpus goals by rewriting them to
`T` from seed theorems holding their statements, or by `ACCEPT_TAC` on
an `aconv` match.  Both are removed.  Acceptance now additionally
requires: no tactic, preprocessor, rewrite set or seed theory names a
benchmark problem or its statement; unreached goals are asserted
expected failures citing `PLAN_phase_1_2_green.md`.

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
