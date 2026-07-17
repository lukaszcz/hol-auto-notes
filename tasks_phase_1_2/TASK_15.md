# TASK_15 — Engine/driver selftests (§8.2.2–§8.2.4)

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

Plan T14, first half (§8.2.2–§8.2.4): the systematic engine and
driver selftests.  (§8.2.1 was delivered with TASK_03; §8.2.5 is
TASK_16.)

## Spec

Read first: `PLAN_phase_1_2.md` §8 preamble + §8.2, §10.2;
`.agent-files/research/phase12-classical-search-port.md` §6.3
(sibling-sharing corner); `src/auto/CLAUDE.md` (testing guidelines).

Extend `src/auto/classical/selftest.sml`:

1. Eigenvariable discipline (§8.2.2) — the classic non-theorems must
   FAIL: `?x. !y. x = y` (metavariable created before the
   eigenvariable must not capture it); dually
   `(!x. ?y. P x y) ==> ?y. !x. P x y`; plus the sibling-sharing
   corner from the report §6.3.  Assert clean failure, not divergence
   or false success, on every driver that could touch them.
2. Replay (§8.2.3): every driver success replays through
   `Tactical.VALID`; grounding determinism (same goal twice ⇒ same
   theorem); the D24 wrapper-step replay round-trip (may extend the
   TASK_12 test into driver-level coverage).
3. Driver semantics (§8.2.4): FAST-vs-SLOW distinguishing goals
   (commitment vs APPEND backtracking); BEST_FIRST size-ordering
   regression; DEEPEN bound accounting (safe steps free, `inst0`
   free, unsafe/dup decrement — a goal solvable at bound n but not
   n-1); D25 pruning positive and negative cases via step-count
   telemetry (may extend the TASK_13 unit tests to driver level).

House rules: exact residues for non-closing tactics; no state leaks;
never weaken a test to make it pass — fix the module with a
failing-first regression.

## Acceptance criteria

1. All three groups present and passing: `Holmake` +
   `./selftest.exe` in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. The §8.2.2 non-theorem battery covers every exported driver
   (loop over the driver list, not hand-picked two).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns.

## Dependencies

TASK_14.
