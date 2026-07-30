# TASK_01 — Record decisions, fix docs, create core skeleton + build wiring

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

## Read first

- `.agent-files/PLAN_phase_5.md` in full — especially §0 (D59–D62),
  §7 (build integration), §9 (documentation edits), §10 (T1).
- `PLAN.md` §2, §3, §8 (the sections being edited).
- `src/auto/CLAUDE.md`.
- An existing `src/auto` core-band directory for the Holmakefile
  pattern (e.g. `src/auto/blast/Holmakefile`,
  `src/auto/rules/Holmakefile`).
- `tools/sequences/upto-auto`, `tools/sequences/more-theories`,
  `src/parallel_builds/core/Holmakefile`.
- Repo `CLAUDE.md` for build/style rules.

## Work items

1. Append decisions D59–D62 to `PLAN.md` §2 (copy the substance from
   PLAN_phase_5.md §0; do NOT cite `.agent-files` paths in any
   committed file — fold substance inline).  Update PLAN.md §3's
   layout block and §8 per PLAN_phase_5.md §9.
2. Edit `src/auto/CLAUDE.md` per PLAN_phase_5.md §9: `linarith/` line
   = "generic linear arith, `LINARITH_TAC` (D55: no registry)";
   delete the `presburger/` and `algebra/` lines; note the
   two-directory linarith layout and that `instances/` is the one
   `src/auto` directory allowed post-boss `INCLUDES`.
3. Create `src/auto/linarith/` with a Holmakefile per PLAN_phase_5.md
   §7: `HOLHEAP` pin to `bin/hol.state0`, `INCLUDES` =
   `src/auto/rules` + `src/simp/src` only, selftest scaffold
   (`selftest.exe`, `linarith-selftest.log`, `EXTRA_CLEANS`).  A
   minimal placeholder `selftest.sml` (prints and exits 0, testutils
   style) so the scaffold builds.  Do NOT create the `instances/`
   directory yet (later task).
4. Build wiring for the core directory only: insert
   `src/auto/linarith` in `tools/sequences/upto-auto` after
   `src/auto/blast` and before `src/auto/clasimp`; add
   `auto/linarith` to `src/parallel_builds/core/Holmakefile`
   `SRCRELNAMES`.  Do not add `theory_tests` entries yet (no theory
   script exists yet; that lands with the settypes task).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` is green, building
  `src/auto/linarith` in the right sequence position and running its
  (placeholder) selftest.
- PLAN.md and `src/auto/CLAUDE.md` edits made as specified; no
  committed file references `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns
  (`tools/h4pedant` clean on touched files).
- Commit the work with a descriptive message.
