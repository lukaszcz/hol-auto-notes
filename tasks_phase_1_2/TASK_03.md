# TASK_03 — `clasetUnify`: the unifier + golden battery (D21)

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

Plan T3 (§3.2): implement `clasetUnify.{sig,sml}` — typed FO core +
pattern case + Lean-style heuristics, single-solution/deterministic,
with a match mode — and its golden selftest battery (§8.2.1).  This is
the plan's riskiest single module (§10.1): write the tests FIRST.

## Spec

Read first: `PLAN_phase_1_2.md` §3.2, D21 (§0), M-c1/M-c2 (§7),
§8.2.1, §10.1; `src/1/FullUnify.{sig,sml}` (the model:
`FullUnify.sig:21–23`, `FullUnify.sml:82–146`);
`.agent-files/research/phase12-hol4-substrate.md` (unification survey
section); for match mode, the `Envir.above smax` discussion in
`.agent-files/research/phase12-classical-search-port.md` (§3/§6) and
`.agent-files/sources/src/Pure/thm.ML:2503–2510`.

1. One algorithm, two modes, threading `clasetMeta.store`:
   - Typed FO core modeled on `FullUnify` (two-sided, integrated type
     unification, occurs check, rigid-var discipline), reworked so
     unknowns are `clasetMeta` metavariables and bindings go through
     `clasetMeta.bind`/`bind_ty` (allow-sets enforced there).
   - Pattern case per §3.2.1: `?m x1…xk ≟ t` with distinct
     eigenvariables ⇒ `bind (?m, λx̄.t)`; symmetric case; applied
     metavariable spines representable without new term language.
   - FO-approximation heuristic per §3.2.2 (equal-arity decompose;
     single solution, no enumeration).
   - η-handling per §3.2.3 (compare/normalize modulo η).
   - Match mode per §3.2.4: same algorithm, rejecting any binding of a
     metavariable (term or type) created before this rule application;
     `rule_metas` instantiate freely in both modes.
2. API: `unify : store -> {mode, rule_metas} -> term * term
   -> store option` (adjust concretely as needed) + a types-only
   entry.  Deterministic, single-solution.
3. Golden battery (§8.2.1) in `selftest.sml`, authored before the
   implementation: FO cases; pattern-case bindings incl. allow-set
   acceptance/violation; FO-approximation hits and principled
   failures; η cases; match-mode rejections of pre-existing-
   metavariable bindings; an oracle cross-check against `FullUnify`
   on the FO fragment (both succeed with α-equivalent results, or
   both fail — on a curated FO case list).

## Acceptance criteria

1. Golden battery passes; `Holmake` + `./selftest.exe` green in
   `src/auto/classical/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Unifier is deterministic (battery asserts unique results).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_02.
