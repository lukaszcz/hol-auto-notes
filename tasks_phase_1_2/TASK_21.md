# TASK_21 — BLAST reconstruction on the engine (D23, §6.5)

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

Plan T19 (§6.5): replay blast's recorded script on the classical
engine's states — including the engine hyp-subst step's blast
contract (`blast_hyp_subst_tac` semantics) — with PROOF-FAILED
backtracking into the tableau.

## Spec

Read first: `PLAN_phase_1_2.md` §6.5, D23 (§0), M-c/M-f (§7);
`.agent-files/research/phase12-blast-port.md` §6 (six-tactic
vocabulary, replay-instantiation analysis) and §8-J(ii);
`.agent-files/sources/src/Provers/hypsubst.ML:233–282`;
`.agent-files/sources/src/Provers/blast.ML:767, 1254–1277`;
`src/auto/classical/clasetReplay.sig` (the shared vocabulary from
TASK_11).

1. Initialize an engine node from the real HOL4 goal; replay the
   recorded script left-to-right, steps genuinely resolving and
   instantiating typed metavariables (unify mode); grounding once at
   the end via the engine's kernel replay.  No untyped→typed
   back-translation, no Skolem↔variable registry.
2. Vocabulary mapping per §6.5: T2/T3 ⇒ engine assume/contradiction
   steps; T4/T6 ⇒ engine rule application (original stored theorem or
   `REV_DUP_ELIM_RULE`d variant) with premise-prefix strip via
   built-ins; γ-duplicate major moved to the back of `asl` (the one
   remaining reorder); T5 ⇒ engine `CCONTR` step, negation consed at
   front.
3. T1 ⇒ the engine hyp-subst step in its blast-contract form
   (`blast_hyp_subst_tac`): first suitable equality, Free/Skolem
   side, occurs check, orientation; substitute through the goal;
   affected assumptions move to the front in original relative order
   (affectedness = `aconv`-after-substitution, M-f); equation
   consumed.  This is an engine-side addition (classical directory);
   plain `VAR_EQ_TAC` is NOT used here.
4. Failure anywhere along this path (typed unification, grounding,
   kernel replay) raises back into `prv`'s choice stack via the
   TASK_20 hook — `PROOF FAILED for depth n` at trace level 1, then
   backtracking (`blast.ML:1254–1277`; the `nbrs = 1` pruning guard
   keeps a resume point).
5. Unit tests: end-to-end on golden goals (search + reconstruction ⇒
   `Tactical.VALID` theorem) covering each of T1–T6, incl. a
   γ-duplication goal and an equality-reordering goal; a crafted
   PROOF-FAILED → backtrack → success case; a clean-failure case.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/blast/` (and
   `src/auto/classical/` if the hyp-subst step addition touches it).
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Every reconstruction success is `Tactical.VALID`-checked; the
   backtrack path is exercised by a test.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_12 (replay + materialization final), TASK_20.
