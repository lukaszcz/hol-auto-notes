# TASK_06 — `classicalLib` slice 1: `SAFE_TAC`/`CLARIFY_TAC` (D26, D27)

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

Plan T6 (§4): implement `classicalLib.{sig,sml}`, first slice — the
public `SAFE_TAC`, `CLARIFY_TAC`, `SAFE_STEP_TAC`, `CLARIFY_STEP_TAC`
and the claset-explicit programmatic layer (`safe_tac`, `clarify_tac`,
…), with marker processing and D27 failure semantics.

## Spec

Read first: `PLAN_phase_1_2.md` §4, D26/D27 (§0), M-c7/M-sig (§7);
`.agent-files/sources/src/Provers/classical.ML:591–595, 834, 843–844`;
`src/auto/rules/clasetLib.sig` (`process_claset_tags`,
`the_claset`); `src/auto/rules/NTactical.sig`.

1. Signatures exactly per §4: `thm list -> tactic` public layer;
   lowercase `claset -> NTactical.ntactic` programmatic layer (M-sig).
2. `thm list` argument = D4 marker vocabulary via
   `clasetLib.process_claset_tags` against `the_claset()`; unconsumed
   plain theorems added as unsafe intros; `Cong`/`Excl`/`SF` markers
   pass through untouched.
3. Loops (M-c7): `SAFE_TAC` = leftmost-position saturation with
   rescan (`REPEAT_DETERM1 (FIRSTGOAL safe_steps)` semantics incl.
   the position-fell-off-the-end guard); `CLARIFY_TAC` = per-goal
   `REPEAT_DETERM`.  Children replace their parent in place, premise
   order.
4. Failure (D27): `SAFE_TAC`/`CLARIFY_TAC` fail iff nothing changed
   (α-comparison, `CHANGED_PROP` analogue); step tactics fail iff no
   step applies.
5. No claset/theory state may leak on success or failure (extra
   theorems are per-invocation only).
6. Smoke tests in `selftest.sml` (the systematic §8.1 suite is
   TASK_07): a conjunction/implication goal saturates to the expected
   residues under `Tactical.VALID`; D27 failure on a no-op goal;
   an unconsumed plain theorem acts as unsafe intro (i.e. is NOT
   applied by `SAFE_TAC`).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Exported names exactly as in §2 (collision-checked list).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_05.
