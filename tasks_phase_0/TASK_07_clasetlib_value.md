# TASK_07 — `clasetLib` part 1: claset value, netpairs, combinators

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  This task builds the claset *value*:
the record holding rule decls, the four discrimination-net pairs, and the
wrapper lists, plus its combinators and lookup entry points — the object
every later search engine consumes.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §6.1 and §6.6 — the authoritative spec.
- `.agent-files/sources/src/Provers/classical.ML`: `:323–334` (netpair
  routing), `:400–422` (`merge_cs`), `:513–530` (wrapper alists and
  composition semantics), `Bires.pretty_decls` usage for printing.
- The TASK_03 `NTactical` module (`wrapper` type), TASK_04 `clasetNet`,
  TASK_05/06 `clasetRules` — this task composes all three.
- `src/simp/src/simpLib.sml` — simpset ergonomics precedent for the
  value-level API shape.
- `src/basicProof/BasicProvers.sml:842` (`VAR_EQ_TAC`) for the config
  record.

## Deliverables

`src/auto/rules/clasetLib.sig` / `clasetLib.sml` (first slice):

1. The `claset` datatype of plan §6.1: `decls`, `safe_wrappers`
   (compose with `NORELSE`), `unsafe_wrappers` (compose with `NAPPEND`),
   and four netpairs (`safe0`, `safep`, `unsafe`, `dup`).  No
   `extra_netpair`.
2. Value-level API (plan §6.1): `empty_cs`; `add_rule : rulespec ->
   string * thm -> claset -> claset` + convenience wrappers
   (`add_sintros`, `add_intros`, `add_selims`, …); `remove_rule : string
   -> claset -> claset` (deletes across all kinds and all four netpairs
   via stored decl tags — `delete_tagged_rule` port); `merge_cs` (replay
   of `merge_decls` output as incremental net insertion); wrapper ops
   (`add_safe_wrapper`, `add_unsafe_wrapper`, `del_safe_wrapper`,
   `del_unsafe_wrapper` — name-keyed alist update) and
   `app_safe_wrappers`/`app_unsafe_wrappers` with Isabelle composition
   semantics.
3. Introspection: `rules_of : claset -> (rulespec * (string * thm)) list`
   in canonical order; `pp_claset` (per-kind listing à la
   `Bires.pretty_decls`).
4. Lookup entry points (plan §6.1, frozen interface): `claset_part`
   selector (safe0/safep/unsafe/dup) and
   `match_intro_candidates` / `match_elim_candidates` /
   `unify_intro_candidates` / `unify_elim_candidates`, each returning
   tag-sorted candidates per the §5.1 ordering contract.
5. The fixed config record `claset_config` (plan §6.6):
   `hyp_subst_tac = BasicProvers.VAR_EQ_TAC`, `size_of` default heuristic.
6. Selftests (plan §8 groups 4–5):
   - netpair routing: safe 0-subgoal vs branching classification;
     candidate order = (fewest-subgoals, recency) on a crafted 6-rule
     claset; swapped-variant retrieval on negated-assumption queries;
   - value ops: add/remove/merge with canonical-order preservation —
     merge two clasets built in different orders and compare `rules_of`;
   - cross-check `match`/`unify` candidate results against brute-force
     list filtering (plan §10 risk 2).

Global state, persistence, and attributes are **not** in this task
(TASK_08); markers are TASK_09; the TypeBase hook is TASK_10.  Structure
the module so those slices can be added without reworking this one.

## Constraints

- Moscow-ML-compatible SML; dependency stratification per plan §2
  (`src/basicProof` is allowed — needed for `VAR_EQ_TAC`; `src/simp/src`
  is **not**).
- Style: no tabs, no trailing whitespace, < 80 columns.
- The lookup entry points, ordering contract, `add_rule` signature, and
  `claset_config` are on the freeze list (plan §11).

## Acceptance criteria

- All new selftests pass; all previously passing selftests still pass;
  `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_03 (`NTactical`), TASK_04 (`clasetNet`), TASK_06 (`clasetRules`
  complete).
