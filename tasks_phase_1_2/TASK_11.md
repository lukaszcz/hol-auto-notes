# TASK_11 — `clasetReplay`: records, grounding, replay vocabulary

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

Plan T11, first half (§3.5): implement `clasetReplay.{sig,sml}` —
the finalized step-record type, the grounding pass, the zero-search
kernel replay, the failure policy, and the shared replay-step
vocabulary blast will consume.  (The D24 wrapper render/lift-back
completion is TASK_12.)

## Spec

Read first: `PLAN_phase_1_2.md` §3.5, D23 (§0), M-e5/M-e6/M-c (§7);
`.agent-files/research/phase12-classical-search-port.md` §6.6
(zero-search replay); `.agent-files/research/phase12-blast-port.md`
§8-J(ii) (vocabulary requirements); `.agent-files/research/
phase12-hol4-substrate.md` §6.2 (no move-to-back tactic in-tree).

1. Finalize the tree-structured step-record type (one node per goal)
   with §3.5 items 1–4: step kind (rule application: original stored
   theorem, variant plain/swapped/dup/make-elim, elim flag; or
   built-in: assume-close k / contradiction (k,l) / mp / hyp-subst /
   DISCH / GEN / wrapper), target goal position, consumed assumption
   position for elims, metavariables created, eigenvariable names.
   Retrofit TASK_05/TASK_10's placeholder records to this type.
2. Grounding + emission: at search success, `clasetMeta.ground` the
   store, read each step's final instantiations, emit the replay
   tactic sequence — rules via explicit instantiation
   (`INST_TY_TERM`ed theorem + match against the determined position;
   `EXISTS_TAC`-style witnesses; `GEN`/`DISCH` for built-ins).
3. Failure policy (M-e6): hard diagnostic error for classical drivers
   (goal, step, script dump at trace level >= 1); ALSO exposed as a
   catchable outcome for blast's backtrack loop (D23).
4. Shared replay-step vocabulary (consumed by blast reconstruction,
   §3.5 last paragraph): rule application with premise-prefix strip,
   assumption/contradiction closers, hyp-subst step, goal-negation
   (`CCONTR`) step, and move-assumption-to-back (validation-trivial
   list operation).
5. Unit tests: record a small match-mode + unify-mode derivation by
   hand (via clasetStep), ground, replay through `Tactical.VALID`;
   grounding determinism; move-to-back validation round-trip; the
   catchable-failure path (feed a corrupted script, assert catchable
   error, not crash).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Replay of every test derivation validates via `Tactical.VALID`.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_10.
