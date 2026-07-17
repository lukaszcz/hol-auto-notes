# TASK_19 — Translation, typargs, `blastRule` (§6.2–§6.3)

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

Plan T17 (§6.2–§6.3): HOL4-goal/rule translation into prototerms with
per-constant typargs, and `blastRule.{sig,sml}` — lazy rule
acquisition from the Phase-0 claset, incl. the goal-directed
pseudo-rules and weak-elim warnings.

## Spec

Read first: `PLAN_phase_1_2.md` §6.2–§6.3, M-a/M-d/M-e/M-g/M-h/M-i
(§7); `.agent-files/research/phase12-blast-port.md` §4 (rule
conversion) and the typargs analysis; `.agent-files/sources/src/
Provers/blast.ML:185–195, 441–539`; `src/metis/folMapping.sml:456–512`
(the `with_types` precedent); `src/auto/rules/clasetLib.sml:61–77`
(swapped intros via elim nets).

1. Goal intake (§6.2): goal frees ↦ argument-less Skolems (M-e); goal
   type variables ↦ rigid `Free`; initial branch `mkGoal w :: asl` in
   list order, head-first, all `md = true` (M-d).  The four `TRANS`
   errors are vacuous (no schematic goals in HOL4) — document, don't
   port.
2. Typargs (M-a): per-constant, faithful — canonical order =
   `Type.type_vars` of the generic type of `prim_mk_const`
   (session-local cache), images under `Type.match_type`, encoded as
   `fromType` does (`blast.ML:185–195`): tyops ↦ `Const(name,[]) $ …`,
   goal tyvars ↦ `Free`, rule tyvars ↦ per-rule shared `Var` refs.
3. `blastRule`: candidates via the frozen Phase-0 unify-mode lookups
   over safe0/safep (safe list) and unsafe parts, `candidate_order`ed;
   conversion per report §4.7 — fresh Var refs per conversion; intro ⇒
   pattern `mkGoal C` + premise groups `[Goal(ci), qs…]` after
   `skoPrem`; elim ⇒ formula-variable-conclusion check, destructive
   `*False*` binding, `delete_concl` with weak-elim rejection and the
   Isabelle warning texts verbatim (`:441–463, 503–522`).
4. Goal-directed `==>`/`!` (M-g): the two blast-internal pseudo-rules
   (`Goal(p ==> q) ↦ [[Goal q, p]]`; `Goal(!x. P x) ↦
   [[Goal (P sko)]]`), not claset-visible.
5. Duplication: use `clasetRules.REV_DUP_ELIM_RULE` (TASK_17) for the
   γ-rule dup variant; drop the dead `dup_intr` arm with a comment
   citing `blast.ML:537–539` (M-h).
6. Unit tests: typarg encodings for polymorphic constants (golden);
   conversion goldens for representative seed rules (conj/disj/exists
   intro+elim, an iff rule); weak-elim warning + skip; pseudo-rule
   shapes; laziness (conversion happens per node/formula, cached).

## Acceptance criteria

1. `Holmake` + `./selftest.exe` pass in `src/auto/blast/`.
2. `bin/build -t --seq=tools/sequences/upto-auto` green.
3. Warning texts match Isabelle's verbatim (report §4.7 citations).
4. Style: h4pedant clean; no tabs/trailing whitespace; < 80 columns;
   Moscow-ML-portable.

## Dependencies

TASK_17, TASK_18.
