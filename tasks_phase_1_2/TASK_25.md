# TASK_25 — Phase-2 docfiles: drivers + BLAST

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

Plan T22 (§5–§6): `help/Docfiles` entries for the Phase-2 driver
surface and BLAST.

## Spec

Read first: `PLAN_phase_1_2.md` §5, §6.6, D26 (§0); the TASK_08
docfiles (house format for this project); `.agent-files/research/
phase12-blast-port.md` §7 (limitations, to be folded inline).

1. Entries for `FAST_TAC`, `SLOW_TAC`, `BEST_TAC`, `SLOW_BEST_TAC`,
   `FIRST_BEST_TAC`, `ASTAR_TAC`, `SLOW_ASTAR_TAC`, `DEEPEN_TAC`,
   `STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC` (structure
   `classicalLib`): search strategy, numeric defaults, marker
   vocabulary, solve-completely failure semantics; SEEALSO
   cross-links among the family and to `SAFE_TAC`/`CLARIFY_TAC`.
2. Entries for `BLAST_TAC` and `BLAST_DEPTH_TAC` (structure
   `tableauLib`): cross-reference `blastLib.BBLAST_TAC` (the
   bit-blasting tactic — distinguish them explicitly); documented
   limitations per §6.6 (wrappers ignored, weak elims rejected, no HO
   unification in search, equality handling incomplete), each folded
   inline in the docfile's own words.
3. Do NOT cite `.agent-files/` anywhere; fold substance inline.
4. Docfiles build check as in TASK_08.

## Acceptance criteria

1. Every TASK_14/TASK_22 export has an entry; docfiles build cleanly
   via the mechanism used in TASK_08.
2. `BLAST_TAC` ↔ `BBLAST_TAC` cross-references present both ways
   (add the SEEALSO to the existing BBLAST_TAC docfile).
3. No `.agent-files` references in committed files.
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_14, TASK_22 (TASK_23/24 advised so examples reflect tested
behavior).
