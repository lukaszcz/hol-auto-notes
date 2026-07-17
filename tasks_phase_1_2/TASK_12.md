# TASK_12 — D24 materialization: render/unrender + wrapper steps

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

Plan T11, second half (D24, §3.3 materialization + §3.5 item W):
complete the engine-wrapper materialization — full `render`/`unrender`
on metavariable-laden nodes, wrapper-step recording, replay-for-free.

## Spec

Read first: `PLAN_phase_1_2.md` D24 (§0), §3.3 (materialization
hook), §3.5 item 5/W; `.agent-files/research/
phase12-classical-search-port.md` §4.3 (wrapper semantics, the
rigid-frees guarantee); `.agent-files/sources/src/Provers/
classical.ML:718` (uwrapper exemption point, for the module comment).

1. Complete `clasetGoal.render`: node goal `i` as a HOL4 goal with
   metavariables shown as their marked frees (rigid by construction).
2. Complete `unrender`: lift a wrapper's `(goal list, validation)`
   back — re-abstract marked frees to the same metavariables, splice
   the child goals into the node, and record the validation as a
   wrapper step (§3.5 item 5): the validation IS the replay; no
   re-execution, no re-unification.
3. Defensive check: a wrapper result mentioning a marked free it did
   not receive is rejected (clean failure of that wrapper
   application, not a crash).
4. Wire the TASK_05/TASK_10 wrapper call sites (swrappers inside
   every safe step; uwrappers around the inst+unsafe rung, not around
   `depth_step`'s `inst0`) through the completed API; remove the
   stub.
5. Document the rigid semantics in the sig: a wrapper can never
   instantiate engine metavariables (solver-level instantiation is a
   recorded Phase-3 option — cite the decision, not `.agent-files`,
   in committed comments; a comment naming D24 is fine).
6. Unit tests: render/lift-back round-trip on a metavariable node
   (D24 test from §8.2.3): a recorded ntactic wrapper transforms a
   rendered goal, the lifted node carries the child goals, and final
   replay consumes the recorded validation; the defensive rejection
   case; a wrapper on a metavariable-free node still behaves as in
   Phase 1 (regression).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. No behavior change on metavariable-free nodes (Phase-1 selftests
   untouched and green).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_11.
