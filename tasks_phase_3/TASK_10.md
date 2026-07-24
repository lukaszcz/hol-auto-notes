# TASK_10 — `[iff]` decision tree + `Iff` marker wiring

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phase 3
(`.agent-files/PLAN_phase_3.md`) ports Isabelle's clasimp layer
(`Provers/clasimp.ML`) into `src/auto/clasimp/` on top of the delivered
classical stack (`src/auto/rules`, `src/auto/classical`,
`src/auto/blast`) and the Phase-S simplifier: the clasimpset,
simp-wrapper combinators, `AUTO_TAC`/`FORCE_TAC`/`FASTFORCE_TAC`/
`SLOWSIMP_TAC`/`BESTSIMP_TAC`/`CLARSIMP_TAC` with context-explicit
`CS_*` forms, the `[iff]` attribute, `Simp`/`Iff` markers, and the
layer-wide plain-theorem insertion convention (D30).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

First half of plan task 10 (`PLAN_phase_3.md` §8.1): the iff decision
tree — one function shared by the attribute (TASK_11), the `Iff`
marker (wired here) and the TypeBase hook (TASK_12) — plus per-
invocation `Iff` support in the argument processor.

## Spec

Read first: `PLAN_phase_3.md` §8.1, §0.1 (D29); `clasetRules.sig:32–37`
(rule kit); `clasimp.ML:87–98` semantics as summarized in §1.1.2 and
`research/phase3-isabelle-clasimp.md`.

1. The decision tree, for `th` normalized by `SPEC_ALL`; `n` =
   antecedent count of the implicational form; `safe = (n = 0)`,
   uniformly across all branches:

   | Conclusion | Claset contribution | Simpset contribution |
   |---|---|---|
   | `A ⇔ B` | intro = iffD2-half, dest = iffD1-half (dest, **not** elim), major premise rotated first; both safe iff `n = 0` | `th` as rewrite |
   | `¬A` | elim via the `NOT_ELIM` composition; safe iff `n = 0` | `th` (→ `A = F`) |
   | other `A` | intro = `th`; safe iff `n = 0` | `th` (→ `A = T`) |

   The simpset add happens in **every** branch.  Derivations use the
   delivered `clasetRules` kit plus `EQ_IMP_RULE`; swapped/dup
   variants arise inside `clasetLib.add_*` as for any rule.  No
   `iff?` analogue, no unsafe-only variant.
2. Wire `Iff th` in the TASK_07 argument processor: apply the decision
   tree to the temporary claset *and* temporary simpset pair only (no
   persistence), replacing the TASK_07 hook-point error.
3. Selftests (§10.5 first half): derivation-table cases — all six
   shape × conditional (`n = 0` / `n > 0`) combinations, asserting
   safe-vs-unsafe placement and both stores' contributions; an
   `Iff th` per-invocation test through a clasimp tactic (goal
   solvable only with the temporary iff, and no persistent state left
   behind afterwards).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on `src/auto/clasimp/`.
4. The decision tree is one exported-within-the-module function usable
   by TASK_11's hook and TASK_12's TypeBase contribution.

## Dependencies

TASK_07 (argument processor with the `Iff` hook point).
