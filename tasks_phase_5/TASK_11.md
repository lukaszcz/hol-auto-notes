# TASK_11 — D56 wiring: clasimp + aesop solver integration

## Context

This task is part of Phase 5 of the Isabelle-tactics project: porting
Isabelle's `Fast_Lin_Arith` linear-arithmetic engine to HOL4 as a
generic, registry-driven decision procedure in `src/auto/linarith/`
(core) and `src/auto/linarith/instances/` (int/real/rat).  The
ultimate goals of the whole plan (`.agent-files/PLAN_phase_5.md`) are:

1. A faithful untrusted Fourier–Motzkin engine with Farkas-certificate
   (`injust`) trees and kernel replay in both tactic and forward styles.
2. Instance records for `num`, `int`, `real`, `rat` via a live
   in-memory registry (rat is a net-new capability).
3. Goal-level preprocessing per decision D59: relevance filtering,
   splitLib-driven operator splitting, div/mod fact-augmentation, NNF.
4. The D62 public surface (`LINARITH_TAC`, `SIMPLE_LINARITH_TAC`,
   `CFG_LINARITH_TAC`, `LINARITH_PROVE`, `LINARITH_CONV`), the
   `[arith]`/`[arith_split]` theorem sets, `LINARITH_ss`, and the
   `"lin_arith"` unsafe solver wired into clasimp and aesop (D56).
5. Selftests (unit, per-instance, persistence, strength corpus) and
   user documentation.

Quality is judged by resulting automation strength — general,
principled, extensible; no recognition shortcuts.  Any work done in
this task must be a step toward these goals, **but the plan goals
above are NOT this task's acceptance criteria** — only the criteria
listed below are.

## Depends on

TASK_10 (`linarith_solver` exists).

## Read first

- `.agent-files/PLAN_phase_5.md` §6.3 (the exact edits), §6.2
  (unsafe-only rationale).
- `src/auto/clasimp/clasimpLib.sml:8–27` (`derive_clasimp_ss`
  cache), `src/auto/aesop/aesopData.sml:48–83` (`derive_aesop_ss`).
- `src/auto/clasimp/Holmakefile`, `src/auto/aesop/Holmakefile`.
- Existing selftests in both directories for the test idiom.

## Work items

1. `clasimpLib.sml` (`derive_clasimp_ss`): add
   `|> simpLib.add_unsafe_solver linarithLib.linarith_solver`.
   No generation counter (solver reads `[arith]` and the registry at
   invocation).
2. `aesopData.sml` (`derive_aesop_ss`): same one-line addition.
3. `src/auto/clasimp/Holmakefile`: `INCLUDES += auto/linarith`
   (relative path as appropriate; aesop inherits visibility through
   its existing clasimp include — verify, don't assume).
4. Selftest additions in BOTH directories: an `AUTO_TAC` goal and an
   `AESOP_TAC` goal that close only through an arithmetic side
   condition (i.e. fail before this wiring), plus an
   `[arith]`-fact-dependent variant (add a fact to `[arith]` in the
   test, observe the goal close, remove it again — leave global
   state clean).
5. Confirm the aesop discipline note of §6.3 holds in practice:
   unsafe solvers do not run as final solvers in safe mode
   (normalisation stays ≤ 1-subgoal, deterministic) — read the
   relevant simpLib/aesop code paths and state the verification in
   the commit message or a test comment.

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green, including
  clasimp and aesop selftests with the new goals; the new goals
  demonstrably fail without the wiring (verify once manually before
  finalizing, e.g. by stashing the edit).
- No other distribution simpset/clasimp behavior changes; global
  state (sets, registry) clean after tests.
- Style rules respected; commit the work.
