# TASK_06 — `clasetRules` part 2: the five preprocessing derived rules

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  Isabelle preprocesses every declared
rule with meta-level resolution (swap, dup, make-elim, classical repair);
HOL4 has no meta-level, so each becomes a derived rule built from primitive
kernel inferences.  This is the riskiest kernel-level code in Phase 0
(plan §10 risk 1) — golden tests come first.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §5.3 — the authoritative spec, with the
  exact input/output theorem shapes for each of the five rules and the
  kind-dispatched assembly table.
- `.agent-files/sources/src/Provers/classical.ML`: `:150–169`
  (`classical_rule`), `:174–175` (`flat_rule`), `:195–201` (swap),
  `:216` (`dup_intr`), `:218–220` (`dup_elim`), `:286–314` (errors and
  warnings), `:323–334` (netpair routing classification), `:348–368`
  (`ext_info`).
- `.agent-files/sources/src/Pure/bires.ML:149` (`make_elim`).
- TASK_05's `clasetRules` slice (canonical form, types) — build on it.

## Deliverables

Extend `src/auto/rules/clasetRules.{sig,sml}` with:

1. The five derived rules, implemented by primitive inference only
   (UNDISCH/DISCH/SPEC/GEN/PROVE_HYP, `CCONTR`, excluded-middle case
   split) — **no tactic proofs**, so per-rule cost is a fixed handful of
   kernel inferences.  Inputs are in canonical form (plan §5.2):
   - `MAKE_ELIM_RULE` (dest → elim): add fresh `r` and `(B ==> r) ==> r`.
   - `CLASSICAL_RULE` (weak-elim repair): for variable-conclusion elims,
     add `~r` to every premise whose conclusion is not `r`; return input
     unchanged (α-equivalence check) if nothing changed.  Derivation:
     case split on `r`.
   - `SWAP_INTRO_RULE`: intro → elim-form swap
     (`!xs r. ~C ==> (~r ==> A1) ==> … ==> r`); returns NONE when the
     swap adds nothing (negation-/variable-headed `C`); fix the exact
     guard during implementation against Isabelle's behavior on the seed
     corpus (plan §5.3 item 3).
   - `DUP_INTRO_RULE`: γ-retention form
     (`(~C ==> A1) ==> … ==> C`).
   - `DUP_ELIM_RULE`: re-add the major premise as a hypothesis of every
     non-major premise.
   Respect plan §10 risk 1: operate on the canonical spine only; never
   descend into premise-internal binders.
2. Kind-dispatched assembly — the `ext_info` port (plan §5.3 table):
   compute stored `rl`/`dup_rl` per (kind, safety); classification of
   safe rules into 0-subgoal (`safe0`) vs branching (`safep`); Isabelle's
   error messages for ill-formed inputs (premise-free elims,
   un-duplicable intros), warning + no-op for duplicates, warning for
   cross-kind re-declaration.
3. **Golden selftests** in `src/auto/rules/selftest.sml` (plan §5.3, §8
   group 3) — write these first:
   - an `injD`-analogue (`|- inj f ==> f x = f y ==> x = y` over a
     locally defined `inj`) run through dest-declaration must produce
     exactly the repaired elim of `classical.ML:139–148`;
   - swap/dup outputs for `AND_INTRO_THM`-style intros, a classical-disj
     intro, and an exists intro compared against hand-proved expected
     theorems (α-equivalence);
   - rejection cases: premise-free elim raises the specified error;
     duplicate declaration warns and no-ops.

## Constraints

- Moscow-ML-compatible SML; derived rules must be pure kernel-inference
  code (declaration/load-time cost matters — plan §10 risk 3).
- Style: no tabs, no trailing whitespace, < 80 columns.

## Acceptance criteria

- All golden tests pass; all previously passing selftests still pass;
  `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_05 (rule model + canonical form).
