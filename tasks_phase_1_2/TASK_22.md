# TASK_22 — `tableauLib`: `BLAST_TAC`, config, `tryIt` (§6.6)

## Context

The overall project (`.agent-files/PLAN.md`) implements HOL4 analogues
of Isabelle/HOL's proof automation that are **at least as strong** as
the Isabelle originals, with HOL4-idiomatic uppercase names.  Phases
1–2 (`.agent-files/PLAN_phase_1_2.md`) build the classical reasoner in
`src/auto/classical/` and `src/auto/blast/` on top of the Phase-0
claset infrastructure (`src/auto/rules/`): a shared typed-metavariable
search engine (store, unifier, goals, step cascade, replay, drivers),
public tactics `SAFE_TAC`/`CLARIFY_TAC`/`FAST_TAC`/…/`DEEPEN_TAC`,
and a faithful port of Isabelle's blast (`BLAST_TAC`).

Any work done in this task must be a step toward these goals, but the
ultimate plan goals are **not** the acceptance criteria for this task —
only the criteria listed below are.

## Objective

Plan T20 (§6.6): the public blast surface — `BLAST_TAC`,
`BLAST_DEPTH_TAC`, `depth_limit`, `tryIt`, marker processing,
trace/stats.

## Spec

Read first: `PLAN_phase_1_2.md` §6.6, M-l (§7), §4 (marker
processing, mirrored here); `.agent-files/research/
phase12-blast-port.md` §7 (limitations table) and the `tryIt`/stats
analysis (M-h).

1. Exports per §6.6: `BLAST_TAC : thm list -> tactic`
   (`DEEPEN(1, !depth_limit)`); `BLAST_DEPTH_TAC : int -> thm list ->
   tactic` (fixed bound — the `(blast n)` analogue, what `AUTO_TAC`
   will call in Phase 3); `depth_limit : int ref` (default 20);
   `tryIt` (debug: trace + recorded script, no reconstruction —
   shape per the ported original).
2. Markers processed as in `classicalLib` (unconsumed plain theorems
   ⇒ unsafe intros; `Cong`/`Excl`/`SF` pass through).
3. `Feedback.register_trace "blast"`: level 1 = PROOF FAILED +
   weak-elim warnings; 2 = stats (branches created/closed, search vs
   reconstruction time — `blast_stats` parity); 3+ = full trace.
4. No claset/theory state leaks on success or failure.
5. Smoke tests (the corpus is TASK_23): a few golden goals through
   `BLAST_TAC []` under `Tactical.VALID`; `BLAST_DEPTH_TAC` bound
   respected (fails below the needed depth); extra-lemma argument
   used; trace levels produce output without exceptions.

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Exported names/signatures per §6.6; `BLAST_TAC` name matches the
   §2 collision-checked list.
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_21.
