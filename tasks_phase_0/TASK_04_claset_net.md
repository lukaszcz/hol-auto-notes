# TASK_04 — `clasetNet`: dual-mode discrimination net

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  Rule retrieval needs a discrimination
net with *both* match-mode lookup (Phase 1 step tactics) and unify-mode
lookup (Phase 2 blast); no unify-mode net over HOL terms exists in the
tree, so this module provides both now to keep the netpair layer stable
across phases.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §4 — the authoritative spec, including
  the exact signature.
- `src/0/Net.sml` — the label alphabet and first-order Rator-first
  traversal to replicate (`V | Cmb | Lam | Cnst`).
- `src/1/Ho_Net.sml` and `src/simp/src/simpLib.sml:74` — the `fvars`
  wildcard discipline (stored pattern vars + bound vars wild, other frees
  rigid).
- `src/metis/mlibTermnet.sml:202–228` (`unify`, `harvest`) — the only
  in-repo unify-mode net (over metis FO terms); structural template for
  the unify walk.
- `.agent-files/sources/src/Pure/bires.ML:289–299` — why lookup is an
  over-approximation (strictness is enforced at rule-application time).

## Deliverables

1. `src/auto/rules/clasetNet.sig` and `clasetNet.sml` implementing the
   plan §4 signature: `empty`, `insert` (with explicit `patvars`),
   `match` (query vars rigid), `unify` (query `qvars` wild both ways),
   `vfilter` (deletion), `listItems`.  Key semantics:
   - types are ignored (sound: callers re-check candidates with real
     matching/unification);
   - `unify` walk: at a query position in `qvars`, harvest the whole
     subnet; at a stored-`V` edge, skip one query subterm as in `match`;
     no substitution-consistency tracking (pure over-approximation).
2. Selftest coverage in `src/auto/rules/selftest.sml` per plan §4/§8
   group 2:
   - soundness oracles: for random small term pairs, if `p` matches
     (resp. unifies with) `q` then the stored entry is retrieved —
     cross-check against brute-force list filtering;
   - fixed regression cases for `Lam`/`Cmb` corner cases.
3. Holmakefile updated as needed.

## Constraints

- Moscow-ML-compatible SML; dependencies limited per plan §2 (kernel term
  ops, `src/1` at most).
- Style: no tabs, no trailing whitespace, < 80 columns.
- Beware plan §10 risk 2: wrong `patvars` handling silently loses
  candidates — this is why the oracle tests are mandatory, not optional.
- The net implementation is private to `src/auto/rules` (plan §11); the
  signature is what later tasks build on.

## Acceptance criteria

- All new selftests pass; `bin/build -t --seq=tools/sequences/upto-auto`
  green.

## Dependencies

- TASK_01 (build skeleton).
