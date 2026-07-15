# HOL4 term-net (discrimination net) implementations (Phase 0 planning report)

> Research report, 2026-07-15.  One of four reports produced by parallel
> research agents during the Phase 0 planning round (see `README.md`),
> underlying `../PLAN_phase_0.md` §4.  HOL4 citations refer to this
> repository (worktree `isabelle-tactics`, HEAD `af5d4a63f`).

Context: planning a port of Isabelle's classical-reasoner rule indexing.
Isabelle's `Pure/net.ML` has separate `match_term` and `unify_term`
lookup modes: insertion keys are patterns whose Vars are wildcards;
`match_term` returns entries whose key could match the query
instance-wise; `unify_term` returns entries whose key could unify with a
query that itself contains variables treated as wildcards.  All sources
verified.

## 1. `src/0/Net` — first-order kernel term net

**API** (`src/0/Net.sig:17-30`): `empty`,
`insert : term * 'a -> 'a net -> 'a net`, `match : term -> 'a net -> 'a
list`, `index`, `delete : term * ('a->bool) -> ...`, `filter`, `union`,
`map`, `itnet`, `size`, `listItems`, plus legacy `enter`/`lookup` "for
compatibility".  Docs at Net.sig:33-93 note paths ignore types and
variable names, so retrieval is approximate.

**Labels** (`src/0/Net.sml:28-32`): `V | Cmb | Lam | Cnst of
string*string`.  `label_of` (Net.sml:57-64) maps *both* free and bound
variables to `V`:

```sml
fun label_of tm =
   if is_abs tm then Lam else
   if is_bvar tm orelse is_var tm then V else ...
```

**Stored-pattern variables**: `insert` (Net.sml:140-161) stores each
pattern variable as a `V` edge, so they are wildcards in the tree.  Comb
keys are traversed Rator-first (Net.sml:148-149).

**`match` semantics** (Net.sml:76-98): at every position the stored-`V`
subnet is *always* collected — `val Vnet = net_assoc V net` (line 80),
appended unconditionally at line 90 (`... nets [Vnet]`).  But when the
**query** subterm is a variable, `case label of V => []` (line 83): the
only branch followed is the stored-`V` one.  So: **stored variables are
wildcards, query variables are not** — `match tm` returns every entry
whose key *could match* `tm` instance-wise.  This is exactly Isabelle's
`match_term`.  Results are "most specific match first" (Net.sig:58-59).

**`index`** (Net.sml:104-127): follows the exact label path only
(`assoc1 label L`, line 108) — no wildcarding in either direction;
strictly a subset of `match` results (Net.sig:61-66).

**`lookup`/`enter`** (Net.sml:271, 273-290): legacy pair with the same
wildcard semantics as `match` (query `V => []` at line 277), but note it
uses **Rand-first** traversal (`net_update` line 262:
`update (Rator::defd) Rand child`), incompatible with `insert`/`match`
path order — a net must be built with `enter` to be queried with
`lookup`.

**Crucially: there is no unify-mode lookup.**  Nothing in `Net` treats
query variables as wildcards.  An Isabelle `unify_term` port needs a new
traversal function (query-var case must fold over *all* child edges of
the node, recursively skipping one stored subterm — the tricky part is
that a stored `Cmb`/`Lam` edge means "skip a variable-depth subtree",
which requires a `harvest`-style walk as in mlibTermnet below).

Parallel copy for the experimental kernel:
`src/experimental-kernel/Net.{sig,sml}`.  The shared post-kernel
signature is `FinalNet` (`src/prekernel/FinalNet-sig.sml`), pinned by
`src/thm/Overlay.sml:27`
(`structure Net : FinalNet where type term = Term.term`).

## 2. `src/1/Ho_Net` — higher-order-keyed net

**API** (`src/1/Ho_Net.sig:14-19`): `empty`,
`enter : term list * term * 'a -> 'a net -> 'a net`,
`lookup : term -> 'a net -> 'a list`, `merge_nets`, `fold'`,
`vfilter : ('a->bool) -> ...`.  No per-key delete; deletion is by value
predicate (`vfilter`).

**Labels** (`Ho_Net.sml:35-39`): `Vnet | FVnet of string*int | Cnet of
string*string*int | Lnet of int` — head symbol plus **arity**.

**HO approximation on insertion** — `stored_label` (Ho_Net.sml:63-75):
`strip_comb` the key; constant head → `Cnet(Name,Thy,nargs)`, args
indexed; lambda head → `Lnet(nargs)`, body indexed with the bound var
removed from `fvars` (lines 68-69); variable head **in `fvars`** ("local
constants", e.g. assumption-free variables) → `FVnet(Name,nargs)`, args
indexed; variable head **not in `fvars`** → `(Vnet,[])` (line 73): the
entire application `v t1 ... tn` collapses to one wildcard and the
arguments are discarded.  The header comment (Ho_Net.sml:9-17) explains
`fvars`: a rewrite `[x=0] |- x = 0` must only fire on literal `x`.

**Query side** — `label_for_lookup` (Ho_Net.sml:83-90): query variables
become `FVnet(Name,nargs)`, i.e. treated as fixed constants, never
wildcards.  `follow` (Ho_Net.sml:132-146) follows the exact-label edge
plus always the `Vnet` edge (lines 143-145, skipping one query subterm).
So again: **stored instantiable vars are wildcards; query vars are not;
match-mode only, no unify mode.**

**simpLib usage** (`src/simp/src/simpLib.sml`):
- Simpset net type: line 242 `type net = net_conv_info Ho_Net.net`.
- Rewrite keys: line 74
  `key = SOME (free_varsl (hyp th), lhs(#2 (strip_imp(concl th))))` —
  hypothesis frees are the `fvars` frozen as `FVnet`.
- `net_add_conv` (lines 359-364): keyless conversions are entered under
  `any = mk_var("x",alpha)` — a pure `Vnet` wildcard hit on every lookup.
- Application: lines 770-771 `tryfind ... (lookup tm net)` inside
  `rewriter_for_ss`; context rewrites added via `net_add_convs`
  (line 765).
- Name-based removal (`-*`): line 312 `Ho_Net.vfilter`; enumeration via
  `Ho_Net.fold'` (line 1113).
- simpLib *also* uses first-order `Net` for the congruence-context
  reducer: lines 494, 519
  (`exception redExn of (control * thm) Net.net`), 579
  (`Net.match lookup_t n`).
- Other Ho_Net clients: `src/1/Ho_Rewrite.sml:58,68,88,95` (HO
  rewriting), `src/simp/src/congLib.sml:120`,
  `src/quantHeuristics/quantHeuristicsLibBase.sml`.

## 3. Other net structures in the repo

- `src/metis/mlibTermnet.{sig,sml}` — Joe Hurd's FOL discrimination net
  over metis's untyped `mlibTerm` terms, with the full Isabelle-style
  trio: `match` (keys that could match query; stored-var branch always
  followed at mlibTermnet.sml:157, query-var follows only stored vars at
  line 159), `matched` (dual — keys the query would match,
  mlibTermnet.sml:230-256), and `unify` (mlibTermnet.sml:202-228: a query
  `Var` expands the whole subnet via `harvest` (lines 173-200) with
  substitution-consistency tracking).  **This is the only in-repo net
  with a unify_term-style mode** — the best structural template for the
  port, though it works on metis FO terms, not HOL terms.
- `src/metis/mlibLiteralnet.{sig,sml}` — sign/predicate-dispatching
  literal index wrapping mlibTermnet.
- `src/metis/mlibSubsume.{sig,sml}` — clause-subsumption index built on
  the above.
- `src/parse/TypeNet.{sig,sml}` — discrimination net keyed by `hol_type`
  with `find/peek/match`.
- `src/parse/LVTermNet.{sig,sml}` + `LVTermNetFunctor.sml` (functor form,
  applied in `src/1/LVTermNetFunctorApplied.sml`) — net keyed by
  `(term list * term)` (local vars + pattern), `match` returns key-value
  pairs; used by `Overload`/`term_grammar`.
- `src/parse/FCNet.{sig,sml}` — Net clone treating the pretty-printer's
  "fake constants" (which are really variables) as constants; used by
  `term_pp.sml`, `term_grammar.sml`.
- `src/compute/src/clauses.sml:191` — no net, only a TODO comment wishing
  for one.
- tactictoe has no discrimination nets (kNN-based).

## 4. Build band

- `Net` lives in `src/0` = the `**KERNEL**` entry at
  `tools/sequences/kernel:23` (`tools/build/buildutils.sml:117` maps
  `stdknl` → `"0"`; line 213 substitutes `**KERNEL**`), between
  `src/prekernel` (line 22) and `src/thm`.
- `Ho_Net` lives in `src/1` = `tools/sequences/kernel:39`, after
  `src/parse` (34) and `src/bool` (38), before `src/proofman` (41).
- Both are in the `kernel` sequence (`tools/sequences/upto-hol` =
  `#include kernel` + `#include base-hol`; `base-hol` starts at
  `src/compute/src`).  Per CLAUDE.md this is the earliest band:
  per-directory `Holmake` in `src/0`/`src/1` needs `--poly_not_hol`.

**Planning takeaway**: HOL4's `Net.match`/`Ho_Net.lookup` both implement
only Isabelle's `match_term` semantics (insertion keys are patterns whose
variables are wildcards; query variables are treated as rigid).  Neither
has a `unify_term` analogue; `mlibTermnet.unify`
(src/metis/mlibTermnet.sml:202-228) is the only existing implementation
of that lookup mode and would need re-deriving over HOL terms (or Net's
label alphabet) for classical-reasoner elim/intro rule indexing where
goals contain schematic-like free variables.
