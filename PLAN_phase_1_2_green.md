# PLAN — finishing Phases 1/2 honestly (`PLAN_phase_1_2_green.md`)

Created 2026-07-19, after removing the goal-recognition preprocessors
described in `PLAN_phase_1_2.md` §8.3.7.

## 0. Purpose and the rule that governs it

Phases 1/2 are **not** complete.  They were marked complete on figures
produced by recognising benchmark goals rather than proving them.  This
plan takes the honest baseline to a genuine green.

**The rule, restated because it is the point of this plan:** a
benchmark goal is closed by the tableau search, or it is an asserted
expected failure.  Never by a preprocessor, rewrite set, claset seed or
theory that names the problem, its statement, or a lemma whose only
role is to discharge it.  No milestone below is complete if its numbers
depend on recognition.  If a proposed change cannot be justified
without naming a corpus problem, it is out of scope by construction.

## 1. Honest baseline (measured 2026-07-19)

`src/auto/blast/selftest.sml`, after removal, `HOLSELFTESTLEVEL=2`:

| Suite | Result | Open |
|---|---|---|
| Pelletier `BLAST_TAC` (30 s budget) | **42/48** | 34, 38, 41, 42, 43, 45 |
| Table-1 published depths | **6/9** | 34@7, 38@4, 43@5 |
| Set problems (depths 3/3/4/4) | **4/4** | — |
| Halting II @ depth 7 (120 s) | **unsolved** | — |

Encoded as `pelletier_expected_failures`, `table1_expected_failures`
and the Halting II entry.  Each is asserted to *fail*: if search
improves, the suite turns red and the list must be shrunk
deliberately.  The classical and rules selftests are unaffected and
green.

Two facts worth carrying forward:

- **P46 and P52 were seeded but the search solves them unaided.**  The
  seeds masked less than their presence suggested; do not assume every
  removal implies a capability gap.
- **Every open Pelletier problem is a timeout, not a clean failure.**
  An earlier, unretained pre-M2 observation reportedly completed P34
  at depth 7 when the budget was lifted.  Because its exact run was not
  retained, it does not prove capability for this artifact.  Fixed-budget
  search cost is the directly observed symptom that M1 tests; missing
  inference capability and the cause of that cost remain open.

## 2. Milestones

### M1 — Search performance (do this first; it may resolve several)

Hypothesis: the open problems are within reach and the port is paying
large avoidable constant factors.  Evidence already in hand:

1. **The rule cache is defeated.**  `blastSearch.sml:448` and `:598`
   allocate `blastRule.newCache ()` *inside* the per-node clauses, so
   it can only ever hit for the safe/unsafe pair within a single node.
   The cache key is `(safe, vars, formula)` and is sound across nodes,
   and `freshName` ignores its cache argument (session-global counter),
   so nothing in it is node-local.  Allocate one cache in `runTerms`
   and thread it.  Every other node currently re-runs `candidates`
   (net lookup + `candidate_order` sort) and re-converts every matching
   theorem through `canonical_data`.
2. **Linear assoc scans on per-constant paths.**  `blastRule.generic_info`
   (`:64-78`) does `List.find` with string equality over a
   monotonically growing global list, once per constant occurrence in
   every term translation and every `query_skeleton`.  `lookup_type` /
   `lookup_term` (`:80`, `:117`) are likewise linear with `aconv`.
   Replace with `Redblackmap` keyed on the encoded name.
3. **Uncached canonical forms.**  `clasetRules.canonical_form_of` is
   recomputed per application attempt, and the elim path
   (`clasetRules.sml:83-98`) lacks the `is_canonical` short-circuit
   the intro path has (`:69-78`), so it does real kernel work
   (`SPECL` + `MP`/`ASSUME` + `curry_conj_premises` + `DISCH` + `GENL`)
   on every attempt.  Memoize per theorem, or at minimum add the fast
   path.  Same call site in `blastRule.sml:260`.

Acceptance: no behavioural change (all currently-passing goals still
pass, at the same depths); measured wall-clock improvement on the six
open problems recorded in this file.  Any problem that starts solving
turns the suite red — shrink the expected-failure list and raise the
asserted count in the same commit.

#### M1 measurement (2026-07-19)

Method: compare the pre-M1 commit `be308c56d` with the completed M1
commit `c7f72c445`.  The baseline was configured and built through
`tools/sequences/upto-auto` in a detached worktree under `/tmp`.  A
byte-identical temporary executable in each worktree ran exactly the
six open formulae, in the order below, in a fresh process.  Each run
used `BLAST_TAC []`, `Tactical.VALID`, the existing default depth
progression (maximum 20), and the unchanged 30 s `Timeout.apply`
budget.  The two executables ran sequentially on the same host, with
no concurrent build or test launched by this task.  The temporary
harness was removed after measurement.

| Problem | `be308c56d` | `c7f72c445` | Observable change |
|---|---:|---:|---|
| 34 | `>= 30.000 s` timeout | `>= 30.000 s` timeout | indeterminate |
| 38 | `>= 30.000 s` timeout | `>= 30.000 s` timeout | indeterminate |
| 41 | `>= 30.000 s` timeout | `>= 30.000 s` timeout | indeterminate |
| 42 | `>= 30.000 s` timeout | `>= 30.000 s` timeout | indeterminate |
| 43 | `>= 30.000 s` timeout | `>= 30.000 s` timeout | indeterminate |
| 45 | `>= 30.000 s` timeout | `>= 30.000 s` timeout | indeterminate |

These are right-censored observations: `30.000 s` is the timeout
boundary, not a measured completion time.  One observation per
revision was recorded in the original mandated-budget run.  That
single censored observation is not a performance comparison; repeating
the same fully-censored run would still not yield completion times.
This table is retained as the full-search budget result, and supports
no claim of an improvement or regression at that boundary.

To test M1's wall-clock criterion without changing the mandated budget,
an additional uncensored equal-work benchmark pins one explicit
`BLAST_DEPTH_TAC` bound per formula.  The bounds were fixed before any
baseline timing was observed: 34@4, and 38/41/42/43/45@3.  Both
revisions deterministically exhaust (return without proof) below 30
seconds at every bound.  Here "same depths" means the unchanged
configured tactic and theorem arguments run with the same explicit,
asserted depth bound in both revisions.  It is not a claim that these
are unrecorded minimum proof depths.

A current-only calibration showed that five single searches took only
1--8 ms, so before the baseline timing the timed batch sizes were fixed
at 500, 150, 300, 1, 600 and 500 searches respectively for problems
34, 38, 41, 42, 43 and 45.  The harness asserts identical outcome and
counters on every iteration.  Nine measured samples per revision were
then run in fresh HOL processes, in alternating revision blocks
B,C repeated nine times, reversing formula order on even repetitions.
The original three observations were retained when replication was
extended to nine.  The internal timer excludes process startup.  The
table reports median and full observed range; all nine raw samples and
their sorted distributions are retained in `raw.tsv` and `summary.tsv`.
Ratios are baseline median divided by current median.

| Problem@depth (batch) | `be308c56d` median [range] | `c7f72c445` median [range] | Ratio; median change |
|---|---|---|---:|
| 34@4 (500) | 1.324566 [1.265665--1.332898] | 1.081343 [0.852393--1.097296] | 1.225x; 18.4% faster |
| 38@3 (150) | 0.689594 [0.649418--0.721958] | 0.733492 [0.496120--0.763775] | 0.940x; 6.4% slower |
| 41@3 (300) | 0.551140 [0.534326--0.562237] | 0.582392 [0.335794--0.596136] | 0.946x; 5.7% slower |
| 42@3 (1) | 12.313119 [12.266258--12.378128] | 12.169881 [12.151304--12.189878] | 1.012x; 1.2% faster |
| 43@3 (600) | 0.913404 [0.847513--0.919069] | 0.845203 [0.611525--0.871889] | 1.081x; 7.5% faster |
| 45@3 (500) | 0.370673 [0.306633--0.378364] | 0.466448 [0.245996--0.480193] | 0.795x; 25.8% slower |

The complete counters common to both revisions are identical per
constituent search: branches created/closed/choices pruned are 8/1/0,
27/21/29, 5/5/0, 34/97/11, 5/1/0 and 5/0/0 in the same problem order.
The engine has no separate complete inference counter at these
revisions; fixed tactic, explicit depth, exhaustive outcome and these
three complete search counters are the available equal-work check.
The current median is lower for 34, 42 and 43, but higher for 38, 41 and
45.  The distributions for the three slower medians overlap baseline,
so these observations do not establish statistical regressions; they
also do not demonstrate the required improvement for those formulae.
M1's measured-improvement criterion is therefore met for three of the
six workloads and remains unmet for 38, 41 and 45.  No full search now
solves within 30 seconds, and no universal speedup is claimed.

The auditable harness, exact commands, hashes, environment, calibration,
108 raw observations and mechanically-derived summary are retained under
`.agent-files/benchmarks/m1/`.

The full `HOLSELFTESTLEVEL=2` blast suite on `c7f72c445` confirms no
behavioural change: Pelletier remains **42/48**, with the same six
asserted failures; published Table-1 depths remain **6/9**, with
34@7, 38@4 and 43@5 asserted failures; and the set problems remain
**4/4** at depths 3/3/4/4.  Halting II remains an asserted failure at
depth 7 within its unchanged 120 s budget.  Therefore neither expected
failure list nor any asserted count changes after M1.  The
behaviour-preservation half of M1 acceptance is met.  The uncensored
equal-work measurements above show mixed performance, so the
performance half is not fully met.  Improvement at the fixed external
wall-clock boundary remains indeterminate, and the residual problems
proceed to M2 without treating censored times as a speedup.
The complete rerun log is retained as
`.agent-files/benchmarks/m1/verification-level2.log`.

### M2 — Instrument before diagnosing

Do not guess at the residue from M1.  For each still-open problem
record inferences, branches created/closed, choices pruned and depth
reached, and compare against Isabelle's published Table 1 depth for
that problem.  At the M1 revisions `blastSearch.statistics` directly
tracks branches created/closed and choices pruned (plus cache counters
only in the current revision); the configured fixed depth is external,
and there is no complete inference counter.  M2 must add the missing
instrumentation rather than infer those quantities from wall time.

The discriminating question per problem: does our search explore
*more* than Isabelle's at the same depth (consistent with an accounting
or ordering difference in `lim`, `md`, penalty or `candidate_order`),
or does it explore a comparable amount and still not close (consistent
with a capability difference)?  Branch counts alone do not establish
either cause.  Record an indeterminate verdict whenever the evidence
does not exclude the alternatives, before writing any fix.

#### M2 diagnosis (2026-07-19)

The authoritative comparison is the repository's local copy of Paulson's
Blast paper, `papers/paulson1999-blast.txt` §9/Table 1.  It publishes
depth/branch rows for only three open problems: 34@7/100, 38@4/30 and
43@5/24.  Following the measured API contract, only configured depth and
`branches_created` from one completed fixed-depth HOL4 run are compared with
those columns.  HOL4 inferences are not Isabelle tactics, and partial timeout
branches are not completed Isabelle branch counts.

Each probe used `searchGoalMeasured` in a fresh process, a fixed explicit
depth, the unchanged 30-second budget, reproducible ordering, and the same
claset/reconstruction path as `BLAST_DEPTH_TAC depth []`.  A second fresh run
of all eight completed diagnostic rows reproduced their outcomes, all
counters, polls, compact trace summaries and debug/budget protocol fields
exactly.  Full source, commands, environment,
raw TSVs, schedules, checksums and integrity checks are retained under
`benchmarks/m2/`.

| Problem | Fixed-depth evidence | Verdict |
|---|---|---|
| 34 | Depth 6 completes without proof: max cost 6, 160 inferences, branches 37/29, 136 pruned, 133 hits, 3,300 conversions.  The published depth-7 measured-API run is watchdog-censored inside one interval between cooperative polls; no target-depth counter is available or compared with Isabelle's 100.  A pre-M2 lifted-budget completion is only an earlier unretained report. | **Indeterminate.**  M2 proves only the measured-API polling blind spot.  The fixed-budget cause remains indeterminate among accounting/ordering and inner-loop computational cost; depth-7 capability is only reportedly known. |
| 38 | Published depth 4 completes without proof: max cost 4, 624 inferences, branches 140/210, 233 pruned, 314 hits, 5,478 conversions.  The comparable completed branch count is **140 versus Isabelle's 30**. | **Indeterminate; observed completed branch surplus is consistent with accounting/ordering difference but does not exclude a capability difference.** |
| 41 | No published row.  Depth 5 completes without proof: max cost 5, 97 inferences, branches 6/13, no pruning, 63 hits, 1,082 conversions; depth 6 is watchdog-censored between polls. | **Indeterminate**; a cost cliff is established, but ordering and iff/gamma capability are not separable. |
| 42 | No published row.  Depth 3 completes without proof: max cost 3, 451 inferences, branches 34/97, 11 pruned, 637 hits, 6,084 conversions.  Depth 4 reaches max cost 4 and cooperatively interrupts with partial counts 623, 35/141, 10, 924 and 7,856 respectively. | **Indeterminate**; repeated inner work per branch is visible, but there is no external comparator. |
| 43 | Published depth 5 completes without proof: max cost 5, 191 inferences, branches 40/42, 45 pruned, 243 hits, 2,833 conversions.  The comparable completed branch count is **40 versus Isabelle's 24**. | **Indeterminate; observed completed branch surplus is consistent with accounting/ordering difference but does not exclude a capability difference.** |
| 45 | No published row.  Depth 10 completes without proof: max cost 10, 312 inferences, branches 115/89, 92 pruned, 73 hits, 2,477 conversions; depth 11 is watchdog-censored between polls. | **Indeterminate**; depth-sensitive growth is established, but ordering and capability are not separable. |

The completed debug runs retain only exact compact trace derivatives: poll/
state count, maximum live branches, and maximum formula slots in a state.  No
large trace log is needed.  P42@4 returned `Interrupted` after 31.662 seconds
at the next poll; P34@7, P41@6 and P45@11 did not return to `prv` before the
separate 60-second process watchdog.  Those three rows explicitly record
`completion=unobserved` and `NA` counters.  This proves only that the
cooperative measured API's polling at `prv` entry does not bound the inner
interval between polls.  It neither localises the computation within that
interval nor diagnoses production timeout behavior, and is not itself an M3
fix.

#### M2 phase-local follow-up (2026-07-20)

Outer commit `8264571be` added cooperative checkpoints through the named inner
workers and ten phase work counters.  Task 7b reran the formerly critical
P34@7, P41@6, P42@4 and P45@11 rows at the same 30-second cooperative deadline
and 60-second safety watchdog.  It also reran completed published P38@4 and
P43@5 for comparable phase profiles, and completed adjacent P34@6, P41@5 and
P45@10 profiles.  Every row used a fresh sequential HOL process.  Two passes
retained all earlier M2 fields, both stop-poll/checkpoint counts, configured
and resource depth, cache counts, the new phase counters, and bounded trace
summaries under `benchmarks/m2-phase/`.

| Problem | Phase evidence | Verdict |
|---|---|---|
| 34 | Depth 6 reproducibly has 3,300 candidate conversions, 2,674 rule unifications, 231 equality probes and 1,938 literal-close attempts.  Both depth-7 runs are watchdog-censored with no snapshot. | **Still opaque.**  No snapshot distinguishes one indivisible primitive, emergency rollback cleanup, or a caller continuation's reconstruction/validation interval.  No active phase can honestly be named. |
| 38 | Depth 4 reproducibly completes without proof with 5,446 candidate conversions, 4,916 rule unifications, 734 equality probes and 6,367 literal-close attempts.  Core search counts remain 624 inferences and 140/210 branches. | **Mixed work; no time-dominance verdict.**  The completed 140 branches versus Isabelle's 30 retains the original caveat: it is consistent with, but does not prove, an accounting/ordering difference. |
| 41 | Depth 5 reproducibly has 1,069 candidate conversions, 1,189 rule unifications, 125 equality probes and 1,099 literal-close attempts.  Both depth-6 runs are watchdog-censored with no snapshot. | **Still opaque** among an indivisible primitive, emergency rollback cleanup, and caller continuation reconstruction/validation; no phase is selected as causal. |
| 42 | Both depth-4 runs return `Interrupted`.  Run-one/run-two ranges are 617--620 inferences, 34 branches created, 7,807 conversions, 8,417--8,433 unifications, 957--961 equality probes and 13,902--13,955 literal-close attempts. | **Mixed, time-censored work.**  Literal closing has the largest attempt count, but counts are not elapsed time and the partial counters are deliberately recorded as nondeterministic. |
| 43 | Depth 5 reproducibly completes without proof with 2,833 candidate conversions, 2,795 rule unifications, 281 equality probes and 2,142 literal-close attempts.  Core counts remain 191 inferences and 40/42 branches. | **Mixed work; no time-dominance verdict.**  The completed 40 branches versus Isabelle's 24 retains the same non-causal caveat. |
| 45 | Depth 10 reproducibly has 2,455 candidate conversions, 1,974 rule unifications, 336 equality probes and 4,666 literal-close attempts.  Both depth-11 runs are watchdog-censored with no snapshot. | **Still opaque** among an indivisible primitive, emergency rollback cleanup, and caller continuation reconstruction/validation; no phase is selected as causal. |

P38, P43 and all three completed predecessor rows reproduce every non-time
field exactly.  All six target completion/result pairs reproduce.  For P42,
only that pair reproduces: its partial work counters differ because the stop
is selected by elapsed time.  No cutoff state or search-path-prefix
reproduction is claimed.  Retaining the failed strict determinism check is
more honest than presenting censored work as deterministic.  For every
observed row, `stop_polls = cooperative_checkpoints`.

The counters show quantities of work only.  Without phase-local timing they do
not establish elapsed-time dominance by candidate enumeration/net traversal,
canonical conversion, cache copying, rule iteration, unification, equality,
literal closing, or premise/search transitions.  Equality substitution has no
successes in these profiles, literal attempts are largest for P42/P45, and
candidate enumeration equals conversion attempts with only 3--12 percent as
many formula-cache hits; these rank experiments but are not causal findings.

The bounded next step is Task 7c: test the emergency-rollback hypothesis by
making that cleanup observable and bounded while preserving state safety and
ordinary search behavior, then rerun P34@7, P41@6 and P45@11 at the same
30/60-second boundaries.  This does not guarantee that the rows return.  If
any remains watchdog-censored, instrument the caller-continuation boundary to
separate reconstruction/validation from the remaining indivisible search
interval before attempting a search optimization.  Immutable per-theorem
canonical-form memoization remains an unselected candidate; do not land it
from work counts alone.  Complementary-literal indexing ranks behind it and
likewise needs evidence separating literal scans from unification and
transition work.

### M3 — Capability gaps

M2 does not identify a cause.  The following are possible shared
mechanisms to investigate without treating an M2 verdict as evidence
that any one is defective (34, 38, 41, 42, 43 and 45 are all
nested-biconditional and/or diagonal problems):

- **Biconditional handling.**  P41/42/43 nest `<=>` under quantifiers;
  P34 is Andrews's Challenge, essentially iff-nesting.  Check
  `IFF_CELIM_THM` declaration and whether iff splitting duplicates
  correctly under γ.
- **γ-duplication depth.**  `requeueGamma` / `md` accounting governs
  how often a universal is re-used; the published Table-1 depths are
  the reference for whether ours matches.
- **Equality substitution.**  `equalSubst` and its typed counterpart —
  relevant to P43 and P52-shaped goals.

Each fix lands with a failing-first regression in the changed module's
`selftest.sml`, per `src/auto/CLAUDE.md`.

### M4 — Halting II

Attempt only after M1-M3.  It is the largest goal in the suite and
depends on γ-duplication and iff handling being right.  If it remains
out of reach, it stays an asserted expected failure with the M2
measurements recorded here as justification — **not** an answer lookup,
and not a quietly dropped test.

### M5 — Restore honest counts

Shrink both expected-failure lists to whatever M1-M4 achieve, raise the
asserted counts to match, and re-run: `Holmake` + `./selftest.exe` in
all three directories, `bin/build -t --seq=tools/sequences/upto-auto`,
then `bin/build -F -t` as the phase-boundary gate.  Update
`PLAN_phase_1_2.md` §8.3.7's baseline table and reclose TASK_23/TASK_24
in `tasks_phase_1_2/PROGRESS.md` — stating the achieved counts, not
"all pass".

## 3. Structural guard against recurrence

Add to `src/auto/rules/selftest.sml`: assert that every theorem
exported by `clasetSeedTheory` either carries a claset rule attribute
or is one of the explicitly-listed rule schemas consumed
programmatically (`NOT_IMP_CELIM_THM`, `NOT_FORALL_CELIM_THM`,
`NOT_ELIM_THM`).  An untagged, non-rule theorem in the seed theory is
exactly the shape the removed instance seeds had, and the test should
fail on sight of one.

This is a cheap structural invariant, not a substitute for review: it
catches the specific mechanism used here, not recognition in general.
`src/auto/CLAUDE.md` carries the general rule.

## 4. Decided (not open questions)

- Expected failures are asserted to fail, not skipped, so improvement
  forces deliberate list maintenance.
- The full corpus stays in the suite; no goal is removed.  (TASK_23 §3.)
- Budgets stay at 30 s (Pelletier) and 120 s (Halting II).  A problem
  that needs a raised budget is an M1/M2 finding to record, not a knob
  to turn — raising a budget to convert a timeout into a pass is the
  same category of error as this plan exists to correct.
- M1 precedes M3 because it is cheap, behaviour-preserving, and
  determines how much of M3 is actually needed.

## 5. Owner decisions

1. **If a problem proves genuinely out of reach for Isabelle's blast
   too**, TASK_23 §3 allows a permanent expected-failure entry with a
   citation.  Confirm case-by-case; do not self-approve.
2. **Whether Phase 3 (`clasimp`/AUTO) may start before M5.**  AUTO
   consumes `BLAST_DEPTH_TAC` and would inherit the current honest
   weakness.  Recommendation: allow it, since the expected-failure
   lists make the weakness explicit and AUTO's own corpus will be
   measured independently — but this is yours to settle.
