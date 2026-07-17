# TASK_08 — Phase-1 docfiles (+ deferred Phase-0 entries)

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

Plan T8 (§4 last bullet): `help/Docfiles` entries for the Phase-1
tactics plus the Phase-0 attribute/marker entries deferred from
Phase 0 (`PLAN_phase_0.md` §12).

## Spec

Read first: `PLAN_phase_1_2.md` §4; `PLAN_phase_0.md` §12 (the
deferred docfile list); existing docfiles for format, e.g.
`help/Docfiles/Tactic.STRIP_TAC.doc` and a `bossLib` entry;
`developers/` notes on the doc format if needed.

1. Docfiles for `SAFE_TAC`, `CLARIFY_TAC`, `SAFE_STEP_TAC`,
   `CLARIFY_STEP_TAC` (structure `classicalLib`): DOC/SYNOPSIS/
   DESCRIBE/FAILURE (D27 semantics!)/EXAMPLE/SEEALSO, documenting the
   `thm list` marker vocabulary and the unsafe-intro default for
   plain theorems.
2. The deferred Phase-0 entries per `PLAN_phase_0.md` §12: attribute
   and marker vocabulary (`intro`/`elim`/`dest`/`iff`-family
   attributes as delivered, `SIntro`/`Del`/… markers) — check the
   delivered names in `src/auto/rules/clasetLib.sig` and the Phase-0
   plan before writing; document what exists, not what was planned.
3. Cross-reference the docfiles in SEEALSO both ways.
4. Do NOT cite `.agent-files/` paths anywhere in committed docs; fold
   any needed substance inline.

## Acceptance criteria

1. Docfiles build cleanly (run the doc-processing check used by the
   distribution: `Holmake` in `help/src-sml` or the documented
   equivalent — verify the mechanism in `developers/`/`Manual` docs
   and use it).
2. Every tactic exported by TASK_06 has an entry; deferred Phase-0
   entries present.
3. No `.agent-files` references in any committed file.
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_06 (TASK_07 advised, so examples reflect tested behavior).
