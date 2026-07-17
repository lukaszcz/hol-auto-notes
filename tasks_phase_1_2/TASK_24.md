# TASK_24 — BLAST depth/set/robustness regressions (§8.3.2–§8.3.6)

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

## Objective

Plan T21, second half (§8.3.2–§8.3.6): depth regressions, set-theory
problems, Halting II, robustness cases.

## Spec

Read first: `PLAN_phase_1_2.md` §8.3 items 2–6;
`.agent-files/research/phase12-blast-port.md` §9 (Table 1, set
problems, Halting II).

Extend `src/auto/blast/selftest.sml`:

1. Depth regressions (§8.3.2): `BLAST_DEPTH_TAC n` solves each
   Table-1 problem at its published depth — 24@4, 26@3, 28@3, 34@7,
   38@4, 43@5, 46@7, 52@7, 62@1 — locking the penalty/`md`/`lim`
   accounting.  Also assert failure at depth n-1 for at least two of
   them (the accounting lock has teeth in both directions).
2. The four set problems (§8.3.3) in `pred_set` form at depths
   3/3/4/4, with selftest-local set rules; document the
   `~(x IN UNIV)` sensitivity as a comment flagged for Phase-8
   seeding.
3. Halting II (§8.3.4) behind a higher `HOLSELFTESTLEVEL`.
4. Robustness (§8.3.5): weak elim declared `[elim]` ⇒ warning + skip,
   not fatal; a HO-unification-requiring goal fails cleanly; a
   crafted equality-substitution-reordering goal exercising
   PROOF FAILED → backtrack (assert success-after-backtrack or clean
   failure with the diagnostic); deepening stops at the cap.
5. Counts + time budgets as assertions everywhere (§8.3.6);
   exhaustive corpora behind `HOLSELFTESTLEVEL`; never prune goals to
   make a gate pass.
6. Any regression found is fixed in its module with a failing-first
   test.

## Acceptance criteria

1. All groups present and passing: `Holmake` + `./selftest.exe` in
   `src/auto/blast/` (default level and, separately verified, the
   higher `HOLSELFTESTLEVEL`).
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Depth assertions match the published Table-1 numbers exactly.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns.

## Dependencies

TASK_23.
