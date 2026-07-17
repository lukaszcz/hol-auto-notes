# TASK_16 — Strength floor: `FAST_TAC []` Pelletier smoke (§8.2.5)

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

Plan T14, second half (§8.2.5): the `fast`-parity smoke test —
`FAST_TAC []` solves the propositional and easy-quantifier Pelletier
problems (1–17 and selected 18–34) with the seed claset.

## Spec

Read first: `PLAN_phase_1_2.md` §8.2.5, §8.3 preamble;
`.agent-files/research/phase12-blast-port.md` §9 (Pelletier notes,
Table 1); `src/meson/test/selftest.sml` (the `M`/`Mfail` driver
shape, the model); Pelletier problem statements (report/paper under
`.agent-files/papers/` if present, else standard formulations).

1. Author HOL4 translations of Pelletier 1–17 and the easy-quantifier
   selection from 18–34 (per §8.2.5; report §9 indicates which of
   18–34 Isabelle's `fast` gets — follow it, and record the chosen
   list in a comment).  Write them as a clearly-delimited corpus
   block in `src/auto/classical/selftest.sml` so TASK_23 can adapt
   the translations for the blast corpus.
2. Test driver in the meson-selftest shape: each problem solved by
   `FAST_TAC []` under `Tactical.VALID`, within a per-goal time
   budget; solved-goal count asserted (regression = failure).
3. Problems Isabelle's `fast` does NOT solve must not be silently
   dropped: include them as explicit expected-unsolved entries or
   leave them for the blast corpus with a comment — never prune to
   make the gate pass.
4. Any lost goal traced to an engine bug: fix in the module with a
   failing-first regression; a genuine strength gap vs Isabelle's
   `fast` is a hard failure of this task (strength parity is the
   project bar), not something to paper over.

## Acceptance criteria

1. `FAST_TAC []` solves every problem on the recorded list; counts +
   budgets asserted; `Holmake` + `./selftest.exe` green.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. The corpus block is reusable (self-contained term quotations,
   numbered, delimited).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns.

## Dependencies

TASK_14 (TASK_15 advised first — engine bugs surface cheaper there).
