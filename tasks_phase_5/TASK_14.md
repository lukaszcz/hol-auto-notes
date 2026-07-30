# TASK_14 — Vendor `Arith_Examples.thy`; strength suite

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

TASK_13 (all instances live — the corpus spans num/int/real).

## Read first

- `.agent-files/PLAN_phase_5.md` §8 item 7 (the spec, incl.
  expected-failure accounting), §11 (performance risk / time
  budgets).
- `.agent-files/sources/README` (or equivalent index) — the vendored
  sources convention and the pinned commit `f7e02b7e1f31`.
- How existing selftests use `HOLSELFTESTLEVEL` (grep
  `src/auto/*/selftest.sml` and `testutils`).

## Work items

1. Vendor Isabelle's `src/HOL/ex/Arith_Examples.thy` at pinned
   commit `f7e02b7e1f31` into `.agent-files/sources/` with a README
   row (note: the vendored copy lives under the gitignored
   `.agent-files/sources` convention used by the plan — follow the
   existing README/sources layout exactly as prior phases did; the
   *translations* land in the repo, the vendored `.thy` follows
   whatever convention existing `sources/` files use).
2. Translate its goal corpus into a strength suite in the core
   `selftest.sml` (and/or the instances selftest for goals needing
   int/real — place each goal where its types build), gated behind
   `HOLSELFTESTLEVEL >= 2`:
   - each Isabelle `arith`-provable goal asserted provable by
     `LINARITH_TAC` (via `Tactical.VALID`);
   - known-incomplete goals (genuine integer-divisibility reasoning
     beyond discreteness — the documented `fast_lin_arith`
     incompleteness) asserted as *expected failures* with the
     failure message/comment citing `intLib.ARITH_TAC`/`COOPER_TAC`
     as the remedy (D55/D57 accounting);
   - suite-level count + time-budget assertions (benchmark style —
     no goal pruning; pick budgets generously above observed times
     and record observed times in a comment).
3. If any corpus goal exposes a genuine strength gap that upstream
   `arith` closes (not in the documented-incompleteness class), fix
   the underlying engine/preprocessing issue rather than reclassify
   the goal — that is the point of the suite.  If a fix is too large
   for this task's scope, record it precisely in the test file as a
   marked known-gap with rationale, and flag it in PROGRESS.md's
   completion-log line for the maintainer.

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; with
  `HOLSELFTESTLEVEL=2` both selftest suites run the strength corpus
  and pass (expected failures failing as expected).
- Every corpus goal is present (count assertion matches the vendored
  file's goal count) — no silent pruning.
- Style rules respected; commit the work.
