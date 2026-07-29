# TASK_21 — Phase gate: full build + freeze/register records

Plan: `.agent-files/PLAN_phase_4.md` §11 T15, §13; parent plan
register.  Read the plan file in full before starting — it is the
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

1. Full build: `bin/build -F -t` (explicit `-F`; bare `bin/build`
   reuses the previous `--seq`).  Fix any fallout.
2. Freeze-list record (plan §13): record as frozen the
   `rulespec`/`cdelta` v2 schema and per-kind `prio` semantics; the
   attribute surface incl. numeric-argument syntax; the `aesop_simp`
   settype; `clasetStep.rule_step` and `clasetMeta.absorb`
   signatures; the marker vocabulary incl.
   `Norm`/`Forward`/`SForward`; the public `aesopLib` signatures
   (`aesop_config`, the four tactics, `augment_aesop`,
   `cases_rule_for`).  Engine internals remain private.  Record it
   wherever earlier phase freezes were recorded (follow the existing
   convention in the parent plan / `.agent-files`).
3. Parent-plan register update: D44–D51 entries + the phase gate
   record, following the format of earlier phase closes.
4. Sanity audit: verify every plan-task deliverable is actually
   consumed (mechanisms called, not just present) — e.g. the index
   entry points, `absorb`, `rule_step`, markers, `aesop_ss` all have
   live call sites.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/` (the freeze/register records live in
  `.agent-files` and are gitignored — that is fine; committed files
  must not cite them).

## Gate (acceptance criteria)

- `bin/build -F -t` completes green.
- Freeze-list and register records written.
- `git diff --check` clean; working tree in a committable state.

## Dependencies

TASK_19 and TASK_20 (i.e. all other tasks).
