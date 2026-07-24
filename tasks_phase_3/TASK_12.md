# TASK_12 — TypeBase completion: constructor intros (§9)

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

Plan task 11 (`PLAN_phase_3.md` §9): the TypeBase completion deferred
from Phase 0 — per-constructor safe intros derived from injectivity,
registered as a clasimp-owned TypeBase contribution.

## Spec

Read first: `PLAN_phase_3.md` §9; `clasetLib.sig:97`
(`register_tyinfo_contribution`, frozen — use as-is); the delivered
rules/ TypeBase hook as the pattern.

1. For each constructor `C`, add the safe intro
   `x₁ = y₁ ⇒ … ⇒ C x̄ = C ȳ` — exactly the intro halves that the
   `[iff]` treatment of injectivity yields (derive via the TASK_10
   decision-tree function or the same derivation path, so the two
   stay consistent).
2. `clasimpLib` registers its own TypeBase contribution via
   `clasetLib.register_tyinfo_contribution`: hook for datatypes
   defined after load + one-shot catch-up sweep over existing
   TypeBase entries, same pattern as the delivered rules/ hook.
3. Nothing already-seeded is duplicated (claset dedup by rule name):
   Phase 0's distinctness (safe elim) and injectivity (safe dest)
   seeds and the `srw_ss` datatype rewrites stay as they are.
4. Case-split theorems stay with `[split]` (Phase S); nchotomy/cases
   remain for the aesop cases-builder (Phase 4) — out of scope.
5. Selftests (§10.6): constructor intros present and usable for (a) a
   datatype defined *after* `clasimpLib` load (hook path) and (b) a
   pre-existing datatype (catch-up sweep path); a no-duplication check
   for an already-seeded rule name; a goal solvable by a clasimp/
   classical tactic only via the new intro.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/clasimp/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. `tools/h4pedant/h4pedant` clean on touched directories.
4. No duplicate claset entries for already-seeded rules.

## Dependencies

TASK_10 (shared derivation function).
