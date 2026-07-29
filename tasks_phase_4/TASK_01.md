# TASK_01 — HolLex attribute-value tweak + unsafe-attribute percent parsing

Plan: `.agent-files/PLAN_phase_4.md` §3.1 (D47, enacts D12); plan task T01.
Read the plan file in full before starting — it is the authoritative spec;
this task file is a pointer, not a replacement.

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

1. `tools/parsing/HolLex`: extend `attributeValue` to admit
   digit-leading tokens (additive); regenerate the lexer.  Existing
   scripts must be unaffected.
2. `clasetLib.register_rule_attribute`: for `intro`/`elim`/`dest`,
   parse `args` as one optional integer in `[1,100]`
   (`Int.fromString`; anything else is a clean error naming the
   attribute); build `{kind, safe = false, prio = SOME n}`.
3. `sintro`/`selim`/`sdest` keep rejecting arguments; update the
   message to say safe-rule priorities are not supported (drop any
   "later phase" wording).
4. Selftests: replace the args-rejection lock for the unsafe
   attributes with round-trip tests (`Theorem foo[intro=75]` ⇒ delta
   carries `SOME 75`); keep the rejection lock for the safe three.

`temp_add_rule`/`export_rule` already accept full `rulespec`s — no
change there.

## Notes

- Committed code, comments, and docs must not reference
  `.agent-files/`.
- Style: no tabs, no trailing whitespace, < 80 columns.

## Gate (acceptance criteria)

- Focused `Holmake` + `selftest.exe` in the touched directories pass
  (plain `Holmake` suffices for `src/auto/*`; regenerate and rebuild
  the lexer for `tools/parsing`).
- `tools/h4pedant` over touched files; `git diff --check` clean.
- `bin/build -t --seq=tools/sequences/upto-auto` green.

## Dependencies

None (independently gateable).
