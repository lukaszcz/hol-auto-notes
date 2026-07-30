# TASK_08 — `linarithLib` part 1: core surface (`SIMPLE_LINARITH_TAC`, `PROVE`, `CONV`), num registration

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

TASK_07 (full replay module).

## Read first

- `.agent-files/PLAN_phase_5.md` §0 (D62), §4.5, §5 (only to know
  what is deliberately NOT in this task: pipeline steps 3–5 and
  `LINARITH_TAC`/`CFG_` are TASK_09), §8 items 4 and 6 (partial).
- `.agent-files/sources/src/Provers/Arith/fast_lin_arith.ML:803–817`
  (simproc contract for `LINARITH_CONV`'s two attempts) and
  `.agent-files/sources/src/HOL/Tools/lin_arith.ML:851` (`simple_tac`).
- `src/auto/claset/clasetLib.sig` — `INSERT_FACTS_TAC`,
  `classify_simp_args` (D30/D42) and `clasetLib.sml:1179–1205`
  (`check_aesop_markers` rejection precedent).
- All landed linarith sigs.

## Work items

Create `src/auto/linarith/linarithLib.sml` + `.sig` (this task
delivers the no-preprocessing surface; `LINARITH_TAC`/`CFG_` +
pipeline are TASK_09):

1. `SIMPLE_LINARITH_TAC : thm list -> tactic` per §4.5: insert
   `arith_facts()` then argument facts (`INSERT_FACTS_TAC`, D30 —
   recorded deviation from upstream `simple_tac`, which inserts
   nothing); negate conclusion into premises (upstream `neg_prop`
   shape — conclusion `¬t` adds `t`, no double negation); NO
   operator splitting; `≠`-split + FM + tactic replay via the
   engine.  Fails with `HOL_ERR` if any case lacks a certificate.
2. Argument processing shared with TASK_09's tactics: plain
   theorems = facts; `Split th` marker type = per-invocation split
   rule (validated with the P-form check; used only by the full
   tactic — `SIMPLE_` rejects it or ignores? Reject loudly:
   `SIMPLE_LINARITH_TAC` does no splitting, so a `Split` argument is
   a user error); claset markers (`Intro`…), `Simp`, `Iff`, aesop
   markers rejected loudly, message naming the tactic
   (`check_aesop_markers` precedent).
3. `LINARITH_PROVE : term -> thm`: forward path on the term alone
   (universal closure stripped, implications hoisted as premises);
   returns `|- tm`.  `LINARITH_CONV : conv`: prove-or-disprove to
   `|- tm = T` / `|- tm = F` (the upstream simproc's two attempts,
   including premise atomization by `CONJUNCTS`).
4. Error surface: entry points whose goal's outer relation is over
   an unregistered carrier fail with
   `no linarith instance for :ty (load intLinarith / realLinarith /
   ratLinarith?)`.
5. Register the num instance (record from TASK_05) and its (empty)
   injection set at module load; remove any temporary local
   registration the earlier selftests did.
6. Selftests: forward forms incl. disproof (§8 item 4);
   `SIMPLE_LINARITH_TAC` on discreteness and `≠`-split goals;
   negative tests from §8 item 6 that apply now — nonlinear goals
   fail cleanly, unregistered-type message text, no state leaked on
   failure (registry/sets unchanged); marker rejection.  Successes
   through `Tactical.VALID`.

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; new tests
  pass.
- `.sig` names match the D62/§12 freeze list for the delivered
  subset (`SIMPLE_LINARITH_TAC`, `LINARITH_PROVE`, `LINARITH_CONV`);
  `LINARITH_TAC`/`CFG_LINARITH_TAC`/`LINARITH_ss`/solver are absent
  for now (TASK_09/TASK_10 extend the same module).
- Style rules respected; commit the work.
