# TASK_09 — `aesopRule` core: rule model + apply/constructors/simp builders

Plan: `.agent-files/PLAN_phase_4.md` §4.2 (rule model, sources 1, 5,
and the claset-rule assembly), §5.1, §5.2, §5.5; first half of plan
task T08.  Read the plan file in full before starting — it is the
authoritative spec; this task file is a pointer, not a replacement.

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

`src/auto/aesop/aesopRule`:

1. The rule model exactly as plan §4.2:

   ```sml
   datatype rphase = RNorm of int | RSafe | RUnsafe of int
   datatype rapply =
       EngineStep of clasetStep.step
     | RenderedTactic of NTactical.ntactic
     | MultiStep of clasetStep.step list
   type rule = {name : string, phase : rphase, apply : rapply,
                once : bool}
   ```

2. Rule assembly from the invocation claset (via the TASK_04 index):
   claset Intro/Elim/Dest — safe → `RSafe` in claset candidate
   order; unsafe → `RUnsafe (prio | 50)` (D48 default); application
   = `clasetStep.rule_step` (mode chosen by the caller per goal, see
   plan §4.4).  Swapped/dup variants are **not** used by aesop.
3. Builders:
   - **apply** (§5.1): `rule_step {theorem, elim = false, mode}`;
     unification-only witness finding.
   - **constructors** (§5.2): `MultiStep` bundling intro
     applications of a theorem list (programmatic registration).
     Unsafe by default; safe registration allowed (dynamic §2.7
     check enforced later in the search task).  Document the
     Lean-divergence note from the plan.
   - **simp** (§5.5): the built-in simp norm rule over
     `aesopData.aesop_ss()`; per-invocation `Simp` args join the
     invocation simpset via existing `classify_simp_args` machinery.
   - **built-in closers**: assumption/contradiction closers (safe,
     ordered first).
4. Fixed safe order (plan §4.2 end): closers, safe0 claset rules,
   safe forward, safep claset rules, conclusion splits, assumption
   splits — encode the ordering scaffold now; forward/split entries
   are populated by TASK_10.
5. Selftests: priority defaulting (D48), safe-order lock, builder
   sanity on small examples (candidate rules produced with expected
   phases/percents).

Forward/destruct/cases/tactic/split builders are **out of scope** —
they are TASK_10.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in `src/auto/aesop` (and any
  other touched dirs) pass.
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

TASK_02 (schema v2), TASK_04 (aesop index), TASK_05 (`rule_step`),
TASK_08 (`aesopData`, dir scaffolding).
