# TASK_11 — `GEN_GLOBAL_SIMP_TAC`: `mut_impc`-parity upgrade of
# `global_simp_tac`

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; this task closes the `mut_impc` gap (Isabelle's mutual
assumption-simplification fixpoint) at the tactic level, per owner
decision D17.  Governing constraint: **all defaults preserve current
behavior** — existing entries (`gvs`/`gs`/…) keep their exact semantics;
new behavior is opt-in by config.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T9 (§7): `xsimptac_config` / `GEN_GLOBAL_SIMP_TAC` with `mut_impc`
change counting (unconditional) and two default-off flags.

## Spec

Read PLAN_phase_S §7 in full, D17 (§0), §2 compat rule 2
(`simptac_config` is frozen — the new flags go in the new extended
record), and `.agent-files/research/phaseS-isabelle-simploop.md` §3.5–3.6,
§4.d.  Isabelle original:
`.agent-files/sources/src/Pure/raw_simplifier.ML:1315–1441`.  Source:
`src/simp/src/simpLib.{sig,sml}` (`global_simp_tac` pass structure,
~964–994) — note TASK_06 may have touched its final goal-directed step;
build on the current state of the branch.

1. ```sml
   type xsimptac_config =
        {base : simptac_config, concl_in_fixpoint : bool,
         imp_rebuild : bool}
   val GEN_GLOBAL_SIMP_TAC : xsimptac_config -> simpset -> thm list
                             -> tactic
   ```
2. **Change counting** (unconditional — pure cost improvement, identical
   results): port `mut_impc`'s `changed`/`k` schedule
   (`raw_simplifier.ML:1384–1415`): track the index of the last changed
   assumption per pass; next pass skips the provably-fixed tail.
   Replaces detect-termination-by-full-no-op-pass.
3. **`concl_in_fixpoint`** (default `false`): simplify the conclusion
   each pass with all assumptions in context; a conclusion change
   re-triggers assumption passes.
4. **`imp_rebuild`** (default `false`): after the fixpoint, for each
   assumption `a` (innermost first) attempt rewriting the `DISCH`ed
   `a ==> w'` with implication-lhs rules; on a hit, undischarge and
   restart the whole fixpoint (`raw_simplifier.ML:1360–1373`).
5. `global_simp_tac cfg = GEN_GLOBAL_SIMP_TAC {base = cfg,
   concl_in_fixpoint = false, imp_rebuild = false}` — existing entries
   (`gvs`/`gs`/`gns`/`rgs`, `bossLib.sml:402–409`) extensionally
   unchanged except the pass schedule (same results, fewer
   re-simplifications).
6. **Selftests** (§8 group 8): the report's §3.5 mutuality examples
   (`{P a, a = b} ⊢ Q`; the three-premise chain); identical results with
   change counting on golden goals (compare against unupgraded
   semantics, i.e. record expected outcomes); `concl_in_fixpoint` and
   `imp_rebuild` behavior tests; `gvs`-defaults regression (golden goals
   through bossLib entries produce the same subgoals as before the
   change).

## Acceptance criteria

1. All existing selftests pass; `gvs`/`gs`/`gns`/`rgs` regression tests
   show unchanged results.
2. New group-8 tests pass.
3. `simptac_config` record untouched (compat rule 2);
   `xsimptac_config`/`GEN_GLOBAL_SIMP_TAC` exported per §7 (frozen at
   phase completion, §12).
4. `bin/build -t --seq=tools/sequences/upto-parallel` green.
5. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_06 (both touch the simpLib tactic layer; plan orders T9 after the
loop rewiring).  Independent of the splitter tasks (TASK_07–10).
