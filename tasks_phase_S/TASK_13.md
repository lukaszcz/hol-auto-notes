# TASK_13 — Docfiles, `notes.md`, h4pedant pass

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgraded the simplifier in
`src/simp/src/` (engine hooks, tactic loop, splitter, congprocs,
`GEN_GLOBAL_SIMP_TAC`).  This task documents the new user surface.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T11 (§9): Docfiles for every user-facing addition, update
`src/simp/src/notes.md`, and a clean pedant pass over everything Phase S
touched.

## Spec

Read PLAN_phase_S §9 and skim §3–§7 for the semantics being documented.
Study several existing entries under `help/Docfiles/` for the format
(`.doc` markup, `\SEEALSO`, `\EXAMPLE` etc.) and check how Docfiles are
validated in the build.

1. New `help/Docfiles` entries: `splitLib.SPLIT_TAC`, `simpLib.split_ss`,
   `simpLib.add_split`, `simpLib.Split`, the `[split]` attribute
   (documented on the SPLIT_TAC page), the `simpLib.add_looper` family,
   the `simpLib.add_unsafe_solver` family, `simpLib.set_cond_depth`,
   `simpLib.set_term_ord`, `simpLib.clear_rules`,
   `simpLib.GEN_GLOBAL_SIMP_TAC`.
2. `SPLIT_TAC`'s page cross-references `Cases_on`/`CASE_TAC` (the
   global-splitting alternatives) and notes the one `examples/` local
   shadow (`examples/machine-code/hoare-triple/set_sepScript.sml:60`).
3. Update `src/simp/src/notes.md` with the new engine seams
   (context_thms, subgoaler/solver pipeline, dynamic
   cond_depth/term_ord binding, looper/final-solver tactic loop).
4. Run `tools/h4pedant` over all files Phase S touched (use
   `git diff --name-only` against the branch base to enumerate); fix any
   tab/whitespace/column violations.

## Acceptance criteria

1. All listed Docfiles exist and pass whatever Docfile
   validation/build step the distribution runs (check
   `help/` build machinery).
2. `notes.md` updated.
3. `tools/h4pedant` clean on all touched files.
4. `bin/build -t --seq=tools/sequences/upto-parallel` green.

## Dependencies

TASK_09, TASK_10, TASK_11, TASK_12 (documents their surface).
