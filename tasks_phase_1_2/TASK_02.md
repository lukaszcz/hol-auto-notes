# TASK_02 — `clasetMeta`: the metavariable store (D21)

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

Plan T2 (§3.1): implement `clasetMeta.{sig,sml}` — the abstract,
persistent store of typed term/type metavariables with allow-sets —
plus its unit tests.

## Spec

Read first: `PLAN_phase_1_2.md` §3.1 and D21 (§0);
`src/1/FullUnify.{sig,sml}` (the `Env` representation,
`FullUnify.sml:22`, is the persistence model);
`.agent-files/research/phase12-classical-search-port.md` §6 (engine
requirements E1–E11, for what downstream consumers need).

1. Implement exactly the §3.1 API sketch (`meta`, `tymeta`, `store`,
   `empty`, `new_meta`, `new_tymeta`, `bind`, `bind_ty`, `walk`,
   `norm`, `metas_of`, `is_meta`, `ground`, `collapse`).  Adjust
   names/types only where SML forces it; keep the API abstract — the
   representation must stay swappable (D21).
2. Representation per §3.1: metavariables are fresh free variables
   with a reserved name prefix (`Term.genvar`-derived), occurring as
   leaves; `is_meta` recognizes them.  `bind` enforces the occurs
   check and `free eigenvariables of t ⊆ allow(?m)`; goal frees of the
   user's goal are always permitted (they are not eigenvariables).
3. Type metavariables: marked type variables, freshened per rule
   application; no allow-sets at the type level.
4. Store is persistent (`Redblackmap`-based); `walk` chases bindings
   lazily, `norm` produces the full βη normal form under the store.
5. `ground` (M-e5): leftover type metavariables ↦ `bool`, then
   leftover term metavariables ↦ `ARB` at their now-ground types;
   deterministic.  `collapse` produces `INST_TY_TERM`-shaped
   substitutions à la `FullUnify.collapse`.
6. Unit tests in `selftest.sml`: create/bind/walk/norm round-trips,
   occurs-check and allow-set `bind` refusals, persistence (an old
   store unaffected by later binds), `ground` determinism, `collapse`
   applied via `Drule.INST_TY_TERM`.

Note: the API is frozen at Phase-2 completion (§11); design for the
consumers in §3.2–§3.6 but implement only what §3.1 lists.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns.
4. Moscow-ML-portable SML (no Poly/ML-isms).

## Dependencies

TASK_01.
