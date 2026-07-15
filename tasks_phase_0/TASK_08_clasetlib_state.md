# TASK_08 — `clasetLib` part 2: persistent global claset + attributes

## Context

This task is part of Phase 0 of a larger project (`.agent-files/PLAN.md`):
building HOL4 analogues of Isabelle/HOL's proof automation (`auto`, `blast`,
`force`, `safe`, `clarify`, …) that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax (the target is
automation *strength* parity, not Isabelle-style syntax).  Phase 0
(`.agent-files/PLAN_phase_0.md`) delivers the shared foundation: the
classical rule database ("claset").  This task makes the claset
*persistent and declarative*: rules declared with `Theorem foo[sintro]`
survive theory export/reload and merge across theory ancestry, exactly
like `[simp]` does today.

Everything you build must be a concrete step toward these goals — general,
principled, extensible.  However, the ultimate plan goals are **not**
acceptance criteria for this task: you are done when this task's own
deliverables and acceptance criteria are met.

## Prerequisite reading

- `.agent-files/PLAN_phase_0.md` §6.2, §6.3, and decisions D11/D12 (§0) —
  the authoritative spec.
- `src/basicProof/BasicProvers.sml:1119–1253` — the `srw_ss` state
  machine: the template to port field-for-field (`cstate`, lazy
  `init_state`, pending list).
- `src/parse/AncestryData.sig` (esp. `fullmake`) and
  `src/parse/AncestryData.sml:277–279` (delta replay on load).
- `src/1/ThmAttribute.sig:15` (`register_attribute`) and
  `src/1/ThmAttribute.sml:86–90` (`legal_attrsyntax`).
- TASK_05's `cdelta` codec — this task wires it in.

## Deliverables

Extend `src/auto/rules/clasetLib.{sig,sml}`:

1. **Global state** (plan §6.2): `type cstate = claset * bool * pending
   list` with lazy initialisation — the TypeBase catch-up sweep (hook
   arrives in TASK_10; leave a clean seam) and pending-delta replay run on
   first `the_claset()` demand.
2. **`AncestryData.fullmake` instance**: `tag = "claset"`,
   `initial_values = [("min", empty state)]`, `apply_delta`;
   `uptodate_delta` checks theorem liveness; `sexps` = the TASK_05 codec;
   `globinfo` with `thy_finaliser = SOME batch_finaliser` batching a
   loaded theory's deltas into one decls/net extension per theory.
   Failed name lookup on load degrades to a warning + dropped delta
   (`ThmSetData.sml:56–66` precedent).
3. **Public API** (plan §6.2, frozen): `the_claset`, `export_rule`,
   `temp_add_rule`, `delrule`, `temp_delrule` (rule removal is
   function-based per D12 — no `[rule del]` attribute), `augment_claset`
   (not persisted: wrappers and programmatic rules; libraries re-establish
   them at load time, like simpset dprocs), `claset_of_theory`,
   `merge_clasets`, `with_claset`.
4. **Six attributes** (plan §6.3, D12): register `intro`, `sintro`,
   `elim`, `selim`, `dest`, `sdest` via `ThmAttribute.register_attribute`.
   `storedf` = record delta (ADD) + apply to global value; `localf` =
   apply to global value only.  Non-empty attribute argument lists raise
   a clear error mentioning that priorities arrive in a later phase.
5. **Selftests** (plan §8 group 6, attribute part): drive
   `Theorem foo[sintro]: …`-style declarations through the
   `Theory`/`ThmAttribute` machinery in-process and check the global
   claset picks them up; `delrule`/`temp_delrule` behavior; duplicate and
   cross-kind warnings surface once.

Cross-theory persistence scenarios (export/reload, diamond merge) are
TASK_12 (`theory_tests/`), not this task.

## Constraints

- Moscow-ML-compatible SML; stratification per plan §2.
- Style: no tabs, no trailing whitespace, < 80 columns.
- Attribute names and the API signatures above are on the freeze list
  (plan §11); the settype `"claset"` and the six attribute names were
  collision-checked free (plan §2) — keep them exactly.

## Acceptance criteria

- All new selftests pass; all previously passing selftests still pass;
  `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

- TASK_07 (claset value slice of `clasetLib`).
