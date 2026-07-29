# TASK_05 — `clasetStep.rule_step` + differential tests

Plan: `.agent-files/PLAN_phase_4.md` §3.2 (D45); plan task T04.
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

Additive `clasetStep` export (Phase-2 freeze amendment D45),
wrapper-free, standard child policy, explicit unification mode:

```sml
val rule_step :
  {theorem : thm, elim : bool, mode : clasetUnify.mode} -> step
```

- Internals: the existing cascade rule-application path (canonical
  form, fresh metas for rule variables, conclusion/major-premise
  unification per `mode`, `clasetGoal.children`/`elim_children`,
  per-alternative `step_record` with instantiated-replay `action`) —
  **re-exported, not re-implemented**.  This is the
  `blast_rule_step` analogue minus `ExactBlastPrefixes`.
- Each alternative in the returned seq is one candidate rapp.
- If the forward builder (plan §5.3) needs non-consuming elim
  application at replay (`children` with `consumed = NONE` on an elim
  path), the companion additive *non-consuming* `clasetReplay` action
  lands here under the same gate.  Assess this now: implement it if
  the replay vocabulary cannot already express non-consuming elim.
- Differential selftests against `blast_rule_step` on intro/elim
  examples where the two policies agree.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

None (independently gateable).
