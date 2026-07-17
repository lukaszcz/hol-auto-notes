# TASK_05 — `clasetStep` match mode: safe/clarify cascade (D22)

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

Plan T5 (§3.4, match-mode slice): implement `clasetStep.{sig,sml}` —
the one step cascade — for the Phase-1 steps: `safe_step`,
`clarify_step`, built-in DISCH/GEN intro steps, the hyp-subst slot,
safe-wrapper application, with per-step `(goals, validation)` emission
on metavariable-free nodes (D22).  Unify-mode steps (`inst*`/`unsafe`/
`dup`/`step`/`depth_step`) are TASK_10 — design the types so they slot
in without reshaping.

## Spec

Read first: `PLAN_phase_1_2.md` §3.4, D22 (§0), M-c2/M-c3/M-c6/M-c9/
M-c10 (§7); `.agent-files/research/phase12-classical-search-port.md`
§3 (line-by-line semantics of `classical.ML:578–732`);
`.agent-files/sources/src/Provers/classical.ML:578–625`;
`.agent-files/research/phase12-hol4-substrate.md` §5.10 (`VAR_EQ_TAC`
vs `hypsubst.ML`); `src/auto/rules/clasetLib.{sig,sml}` (candidate
lookups, wrappers, `claset_config`).

1. Step type: `node * goalpos -> (step_record * node) seq` (lazy
   alternatives); `step_record` is a placeholder type here, finalized
   in TASK_11 — record enough per §3.5 items 1–2/4 (step kind, target
   position, consumed assumption position, eigenvariable names) plus
   the per-step kernel validation (D22).
2. Candidates come exclusively from the frozen Phase-0 `match_*`
   lookups, tag-sorted, with adjacent-equal-tag dedup at the consumer
   (M-c9, `untag_list` semantics).
3. `safe_step` = FIRST-of-five under safe wrappers, per §3.4:
   (1) assumption close (M-c2: `aconv` after βη — one shared closing
   primitive); (2) `eq_mp` step (M-c10: `~`/`==>` shapes only);
   (3) safe0 by matching; (3½) built-in DISCH/GEN steps, tag-ordered
   as the oldest weight-1 candidates; (4) hyp-subst slot; (5) safep by
   matching.
4. Hyp-subst slot (M-c6): saturating `REPEAT_DETERM1`-style over
   `claset_config.hyp_subst_tac` (`BasicProvers.VAR_EQ_TAC` as
   delivered, extras kept).  The engine-internal metavariable-node
   variant is TASK_10 material; leave the switch point in place.
5. `clarify_step` per §3.4: slot (2) dropped; safep restricted to
   weight-1 plus the `bimatch2_tac` weight-2 acceptance (the
   one-child-closes check distributes over candidates; non-closing
   applications backtracked away).
6. M-c3 (match mode): skip candidates leaving rule variables
   uninstantiated in premises, with a trace-level notice; ground
   premise-absent leftovers with `ARB`.
7. Safe wrappers (swrappers) applied inside every safe step at
   Isabelle's points (D24; on metavariable-free nodes wrappers are
   plain ntactic wrappers per D22 — use `clasetGoal.render`/
   `unrender` for the metavariable-free case delivered by TASK_04).
8. Per-step validation emission (D22): on metavariable-free nodes each
   step carries its kernel validation so Phase-1 exports are genuine
   `NTactical.ntactic`s.
9. Unit tests in `selftest.sml`: cascade slot order on a crafted
   claset (each slot fires exactly when earlier ones cannot); M-c2
   βη-closing; `bimatch2` accept/reject; M-c3 skip notice; validations
   check via `Tactical.VALID` on materialized goals.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. No changes to frozen Phase-0 interfaces (`src/auto/rules`).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_04.
