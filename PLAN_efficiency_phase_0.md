# Plan (M1): Efficiency fixes for the claset library

Date: 2026-07-16. Branch: `isabelle-tactics` (off `origin/develop`).
Scope: `src/auto/rules/clasetLib.sml`,
`src/auto/rules/clasetRules.{sml,sig}`, and focused tests under
`src/auto/rules/`.

Three wasted-work findings surfaced by the `/simplify` efficiency pass.
The findings are valid, but each optimisation must preserve the current
claset semantics, including edge cases involving duplicate declarations,
deletions, and lazy global-state initialisation.

Line references are against commit `e39b4e83a`.

---

## Ground rules

- **Preserve observable claset behaviour.** Before and after each fix, retain:
  - the declarations returned by `rules_of`, including names, specifications,
    canonical theorems, declaration order, and indices observable through
    candidate tags;
  - safe and unsafe wrappers and their order;
  - the exact sequences returned by every
    `match_*_candidates`/`unify_*_candidates` query;
  - the order and content of non-claset leftovers returned by
    `process_claset_tags`; and
  - existing warnings for stale, ill-formed, duplicate, and cross-kind
    persistent declarations.
- The internal tree shape and raw insertion order of a `clasetNet.net` need
  not be structurally identical. `claset` and `claset_part` are abstract;
  extensional candidate contents and the public, sorted retrieval order are
  the relevant invariants.
- TypeBase contribution functions are value providers, not event callbacks.
  Document that they must be pure and deterministic and that the library does
  not guarantee their invocation count. This is the only intended relaxation
  of the former blanket "bit-for-bit" wording.
- Prefer removing redundant work at its source. Do not add a long-lived cache
  unless a measured follow-up demonstrates that the direct fixes are
  insufficient.
- Land F1, F2, and F3 as separate commits so each can be measured and reverted
  independently.
- Functional tests establish equivalence; a development-only work counter or
  benchmark establishes that an efficiency fix actually removes the claimed
  work. Do not use unstable wall-clock thresholds as CI assertions.

---

## F1 — Replace `marker_name`'s repeated full-claset sorts (HIGH)

### Where

`clasetLib.sml:637-647` (`marker_name`) and `:660-674`
(`process_claset_tags`).

```sml
fun marker_name cs =
  let
    fun already_used name =
      List.exists (fn (_, (name', _)) => name = name') (rules_of cs)
    fun find index =
      let val name = "__claset_marker_" ^ Int.toString index
      in if already_used name then find (index + 1) else name
      end
  in
    find 0
  end
```

### Why it is wasteful

Every `already_used` call evaluates `rules_of cs`. That calls `dest_decls`,
which folds the complete `byconcl` table and sorts all declarations. Finding
the `j`th consecutive marker name repeats that work for indices `0..j`.

For `k` successfully added consecutive markers on a claset of `N` rules, the
current path performs `O(k^2)` complete folds and sorts, or approximately
`O(k^2 * N log N)` comparison work. Duplicate marker theorems and `Del`
operations can change which names are occupied, so they must be included in
the semantic analysis even though `k` is normally small.

### Fix

Add a name-membership operation beside the existing declaration accessors:

```sml
(* clasetRules.sig *)
val decl_name_member : decls -> string -> bool

(* clasetRules.sml *)
fun decl_name_member (Decls {byname, ...}) name =
  Option.isSome (Symtab.lookup byname name)
```

Use it from `marker_name`, pattern matching the private `CS` constructor to
obtain `decls`:

```sml
val marker_prefix = "__claset_marker_"

fun marker_name (CS {decls, ...}) =
  let
    fun find index =
      let val name = marker_prefix ^ Int.toString index
      in
        if decl_name_member decls name then find (index + 1) else name
      end
  in
    find 0
  end
```

Keep `process_claset_tags`'s control flow unchanged. In particular, do **not**
thread a monotonically increasing counter through the batch.

This retains the current rule: every marker independently receives the lowest
currently unused non-negative marker index. It also handles all cases that
invalidate a monotonic allocator:

- an initial marker-name gap, such as marker `1` existing while marker `0` is
  free;
- an `add_rule` rejected because the same theorem and rule kind already exist;
  and
- a `Del` that makes a lower marker index reusable before a later marker.

The resulting worst-case marker allocation is `O(k^2 log(N+k))` `Symtab`
lookup work for consecutive markers. This is not asymptotically linear in
`k`, but it removes every full-claset fold and sort from the hot path while
preserving exact naming semantics. Since inline marker lists are normally a
handful of rules, this is the preferred complexity/robustness tradeoff.

### Equivalence argument

`byname` contains exactly the names represented in `byconcl`:

- `empty_decls` initializes both tables empty;
- `extend_decl` inserts the same accepted declaration into both;
- `remove_decl` removes that declaration from both; and
- `merge_decls` adds declarations only through `extend_decl`.

Therefore `decl_name_member decls name` is true exactly when the old
`List.exists` over `rules_of` found `name`. Each `marker_name` call returns the
same string as before. Because `process_claset_tags` itself is unchanged,
failed additions and deletions affect later allocation exactly as before.

### Validation

Keep the existing marker round-trip, `Del`, and leftovers-order tests. Add
focused regressions that assert names through `rules_of`:

1. Several distinct markers on `empty_cs` receive marker names `0..k-1`.
2. With marker `1` pre-existing and marker `0` free, two distinct new markers
   receive `0` and `2`; no requested rule is dropped.
3. Two equal marker theorems followed by a distinct theorem do not consume a
   name for the rejected duplicate; the successful rules are named `0` and
   `1`.
4. `Intro th1`, `Del "__claset_marker_0"`, `Intro th2` reuses marker `0` and
   leaves only `th2` under that name.
5. Non-claset leftovers remain in input order in all mixed cases.

During development, instrument or profile `dest_decls` and confirm that
processing markers no longer calls it for name allocation. Do not commit the
instrumentation.

---

## F2 — Incrementally apply ADD-only theory batches (MEDIUM)

### Where

`clasetLib.sml:355-401` (`apply_cdelta`, `update_decls`, `rebuild_claset`,
and `batch_apply`).

### Why the opportunity is real but conditional

For every batch, the current `batch_apply` first computes the final `decls`
table and then reconstructs all four netpairs from every surviving
declaration. A theory containing only `M` additions on top of `N` declarations
therefore reinserts all `N+M` declarations and sorts `dest_decls`, even though
`add_rule` already supports inserting only each accepted new declaration.

The same argument does **not** apply to arbitrary batches. `remove_rule`
deletes an index by applying `clasetNet.vfilter` throughout all four netpairs;
folding `R` removals incrementally can cost `O(R*N)` full-net traversal work.
One rebuild after updating the declaration table remains a safe bounded path
for removal-containing batches.

### Fix: a conservative two-path `batch_apply`

1. Factor the ADD-delta loading and guarded application enough that both
   single-delta replay and the add-only batch path use the same logic.
2. Preserve the warning source string used by each old path:
   `apply_cdelta` for single replay and `update_decls` for batch replay.
3. If a batch contains no `RM`, fold the guarded incremental ADD helper over
   the existing claset.
4. If a batch contains any `RM`, retain the existing `update_decls` plus
   `rebuild_claset` path unchanged.

Schematic structure:

```sml
fun apply_add_delta warning_source {name, spec} cs =
  case load_delta (ADD {name = name, spec = spec}) of
      NONE => cs
    | SOME (name', spec', th) =>
        let val pname = persistent_name name' in
          add_rule spec' (pname, th) cs
          handle HOL_ERR _ => drop_illformed warning_source pname cs
        end

fun apply_cdelta (ADD args) cs = apply_add_delta "apply_cdelta" args cs
  | apply_cdelta (RM name) cs = remove_rule name cs

fun is_removal (RM _) = true
  | is_removal (ADD _) = false

fun batch_apply deltas (cs as CS {decls, ...}) =
  if List.exists is_removal deltas then
    rebuild_claset
      (List.foldl (fn (delta, acc) => update_decls delta acc) decls deltas) cs
  else
    List.foldl
      (fn (ADD args, acc) => apply_add_delta "update_decls" args acc
        | (RM _, _) => raise Fail "batch_apply: impossible removal")
      cs deltas
```

Use a small local helper instead of an intentionally partial anonymous
function if that reads more clearly in the final SML. The `RM` branch is
unreachable because of the preceding check, but it must remain explicit for
exhaustiveness.

Keep `update_decls`, `rebuild_claset`, and `empty_netpair`; they remain needed
by the removal-containing path. A bulk-delete or index-set filtering design is
out of scope for this phase and should be considered only after measurements
show removal batches to be material.

### Equivalence argument: ADD-only path

- **Delta resolution and diagnostics:** both paths call the same `load_delta`
  once per delta, convert the same persistent name, catch the same `HOL_ERR`,
  and use the old batch warning source `update_decls`.
- **Declarations:** old `update_decls` and new `add_rule` both construct the
  same declaration and call `extend_decl` in delta order. Accepted,
  duplicate, cross-kind, stale, and ill-formed additions therefore leave the
  same `decls`, `next`, names, and indices.
- **Wrappers:** the old rebuild copies both wrapper lists unchanged; the new
  incremental fold also preserves them.
- **Net contents:** every accepted declaration receives the same unique index
  and is inserted into the same classified netpair(s). Existing entries are
  retained instead of reconstructed, but the extensional set of tagged rules
  is the same.
- **Retrieval order:** all public match and unify functions apply
  `candidate_order`, which sorts by `(weight, index)`. Indices are unique per
  declaration (with distinct doubled indices for primary/swapped entries), so
  insertion order cannot change the returned sequence.

For a batch containing `RM`, execution remains on the current code path, so
its behavior and complexity are unchanged.

### Validation

Private functions such as `batch_apply` cannot be called directly from
`selftest.sml` through the opaque `clasetLib` signature. Do not expose
production internals solely for a test. Instead:

- Keep the existing declaration, candidate-order, persistent-state,
  diamond-merge, removal, and reload tests.
- Extend `theory_tests/` with an ADD-only theory that contributes rules to
  safe-zero, safe-positive, unsafe, and duplicate netparts. In a child theory,
  check `rules_of` and match/unify candidate sequences, including equal-weight
  rules whose order depends on declaration indices.
- Retain or extend a mixed ADD/RM theory test to demonstrate that the rebuild
  path still handles removal precedence and reconstruction correctly.
- Exercise a duplicate ADD in the ADD-only theory and confirm the same warning
  and unchanged rule/candidate set.

For the efficiency witness, temporarily count calls to `add_decl` or net
insertion while loading a synthetic ADD-only chain. Confirm that a batch adds
only its accepted new declarations rather than reinserting all ancestors.
Record the before/after counts in the commit message; do not retain the
counter in production code. A wall-clock comparison may supplement the count
but is not a CI gate.

---

## F3 — Coalesce redundant TypeBase catch-up events at first demand (MEDIUM)

### Where

`clasetLib.sml:328-442` (pending state and `init_state`), `:465-484`
(`update_claset` and registration), and `:547-551` (the two module-load
registrations).

### Why it is wasteful

Each module-load `register_tyinfo_contribution` updates the contribution table
and queues `Modify catch_up_typebase` while the global claset is uninitialized.
The two built-in registrations therefore queue two consecutive full sweeps.
At first demand, `init_state` replays both and then calls
`catch_up_typebase` unconditionally a third time.

With no intervening claset update, the later sweeps are idempotent for pure,
deterministic contributions: `add_tyinfo_rule` tests `has_decls` by canonical
theorem before adding. They nevertheless re-run every contribution over every
`TypeBase` entry and repeat canonicalisation-based membership checks.

Simply declining to queue pre-initialization sweeps is not equivalent. A
queued claset modification can occur between a registration and first demand;
moving all TypeBase work to the end can change which declaration name wins a
same-theorem conflict. The optimisation must retain the relative position of
catch-up requests among other pending updates.

Runtime tracing adds one important constraint: in a real fresh process, the
two built-in catch-up requests are followed by further ancestry batches and
modifiers before first demand.  The first catch-up and the final repair are
therefore both semantically necessary.  Only the adjacent second request is a
redundant application.  A direct implementation of the boolean replay below
would reduce three provider scans and applications to two, not one.

### Fix: represent events explicitly and cache provider results

Extend `pending` with a distinguished constructor:

```sml
datatype pending =
    ApplyDelta of cdelta
  | ApplyBatch of cdelta list
  | Modify of (claset -> claset)
  | CatchUpTypeBase
```

When the state is initialized, registration still applies
`catch_up_typebase` immediately. When it is uninitialized, registration queues
`CatchUpTypeBase` at the same chronological position where it currently queues
`Modify catch_up_typebase`.

Factor TypeBase processing into two operations:

1. `collect_typebase_rules` traverses `TypeBase.elts`, invokes each
   contribution, and returns the rules in exactly the order in which the old
   nested folds applied them.
2. `apply_tyinfo_rules` applies an already collected list with the existing
   canonical-theorem deduplication.

At first demand, collect the final provider results exactly once.  Move
pending replay below these helpers, pass the collected list through it, and
track whether the current claset has been caught up since its last possible
mutation:

```sml
fun replay_pending typebase_rules [] (cs, caught_up) =
      if caught_up then cs else apply_tyinfo_rules typebase_rules cs
  | replay_pending typebase_rules (update :: updates) (cs, caught_up) =
      (case update of
           CatchUpTypeBase =>
             if caught_up then
               replay_pending typebase_rules updates (cs, true)
             else
               replay_pending typebase_rules updates
                 (apply_tyinfo_rules typebase_rules cs, true)
         | ApplyDelta delta =>
             replay_pending typebase_rules updates
               (apply_cdelta delta cs, false)
         | ApplyBatch deltas =>
             replay_pending typebase_rules updates
               (batch_apply deltas cs, false)
         | Modify f =>
             replay_pending typebase_rules updates (f cs, false))

fun init_state (state as (cs, initialised, pending)) =
  if initialised then state
  else
    let val typebase_rules = collect_typebase_rules ()
    in
      (replay_pending typebase_rules (List.rev pending) (cs, false), true, [])
    end
```

The actual implementation may factor the cases differently, but it must keep
these state transitions:

- a catch-up applies the cached list and sets `caught_up = true`;
- an adjacent catch-up with no intervening claset transformation is skipped;
- every `ApplyDelta`, `ApplyBatch`, or `Modify` conservatively sets
  `caught_up = false`; and
- the end of replay reapplies the same cached list exactly when the last
  pending transformation may have made the derived TypeBase rules stale.

Registration should update the contribution table first, then update the
global state in one `#update_global_value` call:

```sml
fun request_typebase_catchup (cs, initialised, pending) =
  if initialised then (catch_up_typebase cs, true, [])
  else (cs, false, CatchUpTypeBase :: pending)

fun register_tyinfo_contribution entry =
  (tyinfo_contributions := update_alist entry (!tyinfo_contributions);
   #update_global_value adresult request_typebase_catchup)
```

Add a signature comment stating that a contribution must be pure and
deterministic. Its result for a given `tyinfo` may be evaluated more than once,
and invocation count and timing are not public API guarantees.

### Equivalence argument

For a pure deterministic contribution table, collecting once is equivalent to
every old catch-up evaluating the providers again:

1. All pending catch-up closures are replayed only at first demand, after the
   contribution table and `TypeBase` have reached the same final values seen
   by `collect_typebase_rules`.
2. Each pure deterministic contribution returns the same ordered rule list
   for the same `tyinfo` on every old invocation.
3. `rules_for_tyinfo` and `collect_typebase_rules` preserve the old nesting
   order: TypeBase entries, then contribution-table entries, then each
   contribution's rule list.
4. Applying that cached list at a catch-up point therefore produces the same
   declarations, names, indices, and warnings as recomputing the list there.

The replay skips an application only after a preceding application and before
any other pending transformation. Any delta, batch, or arbitrary modifier
invalidates `caught_up`, even if it happens to be harmless, so the next
requested or final application still runs. Consequently:

- the first catch-up remains at the same chronological position relative to
  persistent and temporary updates;
- a modification after a catch-up is still followed by a later catch-up, as
  under the old unconditional final sweep;
- conflicts, removals, generated names, declaration indices, and final
  candidate order are preserved; and
- real startup performs one TypeBase/provider collection scan, applies the
  cached list at the first built-in request, skips the adjacent request, and
  reapplies the cached list after later pending mutations.

The number of applications cannot safely fall to one without changing
chronological conflict winners or adding substantially more mutation
tracking.  The provider scan does fall from three to one; cached membership
applications fall from three to two.  The number of calls into contribution
functions is intentionally not preserved, and the documented
purity/determinism requirement makes that count non-observable API behavior.

### Validation

- Keep the existing test that TypeBase facts are present at first demand and
  the existing duplicate-registration rule-count test.
- Add a fresh-process first-demand test using pure test contributions. Cover
  these ordering-sensitive cases:
  1. register a contribution, queue a temporary same-theorem declaration with
     a different name, then demand the claset and assert the same winner as the
     current implementation;
  2. register a contribution, queue deletion of its generated name, then
     demand the claset and assert that the final catch-up restores the derived
     rule; and
  3. place two registrations consecutively and assert that both contributed
     rule sets are present exactly once.
- Run `theory_tests/reloadCheck` to ensure datatype reloads still do not
  duplicate TypeBase-derived rules.

During development, count provider collection and cached application passes in
a fresh initial demand. Confirm the change from three provider scans and three
applications to one provider scan and two cached applications. Do not retain a
production counter.

---

## Sequencing and interactions

The fixes remain independently reviewable. Recommended order:

1. **F1:** smallest public-data-structure addition and exact marker regressions.
2. **F3:** localized lazy-state change with fresh-process ordering tests.
3. **F2:** load-path fast path after the functional coverage is strongest.

F1 adds `decl_name_member` to `clasetRules.{sig,sml}`. F2 retains
`update_decls`, `rebuild_claset`, and `empty_netpair`. F3 changes the private
`pending` datatype and the location/shape of pending replay but does not alter
the serialized `cdelta` format or ancestry data.

After each commit:

1. Run
   `(cd src/auto/rules && ../../../bin/Holmake
   --holstate=../../../bin/hol.state0)`.
2. Run `src/auto/rules/selftest.exe` and inspect warnings as well as exit
   status.
3. Run Holmake in `src/auto/rules/theory_tests` so the reload executable is
   exercised in a fresh process.
4. Run `bin/build -t --seq=tools/sequences/upto-auto` for cross-theory coverage.
5. Run `h4pedant` on every changed SML/signature file.

## Definition of done

- All functional and cross-theory tests pass, including the new marker-gap,
  duplicate-marker, deletion/reuse, ADD-only batch, mixed batch, TypeBase
  first-demand, and TypeBase ordering cases.
- F1 performs no `dest_decls` call for marker-name allocation.
- F2 inserts only accepted new declarations for ADD-only batches and retains
  the rebuild path for every batch containing an `RM`.
- F3 performs one TypeBase/provider collection scan on the ordinary
  first-demand path and reapplies the cached ordered rules after every
  intervening pending claset transformation.
- Public documentation states the TypeBase contribution purity/determinism
  requirement and disclaims callback invocation-count guarantees.
- Before/after work counts are recorded in the corresponding commit messages;
  no profiling hooks or counters remain in production code.
- `selftest.sml`, `theory_tests/`, `upto-auto`, and `h4pedant` are green.
