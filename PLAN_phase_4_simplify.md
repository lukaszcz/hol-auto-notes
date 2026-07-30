# Phase 4 simplify plan — `/simplify` findings deferred from the aesop pass

Date: 2026-07-30.  Branch: `isabelle-tactics`.  Parent plan:
`PLAN_phase_4.md` (amends D45 §3.2/§5.3, D46 §3.4, D50 §6).

The `/simplify` pass over `origin/isabelle-tactics...HEAD` (21 commits,
the aesop layer) applied the mechanical cleanups directly (§5) and
deferred three items as owner decisions.  Those decisions were taken
one-by-one on 2026-07-30 (D52–D54, §0.1) and this plan implements them.

All `src/…:line` references were verified on 2026-07-30 against the
tree *after* the `/simplify` fixes of §5 landed, so line numbers differ
from those in `PLAN_phase_4.md`.

---

## 0. Owner decisions

### 0.1 Taken 2026-07-30 (record in `PLAN.md` §2 as D52–D54)

| # | Decision |
|---|---|
| **D52** | **The D45 non-consuming elim umbrella closes unused.**  D45 authorised an additive non-consuming elim replay action in `clasetReplay` *"if implementation requires it"* (`PLAN_phase_4.md` §3.2, §5.3).  The forward builder did not require it — §5.3's forward path ships through `FORWARD_RULE_TAC` — so `NONCONSUMING_ELIM_RULE_TAC`, `nonconsuming_elim_rule_action`, the `retain_major` parameter they forced into the shared `rule_tac_with`, and their selftest are all removed.  Rationale: a replay primitive that only a test drives is untested where it matters, and the parameter is a special case in shared infrastructure serving a non-caller.  **Consequence, accepted**: a future rule family wanting elim-style children while retaining the major assumption rebuilds it (cheaply — the parameter is one line of `rule_tac_with`), and the test pinning those semantics is lost. |
| **D53** | **`SearchFailed`'s safe-goal report becomes a thunk.**  `safe_goals : (gid * cgoal) list` becomes `safe_goals : unit -> (gid * cgoal) list`.  The second full safe search stays available and unconditional to anyone who asks, and costs nothing to the callers that discard it — which today is both production failure branches in `aesopLib.close_raw`.  Rejected: gating on the `aesop` trace level (the field would silently mean two things, and a caller legitimately wanting the frontier would have to enable tracing); a `report_safe_goals` config flag (a boolean whose only job is to disable work, and it moves the tested `default_config` record). |
| **D54** | **The claset precomputes its Norm declaration list; Norm leaves the aesop net.**  `CS` gains a `norm_decls` field maintained by the same five paths that maintain the netpairs, exposed as `clasetLib.norm_rules_of`.  `insert_aesop_decl` stops indexing Norm, and `aesop_class`/`norm_rank`/`compare_aentry` lose their Norm arms.  Rationale: the per-assembly `rules_of` scan is O(all declarations) on the hot path and grows with the global claset, while the Norm net entries were retrieved, sorted and deduplicated on every goal expansion only to be filtered out by every consumer.  Rejected: index-driven Norm retrieval — `aesopNorm.normalise` fetches its rule list once and reuses it across the fixpoint while the goal is rewritten, so conclusion-indexing against the initial goal would drop norm rules that become applicable only after an earlier norm step (a strength regression the existing restart-after-success test would not catch).  **Consequence, accepted**: `aesop_target_candidates` narrows to Intro rules; its `clasetLib.sig` contract comment, `PLAN_phase_4.md` §3.4, and three `rules/selftest.sml` tests change (§3.4). |

### 0.2 Decided in this plan (not owner-level)

- **`norm_rules_of` returns `dest_decls` order, not insertion order.**
  `claset_rules_core` currently takes
  `List.filter norm_declaration (rules_of claset)`, and
  `aesopNorm.ordered_rules` sorts that by penalty with a *stable*
  index tiebreak.  So the incoming order is observable for two Norm
  rules of equal penalty.  `add_decl` therefore inserts into
  `norm_decls` at its `clasetRules.decl_order` position rather than
  appending, and §3.3 adds the test that pins the equivalence.
- **`norm_decls` stores `decl`, not `(rulespec * (string * thm))`.**
  `remove_rule` deletes by tag index exactly as the netpairs do, and
  `norm_rules_of` projects on read.  Storing the projection would need
  a second name→index lookup on removal.
- **O(#norm) insertion per declaration is accepted.**  It is
  declaration-time cost proportional to the number of *Norm* rules
  (a rare kind), traded against an O(all declarations) scan on every
  goal expansion.  No generation counter or memo cell is introduced —
  a `ref` inside `CS` would be shared across the persisted copies.
- **The `frontier ()` thunk is not memoised.**  With tracing at level 1
  or above the report path calls it once and a consumer may call it
  again.  Documented in the sig; memoising would need a mutable cell in
  an otherwise pure outcome value.
- **`report_failure` gains a `traced 1` guard.**  It only ever traced,
  but built its argument eagerly; the guard makes D53's saving real on
  the default trace level.  Uses the `traced` predicate added in §5.
- **No new `Docfile` entries.**  D52 removes an undocumented internal
  primitive; D53 and D54 change types on engine-internal signatures.
  `help/Docfiles/aesopLib.*.smd` are unaffected — verify with §4.3.

### 0.3 Correction to the review that produced this plan

The `/simplify` efficiency pass initially proposed making Norm
retrieval index-driven, on the reasoning that `rule_index_of Norm` is
the rule's conclusion and `rule_step {elim = false}` applies it to the
target, so the index filter would be sound.  **That reasoning is wrong
and D54 must not act on it.**  Verified at `aesopSearch.sml:280` and
`aesopNorm.sml:153-187`: `next_safe_with` computes
`#norm (source (rule_input clasetUnify.Match initial_goal))` **once**
and hands that list to `normalise`, whose `scan` restarts from
`ordered` after every success while the goal has been rewritten.  A
rule indexed against the initial conclusion is therefore not the same
set as a rule applicable at iteration *k*.  Index-driven Norm
retrieval is only sound if retrieval moves *inside* the fixpoint, one
query per iteration — a strength-neutral but per-iteration-costlier
design that is **out of scope here** and noted in §6.

---

## 1. Scope

Three independent changes, no shared code between them; they may land
as three commits in any order.  §5 records what already landed.

**Status: all three implemented 2026-07-30.**  Deviations from the
prose below, all in the test plan:

- §4.6 lists three `rules/selftest.sml` tests to change; a **fourth**,
  `"aesop index follows add, remove, and merge maintenance"`
  (selftest.sml:1711), also asserted Norm through the index.  Its Norm
  assertions moved to `norm_rules_of`, and it now additionally pins that
  Norm appears in *neither* index side.
- §4.6's first row proposes `not (has_aesop_name "aesop_norm" target)`
  where `target` queries `p /\ q`; that passes vacuously, since the Norm
  rule's conclusion is an equality and never unified with `p /\ q` even
  under the old index.  The test keeps the `p = q` query (renamed
  `norm_shaped`) — the query that *did* retrieve the rule before — and
  asserts the exclusion there as well.
- §4.2's `insert_norm_decl` needs `clasetRules.decl_order`, which was
  not exported.  `clasetRules.sig` gains it (additive).

| Item | Files | Direction |
|---|---|---|
| D52 | `src/auto/classical/{clasetReplay.sig,clasetReplay.sml,selftest.sml}` | deletion only |
| D53 | `src/auto/aesop/{aesopSearch.sig,aesopSearch.sml,selftest.sml}` | type narrowing |
| D54 | `src/auto/rules/{clasetLib.sig,clasetLib.sml,selftest.sml}`, `src/auto/aesop/aesopRule.sml` | claset field + API narrowing |

---

## 2. D52 — remove the non-consuming elim replay action

### 2.1 `clasetReplay.sig`

Delete two blocks:

- lines **80–88**: the `NONCONSUMING_ELIM_RULE_TAC` comment and `val`
  (keep the `FORWARD_RULE_TAC` block that follows at 86–92).
- lines **124–128**: the `(* Replay-action form of
  [NONCONSUMING_ELIM_RULE_TAC]. *)` comment and
  `val nonconsuming_elim_rule_action` (keep `forward_rule_action`).

### 2.2 `clasetReplay.sml`

1. **`rule_tac_with` (line 330)** — drop the `retain_major` parameter:

   ```sml
   fun rule_tac_with function_name make_children
       {theorem, elim, consumed, parameters, eigenvariables} (asl, w) =
   ```

2. **lines 388–390** — restore the unconditional delete, keeping the
   `function_name` (not the literal `"RULE_TAC"`) that the aesop pass
   correctly introduced:

   ```sml
         in
           ([major_thm], tl premises0,
            delete_nth function_name asl major_pos)
         end
   ```

3. **line 433** — `rule_tac_with "RULE_TAC" ordinary_rule_children fields`.
4. **lines 435–440** — delete `NONCONSUMING_ELIM_RULE_TAC` entirely.
5. **line 504** — `rule_tac_with "BLAST_RULE_TAC" make_children {…}`.
6. **lines 786–787** — delete `nonconsuming_elim_rule_action`.

`ordinary_rule_children` (line 426) **stays**: it is shared by
`RULE_TAC` and is the extraction the aesop pass made to avoid an inline
lambda.  It now has one call site, which is fine — it names the
standard child policy that `BLAST_RULE_TAC` deliberately overrides.

### 2.3 `src/auto/classical/selftest.sml`

Delete the whole test at **3200–3226** (`"nonconsuming elim replay
retains its selected major assumption"`), including the
`consuming_children` binding it uses for contrast.  The consuming
behaviour it contrasted against is already covered by the
`clasetReplay.RULE_TAC` elim cases immediately above it (3160–3198) and
by the `consumed_of … = [SOME 1, SOME 2]` assertion at 3196.

### 2.4 Grep gate

After the edit, `grep -rn "NONCONSUMING\|nonconsuming\|retain_major"
src/ tools/` must be empty.

---

## 3. D53 — thunk the safe-goal report

### 3.1 `aesopSearch.sig`

Lines **34–38**, plus the comment at 44–46:

```sml
  datatype search_outcome =
      SearchProved of tree
    | SearchFailed of
        {tree : tree, safe_goals : unit -> (gid * cgoal) list,
         reason : failure_reason}
```

Replace the existing comment with one that states the cost, because the
thunk is the whole point of the type:

```sml
  (* [safe_goals] runs a fresh safe-only saturation of the original
     goal and returns its exact residual frontier, as [safe_frontier]
     would.  That is a second search, so it is deferred: a caller that
     only needs to know the search failed never pays for it.  Not
     memoised -- each application recomputes. *)
```

### 3.2 `aesopSearch.sml`

1. **lines 38–40** — mirror the datatype change.
2. **`report_failure` (line 535)** — take the thunk and guard, so the
   default trace level computes nothing:

   ```sml
   fun report_failure reason frontier =
     if not (traced 1) then ()
     else
       let val safe_goals = frontier ()
       in
         trace 1
           (fn () =>
             reason_string reason ^ "; " ^
             Int.toString (length safe_goals) ^ " safe goal(s)");
         List.app
           (fn (id, cgoal) =>
             trace 1
               (fn () =>
                 "safe goal " ^ Int.toString id ^ ": " ^
                 cgoal_string cgoal))
           safe_goals
       end
   ```

   (`traced` was added in §5; `trace`'s own level test then never
   fires false here, which is harmless.)

3. **`failed` (lines 557–566)** — build the thunk once and share it
   between the report and the outcome:

   ```sml
         fun failed reason tree =
           let
             fun frontier () =
               safe_frontier
                 (safe_completion
                    {max_depth = max_depth, rules = rules} initial)
             val _ = report_failure reason frontier
           in
             SearchFailed
               {tree = tree, safe_goals = frontier, reason = reason}
           end
   ```

   Note `initial`, not `tree`: the report is deliberately the
   safe-only frontier of the original goal, unpolluted by unsafe
   rapps and exhausted branches.  That is why it cannot reuse `tree`
   and why it is a second search at all.

`aesopLib.close_raw` matches `SearchFailed _` on both branches and is
untouched — which is exactly the saving.

### 3.3 `src/auto/aesop/selftest.sml`

Four sites destructure `safe_goals`; each becomes an application.

| Line | Change |
|---|---|
| 2335–2340 | bind `safe_goals`, then `case safe_goals () of [(_, {w, ...})] => … \| _ => false` |
| 2358–2359 | no change (already `...`-elides the field) |
| 2383–2388 | as 2335 |
| 2413–2419 | `length (safe_goals ()) = 3` and three `contains_target … (safe_goals ())` — bind `val goals = safe_goals ()` once in a `let` |

Add one test that pins the deferral itself, since it is now the
observable contract:

```sml
val _ =
  test
    ("aesop failure defers its safe-goal report until applied",
     fn () =>
       case search_safe_goal_outcome of
           aesopSearch.SearchFailed {safe_goals, ...} =>
             let
               val first = safe_goals ()
               val second = safe_goals ()
             in
               length first = 3 andalso
               ListPair.allEq
                 (fn ((_, {w = w1, ...} : clasetGoal.cgoal),
                      (_, {w = w2, ...} : clasetGoal.cgoal)) =>
                   aconv w1 w2)
                 (first, second)
             end
         | _ => false)
```

This asserts repeated application is consistent (the D-0.2 no-memo
decision is safe) and that the outcome value survives being carried
around unapplied.

---

## 4. D54 — precompute Norm declarations in the claset

### 4.1 `clasetLib.sml` — the `CS` record

Thread one field through the record and its **seven** construction
sites.  Verified list, all in `clasetLib.sml`:

| Line | Site | Action |
|---|---|---|
| 22–30 | `datatype claset` | add `norm_decls : decl list` |
| 40–48 | `empty_cs` | `norm_decls = []` |
| 127–152 | `add_decl` | thread + insert (§4.2) |
| 163–189 | `add_rule_by` | thread the tuple |
| 219–246 | `remove_rule` | filter by tag index |
| 253–275 | `merge_cs` | falls out of `add_decl` fold |
| 293–304, 306–317 | `map_safe_wrappers`, `map_unsafe_wrappers` | copy unchanged |
| 562–581 | `rebuild_claset` | falls out of `add_decl` fold |

`add_decl`'s accumulator tuple is already five-wide and becomes six.
It is at the width where a record is clearer than a tuple; convert it:

```sml
fun add_decl (decl : decl)
  {safe0, safep, unsafe, dup, aesop_index, norm_decls} = …
```

and update the three fold sites (178, 231–232, 567–570) accordingly.
This is a mechanical readability change inside one module, not an API
change, and it removes the positional-tuple hazard that adding a sixth
component would otherwise create.

### 4.2 Insertion in `decl_order` position

```sml
(* Norm rules never enter the four classical netpairs, so the claset
   keeps them as an ordered list instead -- the aesop normalisation
   phase wants all of them, not the ones matching one goal.  Held in
   [dest_decls] order so that [norm_rules_of] agrees with filtering
   [rules_of], which is the tiebreak the penalty sort relies on. *)
fun insert_norm_decl (decl : decl) decls =
  let
    fun insert [] = [decl]
      | insert (current :: rest) =
          case decl_order (decl, current) of
              GREATER => current :: insert rest
            | _ => decl :: current :: rest
  in
    insert decls
  end
```

`add_decl` calls it only when `#kind spec = Norm`; `remove_rule` uses
the same `{tag = {index, ...}}` predicate the netpair deletion uses at
225–229.

### 4.3 `clasetLib` — the new export and the narrowed one

Add beside `rules_of` (line 333):

```sml
fun norm_rules_of (CS {norm_decls, ...}) =
  map (fn {spec, name, orig, ...} => (spec, (name, orig))) norm_decls
```

In `clasetLib.sig`, add after `rules_of` (line 63):

```sml
  (* The claset's Norm declarations, in [rules_of] order.  The aesop
     normalisation phase applies all of them to every goal rather than
     retrieving by goal shape, so they are kept as a list; this is the
     precomputed equivalent of filtering [rules_of] by kind. *)
  val norm_rules_of : claset -> (rulespec * (string * thm)) list
```

and narrow the `aesop_target_candidates` contract comment (80–86):
`Target candidates comprise Intro rules` — drop `and Norm`, and drop
the sentence `Norm rules precede safe rules, which precede unsafe
rules` in favour of `Safe rules precede unsafe rules`.

### 4.4 `clasetLib.sml` — drop Norm from the index and the ordering

1. **`insert_aesop_decl` (100–114)** — the routing condition becomes
   `if kind = Intro then target else hyp`, and the `Norm` case is gone.
   Add a comment recording *why* Norm is absent, so it does not read as
   an omission:

   ```sml
   (* Norm rules are not indexed: the normalisation phase takes the
      whole list (see [norm_rules_of]), so an entry here would be
      retrieved, ordered and deduplicated on every goal expansion only
      to be filtered out again. *)
   ```

2. **`aesop_class` (464–466)** — delete the `{kind = Norm, ...}` arm;
   the function becomes safe = 0, unsafe = 1.
3. **`compare_aentry` (468–484)** — delete the
   `#kind spec1 = Norm andalso #kind spec2 = Norm` branch.
4. **`norm_rank` (456)** — delete; it had no other caller.

`unsafe_percent` (458) stays — `compare_aentry` still uses it.

### 4.5 `aesopRule.sml`

Line **469–471**:

```sml
    val norm_declarations =
      map (declaration_rule clasetUnify.Match)
        (clasetLib.norm_rules_of claset)
```

and delete `norm_declaration` (the predicate at 429–430), which then
has no caller.  `ordinary_kind`, `unsafe_declaration`,
`safe_forward_declaration` and `safe_class` all stay.

### 4.6 `src/auto/rules/selftest.sml`

Three tests assert Norm through the index and must move to the new
export.  Verified line ranges:

| Lines | Test | Change |
|---|---|---|
| 1371–1416 | `"aesop index retrieves every rule kind from its designated side"` | drop the `norm` query and its `has_aesop_entry` assertion; rename to `"…every indexed rule kind…"`; assert instead `not (has_aesop_name "aesop_norm" target)` so the exclusion is pinned |
| 1418–1441 | `"aesop index treats query metavariables as unification wildcards"` | drop `"meta_norm"` from the `target_cs` declarations and from the expected `targets` list |
| 1483–1516 | `"aesop safe and norm candidates retain their phase orders"` | split: keep the safe half under `"aesop safe candidates retain their phase order"`; move the norm half to a new `norm_rules_of` test (below) |

The replacement for the norm half, which pins the D-0.2 ordering
decision rather than the old index order:

```sml
val _ =
  test
    ("claset norm declarations agree with filtering rules_of",
     fn () =>
       let
         val norm_declarations =
           [({kind = clasetRules.Norm, safe = false, prio = SOME 4},
             ("norm_late", refl_intro [] ``p /\ p``)),
            ({kind = clasetRules.Norm, safe = false, prio = NONE},
             ("norm_zero", refl_intro [q] ``p /\ q``)),
            ({kind = clasetRules.Norm, safe = false, prio = SOME ~3},
             ("norm_early", refl_intro [x, y] ``x /\ y``))]
         fun install cs =
           List.foldl
             (fn ((spec, named_th), acc) => add_rule spec named_th acc)
             cs norm_declarations
         fun expected cs =
           List.filter
             (fn ({kind, ...} : clasetRules.rulespec, _) =>
               kind = clasetRules.Norm)
             (rules_of cs)
         fun agrees cs =
           map (fn (_, (name, _)) => name) (norm_rules_of cs) =
           map (fn (_, (name, _)) => name) (expected cs)
         val incremental = install empty_cs
         val merged = merge_cs (empty_cs, incremental)
         val removed = remove_rule "norm_zero" incremental
       in
         agrees incremental andalso agrees merged andalso
         agrees removed andalso
         not
           (List.exists
             (fn (_, (name, _)) => name = "norm_zero")
             (norm_rules_of removed))
       end)
```

The three clasets cover the three maintenance paths that can disagree
(incremental `add_decl`, `merge_cs`'s replay, and removal).  Note it
asserts *agreement with `rules_of`*, not a hardcoded order, so it
survives any future change to `decl_order`'s Norm group position.

A `theory_tests/` scenario is **not** needed: `norm_decls` is derived
data rebuilt from `decls` on every construction path, exactly like the
netpairs, and no delta encoding changes.  The existing
`schemaV2Base/Child` scenarios already cover Norm persistence.

---

## 5. Already landed (2026-07-29, `/simplify` mechanical pass)

Recorded so this plan reads against the right tree.  **Verified green
on 2026-07-30**: `bin/build -t --seq=tools/sequences/upto-auto`
("Hol built successfully"), the `rules`, `classical` and `aesop`
`selftest.exe` runs each exit 0, and `tools/h4pedant/h4pedant` is clean
on every changed file.  `bin/build -F -t` has **not** been run yet —
that is §6 step 3, still outstanding for the §5 work as well, because
`clasetReplay` and the `CS` record are consumed outside `src/auto/`.

- Five helpers duplicated verbatim across aesopNorm/aesopSearch/
  aesopLib hoisted into `aesopTree`: `changed`, `cgoal_under`,
  `direct_children`, `rendered_record` (the ~20-line replay-record
  builder, which also stopped re-rendering the parent goal per
  alternative), and `make_node` split into `goal_node`/`child_node` so
  the `level` vs `level + 1` difference is explicit.
- `aesopRule.norm_builtins` is now consumed by `claset_rules_core`
  via `norm_builtins_with`, instead of the same four rules being
  re-inlined there.  This was the plan-deliverable gap: §6's
  documented built-in order was selftested on one copy and used from
  another.
- `aesopTree.set_search_state` replaces the 3–4 chained single-field
  setters in `install_committed`, `prepare_unsafe`, `unsafe_phase` and
  `exhaust_goal`, cutting that many whole-tree `refresh` fixpoints to
  one; `set_safe_done`/`set_unsafe_cursor` route through it and three
  15-field record copies went away.
- `split_rules ()` cached against `splitLib.named_split_thms ()`
  instead of re-deriving every `mk_asm_split` per assembly.
- `unique_declarations` on `Redblackset` instead of `kept @ [x]` with a
  linear name scan; `trace_install`'s `copies_in` moved behind the new
  `traced` predicate; `seq.flatten` for `append_sequences`.
- Dead code: `aesopTree.set_forwarded`/`replace_forwarded`,
  `states_of`, `aesopRule.registry_index_matches`.
- `clasetLib.fresh_rule_name {prefix, from}` generalises `marker_name`;
  `aesopLib` uses it instead of re-implementing name allocation over
  `rules_of`, and its marker dispatch is table-driven.
- `HOLSourceParser`: dropped the always-`false` `force` parameter and
  folded `parseIdentifiers'`, whose second instantiation the aesop pass
  had removed.  Aesop `Holmakefile` dependency lines merged.

---

## 6. Verification

0. **The §5 baseline is green** (see §5) — `upto-auto` and the three
   selftests pass, so any failure below is attributable to §2–§4.
   Re-run the gate before starting if the tree has moved since
   2026-07-30.
1. Per item, in the changed directory: `Holmake && ./selftest.exe`
   — `src/auto/classical` for D52, `src/auto/aesop` for D53,
   `src/auto/rules` **and** `src/auto/aesop` for D54 (D54 changes an
   export that aesop consumes).
2. `bin/build -t --seq=tools/sequences/upto-auto` after each item.
3. `bin/build -F -t` once, after all three: D52 touches
   `clasetReplay`, which `src/auto/blast` replays through, and D54
   touches the `CS` record that every classical engine carries.
4. `tools/h4pedant` on the changed files (tabs / trailing whitespace).
5. Grep gates: §2.4 for D52; for D54,
   `grep -n "norm_rank\|norm_declaration\b" src/auto/` must be empty
   and `grep -n "Norm" src/auto/rules/clasetLib.sml` must show only
   the spec constant, the marker plumbing, and the §4.4 comment.
6. Confirm no `help/Docfiles/` change is required (§0.2): none of the
   three items alters a documented entry point's surface.

## 7. Noted, deliberately out of scope

**Per-iteration Norm retrieval.**  §0.3 establishes that index-driven
Norm retrieval is sound only if the query moves inside the
normalisation fixpoint — one `aesop_target_candidates` call per
iteration against the current goal, replacing the whole-list pass.
That would trade a per-iteration retrieval cost for a much smaller
rule list per iteration, and could *increase* strength, since a rule
indexed by the rewritten conclusion may be found where the initial
query missed it.  It needs its own measurement (norm rules are
currently few, so the whole-list pass may well be cheaper) and it would
re-add the Norm index that D54 removes.  Raise as a Phase-5 item with
benchmark evidence; do not fold it into D54.
