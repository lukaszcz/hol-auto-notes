# TASK_09 — `[split]` set + attribute, TypeBase cache, `cases_simp`,
# `add_split`/`del_split`/`split_ss`

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; this task wires the splitter (TASK_07/08) into the
simpset world: persistent `[split]` rule set, automatic per-datatype
splits via TypeBase, and the `split_ss` fragment.  Governing constraint:
**all defaults preserve current behavior** — no distribution simpset
consumes any of this in Phase S.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T8, first half (§6.4–6.5 minus `process_tags`/`Excl` integration and
the RW_TAC parity suite, which are TASK_10): registration surface,
persistent set, TypeBase cache, `cases_simp` rewrite, and the fragment.

## Spec

Read PLAN_phase_S §6.4–6.5, §6.6 (API must not be narrowed), D18–D19
(§0), and `.agent-files/research/phaseS-hol4-splitting-idioms.md` §1b,
§5, §7.  Sources: `src/simp/src/splitLib.{sig,sml}`,
`src/simp/src/simpLib.{sig,sml}`, `src/1/ThmSetData` usage precedents
(e.g. `BasicProvers.sml`), `src/1/Prim_rec.sml:2028–2043`.

1. **TypeBase cache** (§6.5, in splitLib): `type_split_of : hol_type ->
   thm` derives the split theorem via `Prim_rec.prove_case_ho_imp_thm`
   (surfaced as `TypeBase.case_pred_imp_of`); `type_asm_split_of`
   returns the stored `case_elim` tyinfo field.  Both cached per
   `(thy, tyop)` in an `Sref` dictionary, lazily filled (no TypeBase
   hook needed; types defined later are found later).
2. **`[split]` persistent set** (§6.4, in splitLib):
   `ThmSetData.export_with_ancestry`, settype `"split"`, plain
   ADD/REMOVE; gives the `Theorem foo[split]` attribute and
   `temp_add_split`-style functions by the standard mechanism.
   `split_thms : unit -> thm list` returns the current set.
3. **simpLib surface** (§6.4): `add_split th` inspects the rule
   (asm-variant by rhs shape) and installs a named looper
   `split <thy$name>` / `split_asm <thy$name>` wrapping `SPLIT_TAC
   [th]` — one looper per rule; `del_split : string -> simpset ->
   simpset` removes by that naming scheme.
4. **`split_ss`** (§6.4): one fragment containing
   (a) the stateful splitter looper named `"splitter"` which at
   invocation consults the current `[split]` set plus TypeBase
   case-splits for case constants actually occurring in the goal
   (call-time TypeBase read — the `BasicProvers.sml:877–878` precedent);
   (b) the `cases_simp` analogue rewrite
   `⊢ (b ==> t) /\ (~b ==> t) <=> t`, derived at load time from
   `SPECL [b,t,t] COND_EXPAND_IMP` and `COND_ID` — no theory change.
   `if` needs no special-casing (`bool`'s case constant is `COND`).
5. Leave hooks for exclusion (TASK_10): the splitter looper must consult
   `excl_loopers` when skipping rules/types, but populating it from
   `Excl` strings is TASK_10.
6. **Selftests** (§8 group 6, integration subset): `SIMP_TAC (bool_ss ++
   split_ss)` splits an `if` in the conclusion and a `list` case; a
   locally defined datatype splits via the TypeBase path; cache reuse
   (second call hits the cache — at minimum, correctness twice);
   `[split]` attribute + `split_thms` round-trip (theory_tests-style
   scaffolding if a persistent-theory test is needed); `cases_simp`
   collapses the trivial split; `add_split`/`del_split` add/remove the
   looper by name; asm-variant auto-routing.

## Acceptance criteria

1. New integration selftests pass; all existing selftests still pass.
2. No default simpset changed; `split_ss` is opt-in only.
3. Settype/attribute name `split` registers cleanly (verified unclaimed
   in the plan; re-verify at registration).
4. `bin/build -t --seq=tools/sequences/upto-parallel` green.
5. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_04 (looper/fragment surface), TASK_06 (loop honors loopers),
TASK_07, TASK_08.
