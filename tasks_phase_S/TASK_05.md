# TASK_05 — `Split` marker constant (markerScript / markerLib)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; part of it is the Isabelle splitter, whose per-invocation
rule supply uses a `Split th` marker (like the existing `Cong th`).
Governing constraint: **all defaults preserve current behavior**.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T5 (§5.2, marker part only): add the `Split` marker constant to the
marker theory and its mk/dest support to markerLib.  This is a small,
purely additive theory change, done early because everything downstream
rebuilds after any `src/marker` change.

## Spec

Read PLAN_phase_S §5.2 and D20 (§0).  Sources:
`src/marker/markerScript.sml`, `src/marker/markerLib.{sig,sml}`.

1. Add a `Split` marker constant to `markerScript.sml` following the
   `Cong` thm-carrying pattern exactly (see how `Cong` is defined in the
   script and handled at `markerLib.sml:77`).
2. Add `markerLib.Split : thm -> thm` and `markerLib.destSplit`
   (mirroring the `Cong`/`destCong` pair — match their actual names and
   types in `markerLib.sig`).
3. Do **not** touch simpLib here: the `simpLib.Split` re-export and
   `process_tags` handling are TASK_10.
4. Names were collision-checked 2026-07-16 (D20); still, verify `Split`
   is free in the marker theory before defining.

## Acceptance criteria

1. `src/marker` builds; the constant and mk/dest functions work
   (round-trip `destSplit (Split th) = th` — add a check to whatever
   test surface `src/marker` has, or verify by the simp selftest later
   consuming it; a minimal inline sanity check in an existing selftest
   is fine if `src/marker` has none).
2. `bin/build -t --seq=tools/sequences/upto-parallel` green (this
   rebuilds most of the tree — expected).
3. No existing marker behavior changed (purely additive).
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

None (independent of TASK_01–04; scheduled early because of rebuild
cost).
