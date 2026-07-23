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

## Status: COMPLETED/RECLOSED 2026-07-23 at `f4fc8be66`

All groups are present and passing.  Public proof search passes all nine
published Table-1 depths with `table1_expected_failures = []`.  The four
set problems pass at depths 3/3/4/4, and the robustness cases remain green.
At level 2 the depth-7 public Halting II attempt succeeds within the
unchanged 120-second budget and is asserted kernel-valid.  It is no longer
an expected failure.

Reviewed commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1` fixes persistent
metavariable expansion and exact replay generally.  It contains no
recognition or fallback shortcut.  The accepted committed-state package is:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
```

Its 47-entry package manifest digest is
`805cb6086f5fb65e0869dfd73722c9296cb0ec467fc150e8c410fe9d4e7e9c52`.
Its frozen plan and post-run identities bind exact commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`.

Fresh configure, exact `upto-auto`, direct Blast levels 1 and 2, and
h4pedant pass, followed by the committed-state full gate.  Both Blast levels
record exactly 9/9 unique Table 1 and 4/4 unique set successes.  Level 2
records exactly one kernel-valid Halting II `OK`; level 1 does not run it.
Acceptance criteria 1 through 4 are met without an owner exception, so
TASK_24 is completed/reclosed.

The exact integrated disclosure is one expected
`suspFastTheory ... F-CHEAT`, zero `CHEATED` and zero `Saved CHEAT`.
The separate full-build classification is recorded in `PLAN.md` §11.
Candidate 05 remains historical pre-commit functional evidence only.

On 2026-07-23 the owner also decided to close M2 once the complete suite and
Halting II pass because `perf_event_paranoid` cannot be lowered.  Those
conditions now pass.  The unavailable kernel profiler remains an
environmental disclosure, not a TASK_24 or M2 blocker.

### Reopening history

This task was reopened on 2026-07-19 because earlier figures were produced
by goal recognition, not proof search: `tableauLib.blast_preprocess` /
`halting_preprocess` rewrote corpus goals to `T` from seed theorems holding
their statements, or used `ACCEPT_TAC` after an `aconv` match.  Both were
removed.  The honest post-removal baseline was Table 1 at 6/9, sets at 4/4,
and Halting II unsolved; the later `7ea3b07fa` state reached 8/9 while
Halting II remained an asserted expected timeout.  At `5bc674569`, Table 1
reached 9/9 but Halting still failed, so the task remained reopened.
The `f4fc8be66` Halting success now satisfies the unchanged acceptance
criterion and supersedes those statuses, not the incident history.

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
