# Phase 3 research: the delivered HOL4 substrate (rules/, classical/, blast/) as Phase 3 will consume it

Date: 2026-07-19.  Worktree: `isabelle-tactics`.  All references verified
against the working tree at the time of writing (branch head
`315b56aa2`).  Scope: everything the clasimp layer
(`AUTO_TAC`/`FORCE_TAC`/`FASTFORCE_TAC`/`CLARSIMP_TAC`/`[iff]`,
`src/auto/clasimp/`) must build on, plus the freeze constraints and the
gaps that force owner decisions.

Companion plans: `.agent-files/PLAN.md` §7 (Phase-3 sketch),
`.agent-files/PLAN_phase_1_2.md` (Phase 1–2 as-built plan and freeze
list), `.agent-files/research/phase12-classical-search-port.md` §4
(wrapper semantics; §4.3 = the recorded Phase-3 instantiation option).

---

## 1. `src/auto/rules/` — module inventory and the claset API

Modules (`src/auto/rules/`): `NTactical.{sig,sml}`, `clasetNet.{sig,sml}`,
`clasetRules.{sig,sml}`, `clasetLib.{sig,sml}`, `clasetMarkerScript.sml`
(theory `clasetMarker`), `clasetSeedScript.sml` (theory `clasetSeed`),
`selftest.sml`, `theory_tests/` (cross-theory persistence scenarios).

### 1.1 The `claset` type and rule combinators

`claset` is abstract in `clasetLib.sig:10`; the representation
(`clasetLib.sml:18–25`) is

```sml
datatype claset =
  CS of {decls : decls,
         safe_wrappers   : (string * NTactical.wrapper) list,
         unsafe_wrappers : (string * NTactical.wrapper) list,
         safe0_netpair : netpair, safep_netpair : netpair,
         unsafe_netpair : netpair, dup_netpair : netpair}
```

Four netpairs (safe0 = 0-subgoal safe, safep = branching safe, unsafe,
dup = duplicating unsafe variants); `netpair = intro net * elim net`.
Public combinators (`clasetLib.sig:15–35`):

- `empty_cs`; `add_rule : rulespec -> string * thm -> claset -> claset`
  (`clasetLib.sml:123`); batch forms `add_sintros/add_intros/add_selims/
  add_elims/add_sdests/add_dests : (string * thm) list -> claset -> claset`
  (`clasetLib.sml:158–163`, built from the six specs at `:148–153`);
- `remove_rule : string -> claset -> claset` (`:165`);
  `merge_cs : claset * claset -> claset` (`:193`, decl-canonical merge,
  wrapper alists merged left-priority via `merge_alists` `:188`);
- global state: `the_claset : unit -> claset` (`:568`),
  `export_rule : rulespec -> string -> unit` (persistent delta, `:675`),
  `temp_add_rule` (`:572`), `delrule`/`temp_delrule` (`:684`/`:574`),
  `augment_claset : (claset -> claset) -> unit` (`:577` — the documented
  channel for libraries to re-establish non-persistable wrappers at load),
  `claset_of_theory`, `merge_clasets`, `with_claset` (`:693–697`);
- inspection: `rules_of` (`:265`), `pp_claset` (`:310`);
- part accessors and candidate queries (`clasetLib.sig:47–55`):
  `claset_part : part -> claset -> claset_part` with
  `datatype part = Safe0Part | SafePPart | UnsafePart | DupPart`
  (`clasetLib.sig:13`), plus `safe0_part/safep_part/unsafe_part/dup_part`
  and `match_/unify_intro_/elim_candidates : claset_part -> term ->
  (tag * brl) list` (`clasetLib.sml:312–333`).
- `claset_config : {hyp_subst_tac : tactic, size_of : goal -> int}`
  (`clasetLib.sig:82`; delivered values `BasicProvers.VAR_EQ_TAC` and the
  Isabelle atoms-plus-abstractions metric, `clasetLib.sml:732–734`).

### 1.2 The wrapper representation and API (Phase 3's `addss`/`addSss` plug point)

`NTactical.sig:5–7` (frozen D13 vocabulary):

```sml
type nresult = goal list * validation
type ntactic = goal -> nresult seq.seq        (* portableML/seq *)
type wrapper = ntactic -> ntactic
```

Combinators exported (`NTactical.sig:9–21`): `LIFT : tactic -> ntactic`,
`DETERM : ntactic -> tactic`, `NNO_TAC`, `NALL_TAC`, `NTHEN`, `NORELSE`,
`NAPPEND`, `NTRY`, `NREPEAT`, `NCHANGED`, `NFIRST`, `nEVERY`
(implementations `NTactical.sml:11–77`; `NCHANGED` filters out
single-goal α-equal results, `:63–71`; `NREPEAT` is deterministic via
`DETERM`, `:61`).

Wrappers are **named alists** on the claset, exactly Isabelle's
`swrappers`/`uwrappers`.  API (`clasetLib.sig:37–42`):

```sml
val add_safe_wrapper    : string * NTactical.wrapper -> claset -> claset
val add_unsafe_wrapper  : string * NTactical.wrapper -> claset -> claset
val del_safe_wrapper    : string -> claset -> claset
val del_unsafe_wrapper  : string -> claset -> claset
val app_safe_wrappers   : claset -> ntactic -> ntactic
val app_unsafe_wrappers : claset -> ntactic -> ntactic
```

Semantics (`clasetLib.sml:213–263`): `update_alist` replaces an existing
name in place, otherwise conses at the **front** (`:213–224`);
application is `List.foldl (fn ((_, w), acc) => w acc) tac wrappers`
(`:256–257`) — head applied first, so the **newest wrapper is innermost,
oldest outermost**, matching upstream `classical.ML:529–530` fold
semantics (verified `phase12-classical-search-port.md` §4.1; selftest
parity tests exist per `PLAN_phase_1_2.md` §8.1.4).  There are **no**
`addSbefore/addSafter/addbefore/addafter` derived combinators — Phase 3
builds `addss`/`addSss` from `add_unsafe_wrapper`/`add_safe_wrapper`
directly with `NORELSE`/`NAPPEND` composition (safe = ORELSE-style,
unsafe = APPEND-style, per D13).  Wrappers are closures and are **never
persisted** (`src/auto/CLAUDE.md`); the sanctioned pattern is
re-establishing them via `augment_claset` at library load.  Phase 3's
`addss(ss)` wrapper must therefore be installed by `clasimpLib` itself
(named entries, e.g. `"addss"`), and per-invocation variants built with
`add_unsafe_wrapper` on the invocation claset.

### 1.3 Marker vocabulary (per-invocation modifiers)

Theory `clasetMarker` (`clasetMarkerScript.sml:7–13`) defines exactly:
`SIntro`, `Intro`, `SElim`, `Elim`, `SDest`, `Dest` (all
`(x:bool) = x` congruence-style markers) and `Del ((x:'a)) = T`
(tag-style, carries a string name).  ML side (`clasetLib.sig:57–71`,
`clasetLib.sml:749–765`): constructors `SIntro … Dest : thm -> thm`
(via `markerLib.genCong`), `Del : string -> thm`
(`markerLib.genmktagged`), and destructors `destSIntro … destDest :
thm -> thm option`, `destDel : thm -> string option`.

**`process_claset_tags : thm list -> claset -> claset * thm list`**
(`clasetLib.sml:792–806`): folds over the theorem list; each of the six
rule markers becomes `add_rule spec` under a fresh generated name
`"__claset_marker_N"` (`marker_prefix` `:767`, freshness loop
`:769–779`); `Del name` becomes `remove_rule name`; everything else is
returned as leftovers in order.

How the public tactics consume it (`classicalLib.sml:265–274`):
`invocation_claset theorems` = `process_claset_tags theorems
(the_claset ())`, then `add_plain_theorems` adds non-marker leftovers as
**unsafe intros** named `"__classical_extra_N"` (`:241–263`) — except
recognized *passthrough* markers, which are silently dropped from the
claset: `AC`, `Cong`, `Split`, `Excl`, `ExclSF`, `FRAG`, and
`Once/Ntimes`-bounded theorems (`is_passthrough_marker`,
`classicalLib.sml:229–239`).  `tableauLib` does the same with prefix
`"__blast_extra_N"` (`tableauLib.sml:22–71`).

**Facts Phase 3 must reckon with (verified by grep over the tree):**

- There is **NO `Iff` marker** — not in `clasetMarkerScript.sml`, not in
  `clasetLib`, nowhere in `src/auto/`.  PLAN.md §11's resolved
  micro-decision reserves the name `Iff` in the planned marker
  vocabulary, so adding it is pre-sanctioned in intent, but it is new
  Phase-3 work (marker constant + constructor/destructor + processing).
- There is **NO `Simp` marker** anywhere (`src/marker`, `src/simp`,
  `src/auto`).  PLAN.md §7 mentions "`Simp th` (≡ existing rewrite
  argument)" for the clasimp tactics; whether the simp-side rewrites of
  `AUTO_TAC [..]` arrive as plain theorems (current classical convention:
  plain leftovers become unsafe intros — a conflicting default!), as a
  new `Simp` marker, or as a separate list argument is an **open design
  point for the Phase-3 plan** (owner decision material: the plain-thm
  default of `classicalLib` gives extra lemmas to the claset, while
  clasimp users will often mean "extra rewrite").
- The `Split` marker **exists** in `src/marker`
  (`markerScript.sml:115`, `markerSyntax.sig:8`, Phase S) and is
  currently a passthrough for classical/blast tactics; Phase-S
  `splitLib` in `src/simp` consumes it.  Phase 3's clasimp tactics can
  route it to the simp side unchanged.

### 1.4 Attributes and persistence (where `[iff]` has to live)

Registered attributes (`clasetLib.sml:704–719`): exactly six —
`intro`, `sintro`, `elim`, `selim`, `dest`, `sdest` — via
`ThmAttribute.register_attribute` with `storedf` = `export_rule spec`
(persistent) and `localf` = `temp_add_rule` (session).  Attribute
arguments are rejected with "priorities arrive in a later phase"
(`:699–702`).  **No `[iff]` attribute exists.**

Persistence: one `AncestryData.fullmake` instance, tag `"claset"`
(`clasetLib.sml:551–560`), global value `cstate = claset * bool *
pending list` with lazy first-demand initialization (`:343–350`,
`init_state` `:531–539`), per-theory batch finaliser (`:547–549`), and
TypeBase catch-up interleaving.  The delta type is
(`clasetRules.sig:55`):

```sml
datatype cdelta = ADD of {name : thname, spec : rulespec} | RM of string
```

with `rulespec = {kind : rulekind, safe : bool, prio : int option}` and
`datatype rulekind = Intro | Elim | Dest` (`clasetRules.sig:7–8`).
Encoding is tag-dispatched: `"clasetADD1"`/`"clasetRM1"`
(`clasetRules.sml:587–592`), decode via `ThyDataSexp.first
[dec_add, dec_rm]` (`:604`).

**Consequence for `[iff]`:** the current delta **cannot** carry an
"iff" kind.  The `rulespec`/`cdelta` schema (v1) is on the Phase-0
freeze list (`PLAN_phase_0.md` §11: "rulespec/cdelta schema (v1)…
changes require an owner decision").  Technically the tag-dispatched
sexp decoding makes an *additive* new delta tag (e.g. `"clasetIFF1"`)
or a v2 schema clean to add, and `decode_delta`'s `first`-style
dispatch would ignore unknown tags in old loaders — but any of:
(a) extending `cdelta`/`rulespec`, (b) a second AncestryData instance
owned by `clasimp/` (tag `"iff"` say) that fans out into both the
claset and the simpset at load, or (c) piggybacking on
`ThmSetData.export_with_ancestry` for the iff list, is an **owner
decision**.  Note the layering constraint: `src/auto/rules` must not
depend on `src/simp` (`src/auto/CLAUDE.md`), and `[iff]` must feed
*both* databases atomically (`clasimp.ML:87–112` semantics per PLAN §7)
— so the attribute registration itself must live in `clasimp/` (which
may depend on `src/simp`; `src/simp/src` builds before `src/boss`), not
in `rules/`.  Option (b) is the only one that keeps the frozen v1
schema untouched.

Also relevant: `register_tyinfo_contribution` (`clasetLib.sig:78–80`,
impl `:583–591`) — TypeBase-derived rules are *not* deltas; two
contributions are installed (`"claset-distinctness"`,
`"claset-injectivity"`, `:669–673`).  Phase 0's completion notes
explicitly defer **constructor intros to Phase 3's `[iff]` machinery**
(`PLAN_phase_0.md` §12).  A useful private precedent already in the
file: `iff_dest_rule` (`clasetLib.sml:623–630`) derives the forward
implication of an iff via `EQ_IMP_RULE` — the shape of the
`iffD1`/`iffD2` processing `[iff]` needs, currently private.

### 1.5 Rule preprocessing kit (`clasetRules`)

`clasetRules.sig:30–36`: `MAKE_ELIM_RULE : thm -> thm` (dest→elim),
`CLASSICAL_RULE : thm -> thm` (weak-elim classical repair),
`SWAP_INTRO_RULE : thm -> thm option` (swapped intro variants),
`DUP_INTRO_RULE`, `DUP_ELIM_RULE`, `REV_DUP_ELIM_RULE` (duplicating
variants; the last is the blast γ-duplicate form added by the Phase 1–2
amendment), and `ext_info : rulespec -> thm -> info` (computes
`{rl, dup_rl}`, each `thm * thm option` with the swapped variant).
Canonical-form utilities: `canonical_rule(_of)`, `canonical_form(_of)`,
`rule_index(_of)`, `rule_premises(_of)`, `rule_conclusion`
(`clasetRules.sig:19–27`).  Everything `[iff]` needs to build
intro/dest pairs and their dup/swapped variants already exists here.

---

## 2. `src/auto/classical/` — modules, contracts, wrapper points

Modules: `searchHeap`, `clasetMeta`, `clasetUnify`, `clasetReplay`,
`clasetGoal`, `clasetStep`, `clasetSearch`, `classicalLib`
(+ `selftest.sml`, 3342 lines).

### 2.1 `classicalLib` public signature (frozen)

`classicalLib.sig` in full: uppercase, all `thm list -> tactic` —
`SAFE_TAC`, `CLARIFY_TAC`, `SAFE_STEP_TAC`, `CLARIFY_STEP_TAC`,
`STEP_TAC`, `SLOW_STEP_TAC`, `INST_STEP_TAC` (`:5–11`); `FAST_TAC`,
`SLOW_TAC`, `BEST_TAC`, `SLOW_BEST_TAC`, `FIRST_BEST_TAC`, `ASTAR_TAC`,
`SLOW_ASTAR_TAC`, `DEEPEN_TAC` (`:13–20`).  Claset-explicit lowercase
layer (`:22–38`): `safe_tac, clarify_tac, safe_step_tac,
clarify_step_tac, step_tac, slow_step_tac, inst_step_tac, fast_tac,
slow_tac, best_tac, slow_best_tac, first_best_tac, astar_tac,
slow_astar_tac : clasetLib.claset -> NTactical.ntactic` and
`deepen_tac : claset -> {start : int} -> ntactic`.

The `thm list` is the marker vocabulary (§1.3); every uppercase tactic
is `public tac thms = NTactical.DETERM (tac (invocation_claset thms))`
(`classicalLib.sml:273–292`), reading the global claset **at run time**.
`DEEPEN_TAC` fixes `start = 4` (`:291–292`).

### 2.2 `clasetStep` step/record contracts (frozen)

`clasetStep.sig`: `type step = node * goalpos -> (step_record * node)
seq.seq` (`:13`; `goalpos` is 1-based).  `step_record` accessors
`kind_of/target_of/consumed_of/created_of/eigenvariables_of/
validation_of` (`:16–21`).  Exported step constructors (`:22–30`):
`safe_step, clarify_step, inst0_step, instp_step, inst_step,
unsafe_step, dup_step, step, slow_step : claset -> step`; the exact
blast transitions (`:35–43`); and — decisive for Phase 3 —

```sml
(* [depth_step cs part m] selects the duplicating or non-duplicating
   unsafe net through [part].  Safe and inst0 inferences cost nothing;
   an instp/part inference costs one unit. *)
val depth_step : clasetLib.claset -> clasetLib.claset_part -> int -> step
```
(`clasetStep.sig:45–48`).

**The nodup step exists.**  `depth_cascade part cs = instp APPEND
rule_results Unify part` (`clasetStep.sml:1320–1322`);
`unsafe_cascade` uses `unsafe_part` (non-duplicating,
`:1312–1314`), `dup_cascade` uses `dup_part` with the dup flag
(`:1316–1318`).  So Isabelle's `depth_tac` = `depth_step cs
(clasetLib.dup_part cs) m` and **`nodup_depth_tac` = `depth_step cs
(clasetLib.unsafe_part cs) m`** — the same code parameterized by the
netpair, exactly as `PLAN_phase_1_2.md` §3.4 promised
("parameterized by the unsafe-netpair choice so Phase 3's
`nodup_depth_tac` (`clasimp.ML:128–143`) is the same code with `unsafe`
instead of `dup`").  `depth_step`'s recursion (`clasetStep.sml:
1544–1576`) fully solves the target goal within `m` bound units:
safe steps free (`safe_steps_at`, `:1496–1511`), `inst0_step` closers
free and **un-wrapped** (`:1561`), the branching rung
(instp+part) wrapped in `app_unsafe_wrappers` and costing one unit
(`:1563–1570`), children solved recursively at `m - 1`.

There is also a plain `unsafe_step` (nodup, single step, no bound) if a
one-shot variant is ever wanted.

### 2.3 Wrapper application points (D24, as delivered)

All wrapper application goes through `wrapped_step apply_wrappers
cascade cs` (`clasetStep.sml:1401–1468`):

- renders the target goal (`clasetGoal.render node pos`, `:1405`),
- gives the wrapper stack the cascade as a base `ntactic` (`:1411–1419`;
  on the identical rendered goal the cascade runs on the true node and
  its exact `direct` results are remembered; on any *other* goal the
  wrapper hands in, the cascade runs on a temporary node lifted from
  that goal),
- applies `apply_wrappers cs base` to the rendered goal (`:1421`),
- lifts each `(goals, validation)` back: exact cascade results are
  spliced natively; anything else goes through `clasetGoal.unrender`
  and is recorded as an opaque `Wrapper` step whose validation *is* the
  replay (`:1423–1465`, `wrapper_direct` `:1390–1399`).

Application sites (verify vs research §4.2 table — all match):

| step | wrappers | where |
|---|---|---|
| `safe_step` | safe | `clasetStep.sml:1470–1471` |
| `clarify_step` | safe | `:1473–1474` |
| `inst0/instp/inst/unsafe/dup_step` | none (identity) | `:1476–1489` |
| `step`/`slow_step` unsafe rung (`inst APPEND/ORELSE unsafe`) | unsafe | `general_step`, `:1534–1539` |
| `depth_step` branching rung (instp+part) | unsafe | `:1565–1567` |
| `depth_step` `inst0` closers | **none** | `:1561` (upstream `classical.ML:718` parity) |

Safe wrappers therefore reach every search (all drivers saturate via
`safe_step`), and an unsafe wrapper in the depth searches is offered as
an alternative to the bound-consuming branching step but never to the
trivial closers — precisely the geometry `addss` needs.

### 2.4 Materialization (rigid semantics) — the surface `addss` runs on

`clasetGoal.sig:74–87` (frozen node shape):

```sml
val render   : node -> int -> goal
val unrender : node -> int -> goal list * validation -> node option
```

`render` normalizes under the store and exposes **unbound engine
metavariables as their reserved marked frees** ("HOL4 tactics
consequently see rigid variables, not holes", `clasetGoal.sml:343–345`).
`unrender` (`:360–436`) verifies the result mentions only markers that
were in the rendered input (a new marker ⇒ `NONE`), lifts genuinely
fresh frees as eigenparameters (registered via
`clasetMeta.register_eigen`), and on the marked path records the
returned validation as an opaque `Wrapper` replay action.  The sig
comment states the constraint verbatim: "**Thus wrappers cannot
instantiate engine metavariables.  Isabelle-style solver-level wrapper
instantiation remains an explicit Phase-3 option, rather than weakening
this rigid interface.**" (`clasetGoal.sig:83–85`).

Phase-3 consequence: a simp wrapper sees metavariables as rigid frees
with reserved names (`clasetMeta.is_meta` recognizes them,
`clasetMeta.sig:22`).  It can rewrite around them soundly; it can never
solve `?x = t` side conditions by instantiation.  See §5 for the
recorded options.

### 2.5 Search drivers — programmability for AUTO_TAC's step 3

`clasetSearch.sig` (public; NOT on the Phase 1–2 freeze list, which
names only clasetMeta/clasetGoal/clasetStep/clasetReplay/classicalLib/
tableauLib):

```sml
type expansion = node -> node seq.seq
val node_limit : int ref                     (* default 100000, :39 *)
val DEPTH_FIRST : (node -> bool) -> expansion -> expansion   (* :63 *)
val DEPTH_SOLVE : expansion -> expansion                     (* :261, D25 pruning *)
val BEST_FIRST  : (node -> bool) -> expansion -> expansion   (* :356 *)
val ASTAR       : (node -> bool) -> expansion -> expansion   (* :413 *)
val DEEPEN : int * int -> (int -> expansion) -> int -> expansion  (* :441 *)
```

`DEEPEN (increment, limit) bounded start` is **fully programmable**:
increment, ceiling, start, and the bound-indexed expansion are all
arguments; only `classicalLib.deepen_tac` hardcodes `(2, 10)`
(`classicalLib.sml:221–222`) and `DEEPEN_TAC` the start 4 (`:291–292`).

`classicalLib`'s (private but small) plumbing shows the exact recipe a
bounded depth-n claset search needs (`classicalLib.sml`):

- `safe_saturate_node cs node` (`:158–175`) — Isabelle's
  `safe_depth_tac` pre-saturation of the complete state;
- `bounded_depth cs bound initial` (`:208–219`) = saturate, then
  `DEPTH_SOLVE (project (depth_step cs (dup_part cs) bound (node, 1)))`;
- `solve search goal` (`:179–185`) = run search from
  `clasetGoal.from_goal goal`, keep solved nodes, replay via
  `replay_node` (`:115–122`) = `clasetReplay.ground (store) (replay
  node)` then `clasetReplay.REPLAY_TAC grounded original` — all public,
  frozen APIs (`clasetReplay.sig:59–66`: `ground`, `REPLAY_TAC`).

**Therefore Isabelle's auto step 3 is buildable from exported pieces
today**: `REPEAT` on first subgoal of `BLAST_DEPTH_TAC 4 thms` ORELSE
`CHANGED` of `solve`-style replay of `safe_saturate + DEPTH_SOLVE
(depth_step cs (unsafe_part cs) 2 (·,1))` with the simp wrapper
installed as an unsafe wrapper on `cs`.  Nothing exported does this
yet — `bounded_depth`, `safe_saturate_node`, `solve`, `replay_node`,
`rendered_goals` are all private to `classicalLib.sml`, so clasimp
must either reimplement ~60 lines against public frozen APIs
(`clasetGoal.from_goal/goals`, `clasetStep.depth_step/safe_step`,
`clasetSearch.DEPTH_SOLVE`, `clasetReplay.ground/REPLAY_TAC`) or an
owner decision adds exports to `classicalLib` (its signature is frozen;
even additive exports need the nod).  A nuance to preserve when
reimplementing: `safe_saturate_node`'s comment (`classicalLib.sml:
155–157`) — saturating before `DEPTH_SOLVE` keeps safely-generated
siblings visible to the D25 commitment test.

Also note `first_best_tac` (`:201–203`) uses `expand_first`
(first-goal-where-anything-applies, `:141–153`) — the `FIRST_BEST`
shape `FORCE_TAC` needs is already exported as
`first_best_tac : claset -> ntactic`.

### 2.6 `clasetReplay` / `clasetMeta` — what Phase 3 touches

`clasetReplay.sig`: `step_kind` includes `Wrapper` (`:21`); `script`,
`ground : store -> script -> grounded_script` (deterministic: tymetas →
`bool`, then metas → `ARB`; `:57–59`), `replay` (outcome-typed) and
`REPLAY_TAC` (raises diagnostic `HOL_ERR`; `:63–66`).  Phase 3's
drivers should use `REPLAY_TAC` like `classicalLib` does.
`clasetMeta.sig` is the frozen store API (`empty/new_meta/bind/walk/
norm/is_meta/ground/collapse/bindings…`) — clasimp needs at most
`is_meta` (to keep simp away from marked frees if it ever wants a
guard; rigidity already protects soundness).

---

## 3. `src/auto/blast/tableauLib` — surface for AUTO's depth-4 blast

`tableauLib.sig` in full (frozen):

```sml
val BLAST_TAC       : thm list -> tactic
val BLAST_DEPTH_TAC : int -> thm list -> tactic
val depth_limit     : int ref                    (* default 20 *)
val tryIt : int -> thm list -> goal -> try_result
```

`BLAST_DEPTH_TAC depth theorems` (`tableauLib.sml:199–203`) runs a
**single search at exactly that depth** (`run_depths (SOME depth)
(fn _ => NONE)`), reads the global claset at run time, and processes
the same marker vocabulary via `process_claset_tags` +
plain-leftovers-as-unsafe-intros (`invocation_claset`,
`tableauLib.sml:65–71`; passthroughs `:23–30`).  So
`BLAST_DEPTH_TAC 4 thms` is directly usable as auto's step-3 blast leg,
with two caveats to record in the Phase-3 plan:

1. The public blast tactics prepend two blast-local safe elims
   (`NOT_IMP_CELIM_THM`, `NOT_FORALL_CELIM_THM`; `blast_claset`,
   `:59–63`) and run fixed preprocessing — `PURE_REWRITE_TAC` with nine
   seed rewrites plus a `PURE_ONCE_REWRITE_TAC` and the Halting-II
   `ACCEPT_TAC` special case (`blast_preprocess`/`halting_preprocess`,
   `:172–195`).  Inside AUTO's REPEAT loop this preprocessing runs on
   every iteration; it is pure-rewrite (cheap, idempotent-ish) but is a
   deliberate deviation from the raw `Blast.depth_tac` Isabelle calls
   (PLAN.md §6.3 documents the deviation).  Whether AUTO_TAC calls
   `BLAST_DEPTH_TAC` as-is or wants a preprocessing-free entry is a
   small owner/design decision; the current surface only offers the
   preprocessed form, and `tableauLib`'s surface is frozen.
2. Blast ignores wrappers entirely (faithful; `blast.ML:16`) — the simp
   wrapper only lives in the claset-search leg, as in Isabelle.

---

## 4. Build/test conventions for the new `src/auto/clasimp/`

- **Sequence**: `tools/sequences/upto-auto` currently ends
  `src/auto/rules`, `src/auto/classical`, `src/auto/blast`,
  `!src/auto/rules/theory_tests` (lines 3–6).  Add
  `src/auto/clasimp` after `src/auto/blast`.  Also add `auto/clasimp`
  to `SRCRELNAMES` in `src/parallel_builds/core/Holmakefile` (line 5
  currently: `algebra auto/rules auto/classical auto/blast bag …`).
- **Holmakefile pattern** (all three dirs identical shape):
  `HOLHEAP = $(HOLDIR)/bin/hol.state0`; `INCLUDES` listing the sibling
  auto dirs (`classical/` includes `rules`; `blast/` includes `rules`
  and `classical`); explicit `.uo` dependency lines; `selftest.exe`
  built by `$(HOLMOSMLC) -o $@ $<` from `selftest.uo` + all module
  `.uo`s; `ifdef HOLSELFTESTLEVEL` tee into `<name>-selftest.log`;
  `EXTRA_CLEANS`.  clasimp additionally needs
  `$(HOLDIR)/src/simp/src` in `INCLUDES` (permitted: `src/simp/src`
  builds pre-`boss`; only `rules/` is forbidden to depend on simp —
  `src/auto/CLAUDE.md`).
- **Selftests**: `testutils` (`tprint` + `OK`/`die`; local
  `fun test (name, check)` helper convention as in
  `classical/selftest.sml:1–6`); tactic successes through
  `Tactical.VALID`; exact residual goals for non-closing tactics;
  negative cases; no claset/simpset/theory state leaks; strength
  corpora as assertions with time budgets, exhaustive sets behind
  higher `HOLSELFTESTLEVEL`.  Persistence/attribute work (the `[iff]`
  attribute) additionally gets `theory_tests/`-style scenarios
  (child visibility, diamond merge, reload idempotence — the
  `rules/theory_tests/` Holmakefile is the model, including the phony
  fresh-process `reload-check`/`state-replay-check` targets).
- **Gates**: `bin/build -t --seq=tools/sequences/upto-auto` per task;
  `bin/build -F -t` at the phase boundary (known pre-existing failure:
  `src/probability` `in_borel_measurable_inv`, recorded in PLAN.md §11
  gate record for Phases 1 and 2).

---

## 5. Phase-3 hooks recorded in the Phase 1–2 plan; the §4.3 option

`PLAN_phase_1_2.md` §1 "out of scope" names the hooks built for
Phase 3: "**`nodup` step parameterization, `addss`-style wrapper
points, safe-simp wrapper slot**" — all verified delivered above — and
"solver-level wrapper instantiation (recorded Phase-3 option, D24)".

`phase12-classical-search-port.md` §4.3 (read in full): Isabelle's
rewriter treats goal Vars as rigid, but its *solvers* may instantiate
them — conditional-rewriting side conditions always use the unsafe
solvers (`resolve_tac`/`assume_tac`), and even "safe" simp may
instantiate unknowns (upstream comments quoted).  The HOL4 render/
unrender design reproduces exactly the rewriter-level rigidity and
cannot reproduce solver-level instantiation.  **Recorded options for
Phase 3** (verbatim substance):

- (a) accept rigid behavior — wrapper simp never instantiates engine
  metavariables (slightly weaker than Isabelle's `addss`, still sound);
- (b) add designated engine "solver" steps that unify a goal against
  refl-style closers, recovering the common `?x = t` side-condition
  cases of Isabelle's unsafe solver (note: the engine's `inst0_step`
  already unifies the conclusion against assumptions and safe0 rules —
  option (b) would extend this shape to simp side conditions);
- (c) full generality (wrapper returns instantiations) — needs a
  metavariable-aware tactic interface, **not recommended**.

The decision was explicitly deferred to Phase 3 ⇒ this is an **owner
decision to schedule** in the Phase-3 plan.  `clasetGoal.sig:83–85`
restates the same commitment from the code side.

## 6. Freeze constraints binding Phase 3 (exact list)

From PLAN.md §11 "Phase 1–2 interface freeze" (= `PLAN_phase_1_2.md`
§11 closing paragraph):

- frozen: the `clasetMeta` store API; `clasetGoal`'s node shape and
  search bookkeeping (the whole `.sig` incl. render/unrender);
  `clasetStep`'s step and record contracts, **depth-step
  parameterization**, and **wrapper application points**;
  `clasetReplay`'s replay-step vocabulary used by blast; the full
  public `classicalLib` tactic signatures; `tableauLib`'s complete
  surface.  Changes (including additive exports to `classicalLib`)
  require an owner decision; module internals stay private.
- still frozen from Phase 0 (`PLAN_phase_0.md` §11): `ntactic`/`wrapper`
  types and combinator semantics; `rulespec`/`cdelta` schema (v1);
  attribute names; marker vocabulary;
  `add_rule`/`export_rule`/`delrule`/`augment_claset`/`the_claset`
  signatures; candidate-lookup entry points + ordering contract;
  `register_tyinfo_contribution`; `claset_config` — with the two
  enacted Phase 1–2 amendments (size metric default;
  `REV_DUP_ELIM_RULE`).
- NOT frozen (usable/extensible with less ceremony): `clasetSearch`'s
  driver surface (`DEEPEN` etc.), `searchHeap`, `clasetUnify`,
  everything in the future `clasimp/` dir.
- observable-behavior preservation duties (`src/auto/CLAUDE.md`):
  `rules_of` contents/order, wrapper lists, candidate-query sequences,
  `process_claset_tags` leftovers, existing warnings.

## 7. Gap summary — what Phase 3 must add or decide

| Item | Status | Action |
|---|---|---|
| `addss`/`addSss` wrapper plug point | exists (`add_(un)safe_wrapper`, `app_*`, D24 points delivered) | build wrappers in clasimp |
| nodup unsafe step | **exists**: `depth_step cs (unsafe_part cs) m` | use directly |
| bounded depth-n solve + replay | pieces public; assembled form private to `classicalLib` | reimplement (~60 loc) in clasimp or owner-decide additive `classicalLib` export |
| DEEPEN start/inc/ceiling | fully programmable in `clasetSearch.DEEPEN`; `classicalLib` hardcodes (2,10)/start 4 | call `DEEPEN` directly if needed |
| depth-4 blast leg | `BLAST_DEPTH_TAC 4 thms` (single-depth, markers, global claset) | use; decide on its built-in preprocessing |
| `Iff` marker | **does not exist** | add (name pre-reserved in PLAN §11) |
| `Simp` marker | **does not exist**; plain thms currently become unsafe intros | design decision needed |
| `[iff]` attribute + persistence | **does not exist**; v1 delta cannot carry it; schema frozen | owner decision (new delta tag / clasimp-owned AncestryData / ThmSetData) |
| iff→intro/dest rule kit | `EQ_IMP_RULE` precedent private (`iff_dest_rule`); public `clasetRules` kit suffices | build in clasimp |
| constructor-intro TypeBase contribution | deferred from Phase 0 to Phase 3's `[iff]` | implement via `register_tyinfo_contribution` |
| solver-level instantiation (§4.3 a/b/c) | deferred decision, hooks in place | owner decision |
| safe-simp mode for `addSss`/`CLARSIMP` | Phase S delivered in `src/simp` (D14–D16: loopers, solver lists, safe-mode `GEN_SIMP_TAC` record) | consume from clasimp |
