# TASK_07 — `splitLib` core: rule analysis, cmap, `SPLIT_CONV`,
# `SPLIT_TAC` (conclusion splits)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; its centerpiece is a port of Isabelle's
`Provers/splitter.ML` — case-splitting inside simplification, the single
biggest simp-strength gap versus Isabelle.  Governing constraint: **all
defaults preserve current behavior**; nothing consumes splitLib by
default in Phase S.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T6 (§6.1–6.2): the new module `src/simp/src/splitLib.{sig,sml}` with
split-rule analysis/indexing and the conclusion-split conversion.

## Spec

Read PLAN_phase_S §6.1–6.2 in full, D18–D20 (§0), §11.2, and the
research report `.agent-files/research/phaseS-isabelle-splitter.md`
(the §n citations in the plan's §6 refer to that report).  The Isabelle
original is `.agent-files/sources/src/Provers/splitter.ML`.

Layering (§2): splitLib sits **below** simpLib — it may depend only on
`Conv`/`Drule`/`TypeBase`/`ThmSetData`/`markerLib`, never on simpsets.
Add it to the `src/simp/src` Holmakefile build.

1. **Rule analysis** (§6.1): recognize split rules
   `⊢ P (c a1 … an) = rhs` with `P` a (universally quantified)
   bool-valued variable; detect asm-variants syntactically (rhs headed by
   negation).  Malformed rules → clear `HOL_ERR` at registration.  Index
   by (head const `c`, asm-flag, type shape) — the cmap of
   `splitter.ML:66–81`; keying must not merge distinct type instances
   (report §5.4).
2. **`SPLIT_CONV : thm list -> conv`** (§6.2), per invocation:
   - **Scan**: find `Const`-headed applications matching a rule pattern
     first-order; reject partial applications; for redexes referencing
     bound variables require the innermost referenced binder's body to
     be bool (the `type_test` rule, `splitter.ML:163–168`).  Collect
     packs `(rule, #binders-to-enter, path)`.
   - **Order** packs by `(#binders, path length)` ascending; iterate
     packs in order until one applies (deliberate divergence from
     Isabelle's first-pack-only — documented in a comment).  Exactly one
     split per successful invocation.
   - **Navigate** via `RATOR_CONV`/`RAND_CONV`/`ABS_CONV` composition.
   - **Apply**: build `P0 = λa. body[redex ↦ a]` replacing **all**
     alpha-equivalent occurrences (report §5.7 — one-occurrence
     replacement can loop); instantiate by `match_term` on the
     `c`-application plus explicit instantiation of `P0` and argument
     variables — never solve for `P` by higher-order matching; then
     beta-reduce both sides
     (`LAND_CONV BETA_CONV THENC RAND_CONV (TOP_DEPTH_CONV BETA_CONV)`).
   - Any failure (no rule, no admissible pack, match failure) = clean
     `HOL_ERR` (looper-termination contract).
3. **`SPLIT_TAC : thm list -> tactic`** — for this task the
   conclusion-side step: `CHANGED` application of `SPLIT_CONV` via
   `CONV_TAC`.  (Asm-rule routing arrives with TASK_08; structure the
   code so TASK_08 slots in the "then asm rules" leg of §6.4.)
4. **Selftests** (§8 group 6, conclusion part) in
   `src/simp/src/selftest.sml`: if-splits (`bool`'s case constant is
   `COND` — build the if-split theorem by hand or via
   `TypeBase.case_pred_imp_of`; the TypeBase *cache* is TASK_09),
   including splits under `!` binders and with the redex referencing
   bound variables; datatype case splits (`list`, `option`);
   all-occurrences semantics; pack ordering (outermost first);
   registration-time rejection of malformed rules (`shouldfail`);
   one-split-per-invocation.

## Acceptance criteria

1. splitLib compiles below simpLib (no simpLib dependency) and the new
   selftest group passes.
2. All existing selftests still pass.
3. `bin/build -t --seq=tools/sequences/upto-parallel` green.
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

None strictly (TASK_05 recommended first so marker rebuilds don't
invalidate this work; no code dependency).
