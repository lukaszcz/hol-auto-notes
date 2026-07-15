# TASK_03 — `NTactical`: nondeterministic tactic combinators

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  Isabelle's classical reasoner is built
on lazy-sequence (backtracking) tactics; `NTactical` is the HOL4 analogue
of `Pure/tactical.ML` semantics and supplies the `wrapper` type used by
clasets and every later search engine (Phases 1–4).

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §3 and decision D13 (§0) — the
  authoritative spec, including the full signature to implement.
- `.agent-files/sources/src/Pure/tactical.ML` — semantics being ported
  (`THEN`, `ORELSE`, `APPEND`, `TRY`, `REPEAT`, `CHANGED`, `DETERM`).
- `src/portableML/seq.sig` and `src/portableML/seq.sml` — the lazy,
  memoizing sequence type used for results (`append` is lazy in both
  arguments, `seq.sml:41–44`).
- `src/1/Tactical.sml` — the `mapshape`-style validation plumbing that
  `NTHEN` must reuse; also `Tactical.VALID` for tests.
- `src/portableML/monads/seqmonad.sig` — shape template only; per plan §3
  it is deliberately **not** reused.

## Deliverables

1. `src/auto/rules/NTactical.sig` and `NTactical.sml` implementing exactly
   the signature in plan §3 (`nresult`, `ntactic`, `wrapper`, `LIFT`,
   `DETERM`, `NNO_TAC`, `NALL_TAC`, `NTHEN`, `NORELSE`, `NAPPEND`, `NTRY`,
   `NREPEAT`, `NCHANGED`, `NFIRST`, `nEVERY`), with the design notes of §3
   respected:
   - `NTHEN`: for each `(gs, v)` in `t1 g`, lazily enumerate result vectors
     of `t2` across `gs` (depth-first Cartesian product — Isabelle's
     `Seq.THEN` semantics), composing validations via `mapshape`-style
     plumbing.  A composed validation is a plain HOL4 `validation`;
     soundness is untouched.
   - Backtracking exists only within a `DETERM` boundary; `DETERM` takes
     the first result and drops alternatives.
   - `NREPEAT` has `REPEAT_DETERM` semantics; `NCHANGED` filters results
     where the goal is unchanged.
2. Selftest coverage appended to (or creating) `src/auto/rules/selftest.sml`
   using `testutils` (`tprint` + `OK`/`die`, `test`), per plan §3/§8 group 1:
   - algebraic laws (associativity of both choices);
   - `NORELSE` vs `NAPPEND` distinguishability under later failure;
   - laziness: a diverging second branch is never forced when the first
     result suffices;
   - validity of composed validations via `Tactical.VALID` on golden goals.
3. Holmakefile updated so the module and selftest build and the selftest
   runs under `Holmake` with `-t`.

## Constraints

- Moscow-ML-compatible SML (no Poly/ML-isms).
- Allowed dependencies: `portableML` (seq), `src/1` (Tactical etc.) — see
  plan §2 stratification.
- Style: no tabs, no trailing whitespace, < 80 columns.
- The `ntactic`/`wrapper` types and combinator semantics are on the Phase 0
  freeze list (plan §11): implement the spec as written; do not redesign.

## Acceptance criteria

- All new selftests pass; `bin/build -t --seq=tools/sequences/upto-auto`
  green.

## Dependencies

- TASK_01 (build skeleton).
