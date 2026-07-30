# TASK_15 — Docfiles, consumer audit, phase gate

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

TASK_11 and TASK_14 (everything else landed).

## Read first

- `.agent-files/PLAN_phase_5.md` §9 (docfile list), §10 (T10), §12
  (freeze list — the audit checklist).
- Existing `.smd` docfiles in `help/Docfiles` for the format
  (grammar pragma, 72-hyphen rule, Failure/Example/See-also
  structure) — pick recent `auto`-layer ones as models (e.g. the
  aesop/claset docfiles).
- Memory note: a task-named mechanism may have been superseded by a
  later task — the audit must check each mechanism is *called*, not
  just present.

## Work items

1. Docfiles per §9: `linarithLib.smd` (structure overview incl. the
   attribute family and instance-loading story),
   `linarithLib.LINARITH_TAC.smd`, `.SIMPLE_LINARITH_TAC.smd`,
   `.CFG_LINARITH_TAC.smd`, `.LINARITH_PROVE.smd`,
   `.LINARITH_CONV.smd`, `.LINARITH_ss.smd`, `.linarith_solver.smd`,
   `.register_instance.smd`, `.arith.smd`, `.arith_split.smd`,
   `.remove_arith.smd` (covers both removers).  Verify examples
   actually run (paste into a scratch check via the selftest or a
   temporary script — but do NOT leave validation scripts in the
   tree; note the repo rule that piping into `bin/hol` is not the
   regression path, it is fine for docfile example sanity only).
2. Consumer audit (Phase-4 discipline): for every §12 freeze-list
   mechanism and every delivered internal mechanism (e.g.
   `divmod_facts`, `pre_split`, injections, `Split` marker,
   `remove_arith_split`, trace), verify a live consumer exists —
   called from shipped code or exercised by a selftest — and fix or
   remove anything dead.  Record the audit table in the commit
   message.
3. Phase gate: `bin/build -F -t` (full build with selftests) green.
   Budget time accordingly; run it in the background and monitor.
4. PLAN.md: record the phase-5 gate/status per §9/§11 of the phase
   plan (add the gate to PLAN.md §11's record).

## Acceptance criteria

- All 12 docfiles present, format-conformant, with working examples.
- Audit complete with no unconsumed mechanisms (or removed).
- `bin/build -F -t` green (the phase boundary), and
  `bin/build -t --seq=tools/sequences/upto-auto` green.
- PLAN.md gate recorded; no committed file references
  `.agent-files/`.
- Style rules respected; commit the work.
