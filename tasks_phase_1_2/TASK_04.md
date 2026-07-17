# TASK_04 — `clasetGoal`: engine goals, nodes, intake, child shape

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

Plan T4 (§3.3): implement `clasetGoal.{sig,sml}` — `cgoal`/`node`
types, HOL4-goal intake, child-goal shape from rule premises, elim
consumption, size, node equality/ordering, and a render/unrender STUB
(completed in TASK_12).  Also apply the sanctioned Phase-0 amendment
correcting `claset_config.size_of` (§11.1).

## Spec

Read first: `PLAN_phase_1_2.md` §3.3, M-c4/M-c5/M-e4/M-e7/M-e9/M-m
(§7), §11.1; `.agent-files/research/phase12-classical-search-port.md`
§1 (intake/atomize) and the lifting-semantics analysis (around
`thm.ML:2536–2543`); `.agent-files/sources/src/Pure/search.ML:160–164`
(heap-ordering model); `src/auto/rules/clasetLib.{sig,sml}` (for
`claset_config`).

1. `cgoal = {params, asl, w}` and abstract `node` per the §3.3 sketch
   (ordered `cgoal list`, `clasetMeta.store`, replay-script slot —
   an abstract placeholder type until TASK_11 — size cache, creation
   level, per-subtree binding marks for D25).
2. Intake (M-e7): `(asl, w)` seeds a single-goal node, `params = []`,
   empty store, `asl` head-first; markerLib material carried opaquely
   (M-m; document in the sig).
3. New assumptions cons at the FRONT (M-c4/M-d).
4. Elim consumption (M-c5): assumptions enumerated in list order as
   alternatives; consumed position deleted from every child.
5. Child-goal shape (M-c4, Isabelle lifting): eager strip of a
   premise's outer `!`/`==>` prefix; fresh eigenvariables named by
   `variant` of the rule's bound names, extending `params` and
   downstream allow-sets; stripped antecedents consed onto `asl`;
   nested structure below the prefix stays.
6. Materialization (D24): `render : node -> int -> goal` showing
   metavariables as their marked frees; `unrender` lifting a
   `(goal list, validation)` back.  STUB acceptable here: `render`
   should work for metavariable-free nodes (Phase 1 needs it);
   full metavariable round-trip + validation recording is TASK_12.
7. Size (M-e9): atoms + abstractions under the current substitution
   (Isabelle `size_of_term`, `term.ML:467–473`; applications add
   nothing).  Correct the Phase-0 `claset_config.size_of` default in
   `src/auto/rules` to this count (sanctioned amendment §11.1; no
   consumer exists yet, so behavior-neutral).
8. Node equality/ordering (M-e4): α-comparison of substituted goal
   lists with a size prefilter; heap tiebreak = (size, `Term.compare`
   on a canonical rendering).
9. Unit tests in `selftest.sml`: intake shape, child-shape stripping
   (incl. nested-prefix non-stripping), elim positional deletion,
   front-cons order, size on golden terms (β under bindings), node
   equality/ordering, render on a metavariable-free node.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/classical/`; the
   `src/auto/rules` selftest still passes after the size_of change.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. No Phase-0 interface changes beyond the §11.1 size_of default.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_03 (store + unifier available; node carries the store).
