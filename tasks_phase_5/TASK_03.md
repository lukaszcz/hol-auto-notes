# TASK_03 — `linarithData`: records, registry, settypes, config, trace; persistence tests

## Context

This task is part of Phase 5 of the Isabelle-tactics project: porting
Isabelle's `Fast_Lin_Arith` linear-arithmetic engine to HOL4 as a
generic, registry-driven decision procedure in `src/auto/linarith/`
(core) and `src/auto/linarith/instances/` (int/real/rat).  The
ultimate goals of the whole plan (`.agent-files/PLAN_phase_5.md`) are:

1. A faithful untrusted Fourier–Motzkin engine with Farkas-certificate
   (`injust`) trees and kernel replay in both tactic and forward styles.
2. Instance records for `num`, `int`, `real`, `rat` via a live
   in-memory registry (rat is a net-new capability).
3. Goal-level preprocessing per decision D59: relevance filtering,
   splitLib-driven operator splitting, div/mod fact-augmentation, NNF.
4. The D62 public surface (`LINARITH_TAC`, `SIMPLE_LINARITH_TAC`,
   `CFG_LINARITH_TAC`, `LINARITH_PROVE`, `LINARITH_CONV`), the
   `[arith]`/`[arith_split]` theorem sets, `LINARITH_ss`, and the
   `"lin_arith"` unsafe solver wired into clasimp and aesop (D56).
5. Selftests (unit, per-instance, persistence, strength corpus) and
   user documentation.

Quality is judged by resulting automation strength — general,
principled, extensible; no recognition shortcuts.  Any work done in
this task must be a step toward these goals, **but the plan goals
above are NOT this task's acceptance criteria** — only the criteria
listed below are.

## Read first

- `.agent-files/PLAN_phase_5.md` §0 (D60, D61), §4.1, §7
  (theory_tests item), §10 (T3).
- `.agent-files/sources/src/Provers/Arith/fast_lin_arith.ML:87–89,
  119–180` and `.agent-files/sources/src/HOL/Tools/lin_arith.ML:71–105`
  (what the data records model upstream).
- `src/portableML/ThmSetData.sml:280–300` (`export_with_ancestry`
  auto-attribute) and its `.sig`.
- `src/auto/aesop/aesopData.sml:26–34` (collision guard convention)
  and the aesop `theory_tests/` directory (round-trip test pattern).
- `src/simp/src/splitLib.sml:24–49` (`rule_parts` P-form validation,
  `remove_name` pattern).
- `src/portableML/Sref.sig`.

## Work items

Create `src/auto/linarith/linarithData.sml` + `.sig` per
PLAN_phase_5.md §4.1:

1. `type linarith_instance` exactly as the plan's record (ty,
   discrete, dest bundle, kit bundle, norm_conv, pre_split,
   divmod_facts) and `type linarith_injection` (from_ty, to_ty, inj,
   hom lemmas).
2. Registry: `Sref`-held assoc list; `register_instance` replaces an
   existing same-type entry with `HOL_WARNING`; `instance_for :
   hol_type -> linarith_instance option`.  `register_injection` /
   accessor(s) for injections (lookup by from/to types and by
   injection constant — anticipate the consumers in §4.1 items a–c).
3. Settypes `"arith"` and `"arith_split"` (D61): both
   `export_with_ancestry` over `thm Symtab.table` keyed by
   `KernelSig.name_toString`, `REMOVE` support, standard collision
   guard; `"arith_split"`'s `apply_delta` validates the splitLib
   P-form shape on add (use `splitLib.rule_parts` or equivalent;
   rejection message names the offending theorem).  Accessors
   `arith_facts : unit -> thm list`, `arith_split_thms : unit -> thm
   list`; removal `remove_arith`, `remove_arith_split : string ->
   unit` writing `REMOVE` deltas.  No generation counters.
4. Config and trace: `type linarith_config = {neq_limit : int,
   split_limit : int}`; `default_config = {neq_limit = 9,
   split_limit = 9}`; `Feedback.register_trace ("linarith",
   trace_level, 3)` plus small trace-print helpers usable by the
   solver/replay modules (upstream `print_ineqs`/`trace_thm`
   equivalents; coordinate with what TASK_02 left as hooks —
   reconcile so exactly one trace variable named "linarith" exists).
5. `theory_tests/` under `src/auto/linarith/` (aesop pattern):
   base/child theory scripts asserting `[arith]`/`[arith_split]`
   declaration → visibility in a child theory → reload idempotence,
   and `remove_arith` writing `RM` deltas.  Add
   `!src/auto/linarith/theory_tests` to `tools/sequences/upto-auto`
   and to `tools/sequences/more-theories` (per §7).  Note: settypes
   need a theory context — if a `linarithScript.sml`-style anchor
   theory is required for `export_with_ancestry`, follow the aesop
   precedent (check how `aesopData` anchors its settype) and add the
   OpenTheory `.ot.art` block to the Holmakefile per §7.
6. ML-level selftest additions where sensible (registry replace
   warning, validation rejection of a non-P-form `[arith_split]`
   candidate).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green, including the
  new `theory_tests` sequence entry and selftest additions.
- Public `.sig` matches the freeze list of PLAN_phase_5.md §12 for
  `linarithData` (instance/injection types, `register_instance`,
  `register_injection`, `instance_for`, `arith_facts`,
  `arith_split_thms`, `remove_arith`, `remove_arith_split`; settype
  names `"arith"`, `"arith_split"`).
- `[arith]` ships empty; `[arith_split]` ships empty at this point
  (seeds come in a later task).
- Style rules respected; commit the work.
