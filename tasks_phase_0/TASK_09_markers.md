# TASK_09 — Marker constructors + `process_claset_tags`

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  This task provides the ML side of the
per-invocation modifier vocabulary (`SIntro th`, `Del "name"`, …) that
every Phase 1–4 tactic will consume, interoperating with the existing simp
markers (`Cong`/`Excl`/`SF`/`Once`).

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §6.4 — the authoritative spec.
- `src/marker/markerLib.sml:77` (thm-carrying `Cong` pattern) and `:102`
  (string-carrying `Excl_t` pattern) — constructor/destructor idioms.
- `src/simp/src/simpLib.sml:834` (`process_tags`) — the analogue for
  `process_claset_tags` (do not depend on `src/simp/src`; only read it as
  the pattern).
- TASK_02's `clasetMarkerTheory` and TASK_07's claset value API.

## Deliverables

Extend `src/auto/rules/clasetLib.{sig,sml}`:

1. Constructors and destructors for the marker constants of
   `clasetMarkerTheory`: `SIntro`, `Intro`, `SElim`, `Elim`, `SDest`,
   `Dest` (thm-carrying), `Del` (string-carrying).
2. `process_claset_tags : thm list -> claset -> claset * thm list`:
   strips claset markers, applies them as *temporary* claset
   modifications (via the TASK_07 value ops), and returns the remaining
   theorems untouched so the same list can flow into simp tag processing.
   Unrecognized markers (`Cong`/`Excl`/`SF`/`Once`, plain theorems) must
   pass through unchanged — interoperation holds by construction.
3. Selftests (plan §8 group 6, marker part): each marker round-trips
   (construct → process → expected temporary claset change); `Del`
   removes for the invocation only; pass-through of `Cong`/`Excl`-marked
   and unmarked theorems verified.

## Constraints

- Moscow-ML-compatible SML; do **not** add a dependency on
  `src/simp/src` (plan §2).
- Style: no tabs, no trailing whitespace, < 80 columns.
- The marker vocabulary is on the freeze list (plan §11); `Iff`/`Split`
  markers belong to later phases — do not add them.

## Acceptance criteria

- All new selftests pass; all previously passing selftests still pass;
  `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_02 (`clasetMarkerTheory`), TASK_07 (claset value ops).
