# TASK_07 — Phase-1 selftest suite (§8.1)

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

Plan T7 (§8.1): the systematic Phase-1 selftest suite in
`src/auto/classical/selftest.sml`, on top of the unit tests already
added by TASK_01–06.

## Spec

Read first: `PLAN_phase_1_2.md` §8 preamble + §8.1; `src/auto/
CLAUDE.md` (testing guidelines); `src/auto/rules/selftest.sml` (house
style, testutils usage); `src/auto/rules/clasetSeedScript.sml` (the
seed claset contents).

Implement the five §8.1 groups:

1. Cascade-order regressions on a crafted claset: each of the five
   safe-step slots fires exactly when the earlier ones cannot (golden
   goals per slot, incl. the built-in DISCH/GEN steps and their tag
   position).
2. `CLARIFY_TAC` restrictions: weight-1-only; `bimatch2`
   one-branch-closes acceptance and rejection; residues asserted
   exactly (e.g. an `A /\ B` conclusion untouched).
3. `SAFE_TAC` on the seed corpus: quantifier/connective goals with
   exact residues; negative tests (never applies unsafe intros; never
   instantiates — a goal solvable only by `EXISTS_INTRO_THM` is left
   untouched).
4. D27 failure semantics; marker vocabulary (`SIntro`/`Del`/…
   consumed; `Cong`/`Excl` pass through); wrapper composition order
   (newest innermost, ORELSE for safe — `classical.ML:529–545` parity).
5. Hyp-subst slot: saturation, occurs-check refusals, bool-atom
   extras.

House rules: successes through `Tactical.VALID`; non-closing tactics
assert exact residual goals; no claset/theory state leaks on success
or failure; test specified behavior, not internals.

## Acceptance criteria

1. All five groups present and passing: `Holmake` + `./selftest.exe`
   in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Any implementation bug found is fixed in its module (with a
   failing-first regression), not worked around in the test.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns.

## Dependencies

TASK_06.
