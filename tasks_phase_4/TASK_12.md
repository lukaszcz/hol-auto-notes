# TASK_12 — `aesopTree` copying algorithm + golden tests

Plan: `.agent-files/PLAN_phase_4.md` §4.3 (copying bullet), §9 item 2,
§12 risk 1; second half of plan task T09.  Read the plan file in full
before starting — it is the authoritative spec; this task file is a
pointer, not a replacement.

## Context

Phase 4 of the isabelle-tactics project builds a full aesop-style
best-first proof search engine (Limperg & From, CPP 2023) in
`src/auto/aesop/`, on top of the shared claset rule DB and the Phase-2
metavariable/replay substrate.  Ultimate goals of the whole plan:
`AESOP_TAC`/`AESOP_SAFE_TAC` (+ `CS_` forms) with close-or-fail
semantics, kernel-checked replay, the paper's full metavariable
algorithm, and a single shared rule DB extended with Forward/Norm
kinds, percent/penalty attributes, and an `aesop_simp` settype.
All work must be a step toward these goals, but the ultimate goals are
**not** acceptance criteria for this task — only the gate below is.
This is the parent plan's declared highest-risk component: write the
golden tests *before* the implementation.

## Scope

Copying (paper §4.3/§4.6), on installing a rapp `R` under `G` with
`assigned ≠ ∅` *or* dropped metas (created-by-ancestors metas in
`G.deps` appearing in no child's `deps` and unassigned — treated as
assigned for copying):

- Walk parents from `G` to the topmost rapp creating any such meta;
  every sibling goal of a path goal whose `deps` meets the
  assigned/dropped set is copied — `cgoal` instantiated under
  `R.store` (`clasetMeta.instantiate` + `norm`), added as an extra
  child goal of `R` with `copy_of` set.
- Skips: siblings that are copies of path goals; duplicate copies of
  one original.  Subtrees are not copied (rules re-apply).
- **No synthesis subgoals for dropped metas**: grounding is
  deterministic (`ARB`), per the paper's inhabited-logic remark and
  E5.

Golden tests (write first): the paper's Fig. 1/Fig. 2 scenarios
(m-coupling, cluster partition, copying incl. transitive coupling
`G1–G2–G3`); the dropped-metavariable case (§4.6 `RingHom`-style goal
in HOL4: `?f. homo f` with a hypothesis supplying a
witness-independent proof); duplicate-copy suppression.  Paper text:
`papers/limperg-from2023-aesop.txt`.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass,
  including the new goldens.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_11 (tree core).
