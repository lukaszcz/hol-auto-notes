# TASK_10 — `clasetStep` unify mode: inst/unsafe/dup steps

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phases
1–2 (`.agent-files/PLAN_phase_1_2.md`) build the classical reasoner in
`src/auto/classical/` and `src/auto/blast/` on top of the Phase-0
claset infrastructure (`src/auto/rules/`): a shared typed-metavariable
search engine (store, unifier, goals, step cascade, replay, drivers),
public tactics `SAFE_TAC`/`CLARIFY_TAC`/`FAST_TAC`/…/`DEEPEN_TAC`,
and a faithful port of Isabelle's blast (`BLAST_TAC`).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T10 (§3.4, unify-mode slice): extend `clasetStep` with
`inst0_step`/`instp_step`/`inst_step`/`unsafe_step`/`dup_step`,
`step`/`slow_step`, `depth_step`, the M-c3 metavariable path, and the
engine-internal hyp-subst step for metavariable nodes.

## Spec

Read first: `PLAN_phase_1_2.md` §3.4 (inst0 onward), D24 (§0),
M-c3/M-c6/M-e8 (§7); `.agent-files/research/
phase12-classical-search-port.md` §3 (`classical.ML:633–655,
708–720`); `.agent-files/sources/src/Provers/classical.ML:633–732`;
`.agent-files/sources/src/Provers/hypsubst.ML:83–104`.

1. `inst0_step`/`instp_step`/`inst_step`/`unsafe_step`/`dup_step`:
   the cascade operations over safe0/safep/unsafe/dup parts in unify
   mode (Phase-0 `unify_*_candidates` lookups); `assume` = unify `w`
   against each assumption; `contr` = elim-resolve the `NOT_ELIM_THM`
   shape then assume; APPEND-composition preserving alternatives
   exactly as upstream.
2. M-c3 unify path: candidates with premise-occurring unfixed rule
   variables now simply create metavariables.
3. Engine-internal hyp-subst for metavariable nodes (M-c6): eliminate
   a Free/param side (never a metavariable), occurs check,
   metavariable-tolerant RHS (`hypsubst.ML:83–104` transposed),
   substitute through the goal; wired into the existing slot switch
   from TASK_05.
4. `step`/`slow_step` (M-e8): whole-node safe saturation first (safe
   steps act on ALL goals; the unsafe rung on the selected goal —
   encoded in the expansion function), then the uwrapper-transformed
   `inst_step ORELSE unsafe_step` (fast) vs `… APPEND …` (slow).
5. `depth_step m` (`classical.ML:712–720`): safe saturation THEN_ELSE
   same-bound recursion, else `inst0` (un-wrapped) APPEND (if `m > 0`)
   the uwrapper-transformed `instp APPEND dup_or_unsafe` costing one
   bound unit; parameterized by the unsafe-netpair choice (Phase 3's
   `nodup` reuse hook).
6. Uwrapper application points per D24: around the inst+unsafe rung,
   NOT around `depth_step`'s `inst0` closers; call through the
   `clasetGoal` render/unrender API (still a stub for metavariable
   nodes — completed in TASK_12; keep the call sites final).
7. Step records: same placeholder discipline as TASK_05 (finalized in
   TASK_11); record created metavariables per step (§3.5 item 3).
8. Unit tests: unify-mode application creating metavariables
   (EXISTS-style rule applies, leaves a metavariable); assume-step
   unifying `w` with an assumption; APPEND alternative order; dup
   vs unsafe parameterization of `depth_step`.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Phase-1 exports (TASK_06 tactics) unchanged in behavior (existing
   selftests untouched and green).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_09 (Phase-1 boundary; technical prerequisites are TASK_05 + 03).
