# TASK_02 — `linarithSolve`: datatypes, FM core, `prove`; unit tests

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

- `.agent-files/PLAN_phase_5.md` §2.1, §4.2, §8 item 1, §11.
- `.agent-files/sources/src/Provers/Arith/fast_lin_arith.ML` in full
  — the port target.  Key regions: `injust`/`lineq` 191–202; FM core
  225–349; `integ`/`mklineq` 510–541; `mknat` 549–553;
  `split_items`/`elim_neq` 574–629; `refutes`/`refute`/`prove`
  631–681.
- `src/portableML/Arbint.sig`, `src/portableML/Arbrat.sig`.
- `src/tools`-independent testutils usage: any `selftest.sml` in
  `src/auto/*` for the `tprint`/`OK`/`die` pattern.

## Work items

Create `src/auto/linarith/linarithSolve.sml` + `.sig` — a faithful
port of the untrusted core, per PLAN_phase_5.md §4.2:

1. Datatypes: `lineq_type = Eq | Le | Lt`; `injust` with `Asm`,
   `Nonneg` (generalizes upstream `Nat`), `LessD`, `NotLessD`,
   `NotLeD`, `NotLeDD`, `Multiplied`, `Added`; `lineq` over
   `Arbint.int` coefficients.  Also the `decomp` result type used
   across modules: relation datatype `REL_LE | REL_LT | REL_EQ |
   REL_NEQ` plus a `negated` flag and `Arbrat` coefficient data (this
   is the recorded deviation from upstream's strings — see §4.2).
2. FM core mirroring upstream one-for-one: `find_add_type`,
   `multiply_ineq`, `add_ineq`, `elim_var`, `is_trivial`,
   `is_contradictory`, `calc_blowup`, `extract_first`, `elim` —
   including pivot heuristics (equations first, minimal |coeff|,
   blowup-minimizing).
3. `integ` (Arbrat→Arbint scaling by denominator LCM), `mklineq`
   (upstream 521–541: discrete `<` ↦ `≤ c−1` via `LessD`, discrete
   `¬≤` ↦ `NotLeDD`, dense strict), `mknonneg` (the `Nonneg`
   generalization of upstream `mknat`).
4. `elim_neq`/`split_items` (upstream 574–629) with the recorded fix:
   each `≠`-premise selects its `neqE` by the premise's type (the
   selection is parameterized — this module has no registry access;
   take a by-type discrimination function/argument).  Preserve the
   two-pass structure (discrete types first) so case order matches
   later replay order.
5. `prove : linarith_config -> (term -> decomp option) -> term list
   -> term -> bool * injust list option` per upstream 658–681 (config
   type may live here temporarily or be taken as a record argument;
   `linarithData` will own the public config type — coordinate via a
   plain `{neq_limit : int, split_limit : int}` record).
6. Trace hooks: accept a trace-level accessor or use
   `Feedback.get_tracefn "linarith"` guarded — keep it compiling
   standalone; final trace registration lives in `linarithData`.
   (If simpler: gate on a locally registered trace and let
   `linarithData` re-use it later; record the choice in a comment.)
7. ML-level unit selftests in `src/auto/linarith/selftest.sml`
   (PLAN_phase_5.md §8 item 1): known systems with expected `injust`
   shapes; blowup pivot choice; equation-first pivoting;
   trivial/contradictory detection; `neq_limit` boundary behavior of
   `prove` (limit exceeded ⇒ `≠` premises ignored, not failure —
   upstream 670–673).

Mosml portability: no native `int` coefficients anywhere in row data
— `Arbint`/`Arbrat` only (indices may be `int`).

## Acceptance criteria

- `bin/build -t --seq=tools/sequences/upto-auto` green; the new unit
  tests run in the linarith selftest and pass.
- `linarithSolve` has a `.sig` exposing exactly what later modules
  need (datatypes, `elim`, `integ`/`mklineq`/`mknonneg`,
  `elim_neq`/`split_items`, `prove`); no `open`-polluting surface.
- Faithful correspondence: each ported function carries a brief
  comment naming its upstream source lines only where the port
  deviates (deviations: `Nonneg`, relation datatype, by-type `neqE`
  selection).
- Style rules respected (no tabs, no trailing whitespace, < 80 cols).
- Commit the work.
