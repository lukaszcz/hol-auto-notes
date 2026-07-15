# Lazy-sequence / backtracking infrastructure before `src/boss` (Phase 0 planning report)

> Research report, 2026-07-15.  One of four reports produced by parallel
> research agents during the Phase 0 planning round (see `README.md`),
> underlying `../PLAN_phase_0.md` §3 and owner decision D13.  HOL4
> citations refer to this repository (worktree `isabelle-tactics`, HEAD
> `af5d4a63f`).

Context: Isabelle tactics return lazy sequences of results enabling
ORELSE vs APPEND (keep-alternatives) composition; HOL4 tactics return a
single result.  This report surveys what exists in the build BEFORE
`src/boss` that is reusable for (a) wrapper combinators over
nondeterministic step tactics and (b) a backtracking search engine.

Build-order context (`tools/sequences/kernel` and
`tools/sequences/base-hol`): `src/portableML` is near the very top of the
kernel sequence (kernel:14), `src/portableML/monads` right after
(kernel:15), `src/1` at kernel:37; then in base-hol: `src/simp/src`
(base-hol:14), `src/metis` (base-hol:15), `src/meson/src` (base-hol:16).
All of the below is available well before `src/boss` (base-hol:57).

## 1. `src/portableML/seq` — yes, a real lazy list

- `src/portableML/seq.sig:13-44` — `type 'a seq` with:
  `cases : 'a seq -> ('a * 'a seq) option`, `fcases`, `append`, `result`
  (singleton), `fresult : (unit -> 'a option) -> 'a seq`,
  `delay : (unit -> 'a seq) -> 'a seq`, `fromList`,
  `flatten : 'a seq seq -> 'a seq`, `map`, `mapPartial`, `filter`,
  `bind : 'a seq -> ('a -> 'b seq) -> 'b seq`, `empty`, `null`, `hd`,
  `tl`, `cons`, `take`, `drop`, `length`.  Norrish, "lazier" variant of
  Paulson's lazy list.
- Implementation `src/portableML/seq.sml:6-22`: 4-constructor datatype
  `LNIL | LCONS | LDELAYREF of 'a seq ref | LDELAYED`; `delay`/`force`
  **memoize** (the ref is overwritten with the forced value,
  seq.sml:12-22).  `append` is fully lazy in both arguments
  (seq.sml:41-44); `bind` = append∘flatten∘map (seq.sml:81-84).  No
  fair/interleaved append and no `interleave` here.
- Shared dir (not poly-only), so both Poly/ML and Moscow ML.
- Existing precedent for "try alternatives from a seq with exception
  backtracking": `src/1/Tactical.sml:1052,1072-1078` (`Q_TAC0` walks the
  parse-result seq, applying the tactic to each parse until one
  succeeds), `src/1/mp_then.sml:61`, `src/1/resolve_then.sml:171` (walk
  `TermParse.prim_ctxt_termS` pattern seqs with a failure continuation
  `k`).

Also in portableML:

- **`Streams`** — `src/portableML/Streams.sig:1-13`:
  `datatype 'a stream = Stream of 'a * (unit -> 'a stream)` (a
  *non-empty* stream; emptiness is the exception `end_of_stream`, with
  `empty_stream : unit -> 'a stream` raising it).  Ops: `stream_map`,
  `stream_append`, `stream_append_list`, `stream_flat`, `permutations`.
  Crude; users: `src/1/match_goal.sml:4`,
  `src/num/arith/src/Sol_ranges.sml`, `src/pred_set/src/hurdUtils.sml`.
- **`seqmonad`** — `src/portableML/monads/seqmonad.sig:4`:
  `type ('a,'b) seqmonad = 'a -> ('a * 'b) seq.seq` — a full
  nondeterministic-state monad over `seq.seq`, i.e. exactly the "wrapper
  combinator over nondeterministic step" shape.  API (seqmonad.sig:6-32):
  `fail`, `return`, `ok`, `>-` (bind), `++`/`+++` (choice,
  keep-alternatives), `>>`, `>->`, `repeat`, `repeatn`, `tryall`,
  `optional`, `mmap`, `lift`, `lift2`, plus injections `fromOpt`,
  `fromErr`, `toError`.  Currently used by the parser
  (`src/parse/Preterm.sml`, `src/parse/TermParse.sml`) and `src/q/Q.sml`,
  `src/integer/CooperShell.sml`.  **This is the closest existing analogue
  of Isabelle's `Goal -> Goalstate Seq.seq` tactic type**: instantiate
  `'a := proof-state`.

## 2. `src/simp/src/Sequence` — Paulson's original Isabelle sequence, ported

- `src/simp/src/Sequence.sig:17-40` — literally Paulson's 1988
  `sequence.ML` (header, Sequence.sig:1-14), ported by Donald Syme 1995.
  `datatype 'a seq = Seq of unit -> ('a * 'a seq) option`
  (`Sequence.sml:10`) — closure-based, explicitly **non-memoizing**
  ("RECOMPUTES if sequence is re-inspected", Sequence.sig:8).  API
  includes things portableML `seq` lacks: `seq_interleave` (fair append),
  `seq_iterate`, `seq_diagonalize`, `seq_chop`, `seq_permutations`,
  `seq_print`, `mk_seq`.
- Users: **only** `src/simp/src/Satisfy.sml:4` (opens it; uses
  `seq_flat`/`seq_map`/`seq_mapfilter`/`seq_iterate`/`seq_hd` for its
  depth-1 Prolog unification search, Satisfy.sml:30-38).  Nothing else in
  the repo references it.
- Export status: it is not re-exported through `simpLib` (no mention in
  `simpLib.sig`/`simpLib.sml`), but as an ordinary structure in
  `src/simp/src` with a default Holmakefile (`src/simp/src/Holmakefile`
  has no NO_SIGOBJ) its `.ui/.uo` land in sigobj, so `Sequence` is a
  **globally visible top-level structure** for any theory built after
  `src/simp/src`.  Note it depends on `liteLib` (`Sequence.sml:6`), so it
  can't move earlier than `src/lite` trivially.

## 3. `src/meson/src` — CPS + exceptions, not sequences

- `mesonLib`'s Prolog engine is **continuation-passing with
  exception-driven backtracking**: `meson_expand_cont`/`meson_expand`
  (`src/meson/src/mesonLib.sml:488-513`) and `expand_goal`
  (`mesonLib.sml:518-576`) thread `cont` functions; failure = `HOL_ERR`
  exception, pruning = a `Cut` exception; alternatives via `tryfind`
  (mesonLib.sml:489).  Continuation caching in `cacheconts`
  (mesonLib.sml:408-419).  The comment at mesonLib.sml:585-586 is
  telling: "If multiple solutions are required, simply give a
  continuation which stores putative solutions then fails; that will
  initiate backtracking!".  No lazy sequences anywhere.
- `jrhTactics` is **not** Isabelle-style.  Types
  (`src/meson/src/jrhTactics.sig:4-10`): `type Goal = thm list * term`
  (assumptions as *theorems*, HOL-Light style),
  `type Goalstate = Goal list * validation`,
  `type Tactic = Goal -> Goalstate`,
  `type refinement = Goalstate -> Goalstate`.  Single-result: its
  `ORELSE` is plain exception handling (`jrhTactics.sml:120`:
  `fun (t1 ORELSE t2) g = t1 g handle HOL_ERR _ => t2 g`), `THEN`/`THENL`
  via `by`/`bys`/`rotate` refinements (jrhTactics.sml:54-72).
  `convert : Tactic -> tactic` (jrhTactics.sml:74-78) maps back to
  standard HOL4 tactics by `ASSUME`-ing the assumption list.  Nothing
  reusable for multi-result search beyond the goal/validation plumbing.

## 4. `src/metis/mlibStream` — third stream type

- Files at `src/metis/mlibStream.{sig,sml}` (metis has no `src/` subdir);
  built at base-hol:15, i.e. after simp, before meson.
- `src/metis/mlibStream.sig:9`:
  `datatype 'a stream = NIL | CONS of 'a * (unit -> 'a stream)` —
  head-strict, tail-lazy, non-memoizing (but
  `memoize : 'a stream -> 'a stream` provided, sig:45).  Rich API
  (sig:15-49): `cons`, `null/hd/tl/hd_tl`, `sing`,
  `append : 'a stream -> (unit -> 'a stream) -> 'a stream`, `map`, `maps`
  (stateful map), `zipwith/zip`, `take/drop`,
  `length/exists/all/filter/foldl/flatten/partial_map(s)`,
  `repeat/count/powers`, `to_list/from_list`, `to_textfile/from_textfile`.
  Used throughout the `mlib*` layer (Joe Hurd's code); it's
  `mlib`-namespaced and conventionally internal to metis-land, though
  technically in sigobj too.

## 5. `src/1` (Lib / Tactical) — nothing multi-result

- Standard tactics are single-result (see 6).  No sequence-of-results
  tactic type exists anywhere in `src/1`.  The only backtracking idioms
  are list-based exception retry: `Lib.tryfind`
  (`src/prekernel/Lib.sig:176`), `Lib.first` (Lib.sig:68), `mapfilter`
  (Lib.sig:101), plus `FIRST`, `ORELSE` in Tactical (exception-based).
  The hand-rolled failure-continuation loops in `mp_then.sml:44-49,61`
  and `resolve_then.sml:135-146,154-157,171` (`try t k` where `k` is the
  "rest of alternatives" continuation) are the closest thing to
  nondeterministic thm-tactics — note `gen_resolve_then` takes a
  `kont : thm -> 'a` and backtracks over unifiers when `kont` raises
  `HOL_ERR` (resolve_then.sml:144-146).

## 6. Goal/tactic/validation types and validity plumbing

- `src/1/Abbrev.sig:8-13`:
  ```
  type goal            = term list * term
  type validation      = thm list -> thm
  type tactic          = goal -> goal list * validation
  type list_validation = thm list -> thm list
  type list_tactic     = goal list -> goal list * list_validation
  ```
- Validity checking exists and is exactly the "replay justification"
  plumbing wanted:
  - `Tactical.VALID` (`src/1/Tactical.sml:438-447`): runs the tactic,
    then applies its validation to `mk_oracle_thm "ValidityCheck"`-
    masqueraded subgoals (Tactical.sml:407-408) and checks the resulting
    theorem proves the original goal (conclusion `aconv` + no bad
    hypotheses, with a special exemption for `marker$suspendlabel` hyps,
    Tactical.sml:410-426).  `VALID_LT` for list_tactics
    (Tactical.sml:448+).
  - `GEN_VALIDATE`/`VALIDATE` (`src/1/Tactical.sml:500-523,540-541`):
    instead of failing, **repairs** an invalid tactic by turning extra
    hypotheses into extra subgoals and composing the validation with
    `PROVE_HYP`.
  - The proof manager applies validity checking to interactive tactic
    application via these (in `src/proofman`, kernel:39).

## Summary for the port

There are three overlapping stream types before boss — `seq` (portableML,
memoized, earliest, with the ready-made `seqmonad` choice/bind combinator
layer), `Sequence` (simp, the verbatim Isabelle-1988 ancestor with
`seq_interleave`, used only by Satisfy), and `mlibStream`
(metis-internal).  Nothing currently implements a
`goal -> goalstate seq` tactic type; `seqmonad` over an explicit
proof-state (goal list + validation, as in jrhTactics' `Goalstate`) plus
`seq.append`/`seq.bind` for APPEND/THEN and first-success for ORELSE is
the natural reusable substrate, with `VALID`-style masquerade checking
already available for validating recorded scripts.
