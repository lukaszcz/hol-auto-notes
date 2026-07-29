# TASK_16 — Proof extraction and replay

Plan: `.agent-files/PLAN_phase_4.md` §4.5 (D51, E6(a)), §9 item 6;
plan task T12.  Read the plan file in full before starting — it is
the authoritative spec; this task file is a pointer, not a
replacement.

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

## Scope

On root proved:

- Select the winning forest (per cluster, its proved goal; per goal,
  its proved rapp).
- Covering store = `clasetMeta.absorb` of the root store with all
  winning-branch final stores (domain-disjointness argued at D51;
  conflicts are hard errors), then `clasetMeta.ground` once.
- Replay bottom-up: each goal's norm-chain records, then its rapp's
  record `action grounded`, children composed positionally (each
  action targets position 1 of its single-goal node);
  `RenderedTactic`/wrapper records replay their recorded
  `fixed_action`.
- Per E6(a): with fully recorded instantiations a replay failure is
  an engine bug — hard diagnostic error, no backtrack-into-search.
- Final result: a standard `(goal list, validation)` with the empty
  goal list, delivered through `Tactical.VALID`.
- Selftests (replay honesty, §9 item 6): every success re-checked by
  the kernel via `Tactical.VALID`; a deliberately corrupted-store
  test asserting the hard-error (not silent) replay policy; the
  dropped-metavariable golden proved with `ARB`-grounding verified
  kernel-side.  Extraction can be exercised on hand-built winning
  trees (TASK_12 goldens) if useful, plus end-to-end via the search
  loop where available.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_06 (`absorb`), TASK_12 (tree + copying).  TASK_15 helpful for
end-to-end tests but not required to start.
