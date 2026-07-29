# TASK_02 — `clasetRules` schema v2 core (kinds, codec, routing, ordering)

Plan: `.agent-files/PLAN_phase_4.md` §3.3 items 1–5 (D46, D47); first
half of plan task T02.  Read the plan file in full before starting —
it is the authoritative spec; this task file is a pointer, not a
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

In `src/auto/rules` (`clasetRules`):

1. `datatype rulekind = Intro | Elim | Dest | Forward | Norm`.
   Document `prio` semantics by kind in the `.sig`: unsafe
   Intro/Elim/Dest/Forward — success percent in `[1,100]`; Norm —
   integer penalty (any int; simp sits at 0); safe rules — reserved,
   ignored in Phase 4.
2. Codec: `clasetADD2`/`clasetRM1` — v2 encoder used **only** when
   the delta needs it (kind ∈ {Forward, Norm}); Intro/Elim/Dest
   deltas keep emitting v1 so theories not using the new kinds stay
   loadable by older code.
   `decode_delta = ThyDataSexp.first [v1-add, v2-add, rm]`.
3. Routing: Forward/Norm rules never enter the four classical
   netpairs (`safe_class_of` extended); classical cascades untouched;
   observable claset behaviour for existing kinds preserved (locked
   by existing selftests).  Forward/Norm live in `decls` (and later
   the aesop index — TASK_04) only.
4. `ext_info` for the new kinds: Forward stores the `MAKE_ELIM_RULE`
   form (safe and unsafe; no swapped/dup variants); Norm stores the
   canonical rule unchanged.
5. `dest_decls`/`rules_of` ordering: existing kind groups unchanged;
   Forward and Norm appended as new groups (within-group order by the
   existing tag order).

Selftests here: schema-v2 codec round-trips (Forward/Norm, percents,
penalties), routing locks (netpairs unchanged by Forward/Norm decls),
v1-emission lock for Intro/Elim/Dest deltas.

Attribute registrations (`[norm]`, `[forward]`, `[sforward]`) and
cross-version theory_tests are **out of scope** — they are TASK_03.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/rules` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

None (independently gateable).
