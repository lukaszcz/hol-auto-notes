# TASK_18 — `src/auto/blast/` skeleton + `blastTerm` (§6.1)

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

Plan T16 (+ the blast half of §2's build wiring): create
`src/auto/blast/` (Holmakefile, sequence + `SRCRELNAMES` entries) and
implement `blastTerm.{sig,sml}` — prototerms, trail, destructive
unification — with unit tests.

## Spec

Read first: `PLAN_phase_1_2.md` §2, §6.1, D3-related notes in D21/D23
(§0), M-k (§7); `.agent-files/research/phase12-blast-port.md` §2–§3
(term language, unification); `.agent-files/sources/src/Provers/
blast.ML:84–381` (the code being ported).

1. Skeleton: `src/auto/blast/Holmakefile` (HOLHEAP as classical's;
   INCLUDES `src/auto/rules` and `src/auto/classical`); add
   `src/auto/blast` to `tools/sequences/upto-auto` (after
   `src/auto/classical`) and to `SRCRELNAMES` in
   `src/parallel_builds/core/Holmakefile`; empty `selftest.sml`
   scaffold.
2. `blastTerm` faithful to `blast.ML`: the seven-constructor
   prototerm datatype with destructive `Var` refs + trail/`clearTo`
   (`:84–111, 343–348`); Skolem args-as-dependency-lists with the
   eigenvariable condition via the occurs check (`:323–338`);
   de Bruijn kit; `norm`/`wkNorm` β/η (`:289–320`); full `unify`
   incl. the rule-local-vars/off-trail subtlety (`:355–381`).
3. Reserved heads (M-k): pseudo-constants `*Goal*`/`*False*` keep
   their Isabelle names; encoded real constants use fully-qualified
   `"thy$name"`; no runtime ancestry check.
4. The destructive representation is PRIVATE to blast (document in
   the sig; the classical engine's persistent store must never mix
   with the trail regime).
5. Unit tests in `selftest.sml`: unification golden cases ported
   from the report's analysis — occurs-check refusals, Skolem
   dependency violations, trail rollback (`clearTo` restores),
   `wkNorm`/`norm` cases, the off-trail rule-local-var case.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green (now
   including the blast directory).
3. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_09 (Phase-2 start; independent of TASK_10–17 — can run in
parallel).
