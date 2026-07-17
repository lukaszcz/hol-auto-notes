# TASK_13 — `clasetSearch`: drivers, D25 pruning, bounding, tracing

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

Plan T12 (§3.6): implement `clasetSearch.{sig,sml}` — the node search
drivers (DEPTH_FIRST/DEPTH_SOLVE, BEST_FIRST, ASTAR, DEEPEN), D25
dynamic pruning, bounding, and the `"classical"` trace family.

## Spec

Read first: `PLAN_phase_1_2.md` §3.6, D25/D26 (§0), M-e4 (§7);
`.agent-files/research/phase12-classical-search-port.md` §3.6
(driver semantics) and §8 (the `safe_depth_tac` DETERM history);
`.agent-files/sources/src/Pure/search.ML`; `.agent-files/sources/src/
Provers/blast.ML:831–867` (`prune`/`clashVar`); `src/metis/
mlibMeson.sml:408–411` (`CHECK_PERIOD` polling pattern).

1. `DEPTH_FIRST`/`DEPTH_SOLVE` (`search.ML:38–75`): explicit stack of
   child sequences, lazy, duplicate-solution suppression via M-e4
   node equality.
2. `BEST_FIRST` (`search.ML:180–199`): `searchHeap` min-heap keyed
   `(size, tiebreak)`; children of the popped node computed eagerly
   and completely; satisfying children end the search;
   `delete_all_min` dedup.  `BEST` expands with `step` at goal 1;
   `FIRST_BEST` with first-goal-where-anything-applies
   (`classical.ML:670–672`).
3. `ASTAR` (`search.ML:226–249`): sorted list, cost
   `size + 5*level`, LIFO among equal costs, first-equal-cost dedup.
4. `DEEPEN (inc, lim)` (`search.ML:147–154`): restart-based;
   committed once a bound succeeds.
5. D25 dynamic pruning: per-subtree binding marks on nodes; when a
   goal's complete solve is committed, discard the subtree's
   remaining alternatives iff none of its bindings touch a
   metavariable visible in the remaining goals (`clashVar`
   transposed to the persistent store by diffing binding sets).
   Applied in DEPTH_SOLVE-shaped loops (FAST/SLOW/DEEPEN);
   BEST/ASTAR unaffected.  The static `safe_depth_tac` DETERM test
   is NOT ported; document the supersession + upstream-inversion
   history in the module comment (substance inline, no
   `.agent-files` citation).
6. Bounding/tracing: iterative deepening as primary bound; a polled
   node counter behind a settable limit ref guarding BEST/ASTAR
   queues; `Feedback.register_trace "classical"` (0 silent,
   1 failures/diagnostics, 2 step summary, 3+ full candidate traces).
7. Unit tests: each driver on small crafted search spaces (order of
   exploration, dedup, deepening restart); a D25-fires case and a
   D25-must-not-fire case (shared metavariable across siblings) via
   step-count telemetry; node-counter limit triggers cleanly.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Driver semantics match the cited `search.ML` line ranges (module
   comment maps each driver to its source lines).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_12 (steps + wrappers + replay records all final).
