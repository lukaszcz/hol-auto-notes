# TASK_04 — Aesop index in `CS` + candidate entry points

Plan: `.agent-files/PLAN_phase_4.md` §3.4 (D46); plan task T03.
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

Non-persisted field on the claset record (pre-authorized by
`PLAN_phase_0.md` §6.1):

```sml
type aesop_index =
  {target : aentry clasetNet.net,   (* keyed by conclusion *)
   hyp    : aentry clasetNet.net}   (* keyed by major premise /
                                       last immediate premise *)
```

`aentry` carries `{name, spec : rulespec, tag, thm}`.

- Keying: Intro (safe+unsafe) by conclusion; Elim/Dest/Forward by
  major premise; Norm by conclusion of the canonical rule.
- Maintenance: built incrementally in `add_decl`; rebuilt by
  `vfilter` on removal; merged by replaying `decl_merge_order` (same
  discipline as the netpairs).
- New additive, `rulespec`-carrying lookup entry points:

```sml
val aesop_target_candidates :
  claset -> {q : term, qvars : term HOLset.set} ->
  (rulespec * (string * thm)) list
val aesop_hyp_candidates : (* same type *)
```

  unify-mode (`clasetNet.unify`); candidate order = `(prio-derived
  rank, weight, recency)` for unsafe, claset candidate order for
  safe.  Match locations are recovered by the caller (hyp-side query
  is per assumption).

Selftests: index retrieval (target/hyp sides, metavariable-containing
queries), candidate-order locks, add/remove/merge maintenance.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_02 (schema v2 kinds; the index routes and carries `rulespec`
with Forward/Norm).
