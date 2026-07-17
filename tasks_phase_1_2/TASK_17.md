# TASK_17 — `REV_DUP_ELIM_RULE` in `clasetRules` (§6.3, §11.2)

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

Plan T15 (§6.3, sanctioned freeze-list amendment §11.2): add the
derived rule `REV_DUP_ELIM_RULE` to `src/auto/rules/clasetRules` as
an additive export, with golden tests.

## Spec

Read first: `PLAN_phase_1_2.md` §6.3 (duplication bullet), §11.2,
M-i (§7); `src/auto/rules/clasetRules.{sig,sml}` (the existing
`DUP_ELIM_RULE` and the derived-rule house style);
`.agent-files/sources/src/Provers/blast.ML:466–467` (the `rev_dup_elim`
being modeled).

1. `REV_DUP_ELIM_RULE`: on the canonical rule spine, duplicate the
   major premise FIRST among each premise's added hypotheses
   (blast.ML's `rev_dup_elim`, vs the existing `DUP_ELIM_RULE` =
   `dup_elim`, which stays as-is).
2. Additive only: no other `clasetRules` export changes; all other
   Phase-0 interfaces remain frozen.
3. Golden tests in `src/auto/rules/selftest.sml`, following the
   existing derived-rule test style: exact output theorems on the
   standard elim shapes (conj/disj/exists elims from the seed set);
   contrast test against `DUP_ELIM_RULE` (hypothesis order differs
   as specified); idempotence/failure edge cases matching the
   existing rules' conventions.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/rules/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Diff to `src/auto/rules` is purely additive (new export + tests).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_09 (Phase-2 start; independent of TASK_10–16 — can run in
parallel with them).
