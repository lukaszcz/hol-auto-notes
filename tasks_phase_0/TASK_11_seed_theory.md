# TASK_11 — `clasetSeedScript.sml`: seed theory (HOL.thy parity)

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  This task seeds it with the
base-logic rule corpus matching Isabelle's `HOL.thy:869–904` declarations,
so the Phase 1+ engines start from strength parity on the propositional/
quantifier core.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §7 — the authoritative spec, including
  both tables (existing theorems to declare; fresh theorems to prove) and
  the faithful-semantics note on `impI`/`allI`/`exE` (built-in Phase 1
  steps, deliberately not theorems — do not try to add them).
- `.agent-files/sources/src/HOL/HOL.thy:869–904` — the parity target.
- `src/bool/boolScript.sml` for the cited existing theorems (`EQ_REFL`,
  `TRUTH`, `IMP_ANTISYM_AX`, `IMP_F`, `AND_INTRO_THM`, `FALSITY`,
  `OR_ELIM_THM`, `EQ_EXT`).
- TASK_08's `export_rule` and attributes — this script is their first
  real client.

## Deliverables

1. `src/auto/rules/clasetSeedScript.sml`:
   - declares the eight existing `boolTheory` theorems via
     `clasetLib.export_rule` with the kinds in the plan §7 table
     (refl/TrueI/iffI/notI/conjI → sintro; FalseE/disjE → selim;
     ext → unsafe intro);
   - proves the eleven fresh theorems of the second table
     (`DISJ_CINTRO_THM`, `CONJ_ELIM_THM`, `IMP_CELIM_THM`,
     `IFF_CELIM_THM`, `EXISTS_ELIM_THM`, `EX1_ELIM_THM`,
     `EXISTS_INTRO_THM`, `EX1_INTRO_THM`, `EX_EX1_INTRO_THM`,
     `FORALL_ELIM_THM`, `NOT_ELIM_THM`) with the exact statements given,
     each a short tactic proof, with the attribute directly on the
     `Theorem` where the table declares one (`NOT_ELIM_THM` is support
     only — proved but not declared);
   - hosts **nothing else**: per-theory corpora (`pair`, `list`, …) are
     Phase 8 and would violate the §2 stratification.
2. Selftest additions: after loading the seed theory, `the_claset()`
   contains all declared rules with the right kinds and canonical order;
   the load-time budget check of plan §10 risk 3 (fail if seed-claset
   init exceeds a generous fixed budget).
3. Holmakefile updated as needed.

## Constraints

- Moscow-ML-compatible SML; dependencies per plan §2 (`boolTheory` etc.).
- Style: no tabs, no trailing whitespace, < 80 columns.
- Verify the fresh-theorem statements typecheck exactly as written in the
  plan; if a statement needs adjustment to be provable, flag it in your
  report rather than silently changing semantics.

## Acceptance criteria

- Theory builds; all selftests pass;
  `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_08 (persistence + attributes); TASK_06 (preprocessing must accept
  the whole seed corpus).
