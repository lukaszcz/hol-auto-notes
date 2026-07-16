# TASK_06 — Tactic-layer loop: `GEN_SIMP_TAC {safe}`, loopers + final
# solvers, entry-point rewiring

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`.  This task ports Isabelle's `generic_simp_tac` loop —
the piece that lets simp restart after a looper (e.g. the splitter) splits
the goal, and try final solvers on residual goals.  Governing constraint:
**all defaults preserve current behavior** — with empty loopers/solvers
the loop must reduce to today's `CONV_TAC o SIMP_CONV` (decision D14).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T4 (§5.1): implement `GEN_SIMP_TAC : simp_mode -> simpset -> thm
list -> tactic` with the rewr/solve/loop structure, and rewire all
existing simp tactic entry points through it.

## Spec

Read PLAN_phase_S §5.1 in full (pseudocode included), D14/D16 (§0), §12
(freeze list), and `.agent-files/research/phaseS-isabelle-simploop.md`
§4.c.  Source: `src/simp/src/simpLib.{sig,sml}` (tactic layer around
`simpLib.sml:893–896` and the `FULL_SIMP_TAC`/`global_simp_tac`
machinery at ~964–994).

1. `type simp_mode = {safe : bool}` and `GEN_SIMP_TAC` with the loop
   shape from §5.1:
   - `rewr_tac` = existing conversion application
     (`markerLib.process_taclist_then` + `CONV_TAC o SIMP_CONV`),
     closing the goal on rewrite to `T`; never fails.
   - `solve_tac` = try each final solver (safe list if `#safe mode`,
     else unsafe list — D16) on the residual conclusion, with
     `context_thms` = the same theorem list the engine invocation saw
     (ASSUMEd assumptions unless `NoAsms`, plus user theorems); accept
     via `ACCEPT_TAC` after hypothesis reconciliation
     (`PROVE_HYP`/`ADD_ASSUM`) — result hyps must be ⊆ asl.
   - `loop_tac` = first applicable looper in registration order, applied
     to the invocation simpset, skipping names in `excl_loopers`; a
     looper fails (never raises `UNCHANGED`) when inapplicable, so `TRY`
     terminates the loop.
   - The simpset `limit` field also bounds looper rounds (§11.3).
2. **Rewiring (D14)**: `ASM_SIMP_TAC ss = GEN_SIMP_TAC {safe=false} ss`;
   `SIMP_TAC` prepends `NoAsms` as today; the `FULL_SIMP_TAC` family and
   `global_simp_tac` get the loop through their final goal-directed step
   only (per-assumption `SIMP_RULE` passes stay conversion-only).
   `SIMP_PROVE`/`SIMP_CONV`/`SIMP_RULE` never run loopers or final
   solvers.
3. **Selftests** (§8 group 5 + zero-change lock):
   - the whole pre-existing selftest corpus passes unmodified through
     the new path (D14 guarantee);
   - a toy looper (e.g. splitting a marker conjunction) exercising
     restart-on-every-subgoal and `TRY` termination;
   - safe/unsafe final-solver list selection under
     `{safe = true/false}`;
   - a final solver closing a residual goal from an assumption
     (context_thms visibility at the tactic layer);
   - looper round bounded by `limit`.

## Acceptance criteria

1. Entire existing selftest suite (incl. TASK_01 golden group) passes.
2. New group-5 tests pass.
3. With empty loopers and solver lists, all rewired entry points behave
   identically to before (no new subgoals, same theorems).
4. `simp_mode`/`GEN_SIMP_TAC` exported with the §5.1 shapes (frozen at
   phase completion, §12).
5. `bin/build -t --seq=tools/sequences/upto-parallel` green.
6. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_04.
