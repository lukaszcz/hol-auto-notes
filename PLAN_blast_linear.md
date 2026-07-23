# Plan: replace `blastRule` linear rule-cache scan

Date: 2026-07-23.  Branch: `isabelle-tactics`.  Parent plan: `PLAN.md`
§6.3 (BLAST).

## 1. The defect

`blastRule.cached` (`src/auto/blast/blastRule.sml:715`) resolves the
per-search rule cache with a whole-list linear scan:

```sml
fun cached (Cache {entries, hits, ...}) safe vars formula =
  case List.find
         (fn entry =>
            #safe entry = safe andalso
            same_vars (#vars entry, vars) andalso
            aconv (#formula entry, formula))
         (!entries) of ...
```

- `entries : entry list ref` is created once per `prove`
  (`blastSearch.sml:1432`), grows by `remember` (a plain cons, no
  eviction, `blastRule.sml:751`), and is consulted on **every** safe/unsafe
  formula expansion through `acquire` (`blastRule.sml:1150–1153`) — the
  hottest tableau operation.
- Each probe runs `same_vars` plus a full `aconv` (alpha-equivalence over
  the untyped prototerm) against every stored entry.

The result is Θ(n) work per lookup over a monotonically growing list, i.e.
≈ Θ(n²) over a search, with a term comparison as the inner constant. On the
deeper Pelletier goals (P34/P45, the M1 censored baselines) the rule cache
is the dominant per-node cost.

`cachedMeasured` (`blastRule.sml:727`, called from `acquireMeasured`
`:1325`) is the same scan with an interruption `checkpoint ()` woven in.
**Resolved (see `PLAN_remove_tower.md` §1/§7):** `cachedMeasured` is the
**production** cooperative-interruptibility lookup — it is reached from the
listed entry point `tableauLib.tryIt` via `searchGoalMeasured`, not part of
the timing tower — so it **survives tower removal and must receive the
identical fix**. Both `cached` and `cachedMeasured` are in scope here.

## 2. Why this is not a mechanical "use a Redblackmap"

The efficiency review suggested "a `Redblackmap` keyed by the formula
(`Term.compare`), bucketing on `(safe, vars)`". That is directionally right
but understates two real constraints, both specific to blast's term
representation (`blastTerm.term`, `blastTerm.sig:6`):

1. **The key is alpha-equivalence, not identity.** Matching uses
   `blastTerm.aconv`. `blastTerm.sig` exposes **no** `compare` and **no**
   hash (`blastTerm.sig:55` is the only comparison primitive). A
   `Redblackmap` needs a total order that is *consistent with the
   equivalence actually used*; supplying an order finer than `aconv`
   silently splits alpha-equal formulas into distinct keys and loses cache
   hits, while an order coarser than `aconv` collapses distinct formulas
   and returns wrong rules. There is no ready `Term.compare` here — these
   are `pterm`s, not kernel `term`s.

2. **Variable cells mutate during the search.** `var = term option ref`
   (`blastTerm.sig:15`); a cached `formula` can contain branch `Var` leaves
   whose ref contents are assigned by `unify` and rolled back by
   `clearTo`/trailing as the search advances and backtracks. `aconv`
   follows current ref contents, so any key computed from a *snapshot* of
   those contents is not stable across the entry's lifetime. This is
   precisely why the current code re-runs `aconv` live on each probe rather
   than hashing once. Any replacement must key on something invariant under
   the trail discipline, or must confine the mutation-sensitive part to a
   live `aconv` check.

So the design question is *what stable, cheap discriminator do we bucket
on so the residual live-`aconv` scan is over a handful of entries, not the
whole cache* — while keeping the returned rule set and its ordering
bit-for-bit identical to today.

## 3. Behaviour that must be preserved (freeze)

- **Equality semantics.** An entry matches iff
  `#safe = safe ∧ same_vars(#vars, vars) ∧ aconv(#formula, formula)` —
  unchanged.
- **Selection order.** `remember` conses newest-first and `cached` returns
  the *first* (newest) match. Downstream `copyRules` freshens whatever is
  returned; but to stay observably identical the replacement must return
  the **same** entry, i.e. the most-recently-remembered match. Any bucket
  must therefore retain newest-first order internally.
- **Per-search lifetime.** The cache is per-`prove`; no cross-search
  sharing, no eviction. `newCache`/`hitCount`/`conversionCount`
  (`blastRule.sml:47–51`, `blastRule.sig:26`) keep their signatures.
- **`copyRules` untouched** (`blastRule.sml:760`) — it is orthogonal.

## 4. Design options — **Option A chosen (2026-07-23)**

Decision recorded below (§4.1 rationale). Options B and C are the rejected
alternatives, retained so the choice is not re-litigated.

### Option A — bucketed entries by a mutation-stable head key — **CHOSEN**

Keep the equality exactly as-is; only change the container. Replace
`entries : entry list ref` with a
`Redblackmap` from a cheap **head key** to a newest-first `entry list`
(the per-bucket list), plus the residual live `aconv` scan *inside* the
selected bucket.

- **Head key** = derived from `head_of formula` (`blastTerm.sig:53`) and
  the two flags already in the equality:
  `key = (safe, length vars, head_tag formula)` where `head_tag` maps the
  head to a stable, orderable token:
  - `Const (name,_)` → `HConst name`
  - `Skolem (name,_)` → `HSkolem name`
  - goal head / `false_name` → their reserved names
  - `Bound i` → `HBound i`; `Abs` → `HAbs`
  - head is a `Var` (unbound metavariable) → single catch-all `HVar`
- **Stability.** A formula's *head symbol* does not change under variable
  binding unless the head itself is a metavariable; rule-triggering
  formulas are intros indexed by conclusion and elims by major premise, so
  their heads are overwhelmingly constants/skolems. The rare `HVar`
  catch-all bucket degrades to today's linear behaviour *for those entries
  only* — never worse than the status quo.
- **`cached`**: compute `key`, `Redblackmap.peek` the bucket (default `[]`),
  `List.find (aconv(#formula, formula))` within it (the `safe`/`vars`
  length are already fixed by the key; `same_vars` still checked to honour
  ref-identity of the var list). Returns the newest match — identical
  selection.
- **`remember`**: cons the new entry onto its bucket (newest-first
  preserved), `Redblackmap.insert` the bucket back.
- **Cost.** O(log #buckets) + O(bucket size) with one `aconv` per bucket
  member. Buckets partition by head constant, so bucket size is a small
  fraction of n on real goals; the quadratic collapses to near-linear.
- **New surface.** None in `blastTerm`. Entirely local to `blastRule`
  (`cache` datatype, `newCache`, `cached`, `remember`, and the twin
  `cachedMeasured` if it survives). `same_vars`/`head_of` already exist.
- **Risk.** Lowest: equality untouched, selection order preserved,
  worst-case equals today. The only correctness obligation is that
  `head_tag` is total and never assigns two aconv-equal formulas different
  keys — true because aconv-equal formulas share a head symbol (heads are
  compared by `aconv` structurally, and a bound/var head is folded into
  `HBound`/`HVar`).

### Option B — total order on `pterm`, key the map by the formula *(rejected)*

Add `blastTerm.compare : term * term -> order` consistent with `aconv`
(alpha-respecting, ref-content-following) and key a `Redblackmap` directly
by `(safe, formula)` with `same_vars` as a tie refinement.

- **Pro.** Fully associative lookup, no residual per-bucket scan.
- **Con.** Must prove `compare x y = EQUAL ⇔ aconv (x,y)` *and* stability
  under the trail mutation discipline (ordering by mutable ref contents is
  the trap of §2.2). This is a new, subtle, exported primitive that can
  silently lose or duplicate entries if inconsistent with `aconv`. High
  correctness burden for a per-search cache whose buckets under Option A
  are already tiny. Not recommended now; revisit only if profiling shows
  Option A's catch-all/bucket residue is material.

### Option C — structural hash + `aconv` within bucket *(rejected; fallback only)*

Add a `blastTerm` hash that ignores variable identities but respects
binding depth and head structure; bucket by hash; live `aconv` within.

- **Pro.** Finer buckets than Option A's head key.
- **Con.** A new `blastTerm` primitive (more surface than A), and hashing
  mutable-ref terms needs the same "ignore contents, use position" care as
  §2.2. Option A's head key already shrinks buckets to constant-headed
  groups; C's extra discrimination is unlikely to pay for its added
  surface. Fallback if Option A buckets prove too coarse on the benchmark.

### 4.1 Decision (2026-07-23): Option A

**Option A is the chosen implementation.** It is the dominating middle
ground — it captures essentially all of the asymptotic win, changes no
equality or ordering semantics, adds zero cross-module surface, and its
worst case is the current behaviour. B and C add exported term primitives
with a consistency-with-`aconv` proof obligation that A avoids entirely.
This matches the layer rule "general, principled, no pragmatic fixes"
(`src/auto/CLAUDE.md`): bucketing on the indexing head is the same
principle the netpairs already use, not a special case.

Options B and C are **rejected** and not to be re-litigated. Option C is
retained only as the explicit fallback **if and only if** the Task-4
benchmark shows Option A's head-key buckets are too coarse (§7 risk 4);
adopting it then is its own decision. Nothing in the task breakdown (§5)
implements B or C.

## 5. Task breakdown (dependency order)

Per-task gate: `Holmake` + `./selftest.exe` in `src/auto/blast/`, then
`bin/build -t --seq=tools/sequences/upto-auto`; `tools/h4pedant` on
`src/auto/blast/`.

| # | Task |
|---|---|
| 0 | *(Resolved — see `PLAN_remove_tower.md` §1/§7: `cachedMeasured` is production interruptibility, kept and fixed here.)* Re-verify at execution time that `cached` (`:715`) and `cachedMeasured` (`:727`) are the only two rule-cache scans and that both flow through `acquire`/`acquireMeasured`. |
| 1 | Introduce the `head_tag`/`key` helper and the bucketed `cache` datatype (`Redblackmap` of key → newest-first `entry list`), rewrite `newCache`/`cached`/`remember`. Keep `hitCount`/`conversionCount`/`copyRules`/`acquire` call sites unchanged (`cached`/`remember` keep their signatures). |
| 2 | Apply the same rewrite to `cachedMeasured` (production interruptibility, per Task 0): checkpoint preserved by polling once per bucket member — a cadence change from per-whole-list to per-bucket that only *reduces* polling and stays cooperative; document it. |
| 3 | **Behaviour-identity selftest**: assert that a batch of `remember`/`cached` sequences (including alpha-variants, differing `vars`, `safe` flips, and a `Var`-headed formula in the catch-all bucket) returns the *same* entry the linear version returns — a direct equivalence test against a reference linear oracle kept in the test. Add to `src/auto/blast/selftest.sml`. |
| 4 | **Micro-benchmark** (selftest, behind the existing higher `HOLSELFTESTLEVEL` gate): a synthetic cache of N constant-headed formulas, assert lookup count/time scales sub-quadratically vs the linear baseline. This documents the win without a fragile absolute budget. |
| 5 | Run the full blast parity suite (Pelletier 1–46, Table 1, set goals) — solved counts and the existing time budgets must be **unchanged or improved**; no proof may change (`BLAST_TAC` output identical). Record in this file. |
| 6 | Phase-boundary gate `bin/build -F -t` (only if any change lands outside `src/auto/`; here it does not, so this is the standard pre-merge full build). |

## 6. Selftests (`src/auto/blast/selftest.sml`)

1. **Equivalence oracle** (Task 3): the linear `List.find` predicate kept
   inline as `reference_cached`; a randomized-but-seed-fixed script of
   `remember`/`cached` operations asserts `new_cached ≡ reference_cached`
   entry-for-entry, including:
   - alpha-equal-but-not-identical formulas (same bucket, `aconv` hit);
   - same head, different `vars` length / `safe` (different bucket, miss);
   - two remembered matches → newest returned (order preservation);
   - `Var`-headed formula (catch-all bucket) still matches by `aconv`.
2. **No-regression**: existing blast proof batteries unchanged (they
   already exercise `acquire`/`cached` end-to-end).
3. **Scaling** (Task 4, higher level only): probe-count vs N is
   sub-quadratic.

## 7. Risks

1. **Head-key instability for `Var`-headed formulas.** Mitigation: the
   `HVar` catch-all preserves today's exact behaviour for that (rare)
   class; the equivalence oracle test covers it explicitly. Worst case =
   status quo, never worse.
2. **Selection-order drift.** A bucket that isn't newest-first would return
   a different (still `aconv`-equal) entry, which `copyRules` would freshen
   differently and *could* perturb a recorded replay script. Mitigation:
   cons-into-bucket keeps newest-first; the order-preservation assertion in
   Task 3 is the guard.
3. **Interaction with tower removal.** Both this plan and
   `PLAN_remove_tower.md` touch `blastRule`. Sequence: land tower removal
   first (it deletes code; smaller merge surface), then this. Task 0 is the
   explicit coordination point; if this lands first, keep `cachedMeasured`
   changes isolated so the tower-removal diff stays clean.
4. **Over-engineering.** Options B/C are deliberately deferred; do not add a
   `blastTerm` compare/hash unless the Task-4 benchmark shows Option A's
   buckets are too coarse. Recorded so a later pass doesn't re-litigate.

## 8. Interfaces

No signature changes. `blastRule.sig` is unchanged (`cached`/`remember`
are internal; only `newCache`/`hitCount`/`conversionCount`/`cache` are
exported and keep their types). No `blastTerm` surface added under the
recommended Option A. Nothing downstream (blastSearch, tableauLib) sees a
change beyond a faster cache.
