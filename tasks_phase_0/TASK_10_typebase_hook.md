# TASK_10 — TypeBase hook + contribution registry

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  Isabelle's datatype package declares
classical rules automatically; this task gives HOL4 the equivalent — every
datatype's distinctness/injectivity facts feed the claset automatically,
via an extensible registry later phases reuse for `[iff]`/`[split]`
contributions.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §6.5 — the authoritative spec, including
  the refinement note (constructors-as-intros and case splits are
  deliberately *not* seeded here).
- `src/1/TypeBase.sig:23` (`register_update_fn`) and the listener pattern
  at `src/basicProof/BasicProvers.sml:1249`.
- `src/1/TypeBasePure.sig` (`distinct_of`, `one_one_of`, `elts`) —
  note both are option-valued/raise on non-datatype tyinfos.
- TASK_08's `init_state`/lazy-init seam — the catch-up sweep plugs in
  there.

## Deliverables

Extend `src/auto/rules/clasetLib.{sig,sml}`:

1. The registry (frozen interface, plan §11):
   ```sml
   val register_tyinfo_contribution :
       string * (TypeBasePure.tyinfo -> (rulespec * (string * thm)) list)
       -> unit
   ```
2. Phase 0's one contribution:
   - **distinctness** (`distinct_of`): each conjunct
     `|- ~(C1 xs = C2 ys)` (and its `GSYM`) becomes a safe 0-subgoal elim
     `|- C1 xs = C2 ys ==> r` (notE composition);
   - **injectivity** (`one_one_of`): `|- C xs = C ys <=> x1 = y1 /\ …`
     becomes the safe dest `|- C xs = C ys ==> x1 = y1 /\ …` (iffD1
     direction).
3. Plumbing: `TypeBase.register_update_fn (fn tyi => (add tyi; tyi))`;
   catch-up sweep over `TypeBase.elts()` inside `init_state`;
   non-datatype tyinfos handled with `Lib.total`.  Additions are
   value-level (not persisted deltas) and idempotent — statement-keyed
   dedup, silent — because the hook refires on theory reload.
4. Selftests (plan §8 group 7): define a small datatype in-process and
   check the distinct/inject rules appear in `the_claset()`; check the
   catch-up sweep covers a type defined *before* first claset demand;
   check reprocessing the same tyinfo does not duplicate.

## Constraints

- Moscow-ML-compatible SML; stratification per plan §2.
- Style: no tabs, no trailing whitespace, < 80 columns.
- Keep the registry general: later phases add `[iff]`/`[split]`
  contributions as further clients without a second hook.

## Acceptance criteria

- All new selftests pass; all previously passing selftests still pass;
  `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_08 (global state / `init_state`).
