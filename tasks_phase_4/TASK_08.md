# TASK_08 — `aesopData`: `aesop_simp` settype + derived simpset (+ dir scaffolding)

Plan: `.agent-files/PLAN_phase_4.md` §4.1 (D46, D50); plan task T07.
Read the plan file in full before starting — it is the authoritative
spec; this task file is a pointer, not a replacement.

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

1. Create `src/auto/aesop/` with a Holmakefile and a `selftest.sml`
   skeleton (testutils conventions), so focused `Holmake` +
   `selftest.exe` work from this task onward.  (Build-sequence /
   parallel-builds integration is deferred to TASK_20, per plan
   §3.7/T14.)
2. `aesopData`:
   - `[iff]`-template settype registration
     (`ThmSetData.export_with_ancestry`, settype `"aesop_simp"`;
     verify the name is collision-free) whose value is the rewrite
     list; `apply_to_global` marks the derived cache stale.
   - Derived simpset cache (D50), via
     `BasicProvers.make_simpset_derived_value`, additionally
     invalidated by `aesop_simp` deltas:

     ```sml
     val aesop_ss : unit -> simpLib.simpset
     (* srw_ss() |> set_cond_depth 40
                 |> set_safe_solvers [clasimp safe stack]
                 |> ++ (rewrites (aesop_simp set))  — NO split_ss *)
     ```

3. Selftests: settype export/reload; cache derivation and staleness
   on `aesop_simp` additions; `split_ss` absence observable (a goal
   that `srw_ss()`-with-splits would split is left unsplit).
4. `Feedback` trace `"aesop"` registration (levels 1–3 per plan §4)
   can live here so later modules share it.

## Notes

- All modules Moscow-ML-compatible SML.
- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

None (independently gateable; uses existing clasimp machinery).
