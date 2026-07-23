# Plan: give `markerLib` a shared generic-marker predicate

Date: 2026-07-23.  Branch: `isabelle-tactics`.  Parent plan: `PLAN.md`
§4 (rule database / marker vocabulary).

## 1. The defect

`clasetLib.is_passthrough_marker` (`src/auto/rules/clasetLib.sml:866`)
hardcodes, as a nine-way disjunction, the **complete generic-marker
vocabulary of two other modules**:

```sml
fun is_passthrough_marker theorem =
  has_marker_head markerSyntax.AC_tm theorem orelse
  has_marker_head markerSyntax.Cong_tm theorem orelse
  has_marker_head markerSyntax.Split_tm theorem orelse
  Option.isSome (markerLib.destExcl theorem) orelse
  Option.isSome (markerLib.destExclSF theorem) orelse
  Option.isSome (markerLib.destFRAG theorem) orelse
  Option.isSome (markerLib.dest_Req0 theorem) orelse
  Option.isSome (markerLib.dest_ReqD theorem) orelse
  is_bounded theorem                       (* BoundedRewrites.DEST_BOUNDED *)
```

It is the guard in `add_plain_theorems` (`clasetLib.sml:893`): leftover
theorems that are *not* classical-rule markers (already consumed by
`process_claset_tags`) are folded into the claset as unsafe intros — unless
they are one of these generic **simplifier-control** markers
(`AC`/`Cong`/`Split`/`Excl`/`ExclSF`/`FRAG`/`Req0`/`ReqD`/bounded), which
must pass through untouched so `AUTO_TAC [Cong th]`, `[Once th]`, etc. do
not mint a bogus classical rule.

Two costs (altitude review):

- **Silent-rot maintenance trap.** The classification is an *allow-list of
  everything foreign*. When `markerLib` (or `BoundedRewrites`) gains a new
  generic marker — and the branch is actively extending this vocabulary
  (HEAD commit "Skip simplifier requirement markers in clasets" is the
  `dest_Req0`/`dest_ReqD` lines being appended here after the fact; Phase S
  added `[split]`, Phase 3 adds `Simp`/`Iff`) — a theorem carrying it falls
  through the disjunction and is turned into a **bogus unsafe intro rule**,
  with no error, until someone notices and remembers to extend this exact
  list.
- **Wrong altitude.** `clasetLib` (the classical rule DB) reaches across a
  layer boundary to enumerate another module's marker set. The knowledge of
  "what are the generic simp-control markers" belongs with the module that
  *owns* those markers, not with each consumer.

## 2. Root cause and correct owner

The vocabulary is owned below `clasetLib`:

- `markerLib`/`markerSyntax` in **`src/marker/`** declare `AC`/`Cong`/
  `Split` (`markerSyntax.*_tm` + `markerLib` constructors) and
  `Excl`/`ExclSF`/`FRAG`/`Req0`/`ReqD` (`markerLib.dest*`,
  `markerLib.sig:20–45`).
- `BoundedRewrites` in **`src/1/`** owns the bounded-rewrite wrapper
  (`DEST_BOUNDED`, `Once`, `Ntimes`; `BoundedRewrites.sig:8–12`).

Build stratification (`src/auto/CLAUDE.md`; `PLAN.md` §3): `src/1` →
`src/marker` → … → `src/simp` and `src/auto/rules`. So:

- `markerLib` sits **below both** `src/simp` (simpLib) and `src/auto/rules`
  (clasetLib) — the two consumers.
- `markerLib` may **legally depend on `BoundedRewrites`** (src/1 precedes
  src/marker); it does not today (`markerLib.sml:4` opens only `HolKernel
  boolLib markerTheory markerSyntax`).

⇒ `markerLib` is the correct home for a single owned predicate that every
consumer calls. When a generic marker is added, its predicate is updated in
the same module, and all consumers stay correct automatically.

Current consumers that hardcode/rederive this vocabulary:
`clasetLib.is_passthrough_marker` (the defect) and `simpLib`'s
`is_AC`/`is_Cong`/`is_Split` + `extract_excls`/`process_tags`
(`simpLib.sml:1230–1274`, dispatching by kind). Phase-3 `clasimpLib` (not
yet built) will be a third — it should consume the predicate from day one.

## 3. Design decisions (owner — one each)

### D-A. Scope of the predicate — does the bounded-rewrite case join it?

- **Option A1 (recommended): one predicate in `markerLib` covering all
  nine**, including bounded. Requires a new `markerLib` → `BoundedRewrites`
  dependency edge (small, legal). Gives a single source of truth exactly as
  the review described: `clasetLib` calls one function.
- **Option A2: `markerLib` owns the marker-only predicate (eight cases);
  bounded stays a separate check.** `clasetLib` becomes
  `markerLib.is_generic_marker th orelse BoundedRewrites-is-bounded th`.
  Keeps `markerLib` free of a `BoundedRewrites` dependency, at the cost of a
  two-part check at each consumer and bounded-awareness still living
  outside the owner. Bounded rewrites are a stable, rarely-extended
  mechanism, so the residual duplication is low-churn.

**Recommendation: A1.** The dependency edge is trivial and `src/1`-local,
and it delivers the actual goal — *one* predicate, so no consumer ever
enumerates the vocabulary again. A2 half-solves it (the churny marker set
is centralized, but bounded stays split out). Decide A1 unless the owner
wants to keep `markerLib`'s dependency surface minimal.

### D-B. Registry vs fixed predicate

A dynamic *registry* (markers self-register) was considered and is
**rejected as over-engineering**: the generic-simp vocabulary is
`markerLib`-owned and static, and the higher-layer markers that a registry
would enable to contribute (Phase-3 `Simp`/`Iff`) are deliberately **not**
passthrough for the classical path (clasimp handles/rejects them, per
`PLAN_phase_3.md` §3.5). A fixed predicate enumerated *once* in the owning
module is the right altitude. Record so this is not re-litigated.

### D-C. Name

Proposed `markerLib.is_generic_simp_marker : thm -> bool` ("theorem is
wrapped in a generic simplifier-control marker, not a logical-rule
declaration"). Collision-check whole-tree before landing; adjust if
`is_simp_marker`/`is_control_marker` reads better. Under A1 it covers
bounded; under A2 name it `is_generic_marker` and keep bounded separate.

## 4. The shared predicate

Add to `markerLib` (`src/marker/markerLib.{sig,sml}`):

```sml
(* True iff [th] carries a generic simplifier-control marker (AC, Cong,
   Split, Excl, ExclSF, FRAG, Req0, ReqD, or a bounded-rewrite wrapper) —
   i.e. it is meant for a simpset invocation, not a logical-rule
   declaration.  Owners of new such markers extend this predicate here. *)
val is_generic_simp_marker : thm -> bool
```

Body enumerates the vocabulary using `markerLib`'s existing `dest*`
functions and `markerSyntax.*_tm` (via the same `same_const`-on-head test
`simpLib.is_AC` uses), plus (A1) `BoundedRewrites.DEST_BOUNDED`. This is the
*only* place the enumeration lives after this change.

Optionally also expose the per-kind predicates `is_AC`/`is_Cong`/`is_Split`
from `markerLib` (it already owns the constructors) so `simpLib` stops
re-deriving them locally (§5.2).

## 5. Consumer migration

### 5.1 `clasetLib` (primary — the altitude fix)

- Replace the body of `is_passthrough_marker` (`clasetLib.sml:866`) with a
  call to `markerLib.is_generic_simp_marker` (A1), or delete
  `is_passthrough_marker` and call the predicate directly at
  `clasetLib.sml:893`. Prefer deletion if no other use.
- Remove the now-dead local helpers **iff unused elsewhere**: `is_bounded`
  (`:863`) and `has_marker_head` (`:858`) — grep first; `has_marker_head`
  may have other callers.
- Behaviour is identical by construction (same nine cases); the change is
  purely *where* the list lives.

### 5.2 `simpLib` (optional dedup — captures "both consult it")

If the per-kind predicates are exposed (§4): make `simpLib.is_AC`/`is_Cong`/
`is_Split` (`simpLib.sml:1230–1232`) thin aliases of the `markerLib` ones,
and have `extract_excls` keep using `markerLib.destExcl`/`destExclSF`/
`destFRAG` (already the case). `process_tags` still dispatches per kind —
its structure is unchanged; only the source of "what is a Cong marker"
moves to `markerLib`. This is a nice-to-have that makes `markerLib` the
single source of truth for marker identity; it is **not** required for the
altitude fix and can be a follow-up task if it risks the simp gate.

### 5.3 Future `clasimpLib` (Phase 3)

Note in `PLAN_phase_3.md` §6 (argument processor) that generic-marker
passthrough must use `markerLib.is_generic_simp_marker`, not a re-hardcoded
list. (Cross-reference only; no code here.)

## 6. Task breakdown

Per-task gate: `Holmake` + `./selftest.exe` in the touched dir, then
`bin/build -t --seq=tools/sequences/upto-auto`; `tools/h4pedant` on touched
dirs. `markerLib` is core (below `src/boss`), so its own change also wants
`bin/build -t --seq=tools/sequences/upto-parallel` and, at the end,
`bin/build -F -t`.

| # | Task |
|---|---|
| 0 | Decide D-A / D-B / D-C (owner). Collision-check the chosen name whole-tree. |
| 1 | Add `is_generic_simp_marker` to `markerLib.{sig,sml}` (+ per-kind predicates if §5.2 opted in); under A1 add the `BoundedRewrites` dependency (open + Holmakefile `.uo` dep line, mirroring the existing explicit-dep pattern in `src/marker/Holmakefile`). markerLib selftest (§7). Gate incl. `upto-parallel`. |
| 2 | Migrate `clasetLib`: replace/delete `is_passthrough_marker`, remove dead `is_bounded`/`has_marker_head` if unused; `clasetLib` regression (§7). Gate `upto-auto`. |
| 3 | *(optional, §5.2)* Point `simpLib.is_AC`/`is_Cong`/`is_Split` at the `markerLib` predicates. simp selftest unchanged-behaviour check. Gate `upto-parallel`. |
| 4 | Cross-reference note in `PLAN_phase_3.md` §6. |
| 5 | Phase gate `bin/build -F -t` (touches core `markerLib`): green modulo the documented pre-existing `src/probability/real_borelTheory` exception (`PLAN.md` §11). Record in §11 gate log. |

## 7. Selftests

- **`src/marker/selftest.sml`** (markerLib has `selftest.exe`): for each of
  the nine wrappers, `is_generic_simp_marker (Marker th) = true`; for a
  plain theorem and for each **classical** marker (`SIntro`/`Intro`/…/`Del`
  from `clasetMarkerScript`) `= false`. The classical-marker negatives are
  the regression that guards the exact boundary the defect got wrong.
  (If a classical marker is defined above `src/marker` and not reachable
  from the marker selftest, put those negatives in the `clasetLib`
  selftest instead — the point is: classical markers must not be
  passthrough.)
- **`src/auto/rules/selftest.sml`**: behaviour-identity for
  `add_plain_theorems`/`invocation_claset` — `FAST_TAC`-style invocation
  with a mix of plain theorems and each generic marker leaves the claset's
  `rules_of` contents/order **unchanged** vs the pre-refactor baseline
  (D-preserve per `src/auto/CLAUDE.md`: observable claset behaviour frozen),
  and a plain theorem still becomes an unsafe intro. Add a **failing-first**
  case: a generic marker (e.g. `Once th`) must not create a rule — the
  exact silent-rot failure mode.

## 8. Risks

1. **markerLib is core; a mistake has wide blast radius.** Mitigation: the
   change is additive (new predicate) + a dependency edge; `upto-parallel`
   and `-F` gates run because a core module changed.
2. **Behaviour drift in claset assembly.** The refactor must be
   bit-identical (same nine cases). Mitigation: §7 `rules_of`
   contents/order equality test against the current behaviour; the
   predicate is a mechanical move of the existing disjunction.
3. **Dead-helper removal over-reaches.** `has_marker_head` may have other
   `clasetLib` callers. Mitigation: grep before deleting (Task 2).
4. **New `markerLib` → `BoundedRewrites` dep (A1).** Legal but adds a build
   edge; mosml functor/dep detection is finicky in `src/marker`
   (see the existing `Table.ui` note in its Holmakefile). Mitigation: add
   the explicit `.uo` dependency line; if it proves troublesome, fall back
   to D-A Option A2 (no edge).
5. **Scope creep into simpLib.** §5.2 is optional; drop it if it risks the
   simp gate — the altitude fix is complete with Tasks 1–2 alone.

## 9. Interfaces / layering

Additive to `markerLib.sig` (new predicate; optional per-kind predicates).
No production signature is removed. Respects `src/auto/CLAUDE.md`
stratification: the shared predicate lives in `src/marker` (below both
`src/simp` and `src/auto/rules`), so `rules/` gains nothing new to depend
on beyond `markerLib`, which it already uses — and in particular `rules/`
still does **not** depend on `src/simp`. Under A1, the only new edge is
`markerLib` → `BoundedRewrites`, both core and correctly ordered.
