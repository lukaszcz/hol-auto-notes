# TASK_11 — `aesopTree` core: nodes, states, clusters, priorities

Plan: `.agent-files/PLAN_phase_4.md` §4.3 (all except the copying
bullet); first half of plan task T09.  Read the plan file in full
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

## Scope

`src/auto/aesop/aesopTree`, one search-state record threaded
functionally (id-keyed `Redblackmap`s + counters; no global refs),
with the goal/rapp/cluster records exactly as plan §4.3.

- **Priorities**: `prio` = Σ ln(percent/100) along the path (root
  0.0; `RSafe` adds 0).  Queue = `searchHeap` keyed by (higher
  `prio` first, then insertion-counter FIFO) — deterministic, fair
  among equals.
- **States** (§2.2/§4.2 of the paper): goal proved iff some child
  rapp proved; rapp proved iff all child *clusters* proved; cluster
  proved iff *some* member goal proved.  Goal stuck iff normalised,
  safe phase done, unsafe candidates exhausted, and all child rapps
  stuck; rapp stuck iff some cluster stuck; cluster stuck iff all
  members stuck.  Irrelevance = any ancestor-or-self proved or
  stuck; checked lazily on queue pop.
- **Metavariable bookkeeping**: `deps` from `clasetMeta.metas_of`
  over `asl @ [w]` and param types, closed transitively through
  `bindings` residues; per-rapp `created` from the `step_record`,
  `assigned` = `bindings`-diff parent→child store.
- **Clusters**: partition of a rapp's child goals by transitive
  overlap of `deps` (union-find at rapp installation).
- Rapp installation API sufficient for TASK_12 (copying) and the
  search loop (TASK_14/15) to build on.
- Selftests: priority arithmetic (log-domain products, FIFO ties);
  state-propagation goldens on hand-built trees (proved/stuck
  cascades, irrelevance); cluster partition (incl. the transitive
  coupling shape `G1–G2–G3`); deps computation.

The copying algorithm (§4.3 copying bullet) is **out of scope** —
it is TASK_12.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_09 (rule model types referenced by goal records), TASK_06
(`absorb` — per the plan's dependency spine for T09).
