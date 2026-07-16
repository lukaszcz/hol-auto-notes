# TASK_04 — simpLib surface: simpset fields, setters, fragment
# constructors, `clear_rules`, pp, history rebuild

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`: engine hooks, configurable limits, a tactic-layer loop
with loopers/final solvers, the Isabelle splitter, congproc fragments, and
a `mut_impc`-parity `global_simp_tac`.  Governing constraint: **all
defaults preserve current behavior** — new simpset fields default empty so
nothing changes until a simpset carries them.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T3 (§4.1–4.4 minus the `congproc_ss` travrules merge, which is
TASK_12): the simpset/ssfrag data model and setter surface for loopers,
solvers, subgoaler, cond_depth, term_ord; `clear_rules`; pretty-printing;
history-rebuild preservation.

## Spec

Read PLAN_phase_S §4 in full, §2 compat rules 1–2 and 5–6, §12 (freeze
list), and `.agent-files/research/phaseS-simplib-compat.md` as needed.
Source: `src/simp/src/simpLib.{sig,sml}`.

1. **Simpset fields** (§4.1): extend the internal `SS` record with
   `loopers`, `unsafe_solvers`, `safe_solvers`, `subgoaler`,
   `cond_depth`, `term_ord`, `excl_loopers` exactly as in the plan.
   Looper semantics: named alist, `add_looper` updates-or-adds by name,
   `del_looper` removes by name (warning if absent), `set_looper`
   replaces with a singleton; application order = registration order
   (earliest first).  Loopers have type `simpset -> tactic` and receive
   the invocation simpset.
2. **Setters** (§4.2): `add_looper`, `del_looper`, `set_looper`,
   `add_unsafe_solver`, `add_safe_solver`, `set_unsafe_solvers`,
   `set_safe_solvers`, `remove_solver` (by name, both lists),
   `set_subgoaler`, `set_cond_depth`, `set_term_ord` — all
   `X -> simpset -> simpset`.  Also `mk_tactic_solver : string * tactic
   -> Traverse.ssolver` implemented exactly per §4.2 (TAC_PROOF on
   `(map concl context_thms, c)` then `PROVE_HYP`-discharge over
   `context_thms`).
3. **Fragments** (§4.3): the public `SSFRAG` record is **frozen** (88
   call sites).  Extend internal `SSFRAG_CON` with `loopers`,
   `unsafe_solvers`, `safe_solvers`, `congprocs` (empty everywhere
   existing); add smart constructors `looper_ss`, `solver_ss`,
   `safe_solver_ss` (follow the `relsimps` precedent,
   `simpLib.sml:94–113`).  Also add the `congproc_ss` constructor with
   its field, but its travrules merge at `++` may be left for TASK_12
   (constructor + field storage here; merging behavior there).
4. **`++` merge**: loopers update-by-name (later fragment wins); solvers
   append, dedup by name; subgoaler/cond_depth/term_ord are
   simpset-level only — fragments cannot set them.
5. **History rebuild** (compat rule 6): `remove_ssfrags` /
   `exclude_ssfrags` → `build_from_history` (`simpLib.sml:676–734`) must
   preserve all six simpset-level fields the way `limit`/`excluded` are
   preserved today.
6. **Introspection** (§4.4): `pp_simpset` prints looper and solver names.
7. **`clear_rules`** (§4.4): clears net, congs, dprocs, relsimps and
   loopers; keeps `mk_rewrs`, `term_ord`, `subgoaler`, `cond_depth` and
   both solver lists.
8. Thread the new fields into the `traverse_data` built at invocation
   (`cond_depth`, `term_ord`, `subgoaler`, `unsafe_solvers` — the engine
   seam always gets the unsafe list, D15/D16).  The tactic-layer loop
   consuming loopers and safe/unsafe final solvers is TASK_06 — do not
   build it here.
9. **Selftests**: setter/merge/rebuild behaviors — add/del/replace looper
   by name; solver dedup at `++`; `remove_ssfrags` preserving the new
   fields; `clear_rules` keeps solvers, drops loopers; a
   `mk_tactic_solver`-backed unsafe solver discharging a side condition
   end-to-end through `SIMP_CONV` (engine seam, §8 group 2); cond_depth
   and term_ord settable per simpset (§8 groups 3–4 via the new setters).

## Acceptance criteria

1. All existing selftests pass; no change to any existing simpset's
   behavior (fields default empty/NONE).
2. New setter/merge/rebuild/clear_rules/solver-seam tests pass.
3. Public `SSFRAG` record and `simptac_config` untouched;
   `remove_simps`/`exclude_ssfrags` names/types unchanged (compat rules
   1, 2, 5).
4. `bin/build -t --seq=tools/sequences/upto-parallel` green.
5. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_03.
