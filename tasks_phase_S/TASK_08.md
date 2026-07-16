# TASK_08 — `SPLIT_ASM_TAC` (assumption splits)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; its centerpiece is a port of Isabelle's splitter.  This
task adds the assumption-side splits (Isabelle's `split_asm`).  Governing
constraint: **all defaults preserve current behavior**.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T7 (§6.3): `SPLIT_ASM_TAC : thm list -> tactic` in splitLib, and the
asm-rule leg of `SPLIT_TAC`.

## Spec

Read PLAN_phase_S §6.3, §6.4 (the `SPLIT_TAC` signature: concl rules
first, then asm rules, `CHANGED`), §11.2, and
`.agent-files/research/phaseS-isabelle-splitter.md` §4.3, §5.9.  Isabelle
original: `.agent-files/sources/src/Provers/splitter.ML` (~394–401 for
assumption selection).

1. Select the first assumption containing a key constant of an
   asm-variant rule (syntactic occurrence — matching Isabelle's selection
   and its documented limitations).
2. Instantiate the asm rule against the negated assumption to derive
   `|- A = (Q1 /\ A1) \/ … \/ (Qk /\ Ak)`; clean double negations
   introduced by context instantiation with
   `NOT_CLAUSES`/`DE_MORGAN_THM` (report §5.9 — without this every asm
   split leaves `¬¬` junk).
3. Pop the assumption and
   `STRIP_ASSUME_TAC (EQ_MP eq (ASSUME A))` — one subgoal per case with
   case condition and instantiated hypothesis assumed (assumption
   proliferation is inherent and matches Isabelle).
4. Extend `SPLIT_TAC` to the full §6.4 semantics: one step — concl rules
   first, then asm rules; `CHANGED`; clean `HOL_ERR` on inapplicability.
5. **Selftests** (§8 group 6, asm part): asm splits for `if` and a
   datatype case (`list`/`option`) in an assumption; verify no `¬¬`
   residue in any produced subgoal; case rules routed automatically by
   rhs shape; `SPLIT_TAC` order (concl before asm); failure when nothing
   splits.

## Acceptance criteria

1. New asm-split selftests pass; all existing selftests still pass.
2. `SPLIT_ASM_TAC`/`SPLIT_TAC` match the §6.4 signatures (frozen at
   phase completion, §12).
3. `bin/build -t --seq=tools/sequences/upto-parallel` green.
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_07.
