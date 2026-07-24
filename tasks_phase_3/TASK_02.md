# TASK_02 — `classicalLib.CS_DEPTH_SOLVE_TAC` (D32/D36)

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

Plan task 02 (`PLAN_phase_3.md` §3.2): export the previously-private
bounded depth-search recipe as `CS_DEPTH_SOLVE_TAC` (Isabelle's
`depth_tac`/`nodup_depth_tac` pair), refactoring the internal users
onto the same helper.

## Spec

Read first: `PLAN_phase_3.md` §3.2, §0.1 (D32, D36, D39);
`classicalLib.sml:107–133,190–195,219–230`; `clasetLib.sig:59–60`;
`clasetStep.sig:62`.

1. Export:

       val CS_DEPTH_SOLVE_TAC :
         {dup : bool} -> int -> clasetLib.claset -> NTactical.ntactic

2. Semantics = the delivered private recipe generalized.
   `bounded_depth` (`classicalLib.sml:219–230`) already has Isabelle's
   `depth_tac` shape — safe-step saturation, then
   `clasetSearch.DEPTH_SOLVE` over `clasetStep.depth_step cs part
   bound` — but hard-wires `clasetLib.dup_part cs`.  Parameterize the
   part: `{dup = true}` → `dup_part`, `{dup = false}` → `unsafe_part`.
   The export is `solve (bounded_depth {dup} cs bound)`, so kernel
   replay (with F4's backtracking on replay failure) is shared, not
   copied.
3. Refactor `CS_DEEPEN_TAC` onto the same helper at `{dup = true}` —
   one implementation, no copies.  No new `Measured` twins (D39).
4. Depth counts unsafe expansions only; uwrappers apply at the
   branching rung only (already the delivered `depth_step` geometry —
   do not change wrapper geometry).
5. Selftests (`src/auto/classical/selftest.sml`, per §10.7): a
   dup/nodup divergence test — a goal solvable only with duplication
   succeeds at `{dup = true}` and fails at `{dup = false}` at the same
   bound; a `CS_DEEPEN_TAC` regression confirming the refactor changed
   no behavior.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`,
   including the new dup/nodup divergence test.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on `src/auto/classical/`.
4. `CS_DEEPEN_TAC` and the export share one `bounded_depth`
   implementation (no copied recipe).

## Dependencies

None.  (TASK_03 also edits `classicalLib`; do not run concurrently.)
