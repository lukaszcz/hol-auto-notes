# TASK_13 — Docfiles (§11)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phase 3
(`.agent-files/PLAN_phase_3.md`) ports Isabelle's clasimp layer
(`Provers/clasimp.ML`) into `src/auto/clasimp/` on top of the delivered
classical stack (`src/auto/rules`, `src/auto/classical`,
`src/auto/blast`) and the Phase-S simplifier: the clasimpset,
simp-wrapper combinators, `AUTO_TAC`/`FORCE_TAC`/`FASTFORCE_TAC`/
`SLOWSIMP_TAC`/`BESTSIMP_TAC`/`CLARSIMP_TAC` with context-explicit
`CS_*` forms, the `[iff]` attribute, `Simp`/`Iff` markers, and the
layer-wide plain-theorem insertion convention (D30).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan task 12 (`PLAN_phase_3.md` §11) plus the Docfile half of plan
task 03 (deferred from TASK_03): all Phase-3 `help/Docfiles` pages and
the Phase-1/2 Docfile updates for insertion semantics.

## Spec

Read first: `PLAN_phase_3.md` §11, §1.1, §3.4, §4.1, §7.4; the
delivered Phase-1/2 Docfiles as format models (and their task's
process: AliasGen, doc processing checks).

1. New pages: the six tactics and their `CS_*` forms,
   `AUTO_DEPTH_TAC`, `add_simp_wrapper`/`add_safe_simp_wrapper`,
   `[iff]`/`remove_iff`, `Simp`/`Iff` markers,
   `classicalLib.CS_DEPTH_SOLVE_TAC`, `tableauLib.CS_BLAST_DEPTH_TAC`.
2. The `AUTO_TAC` entry documents: clasimpset = `srw_ss` + splitter +
   depth-40 side conditions; the splitting difference vs
   `SIMP_TAC (srw_ss())` (prominently); residue semantics
   (change-or-fail); the `{blast, depth}` parameters and defaults.
3. The `CLARSIMP_TAC` entry carries the premise-splitter caveat
   (§7.4); the `FORCE_TAC` entry documents the inert simp wrapper
   under clarify (§1.1.1).
4. Updates: Phase-1/2 tactic Docfiles gain the D30 insertion semantics
   for plain theorems (deferred from TASK_03); `BLAST_TAC`'s page
   notes unchanged public behavior and cross-references the raw
   `CS_BLAST_DEPTH_TAC` entry.
5. Run the standard doc checks used by the Phase-1/2 Docfile tasks
   (doc processing, AliasGen, cross-references, style).

## Acceptance criteria

1. Doc processing succeeds over the new/updated pages; AliasGen and
   cross-reference checks pass.
2. `tools/h4pedant/h4pedant` clean on touched files; no tabs, no
   trailing whitespace, < 80 columns.
3. Every §11 page listed above exists; the three content requirements
   (items 2–4) are present.

## Dependencies

TASK_08, TASK_09, TASK_11, TASK_12 (public surface final; TASK_03's
insertion semantics are an ancestor via these).
