# TASK_10 — `process_tags` integration (`Split` / `Excl`), exclusion
# plumbing, splitter integration + RW_TAC parity selftests

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues of
Isabelle/HOL's proof automation that are **at least as strong** as the
Isabelle originals, with idiomatic HOL4 surface syntax.  Phase S
(`.agent-files/PLAN_phase_S.md`) upgrades the simplifier in
`src/simp/src/`; this task finishes the splitter integration: per-call
`Split th` markers, `Excl`-based exclusion, and the parity test suites
that demonstrate splitter strength.  Governing constraint: **all defaults
preserve current behavior**.

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T8, second half (§5.2 + §6.5 exclusion + §8 group 6 remainder):
marker/exclusion plumbing through simpLib and the remaining splitter
selftests, including the Isabelle-documentation examples and the RW_TAC
if-splitting parity suite.

## Spec

Read PLAN_phase_S §5.2, §6.5, §8 group 6, §11.2–11.3, and
`.agent-files/research/phaseS-hol4-splitting-idioms.md`.  Sources:
`src/simp/src/simpLib.{sig,sml}` (`process_tags`, `simpLib.sml:834–857`),
`src/simp/src/splitLib.sml`, `src/marker/markerLib` (TASK_05's
`Split`/`destSplit`).  For the ported documentation examples:
`.agent-files/sources/` Generic.thy splitter section
(`Generic.thy:1114–1118` area).

1. **`process_tags`** (§5.2):
   - `Split th` → `add_split th` on the invocation simpset;
   - `Excl "name"`: in addition to its current net/dproc filtering, if
     `name` matches a looper or solver name, remove it for the
     invocation; names of the form `split <thy$nm>` go into
     `excl_loopers` for the splitter to honor; `Excl "split.case ty"`
     excludes a type's TypeBase splits.  Both additive: no existing
     `Excl` string can match today.
   - Re-export the marker as `simpLib.Split` beside `Cong`/`AC`/`Excl`
     (`simpLib.sig:89–95`).
2. **Exclusion plumbing** (§6.5): the splitter looper skips rules whose
   looper name is in `excl_loopers` and case constants of types excluded
   as `split.case ty` (finish the hooks left by TASK_09).
3. **Selftests** (§8 group 6 remainder):
   - `Split th` marker per-invocation split (`SIMP_TAC ss [Split th]`);
   - `[split]` attribute round-trip if not already covered by TASK_09;
   - `Excl "split thy$nm"` and `Excl "split.case ty"` suppress splits;
     `Excl` of a looper/solver name removes it for the invocation;
   - ported examples from Isabelle's Generic.thy splitter documentation;
   - **RW_TAC parity**: a suite of goals `RW_TAC` solves via
     `IF_CASES_TAC` that `SIMP_TAC (bool_ss ++ split_ss)` must also
     solve (PLAN §5.2 obligation; see
     `phaseS-hol4-splitting-idioms.md` for the idiom inventory);
   - a looper-non-termination guard check: simpset `limit` bounds
     splitter rounds (§11.3).

## Acceptance criteria

1. All new and existing selftests pass.
2. No behavior change for any invocation not using `Split`/`Excl`
   splitter strings/`split_ss`.
3. `bin/build -t --seq=tools/sequences/upto-parallel` green.
4. Style: no tabs, no trailing whitespace, < 80 columns.

## Dependencies

TASK_05, TASK_06, TASK_09.
