# TASK_20 — `blastSearch`: the tableau engine (§6.4)

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

Plan T18 (§6.4): implement `blastSearch.{sig,sml}` — the faithful
port of blast's search engine.

## Spec

Read first: `PLAN_phase_1_2.md` §6.4, M-l (§7);
`.agent-files/research/phase12-blast-port.md` §5 (the
reimplementation-grade spec — this is the primary source; follow it
clause by clause); `.agent-files/sources/src/Provers/blast.ML`
(the `prv` function and its environment).

1. Branch record faithful to the report §5: level stack / lits /
   vars / lim.
2. The five `prv` clauses; safe cascade order: equality substitution
   → close-with-literal → close-with-any → safe rule → defer.
3. Unsafe expansion with `md`/γ-requeue-at-back; recursive-premise
   level sharing; penalty `1 + ⌊log₄ N⌋`; `mayUndo`; kill-all;
   `prune`/`clashVar`.
4. `DEEPEN (1, depth_limit)` with `depth_limit` a ref defaulting
   to 20.  No timeout (M-l); note the optional polled counter as an
   extension point in a comment — do not build it.
5. Search produces the recorded script in the six-tactic vocabulary
   (report §6.1 T1–T6) for TASK_21's reconstruction; reconstruction
   itself is NOT this task — expose the recorded script and the
   backtrack re-entry hook (`PROOF FAILED` raises back into `prv`'s
   choice stack) as the module interface.
6. Unit tests: search-only (no reconstruction) on golden goals —
   propositional tautologies close; a known-depth goal closes at its
   depth and not below (lim accounting); γ-requeue order; `prune`
   fires/does-not-fire pairs; `mayUndo`/kill-all behavior on a
   crafted branch point.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Module comment maps each ported clause to its `blast.ML` lines.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_19.
