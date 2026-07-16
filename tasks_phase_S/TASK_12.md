# TASK_12 — `congproc_ss`: procedural congruences through fragments

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; this task closes the "congprocs not exposable through
SSFRAG" gap (PLAN §1.2 item 2).  Governing constraint: **all defaults
preserve current behavior**.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T10 (§4.3, congproc part): make the `congproc_ss` fragment
constructor actually merge its congprocs into the simpset's travrules at
`++`.

## Spec

Read PLAN_phase_S §4.3.  Sources: `src/simp/src/simpLib.{sig,sml}`
(`mk_travrules` merge point, `simpLib.sml:669–671`),
`src/simp/src/Opening.{sig,sml}` and `src/simp/src/Travrules.{sig,sml}`
for the congproc type and travrules representation.

1. ```sml
   val congproc_ss : {name : string, relation : term,
                      proc : Opening.congproc} -> ssfrag
   ```
   (constructor + internal `SSFRAG_CON` field may already exist from
   TASK_04 — check the branch state; complete whatever is missing.)
2. At `++`, merge the fragment's congprocs into the simpset's travrules
   exactly where theorem congs are converted today, keyed to the given
   relation.
3. Addition only: names allow future removal, but removal of congprocs
   is a recorded non-requirement (no name index in travrules) — do not
   half-build it.
4. History rebuild (`build_from_history`) must replay congproc-carrying
   fragments correctly (they ride in fragments, so `ADDFRAG` replay
   should cover it — verify with a test).
5. **Selftests** (§8 group 7): a procedural congruence registered
   through a fragment reproduces a known theorem-cong behavior (pick a
   simple cong, e.g. an `==>`- or `COND`-style congruence, expressed
   procedurally); merge across `++`; survival across
   `remove_ssfrags`/`exclude_ssfrags` rebuild.

## Acceptance criteria

1. New group-7 tests pass; all existing selftests still pass.
2. No behavior change for simpsets without congproc fragments.
3. `bin/build -t --seq=tools/sequences/upto-parallel` green.
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_04.  Independent of TASK_05–11.
