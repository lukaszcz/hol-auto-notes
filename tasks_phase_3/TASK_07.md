# TASK_07 — simp-wrapper combinators (D37) + argument processor

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

Plan task 07 (`PLAN_phase_3.md` §5, §6): port `clasimp.ML:44–54`'s
`addss`/`addSss` as `add_simp_wrapper`/`add_safe_simp_wrapper`, and
implement the shared argument processor for all six tactics.

## Spec

Read first: `PLAN_phase_3.md` §5 (incl. §5.1 geometry), §6, §0.1
(D30, D37); `NTactical.sig:9–19`; `clasetLib.sig:46–51`;
`clasetStep.sml:1703–1866` (wrapper geometry — read, do not change);
`markerLib.sig:54` region.

1. In `clasimpLib`:

       val add_simp_wrapper :
         simpLib.simpset -> clasetLib.claset -> clasetLib.claset
       val add_safe_simp_wrapper :
         simpLib.simpset -> clasetLib.claset -> clasetLib.claset

   - `add_simp_wrapper ss` = `add_unsafe_wrapper
     ("asm_full_simp_tac", w)` with `w step = NAPPEND (NCHANGED (LIFT
     (asm_full_simp ss [])), step)` — Isabelle's `addbefore`
     (`APPEND'`).
   - `add_safe_simp_wrapper ss` = `add_safe_wrapper
     ("safe_asm_full_simp_tac", w)` with `w step = NORELSE (step,
     NCHANGED (LIFT (safe_asm_full_simp ss [])))` — Isabelle's
     `addSafter` (`ORELSE'`).
   - Slot strings stay Isabelle's (D37); re-adding overwrites the slot
     (delivered claset semantics).
2. Argument processor (§6), one function shared by all six tactics.
   Every theorem-list entry point wraps in `markerLib.ABBRS_THEN`.
   Partition order:
   - `Simp th` → simpset addition; `Iff th` → per-invocation iff
     (until TASK_10 lands, `Iff` may raise a clear "not yet
     implemented" error — leave a hook point);
   - claset markers (`SIntro`…`Dest`, `Del`) → temporary claset via
     `clasetLib.process_claset_tags`;
   - anything satisfying `markerLib.is_generic_simp_marker` → passed
     through **unchanged** to the simp invocations (deliberate
     asymmetry with §3.4: clasimp has a simpset, so it must *not*
     unwrap content-bearing wrappers — `Once th` is a simp control
     here);
   - plain theorems → inserted as assumptions first (D30), visible to
     every phase of each script.
   Result: a `(claset, simpset)` pair plus an insertion pre-tactic.
3. Selftests (§10.1, §10.2):
   - Unit: each marker kind routed correctly; plain-thm insertion
     visible in residue; `Once th` reaches the simpset (not unwrapped);
     `Abbr` honored.
   - Wrapper: goals solvable only via `add_simp_wrapper` inside search
     at each of the unsafe and depth rungs, and only via
     `add_safe_simp_wrapper` at the safe and clarify rungs (behavioral
     geometry tests, risk §13.6 — use `CS_FAST_TAC`,
     `CS_DEPTH_SOLVE_TAC`, `CS_SAFE_TAC`, `CS_CLARIFY_TAC` on wrapped
     clasets);
   - Rigid-render guard (risk §13.2): `add_safe_simp_wrapper` cannot
     instantiate engine metavariables.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on `src/auto/clasimp/`.
4. Wrapper slot strings are exactly `"asm_full_simp_tac"` and
   `"safe_asm_full_simp_tac"`.

## Dependencies

TASK_05 (`Simp`/`Iff` constructors), TASK_06 (clasimpset,
`asm_full_simp`/`safe_asm_full_simp`).
