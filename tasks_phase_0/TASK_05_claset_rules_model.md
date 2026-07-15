# TASK_05 — `clasetRules` part 1: rule model, canonical form, decls, codec

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  This task ports the rule bookkeeping
of Isabelle's `Pure/bires.ML` — kinds, tags, canonical declaration order,
merge — plus the canonical theorem form and the persisted-delta codec.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §5.1 and §5.2, plus decisions D11/D2
  context in §0 — the authoritative spec.
- `.agent-files/sources/src/Pure/bires.ML:80–246` — kinds, tags, decls,
  `next` counter, `decl_merge_ord` (`:187–190`), `merge_decls`
  (`:230–231`), candidate ordering (`:97–110`).
- `.agent-files/sources/src/Provers/classical.ML:268–273` (swapped-rule
  index interleaving: unswapped at `2k+1`, swapped at `2k`) and
  `:400–422` (`merge_cs` = replay of new decls).
- `src/1/ThmSetData.sml:56–66` — the load-by-name pattern (theorem not
  serialized; failed lookup degrades to warning + dropped delta).
- `src/parse/ThyDataSexp.sig` — the codec substrate (`tag_encode`,
  `first`).
- `src/bool/boolScript.sml:2283` (`AND_IMP_INTRO`) for premise currying.

## Deliverables

`src/auto/rules/clasetRules.sig` / `clasetRules.sml` (first slice), with:

1. **Types** (plan §5.1): `rulekind` (`Intro | Elim | Dest`), `rulespec`
   (`{kind, safe, prio : int option}`), `tag` (`{weight, index}`), `brl`,
   `rl`, `info`, `decl` — exactly as specified.
2. **`decls` container**: canonical order via decreasing `next` counter;
   keyed both by normalized concl (`Term.compare` dictionary, duplicate
   detection) and by declaration name (name-based removal).  Candidate
   ordering helper: sort `(tag, brl)` by `(weight, index)` ascending.
   `merge_decls` port returning the *new* decls to replay (so claset merge
   can be incremental net insertion in TASK_07).
3. **Canonical rule form** (plan §5.2): normalize a theorem to
   `|- !x1…xk. P1 ==> … ==> Pn ==> C`; strip outer `!`s (stripped vars are
   the future net `patvars`); recursively curry top-level conjunctive
   premises with `AND_IMP_INTRO` along the premise spine; leave
   premise-internal `!`/`==>` intact; intro rules index by `C`, elim/dest
   by major premise `P1`; premise-free elims are ill-formed (raise with
   Isabelle's `err_thm_illformed`-style message).
4. **Persisted delta + codec** (plan §5.1): `datatype cdelta = ADD of
   {name : thname, spec : rulespec} | RM of string`; `ThyDataSexp` codec
   with versioned tags `"clasetADD1"` / `"clasetRM1"`, decoding via
   `first [dec1, …]` so future variants can coexist.  Theorems load by
   name lookup; provide the `uptodate`-check helper for stale deltas.
5. **Selftests** in `src/auto/rules/selftest.sml`: canonical-form golden
   examples (incl. nested-conjunction premises, premise-internal
   binders left intact, premise-free-elim rejection); decls ordering and
   `merge_decls` regression replicating Bires merge scenarios (plan §10
   risk 5: `decl_merge_ord` reverses index order per kind-class — test
   this specifically); codec round-trip tests.

The five preprocessing derived rules and `ext_info` assembly are **not**
in this task — they are TASK_06.  Design the `.sig` so TASK_06 can extend
it without reworking this slice.

## Constraints

- Moscow-ML-compatible SML; dependencies per plan §2 (`src/1`,
  `src/parse`, `boolTheory`).
- Style: no tabs, no trailing whitespace, < 80 columns.
- The `rulespec`/`cdelta` schema (v1) is on the freeze list (plan §11) —
  implement as specified.

## Acceptance criteria

- All new selftests pass; `bin/build -t --seq=tools/sequences/upto-auto`
  green.

## Dependencies

- TASK_01 (build skeleton).
