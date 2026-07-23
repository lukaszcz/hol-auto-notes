# PLAN — finishing Phases 1/2 honestly (`PLAN_phase_1_2_green.md`)

Created 2026-07-19, after removing the goal-recognition preprocessors
described in `PLAN_phase_1_2.md` §8.3.7.

## 0. Purpose and the rule that governs it

Phases 1/2 were **not** complete when this plan was created.  They had been
marked complete on figures produced by recognising benchmark goals rather
than proving them.  Recognition was removed.

The reviewed tracked source is now commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`.  Its general,
capture-safe persistent-metavariable expansion and exact replay repair
contains no recognition or fallback shortcut.  Fresh isolated evidence
shows 48/48 Pelletier, 9/9 Table 1, 4/4 set problems and a kernel-valid
Halting II success.  Both expected-failure lists are empty.  TASK_23
remains closed, and TASK_24 is reclosed because every listed group now
passes.

On 2026-07-23 the owner decided to close M2 once the full benchmark suite
and Halting II passed because `perf_event_paranoid` cannot be lowered.
Those conditions now pass, so M2 is closed.  The unavailable kernel
profiler remains an environmental limitation, not an open blocker; no
samples or lower setting are claimed.

This plan is **complete**.  Accepted committed-state attempt-04 proves the
direct gates, exact `upto-auto`, `upto-parallel`, style/hygiene checks and
the phase-boundary `bin/build -F -t` at exact `f4fc8be66`.  Its semantic
audit and independent review pass.  M1 is closed: its original explicit
criterion required behaviour preservation and measured improvement on the
six listed workloads, not remeasurement after every later patch.  The
verified `5bc674569` package has a 1,818-entry manifest, six `>=30s`
censored baselines, and all 18 exact kernel-valid public-production runs
below `3.544s`.  No performance run exists for the newer `f4fc8be66`
replay patch, so current-revision performance is not claimed.  That
transparent limitation is a non-blocking follow-up, not a plan blocker.
The final requirement audit is §6; no next task remains for this plan.

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

Method: compare the pre-M1 commit `be308c56d` with the M1 implementation
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

- **34@4 (batch 500)**
  - `be308c56d` median [range]: 1.324566 [1.265665--1.332898].
  - `c7f72c445` median [range]: 1.081343 [0.852393--1.097296].
  - Ratio; median change: 1.225x; 18.4% faster.
- **38@3 (batch 150)**
  - `be308c56d` median [range]: 0.689594 [0.649418--0.721958].
  - `c7f72c445` median [range]: 0.733492 [0.496120--0.763775].
  - Ratio; median change: 0.940x; 6.4% slower.
- **41@3 (batch 300)**
  - `be308c56d` median [range]: 0.551140 [0.534326--0.562237].
  - `c7f72c445` median [range]: 0.582392 [0.335794--0.596136].
  - Ratio; median change: 0.946x; 5.7% slower.
- **42@3 (batch 1)**
  - `be308c56d` median [range]: 12.313119 [12.266258--12.378128].
  - `c7f72c445` median [range]: 12.169881 [12.151304--12.189878].
  - Ratio; median change: 1.012x; 1.2% faster.
- **43@3 (batch 600)**
  - `be308c56d` median [range]: 0.913404 [0.847513--0.919069].
  - `c7f72c445` median [range]: 0.845203 [0.611525--0.871889].
  - Ratio; median change: 1.081x; 7.5% faster.
- **45@3 (batch 500)**
  - `be308c56d` median [range]: 0.370673 [0.306633--0.378364].
  - `c7f72c445` median [range]: 0.466448 [0.245996--0.480193].
  - Ratio; median change: 0.795x; 25.8% slower.

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

#### M1 final production remeasurement (2026-07-22, historical)

The preceding M1 tables are retained as historical measurements of
`c7f72c445`; they improved only P34, P42 and P43 and did not meet the
six-workload criterion.  A later, separate public-production measurement at
`5bc674569` is retained in this directory:

```text
/tmp/isabelle-tactics-task7f-20260720-root/task22_m1_final_measurement_fresh/
```
Its final manifest has 1,818 entries
and SHA-256
`fa9bc5a1a98be7d09522f1c8d8c2100d18a73e4078987a5314a062784a161571`.

The final comparison uses public production
`Tactical.VALID (BLAST_TAC [])`, the unchanged default maximum depth 20 and
the unchanged 30-second `Timeout.apply`.  At baseline `be308c56d`, every
problem is right-censored at `>=30s`.  At measured commit `5bc674569`, three
exact kernel-valid completion samples per problem are:

| Problem | `be308c56d` | Three `5bc674569` samples (s) |
|---|---:|---|
| P34 | `>=30s` | `1.329700`, `1.320911`, `1.316835` |
| P38 | `>=30s` | `.099931`, `.100237`, `.100036` |
| P41 | `>=30s` | `.009163`, `.009141`, `.009075` |
| P42 | `>=30s` | `.010805`, `.010697`, `.010773` |
| P43 | `>=30s` | `.033935`, `.033627`, `.033786` |
| P45 | `>=30s` | `3.543755`, `3.530560`, `3.470660` |

Every measured interval lies strictly below the baseline censoring boundary.
That strict interval separation met M1's measured-improvement criterion for
all six workloads at `5bc674569`.  A censored baseline does not support a
numerical speedup ratio, so none is computed.  At that revision the honest
suites were 48/48 Pelletier with expected list `[]`, 9/9 Table 1 with
expected list `[]`, and 4/4 sets.  This later evidence superseded only the
earlier status conclusion; it did not rewrite the historical observations
above.

M1 is therefore closed under its original milestone-local acceptance
criterion; that criterion did not require remeasurement after every later
patch.  The newer `f4fc8be66` source has functional, not performance,
evidence, and attempt-04 did not rerun this measurement.  Performance at
`f4fc8be66` is not claimed.  That transparent limitation is a
non-blocking follow-up, not an M1 or plan blocker.

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

- **Problem 34**
  - Fixed-depth evidence: Depth 6 completes without proof: max cost 6,
    160 inferences, branches 37/29, 136 pruned, 133 hits, and 3,300
    conversions.  The published depth-7 measured-API run is
    watchdog-censored inside one interval between cooperative polls; no
    target-depth counter is available or compared with Isabelle's 100.  A
    pre-M2 lifted-budget completion is only an earlier unretained report.
  - Verdict: **Indeterminate.**  M2 proves only the measured-API polling
    blind spot.  The fixed-budget cause remains indeterminate among
    accounting/ordering and inner-loop computational cost; depth-7
    capability is only reportedly known.
- **Problem 38**
  - Fixed-depth evidence: Published depth 4 completes without proof: max
    cost 4, 624 inferences, branches 140/210, 233 pruned, 314 hits, and
    5,478 conversions.  The comparable completed branch count is **140
    versus Isabelle's 30**.
  - Verdict: **Indeterminate; observed completed branch surplus is
    consistent with accounting/ordering difference but does not exclude a
    capability difference.**
- **Problem 41**
  - Fixed-depth evidence: No published row.  Depth 5 completes without
    proof: max cost 5, 97 inferences, branches 6/13, no pruning, 63 hits,
    and 1,082 conversions; depth 6 is watchdog-censored between polls.
  - Verdict: **Indeterminate**; a cost cliff is established, but ordering
    and iff/gamma capability are not separable.
- **Problem 42**
  - Fixed-depth evidence: No published row.  Depth 3 completes without
    proof: max cost 3, 451 inferences, branches 34/97, 11 pruned, 637 hits,
    and 6,084 conversions.  Depth 4 reaches max cost 4 and cooperatively
    interrupts with partial counts 623, 35/141, 10, 924 and 7,856,
    respectively.
  - Verdict: **Indeterminate**; repeated inner work per branch is visible,
    but there is no external comparator.
- **Problem 43**
  - Fixed-depth evidence: Published depth 5 completes without proof: max
    cost 5, 191 inferences, branches 40/42, 45 pruned, 243 hits, and 2,833
    conversions.  The comparable completed branch count is **40 versus
    Isabelle's 24**.
  - Verdict: **Indeterminate; observed completed branch surplus is
    consistent with accounting/ordering difference but does not exclude a
    capability difference.**
- **Problem 45**
  - Fixed-depth evidence: No published row.  Depth 10 completes without
    proof: max cost 10, 312 inferences, branches 115/89, 92 pruned, 73 hits,
    and 2,477 conversions; depth 11 is watchdog-censored between polls.
  - Verdict: **Indeterminate**; depth-sensitive growth is established, but
    ordering and capability are not separable.

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

- **Problem 34**
  - Phase evidence: Depth 6 reproducibly has 3,300 candidate conversions,
    2,674 rule unifications, 231 equality probes and 1,938 literal-close
    attempts.  Both depth-7 runs are watchdog-censored with no snapshot.
  - Verdict: **Still opaque.**  No snapshot distinguishes one indivisible
    primitive, emergency rollback cleanup, or a caller continuation's
    reconstruction/validation interval.  No active phase can honestly be
    named.
- **Problem 38**
  - Phase evidence: Depth 4 reproducibly completes without proof with 5,446
    candidate conversions, 4,916 rule unifications, 734 equality probes and
    6,367 literal-close attempts.  Core search counts remain 624 inferences
    and 140/210 branches.
  - Verdict: **Mixed work; no time-dominance verdict.**  The completed 140
    branches versus Isabelle's 30 retains the original caveat: it is
    consistent with, but does not prove, an accounting/ordering difference.
- **Problem 41**
  - Phase evidence: Depth 5 reproducibly has 1,069 candidate conversions,
    1,189 rule unifications, 125 equality probes and 1,099 literal-close
    attempts.  Both depth-6 runs are watchdog-censored with no snapshot.
  - Verdict: **Still opaque** among an indivisible primitive, emergency
    rollback cleanup, and caller continuation reconstruction/validation; no
    phase is selected as causal.
- **Problem 42**
  - Phase evidence: Both depth-4 runs return `Interrupted`.  Run-one/run-two
    ranges are 617--620 inferences, 34 branches created, 7,807 conversions,
    8,417--8,433 unifications, 957--961 equality probes and
    13,902--13,955 literal-close attempts.
  - Verdict: **Mixed, time-censored work.**  Literal closing has the largest
    attempt count, but counts are not elapsed time and the partial counters
    are deliberately recorded as nondeterministic.
- **Problem 43**
  - Phase evidence: Depth 5 reproducibly completes without proof with 2,833
    candidate conversions, 2,795 rule unifications, 281 equality probes and
    2,142 literal-close attempts.  Core counts remain 191 inferences and
    40/42 branches.
  - Verdict: **Mixed work; no time-dominance verdict.**  The completed 40
    branches versus Isabelle's 24 retains the same non-causal caveat.
- **Problem 45**
  - Phase evidence: Depth 10 reproducibly has 2,455 candidate conversions,
    1,974 rule unifications, 336 equality probes and 4,666 literal-close
    attempts.  Both depth-11 runs are watchdog-censored with no snapshot.
  - Verdict: **Still opaque** among an indivisible primitive, emergency
    rollback cleanup, and caller continuation reconstruction/validation; no
    phase is selected as causal.

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

#### M2 rollback-ownership follow-up (2026-07-20)

Task 7c distinguished ownership at the measured API boundary.
`searchGoalMeasured` may abandon only its fresh engine-owned state on the
explicit `Interrupted` path; `searchTermsMeasured` still restores
caller-owned prototerms, and stop-predicate or continuation exceptions always
restore and propagate unchanged.  A focused regression interrupted exactly
256 live goal-owned assignments and observed zero emergency cleanup
traversal, no continuation, and identical repeated snapshots.  The caller-
owned and exception paths have separate restoration regressions, including a
saved proof whose reachable assigned variables are cleared on a continuation
exception and a debug trace whose engine-owned cutoff assignments remain a
coherent returned snapshot.  Cleanup counting is allocated only in measured
instrumentation; the base term state and ordinary/Stats paths retain their
original allocation shape.  Ordinary, statistics-only, and completed measured
outcomes and existing counters are unchanged.

The exact retained M2 harness then reran P34@7, P41@6 and P45@11 with the
unchanged 30-second cooperative deadline and 60-second watchdog.  All three
remained watchdog-censored with no snapshot.  Therefore emergency rollback
is not sufficient to explain any of these three watchdogs.

The plan's bounded continuation fallback used temporary flushed markers.
P34 and P45 each entered `reconstructWith` and remained there until the
watchdog.  P41 had two reconstructions return `NONE`, then entered a third and
remained there until the watchdog.  None reached validation.  This localises
the observed interval after a found tableau to proof reconstruction, not
search cleanup.  Exact commands, rows and marker counts are retained under
`benchmarks/m2-rollback/`, including self-contained harnesses, raw per-process
markers/statuses and a mechanically-generated summary.  No search/capability
or canonical-form optimization is selected by this evidence; the next
diagnosis must inspect reconstruction without altering honest outcomes or
budgets.

#### M2 measured-reconstruction follow-up (2026-07-20)

Task 7d added a measured-only reconstruction path.  The ordinary
`reconstruct`/`reconstructWith` functions, tactics and Stats path retain their
original workers.  The diagnostic API cooperatively polls and counts replay
recursion, lazy alternative pulls, all six typed script-step families, stored-
rule setup and post-yield transition processing, duplicate-child movement,
open/residual finish checks, grounding and the `Tactical.VALID` kernel-replay
boundary.  `TypedStep` covers lazy-sequence setup; `AlternativeEnumeration`
covers `seq.cases` and therefore any lazy engine-transition forcing needed to
expose a node.  `StoredRuleTransition` begins only after that yield and covers
child counting plus possible duplicate movement, not the engine call.
Every phase has an `Enter`/`Exit` observation.  A true stop returns an
`Interrupted` snapshot; exceptions from stop or observation callbacks,
including `HOL_ERR`, cross legacy catch-all replay boundaries and propagate
unchanged.  Every bracketed operation is indivisible between polls, especially
lazy forcing, external typed transitions, grounding and kernel calls.
Exceptions and replay backtracking can leave an `Enter` without a matching
`Exit`; the last boundary is observation history, not a causal attribution.

A clean fresh-process P34@7, P41@6, P45@11 schedule shared the original
30-second cooperative deadline between search and reconstruction and retained
the independent 60-second watchdog.  All processes exited normally with a
reconstruction interruption.  P34 and P45 each had one interrupted attempt;
P41 had two complete `NONE` attempts followed by an interrupted third attempt.
The accepted P34/P41 snapshots ended after an alternative-enumeration pull;
P45 stopped on entry to a stored-rule transition.  Earlier discarded captures
placed the P34/P41 cutoff at different adjacent boundaries.  These cutoff
locations are scheduler/deadline observations, not evidence that the last
phase caused the cost.  Full phase counters and every boundary observation are
retained and mechanically checked under `benchmarks/m2-reconstruct/`.

The evidence establishes that cooperative reconstruction monitoring closes
the prior watchdog observability gap, and that these attempts perform
substantial repeated typed replay and alternative enumeration.  It does not
select a search or capability optimization.  At that point, the smallest
next diagnostic, if M3 needed it, targeted lazy forcing inside
`clasetStep` or a measured adapter, tagged with typed step kind and script
position.  It was intended to distinguish
`try_rule`/unification, direct child construction and replay-record
construction.  Do not optimize any of those components from the aggregate
counters alone.  Later M2 subsections record what followed.

#### M2 exact stored-rule forcing follow-up (2026-07-20)

Task 7e keeps ordinary `clasetStep` and reconstruction textually and
operationally separate from a measured-only exact stored-rule adapter.  The
adapter preserves the ordinary lazy sequence and result order while exposing
caller-neutral classical boundaries for positional attempt selection,
freshening/setup, minor conclusion unification, elimination-major
unification, rule instantiation/hypothesis alignment, child/store and direct
result construction, lazy yield, direct child replacement, replay-record
construction and record insertion.  `blastReconstruct` combines those events
with its one-based script position and SafeRule/UnsafeRule/duplicate metadata
only in its diagnostic worker.  A true classical stop is an explicit
interrupted pull; callback exceptions cross the legacy catch-all unchanged.
Ordinary reconstruction, tactics, search and Stats retain their prior paths.
The Task 7d `statistics`/`measured_result` types and measured entry points also
retain their exact prior shapes, counters, worker and outer-only polling
boundaries.  Task 7e publishes its added snapshot and counters only through
distinct `detailed_statistics`/`detailed_measured_result` types and detailed
entry points.

The final-source fresh-process schedule again ran P34@7, P41@6 and P45@11
sequentially with one shared 30-second cooperative deadline per process and a
60-second watchdog.  A schedule-wide atomic driver lock excludes overlapping
cooperating invocations of that driver.  Pre/post endpoint snapshots show no
matching harness process at those endpoints, but do not establish the absence
of unrelated or manual processes throughout the interval.  All three
processes returned normally with status zero.
P34 and P45 each had one interrupted reconstruction; P41 had two completed
`NONE` reconstructions followed by one interrupted reconstruction.  The
compact retained protocol records the exact latest outer/classical snapshots
and complete counters without flushing every subphase boundary.

The authoritative evidence is the chronologically first complete locked run
after the final API repair.  The original validator rejected its valid partial
phase prefixes because it required completion-only equalities.  The corrected
validator keeps exact schema, ordering, observer, subtotal, status and global
poll identities while checking the non-nested forcing-stage prefix relations,
entry/exit balances, coherent optional stored context, major-at-most-minor,
SafeRule non-duplication, and positive counts for concrete current boundaries.
Within the fixed P34/P41/P45 block order it requires the exact one/three/one
`attempt_enter`/`attempt_result` schedule before accepting the sole stdout
row, rejects an active or missing attempt at stdout, rejects every later
marker, and then requires the single terminal status.  Fixed positive
schedule/control numerals are canonical `[1-9][0-9]*` tokens equal to their
scheduled literals, and status is exactly `0`.  Elapsed seconds keep unsigned
decimal grammar `[0-9]+(\.[0-9]+)?`; arbitrary natural counters keep
`[0-9]+`, including leading zeroes, so the lexical claim is not overextended.
It deliberately does not require every failed or exceptional Enter to have an
Exit and does not claim to exclude every semantically impossible state.  A
mechanical test accepts interruption before any stored observation and at all
eleven classical Enter/Exit boundaries, reruns all 15 prior negatives, and
reproduces six further retained ordering/lexical negatives before all 21
reject diagnostically.  The authoritative 22-line lock audit,
its preserved later-append contamination, the rejected-schema provenance and
a later locked replication ledger are retained with explicit labels; no run
was selected for a convenient cutoff.

- **P34@7 / attempt 1**
  - Exact stored-rule evidence: 925 attempts: 18 intro and 907 elim; 154
    SafeRule and 771 UnsafeRule; 158 direct results were yielded and
    recorded.
  - Cutoff observation: Interrupted at outer
    `AlternativeEnumeration/Enter`; latest classical event was script 348
    duplicate UnsafeRule, elim assumption 18, `MinorUnification/Exit`.
- **P41@6 / attempt 1**
  - Exact stored-rule evidence: Completed `NONE`; 1,024 attempts and 144
    yielded/recorded direct results.
  - Cutoff observation: Completed replay; latest classical event was script
    2 SafeRule intro, `MinorUnification/Exit`.
- **P41@6 / attempt 2**
  - Exact stored-rule evidence: Completed `NONE`; 1,046 attempts and 166
    yielded/recorded direct results.
  - Cutoff observation: Completed replay; latest classical event was script
    2 SafeRule intro, `MinorUnification/Exit`.
- **P41@6 / attempt 3**
  - Exact stored-rule evidence: 78,376 attempts: 15 intro and 78,361 elim;
    74,243 SafeRule and 4,133 UnsafeRule; 5,335 direct results were yielded
    and recorded.
  - Cutoff observation: Interrupted at outer
    `AlternativeEnumeration/Enter`; latest classical event was script 30
    SafeRule, elim assumption 1, `ChildStoreConstruction/Exit`.
- **P45@11 / attempt 1**
  - Exact stored-rule evidence: 1,251 attempts: 32 intro and 1,219 elim; 365
    SafeRule and 886 UnsafeRule; 234 direct results were yielded and
    recorded.
  - Cutoff observation: Interrupted at outer
    `AlternativeEnumeration/Enter`; latest classical event was script 378
    SafeRule, elim assumption 1, `AttemptSelection/Exit`.

These are work counts, not elapsed-time attribution.  Cutoff counters and
latest classical events vary with deadline scheduling; the last recorded
phase is not causal evidence and can be historical when an outer boundary
observes the deadline.  The large attempt totals establish repeated
exact-rule replay and a high proportion of elimination attempts that do not
reach direct construction, but do not show whether unification cost, theorem
setup, or the number/order of attempts dominates elapsed time.  No
optimization or capability change is selected by this evidence.

At that point, the smallest justified next diagnostic was measured-only
elapsed-time accumulation for these already-defined classical subphases,
reported alongside the existing attempt counters.  It was to determine
whether repeated elimination-major intervals or another subphase accounted
for elapsed process time, without altering the ordinary worker or inferring
time dominance from counts.  The later timed subsections record what
followed.  The auditable harness, compact raw protocol, derived summary,
malformed fixtures, logs and integrity records are retained under
`benchmarks/m2-claset-force/`.

#### M2 classical elapsed-time follow-up (2026-07-20)

Task 7f adds a timed-only exact-rule diagnostic and timed detailed
reconstruction result.  Ordinary classical/reconstruction/search/tactic/Stats
paths are unchanged.  Task 7d legacy and Task 7e untimed detailed public
shapes, counters, observer order and polling boundaries retain exact parity.
The injected clock starts after Enter observation/poll and accumulates before
Exit observation/poll; failures and backtracking are timed without fabricating
an Exit.  Callback/clock exceptions propagate unchanged and a backwards clock
is an explicit HOL_ERR.  Eleven non-nested phase times sum exactly to total
classical time; whole-attempt wall time supplies a non-double-counted outer
reconstruction remainder.

Review repair regenerated the affected UI/UO chain before timing.  Both exact
predeclared calibration schedules then reproduced every paired work/outcome/
counter field in order.  P38@4 timed versus untimed median process time was
1.462416 versus 1.444847 s (+1.22%); P43@5 was 12.506453 versus 12.635443 s
(-1.02%).  P34@6 performed no reconstruction and its startup-dominated
.015829--.019764/.016093--.019555 ranges are not interpreted.  The active
1,000-replay fixture had timed median .033556 s versus untimed .029825 s
(+12.51%), with all .029518--.069834/.033305--.063459 outliers retained.
These schedules had no external watchdog, quantify perturbation only, and do
not correct target time.

The earlier target raw/audit is retained as pre-review evidence, but its
endpoint `pgrep` mistakenly matched `[m]2clasetforce`; only its atomic lock
excluded cooperating drivers.  The single regenerated-final locked
P34@7/P41@6/P45@11 run corrected the endpoint to `[m]2clasetime`, held the
lock from 10:30:40--10:32:32 UTC, and found no match at either endpoint.  It
used the unchanged shared 30-second cooperative deadline and 60-second
watchdog.  All fresh sequential processes returned status zero.  P34/P45
each had one Interrupted attempt; P41 had two Completed NONE attempts then
one Interrupted attempt.

- **P34@7:** process 30.055021 s; attempt wall 29.498945 s; classical
  16.624000 s; process minus attempts 0.556076 s; attempts minus classical
  12.874945 s.
- **P41@6:** process 30.001364 s; attempt wall 28.781906 s; classical
  20.436422 s; process minus attempts 1.219458 s; attempts minus classical
  8.345484 s.
- **P45@11:** process 30.002653 s; attempt wall 29.455225 s; classical
  16.737128 s; process minus attempts 0.547428 s; attempts minus classical
  12.718097 s.

Minor conclusion unification was the largest measured classical phase:
13.605446, 10.220310 and 12.267324 seconds, or 81.84%, 50.01% and 73.29% of
classical time.  It was only 45.27%, 34.07% and 40.89% of total process time.
Major unification was the next consistent phase at 2.433251, 1.822324 and
2.722885 seconds.  P41 additionally spent 3.926697 seconds in attempt
selection.  Exact per-attempt times and every other phase are retained under
`benchmarks/m2-claset-time/`.

**Verdict:** minor unification dominates the measured classical subset, not
the complete process.  Between 8.35 and 12.87 seconds per target remains
unmeasured outer reconstruction, so optimizing unification alone is not yet
justified.  At that point, the smallest next diagnostic was to split minor
unification into normalization, store walk/decomposition/binding and
failure/rollback time, and separately time outer alternative
enumeration/replay recursion while excluding the classical intervals.
Maxima or bounded histograms were required to distinguish a few expensive
calls from attempt volume before selecting an optimization.  Later
subsections record what followed.  No capability or optimization change
landed in Task 7f.

##### Task 7f terminal-boundary and calibration-summary repair

Review found that the outer terminal clock was read only after detailed
statistics and classical snapshots had been aggregated.  The timed-only
worker now captures and validates the terminal clock immediately when replay
produces Completed SOME, Completed NONE or Interrupted, then passes the fixed
elapsed value into report construction.  Therefore attempt minus classical
now excludes diagnostic report aggregation.  A deterministic regression
covers all three terminal outcomes, requires exactly the start and terminal
outer clock reads, pins the elapsed value, and fails on any later read.
Clock exception identity, inner phase timing, untimed APIs and ordinary paths
retain their prior behavior.  Under `pre-boundary-fix-history/`, 14 named
data/log files remain byte-identical to their pre-archive hashes; the five
narrative bodies are preserved with archive banners and therefore have new
hashes.  That preceding regenerated-final evidence is historical only.

A portable AWK summarizer now mechanically derives each representative and
active median, full range, timed/untimed ratio and percentage change from the
raw final ledgers.  The exact TSV is locked; calibration validation regenerates
and byte-compares it while retaining the pre-existing exact schedule, paired
work and result checks.  A generated elapsed-only adversary leaves schedule
and work fields unchanged and is rejected solely by summary drift.

After forced classical/blast/harness regeneration, both full level-2
selftests passed.  The unchanged schedules then ran once, without rerun or
selection, in the required active 10-process, representative 18-process, and
locked target order.  Final calibration medians [full ranges] were P38@4
untimed 1.626393 [1.624928--1.687233] versus timed 1.639761
[1.628874--1.680046] (+.82%); P43@5 12.678592
[12.398727--12.718826] versus 12.557997 [12.447331--12.614098] (-.95%);
P34@6 .015938 [.015787--.015955] versus .015898 [.015876--.015918]
(-.25%, no reconstruction); and the active fixture .029952
[.029760--.041088] versus .044031 [.033360--.045169] (+47.01%).

The one post-boundary target driver held the corrected `[m]2clasetime` lock
from 11:14:26--11:16:19 UTC with clean endpoints and status zero throughout.

- **P34@7:** process 31.911690 s; attempt wall 31.390598 s; classical
  16.514289 s; process minus attempts .521092 s; attempts minus classical
  14.876309 s.
- **P41@6:** process 30.005085 s; attempt wall 28.653267 s; classical
  20.338861 s; process minus attempts 1.351818 s; attempts minus classical
  8.314406 s.
- **P45@11:** process 30.004055 s; attempt wall 29.492010 s; classical
  16.936954 s; process minus attempts .512045 s; attempts minus classical
  12.555056 s.

Minor unification remains the largest measured phase at 13.380533,
10.175967 and 12.349833 seconds, respectively.  The corrected boundary makes
the remaining outer share more precise but does not select an optimization:
8.31--14.88 seconds of each attempt block remains outside the measured
classical phases.  The next-diagnostic and no-optimization verdict above is
unchanged.  Exact attempt vectors, phases, summaries, audits, hashes and
validation evidence are retained under `benchmarks/m2-claset-time/`.

The supported build/selftest reproducer never edits this source tree.  It
copies the complete tree, removes copied git plus external `.codex`, `.pi` and
`.claude` metadata, rebases internal absolute links, and categorizes every
remaining absolute link.  Build-relevant, source-internal and sigobj links
must resolve below the copy; other absolute links are counted and listed, not
covered by a blanket containment claim.  Smart-configuration runs with HOLDIR
unset and PATH limited to copied bin plus validated system directories.
Copied Holmake creates an actual harmless target from a tiny explicit
Holmakefile with ancestor preexecs disabled; its recipe/debug output and
existing canonical target are retained and reject original-root resolution.

The Python supervisor alone owns each command session/process group.  Outer
HUP/INT/TERM traps forward every signal to the active supervisor and return,
including a second signal; they never infer or signal a PGID.  The supervisor
uses TERM first and KILL on a repeated signal or grace expiry, verifies the
group is gone and reaps it.  The outer shell reaps the supervisor and accepts
quiescence only from retained `command_group_gone ... result=PASS` evidence.
`--relocation-check` performs only copy/configuration/diagnostics and removes
its disposable copy.  The separate full-outer synthetic suite signals the
published shell PID and validates statuses 129/130/143/143, descendant
containment and source immutability; it remains distinct from relocation
evidence.  Whole-tree manifests retain hash, ownership, time and mode fields.

The final status-0 relocation check used the current authoritative script in a
private user/mount namespace: the mandated host `namespace-run` directory was
bound to namespaced `/var/tmp` and a fresh tmpfs covered namespaced `/tmp`.
The copied Holmake target produced 241 file-trace lines and zero original-root
matches; all 40 input hashes matched the current inputs, the three 35,653-line
whole-tree manifests were byte-identical, and the disposable copy was removed.
The exact invocation, compact raw evidence, and hashes of omitted bulky raw
audits are retained under `benchmarks/m2-claset-time/`.

#### M2 timed-v2 outer/minor decomposition follow-up (2026-07-20)

**Historical/void evidence-chain notice:** all later claims of authority in
this subsection are superseded by the final chain recorded below.  The
package `benchmarks/m2-timed-v2/` is retained as history only.

Task 7g's additive timed-v2 API measures exclusive outer
AlternativeEnumeration, ReplayRecursion/continuation and Other time, and
splits minor unification into normalization/setup, traversal/decomposition/
binding and the immutable-store zero cleanup.  It retains per-call maxima and
calls/failures.  Ordinary paths and prior timed-v1 shapes are unchanged.

The auditable protocol was frozen and hashed before timing.  A locked forced
rebuild regenerated the classical/blast UI/UO chains and harnesses; both
level-2 selftests passed.  Representative calibration ran its fixed 12 fresh
processes once: P38@4 timed-v1 median [range] was 1.635459
[1.617054--1.636150] seconds versus timed-v2 1.631828
[1.624549--1.633797] (-.22%); P43@5 was 12.519296
[12.499552--12.534213] versus 12.523107
[12.518740--12.524868] (+.03%).  The fixed active 1,000-replay fixture was
.033204 [.033089--.033283] versus .037343 [.037287--.037365] (+12.47%).
Every paired outcome, search counter and ordered reconstruction signature was
identical.  Calibration quantifies perturbation only and does not correct
target times.

Pre-timing/load repairs and the sole predeclared target retry are retained
rather than hidden.  Two calibration helpers first needed public record-type
annotations; the active helper then used reserved identifier `signature`.
Neither failure produced an elapsed row.  The first P34 target harness exited
nonzero during static goal-type elaboration without an attempt or summary;
the predeclared nonzero-harness retry condition authorized one complete
target retry after adding only `val goal : goal`.  Its status-only ledger is
retained.  No valid calibration row or target block was rerun.  The complete
retry raw ledger was SHA-256 sealed before post-collection validator repairs.

The one authoritative fresh sequential target block used the unchanged
shared 30-second cooperative deadline and independent 60-second watchdog.
An atomic lock covered all three processes; the non-self-matching
`[t]ask7gmeasurement` endpoint audit was clean before the block and in the
retained post-block audit.  Status was zero throughout.  P34/P45 each had one
Interrupted/NONE attempt; P41 had two Completed/NONE attempts then one
Interrupted/NONE attempt, exactly as predeclared from the immediately prior
evidence.

- **P34@7**
  - Process / attempts / residual s: 31.902816 / 31.258214 / .644602.
  - Classical / Alternative / Replay / Other s:
    16.576715 / 13.861498 / .001446 / .818555.
  - Minor calls/failures; normalization / traversal / cleanup s:
    928/0; .003631 / 13.396717 / 0.
  - Max traversal / max minor s: .080472 / .080566.
- **P41@6**
  - Process / attempts / residual s: 30.007578 / 28.693033 / 1.314545.
  - Classical / Alternative / Replay / Other s:
    20.311357 / 7.107721 / .041051 / 1.232904.
  - Minor calls/failures; normalization / traversal / cleanup s:
    78,884/2; .101180 / 10.135822 / 0.
  - Max traversal / max minor s: .008215 / .008216.
- **P45@11**
  - Process / attempts / residual s: 30.026667 / 29.408628 / .618039.
  - Classical / Alternative / Replay / Other s:
    16.869572 / 12.217351 / .001700 / .320005.
  - Minor calls/failures; normalization / traversal / cleanup s:
    1,251/0; .005421 / 12.189448 / 0.
  - Max traversal / max minor s: .064181 / .064216.

AlternativeEnumeration is the largest exclusive outer category on all three
targets and is 44.35%, 24.77% and 41.54% of attempt time.  It therefore
crosses the predeclared 40%-on-two-targets threshold for P34/P45.  The retained
pull counts are 356, 30,393 and 419, but timed-v2 exposes no per-pull maximum,
so total time cannot distinguish an outer outlier from pull volume.

Traversal/decomposition/binding is 99.97%, 99.01% and 99.96% of minor time
and 42.86%, 35.33% and 41.45% of attempt time.  It crosses the predeclared
minor threshold on every target.  Its maxima are only .601%, .081% and .527%
of category totals, respectively; together with 928, 78,884 and 1,251 calls,
this identifies accumulated volume rather than a few expensive calls.
Normalization is small and immutable-store failure cleanup is exactly zero.

**Verdict:** Task 7g isolates two general time-owner categories, with the
stronger result being volume-driven minor traversal/decomposition/binding
across all targets.  It still does not isolate a specific principled code
change within store lookup, structural decomposition, pattern/occurs checks
or persistent binding, and AlternativeEnumeration lacks a maximum or bounded
histogram.  Therefore no specific optimization or capability fix was
selected.  At that point, the smallest justified next diagnostic was to
split that traversal category and add a per-pull maximum or bounded
histogram for AlternativeEnumeration; it did not need to revisit
normalization or cleanup.  Later subsections record what followed.  Exact
per-attempt vectors, summaries, calibration, provenance, immutable raw hash,
24 rejected adversarial fixtures and selfchecks are retained under
`benchmarks/m2-timed-v2/`.

##### Task 7g fresh evidence-chain repair (2026-07-20)

**Historical/void evidence-chain notice:** this first fresh chain is also
superseded.  All later claims of authority in this subsection are historical;
the package `benchmarks/m2-timed-v2-fresh/` is not current evidence.

Review established that the preceding numeric raw was sound as an observation,
but its missing original pre-repair bodies and incomplete post-collection
runnable provenance cannot be retroactively proved.  The whole earlier
package is therefore retained and explicitly labelled reviewed-pre-final
historical; none of its rows is authoritative or imported below.

A wholly fresh chain under `benchmarks/m2-timed-v2-fresh/` froze complete byte
bodies for the predeclaration, harnesses, build file, schedules, collector,
runner, validators, synthetic fixture generator/mutator, summarizers, summary
checker and selfcheck before timing.  Its artifact manifest uses the actual
UI/UO paths under `src/auto/{classical,blast}/.hol/objs/...` and records
exact source, harness executable, HOL image and tool identities.  A first
pre-freeze
manifest attempt failed on the obsolete object path; its complete bodies,
sole diagnostic, statuses and exact repair diff are retained.  It preceded
both seal and clocks.

The final preflight forced both affected builds, passed both level-2
selftests, built all three harnesses, and passed synthetic valid calibration
and target fixtures plus 32 independent adversaries.  Each failure log has
its intended sole diagnostic and no PASS.

Under one atomic lock, the unchanged 12 representative, 10 active and
P34@7/P41@6/P45@11 1/3/1 target schedules then ran exactly once with no
retry.  Every harness process and target watchdog exited zero.  Immediate
pre/post snapshots bracket each segment and are clean; separate pre/post
artifact manifests match the frozen identity.  Every paired calibration
outcome, work counter and ordered reconstruction signature matches.

Representative timed-v2 versus timed-v1 medians [full ranges] are P38@4
1.632407 [1.625381--1.660721] versus 1.640508
[1.635822--1.663227] seconds (-.49%), and P43@5 12.622675
[12.596808--12.624016] versus 12.590901
[12.461458--12.592334] seconds (+.25%).  The active 1,000-replay fixture is
.060769 [.037442--.061355] versus .037618 [.037333--.037918] seconds
(+61.54%).  These quantify perturbation only and do not adjust targets.

- **P34@7**
  - Process / attempts / residual s: 30.033281 / 29.557630 / .475651.
  - Classical / Alternative / Replay / Other s:
    16.557207 / 12.185943 / .001409 / .813071.
  - Minor calls/failures; normalization / traversal / cleanup s:
    927/0; .003613 / 13.530240 / 0.
  - Max traversal / max minor s: .083844 / .083929.
- **P41@6**
  - Process / attempts / residual s: 30.002220 / 28.886708 / 1.115512.
  - Classical / Alternative / Replay / Other s:
    20.541524 / 7.079393 / .042280 / 1.223511.
  - Minor calls/failures; normalization / traversal / cleanup s:
    78,685/2; .102817 / 10.106333 / 0.
  - Max traversal / max minor s: .006703 / .006707.
- **P45@11**
  - Process / attempts / residual s: 30.044913 / 29.579849 / .465064.
  - Classical / Alternative / Replay / Other s:
    16.802537 / 12.459903 / .001775 / .315634.
  - Minor calls/failures; normalization / traversal / cleanup s:
    1,250/0; .005432 / 12.189651 / 0.
  - Max traversal / max minor s: .064524 / .064563.

Fresh AlternativeEnumeration shares are 41.23%, 24.51% and 42.12% of
attempt time and cross the predeclared threshold on P34/P45.  Minor traversal
shares are 99.97%, 98.99% and 99.96% of minor time and 45.78%, 34.99% and
41.21% of attempt time.  Maxima are only .620%, .066% and .529% of traversal
totals, so this historical fresh evidence supports the same volume-driven
general category, not a specific optimization.  At that point, the next
diagnostic remained a split of traversal plus a per-pull maximum or bounded
AlternativeEnumeration histogram.  The final Task 7g and later subsections
supersede only that status.  No capability or optimization change was
selected.

##### Task 7g final authoritative evidence chain (2026-07-20)

Review then required a third, wholly fresh chain rather than retrofitting
either prior package.  `benchmarks/m2-timed-v2-final/` is the sole
authoritative Task 7g evidence.  It imports no old row.  Both earlier
packages now have prominent historical/void banners, whose hashes are
retained in the final package.

Before any clock, the final chain froze the complete byte bodies of the
predeclaration, `SEAL_PLAN.md`, harnesses, build file, schedules, collector,
runner, validators, fixture generator/mutator, summarizers, summary checker,
selfcheck and preparation script.  The complete runtime closure has 413
data rows in deterministic sectional order: 398 repository paths C-sorted
first, then 15 tool records in deterministic declared order.  It is not
globally path-sorted.  The authoritative post-collection correction is
`benchmarks/m2-timed-v2-final/FINAL_AUDIT_ERRATA.md`; it overrides only the
frozen predeclaration's false phrase "sorted by path" and changes no
membership, identity or comparison.  The closure contains every regular file
under `src/auto`, all harness source/UI/UO/executable files, `bin/hol`,
`bin/Holmake`, the exact `bin/hol.state0` heap, configure identities and
relevant host tools.  It
explicitly contains `blastSearch`, `blastRule`, `blastTerm`, `tableauLib`,
`clasetLib` and `clasetSeedTheory`.  Preloaded dependencies are closed by the
exact heap hash; automation loaded after it is independently present.

One pre-seal environment-provenance command hung because `poly --version`
inherited an interactive terminal.  No seal or clock existed.  Complete
before/after bodies, logs, statuses and full labeled diffs are retained; the
only protocol repair supplied `/dev/null` and explicitly status-recorded the
probe.  Every full build and level-2 selftest was then rerun from clean state.
The repaired preflight passed, as did synthetic wrapper/HOL-child endpoint
detection and 34 independent adversaries.  These include wrong and
noncanonical-equivalent problem/depth literals (`34` versus `034`, `7`
versus `7.0`) and summary drift; every negative emits one diagnostic and no
PASS.

Under one lock the unchanged 12 representative, ten active and exact 1/3/1
target schedules ran once, with no retry.  All 25 harness processes and three
target watchdogs exited zero.  All six immediate endpoint audits were clean,
and both complete manifests bracketing each segment are byte-identical to the
frozen closure.  The calibration, target and summary validators pass.

Representative timed-v2 versus timed-v1 medians [full ranges] are P38@4
1.649530 [1.642255--1.660204] versus 1.633429
[1.632719--1.667271] seconds (+.99%), and P43@5 12.578063
[12.281841--12.629820] versus 12.568258
[12.458797--12.569931] seconds (+.08%).  The active 1,000-replay fixture is
.060740 [.037328--.061652] versus .037840 [.033335--.038100] seconds
(+60.52%).  Paired outcomes, work counters and ordered signatures match;
these observations quantify perturbation only and do not adjust targets.

- **P34@7**
  - Process / attempts / residual s: 30.027199 / 29.538150 / .489049.
  - Classical / Alternative / Replay / Other s:
    16.586384 / 12.125281 / .001409 / .825076.
  - Minor calls/failures; normalization / traversal / cleanup s:
    923/0; .003528 / 13.570925 / 0.
  - Max traversal / max minor s: .082677 / .082759.
- **P41@6**
  - Process / attempts / residual s: 30.002148 / 28.877672 / 1.124476.
  - Classical / Alternative / Replay / Other s:
    20.534149 / 7.080400 / .041838 / 1.221285.
  - Minor calls/failures; normalization / traversal / cleanup s:
    78,639/2; .103063 / 10.101888 / 0.
  - Max traversal / max minor s: .006659 / .006662.
- **P45@11**
  - Process / attempts / residual s: 30.024981 / 29.559788 / .465193.
  - Classical / Alternative / Replay / Other s:
    16.786278 / 12.458241 / .001740 / .313529.
  - Minor calls/failures; normalization / traversal / cleanup s:
    1,250/0; .005168 / 12.177085 / 0.
  - Max traversal / max minor s: .064477 / .064515.

AlternativeEnumeration is the largest exclusive outer owner and is 41.05%,
24.52% and 42.15% of attempt time.  It crosses the final chain's predeclared
40%-on-two-targets rule on P34/P45.  Traversal/decomposition/binding is
99.97%, 98.99% and 99.96% of minor time and 45.94%, 34.98% and 41.19% of
attempt time, crossing the predeclared minor rule on all targets.  Its maxima
are only .609%, .066% and .529% of category totals, below the predeclared 5%
ceiling, so the broad component is descriptively volume-driven.

**Final Task 7g verdict:** the data select a deeper split of minor traversal
among store lookup, structural decomposition, pattern/occurs checks and
persistent binding, plus a per-pull maximum or bounded histogram for
AlternativeEnumeration.  The predeclared rule forbids selecting an
optimization from these broad buckets.  No specific optimization or
capability fix is yet justified, so M3 remains diagnostic work rather than an
implementation selected by Task 7g.

A post-review, post-collection integrity repair changed no frozen input,
schedule, runtime manifest, raw observation, summary, or historical log and
reran no timing.  A typed deterministic package inventory now records regular
file hashes and every exact symlink target; the checksum manifest includes the
inventory and hashes every regular file except checksum self.  Together they
cover all regular files except checksum self, plus every symlink target.  The
read-only selfcheck compares both regular-file bytes and symlink targets before
and after, and a disposable-copy adversary proves a retargeted endpoint fixture
symlink is rejected without touching the authoritative symlinks.  The erratum
records exact provenance and the mechanical sectional-order and six-endpoint
manifest audit.

#### M2 timed-v3 fine decomposition measurement (2026-07-21)

Task 7h source adds an operation-honest measured-only split of the coarse
minor traversal bucket into persistent store lookup/walk, structural
decomposition/recursion, pattern/occurs/allow decisions, persistent
binding/update and explicit other.  It also splits AlternativeEnumeration
into completed, exhausted/failed and interrupted pulls with totals/maxima,
explicit residual, O(1) classical elapsed snapshots and terminal sequence
statistics-read counts.  Ordinary paths and every timed-v1/v2 public shape
remain unchanged.  This measurement task changed no tracked source and
selected no optimization.

The sole intended authoritative measurement package is
`benchmarks/m2-timed-v3-final/`.  Before timing it froze 29 complete input
bodies, the exact unchanged schedules, hypotheses, retry rule, thresholds and
interpretation.  Its 425-row runtime closure comprises 396 C-sorted repository
paths followed by 29 declared-order resolved tools; it contains every regular
file below `src/auto`, all harness artifacts, exact heap/bin and configuration
inputs.  A first formal pre-seal run passed both forced builds, both level-2
selftests and all harness builds, then failed the endpoint synthetic because
three copied patterns still named `task7g`.  It emitted no diagnostic.  The
complete before/after bodies, status/logs, traced diagnosis and exact repair
diff are retained.  The repair changed only endpoint literals and its ledger;
the full clean rerun passed wrapper/HOL-child non-self-match and all three
positive plus 88 independent negative validator cases before seal.

Under one lock, all 12 representative and ten active fresh processes ran in
the exact frozen order with status zero.  Every paired outcome, search counter
and ordered reconstruction signature matched; all immediate closure manifests
and endpoint snapshots were clean.  Mechanical medians [full ranges] were:

- **P38@4**
  - timed-v2 s: 1.645494 [1.622249--1.647912].
  - timed-v3 s: 17.381038 [17.283753--17.555089].
  - v3/v2: 10.562808; change: +956.28%.
- **P43@5**
  - timed-v2 s: 12.568361 [12.396127--12.638378].
  - timed-v3 s: 756.408587 [454.547679--779.761296].
  - v3/v2: 60.183550; change: +5918.36%.
- **Active 1,000 replay**
  - timed-v2 s: .037177 [.037103--.068938].
  - timed-v3 s: .053581 [.053528--.053775].
  - v3/v2: 1.441241; change: +44.12%.

Both representative ratios fail the frozen [0.95,1.05] causal-comparability
gate by orders of magnitude, and active change exceeds the 25% micro-cost
gate.  Calibration therefore forbids causal target time-owner, micro-cost,
projected-speedup or optimization claims from this timed-v3 diagnostic.

The frozen target block then began P34@7 with its 30-second cooperative
deadline and independent 60-second watchdog.  It emitted no ATTEMPT, SUMMARY,
stdout or stderr before the directly observed watchdog exit 124.  The child
status file was absent after termination, so the collector supplied its
explicit default 143.  Thus raw `STATUS|1|34|143` and the `target-process` 143
ledger field are collector-inferred, not an observed child exit.  The
post-target closure and immediate process endpoint audits were nevertheless
clean.  P41/P45 never started.  The ordinary validator rejects the exact
two-line raw ledger with the sole diagnostic
`verify-target: status/order/value`.  The frozen no-retry rule was honoured:
no benchmark process or valid row was rerun.

**Final Task 7h verdict:** catastrophic timed-v3 perturbation and target
censoring are measured.  No traversal subcomponent or Alternative-pull
threshold can be interpreted, and no production optimization or capability
fix is selected.  Source inspection exposes unbounded trace
retention/concatenation, clock frequency, allocation and other timed-v3
observer costs as candidate causes, but no ablation or profile separated
them.  Bounded O(1) hot-path aggregation with no unbounded operation trace is
a conservative next-instrumentation constraint, not a measured trace-cause
diagnosis.

Any replacement protocol must use an explicitly supervised process group,
send TERM, wait a frozen grace interval, escalate to KILL if required, prove
the group gone, reap it, and immediately audit the endpoint.  The current
post-watchdog process and artifact endpoints were clean, so this future
constraint does not alter the historical evidence or authorize rewriting the
sealed collector.  The package's `FINAL_REVIEW_ERRATA.md` is authoritative
for these post-collection corrections.

#### M2 Task 7j/7k failed-chain chronology and fresh retry (2026-07-21)

Task 7j's `benchmarks/m2-timed-v4-final/` is a reviewed
failed-comparability/protocol chain, not authoritative fresh M2 evidence.  Its
P38 pair is a retained equal-work calibration observation of material timed-v4
observer overhead, and P43's timed-v4 child reached the external watchdog
without an internal row.  The representative schedule did not complete.  The
frozen collector then aborted under `set -e`; there was no unconditional
finalizer, contemporaneous outer status or immediate raw seal, and the later
materialization commands were not retained.  The package's
`FINAL_REVIEW_ERRATA.md` is the controlling chronology.  Active calibration
and every P34/P41/P45 target were forbidden and never ran.

Task 7k's separately sealed
`benchmarks/m2-v10-small-calibration-final/` stopped even earlier.  The first
P38@4 mode-A child invoked the generated launcher from repository root, while
its relative module load required the package working directory.  UI loading
failed with status 1 before the SML body, search and first benchmark clock;
the no-retry rule stopped children 2--20.  The supervisor monotonic timer for
the recorded `0.448013836` seconds begins before launch-vector construction
and before wrapper bootstrap, spawn and GO.  Elapsed is computed after
supervisor cleanup, pidfd closure and classification, but before status
serialization and durable publication.  It therefore includes supervisor
setup, the failed supervised execution and cleanup/classification, while
excluding collector raw sealing, audits and publication.  It is not a
benchmark time, P38 evidence, external calibration elapsed, complete
collector transaction elapsed or end-to-end calibration elapsed.

Independent review adds four limitations without changing the sealed Task 7k
package.  First, `ARTIFACT-REFERENCE.tsv` was created after `SEALED.txt` and
is absent from `PRECOLLECTION.sha256`.  It is postcollection checksum-bound
and byte-equal to the retained child-final artifact audit, but was not
cryptographically bound from creation through benchmark GO; no retrofit
immutability claim is valid.  Second,
`preflight-logs/pre-collection-endpoint.txt` contains two regex self-matches
and is noisy/non-authoritative.  The clean authoritative exact `/proc`
endpoints are `collection/pre-endpoint.txt`,
`collection/failure-endpoint.txt`,
`collection/child-1/audits/final-endpoint.txt` with its final status, and
`final-process-audit.txt`.  Third, the supervisor-interval terminology above
replaces every broader elapsed interpretation.  Fourth, live
`.hol/locks/task7kcalibration.{exe,uo}.lock` and
`.hol/make-deps/task7kcalibration.sml.d` remain inventoried metadata.  They
must be distinguished from absent top-level executable, UI/UO, cache,
process and temporary residue, and from the intentional frozen artifacts
under `frozen-inputs/`.

Neither Task 7j nor Task 7k supports timing attribution, target profiling,
projected speedup, optimization selection, capability attribution or an M2
conclusion.  Timings produced while testing or repairing protocol machinery
are protocol controls only and are not benchmark evidence.

At that point, the prescribed next attempt was a wholly fresh and separately
sealed chain.  Before its final seal it had to use either an absolute harness
UI load or a frozen, explicitly controlled package working directory, then
pass a load-only, no-search, no-timing smoke through the exact collector,
supervisor, command vector and working directory intended for collection.
After that smoke it had to remove live Holmake lock/make-dependency metadata,
or explicitly define the exact retained metadata and its role before
sealing.  Before any benchmark GO it had to create the artifact reference
and bind its digest, exact auditor identity, frozen schedule and frozen
input manifest in one final
precollection/GO seal.  Exact `/proc` identity/endpoint audits with retained
statuses were required before each child, after every child or failure, and
at finalization.  Only a complete calibration passing its frozen
comparability gates could authorize target collection or M2 interpretation.
The Task 7l through 7n subsections record what followed.

The external review resolution, exact reviewed-package references and
byte-identical before/after sealed-package manifests are retained under
`benchmarks/m2-v10-small-calibration-final-review/`; that directory is a
postcollection erratum and is not part of the Task 7k precollection seal.

#### M2 Task 7l reviewed failed retry and next protocol (2026-07-21)

Task 7l's separately sealed
`benchmarks/m2-v10-small-calibration-retry-final/` also stopped before its
first authoritative calibration child.  Its final 19-entry `GO-SEAL.txt` was
reportedly verified successfully from package root before the package was
made read-only, but neither operation has retained stdout/stderr/status or a
status-bearing log.  The hashes remain reconstructable from 18 live bound
paths plus the byte-identical frozen
`frozen-inputs/generated/task7lcalibration.exe`; after intentional top-level
cleanup, the current package-root seal check fails on that absent executable.
No retrofit verification or read-only claim is valid.

The authoritative driver was invoked from repository root.  Its unscoped
package-relative seal check therefore reported all 19 entries missing and
stopped under `set -e`.  The following `test ! -w "$dir"` checked only the
package directory, not its descendants, and was never reached.  The retained
seal-check log plus shell code imply exit 1, but no wrapper retained driver
stdout, stderr, numeric status, or an unconditional transaction-final exact
endpoint.  Later clean status-bearing endpoint audits do not replace that
missing transaction record.

The authoritative calibration collection never invoked its collector or
supervisor.  Supervisor classification was **not evaluated**, no supervisor
benchmark-GO commit occurred, and attribution is **indeterminate** for lack
of calibration evidence.  The successful earlier load-only smoke did run the
collector and supervisor, so the no-collector/no-supervisor statement is
scoped only to authoritative calibration collection.  `GO-SEAL.txt` is an
input-integrity seal, not a supervisor benchmark-GO commit.

Task 7l preserves identities and repair histories for all three pre-seal
attempts, but not complete transaction evidence for all three.  Attempt 1
has its bodies, hashes, command, narrative and repair diff but no direct
stdout, stderr or status artifact.  Also, attempt 2's sealed repair narrative
mistypes the package source as `../../task7lcalibration.sml`; from its
directory the correct relative path is `../task7lcalibration.sml`.  Both are
external chronology corrections; the sealed bytes remain unchanged.  At
that point, every next pre-seal attempt was required to retain exact
command/cwd, stdout, stderr, numeric status, involved before/after bodies
and hashes, and the exact diff before retry.

Top-level live executable, UI/UO, lock, make-dependency and `.hol` log paths
are clean.  Intentional evidence artifacts remain under
`frozen-inputs/generated/`, `pre-seal-attempt-0/full-bodies/`, and the
collector-validator `package-copy/` roots below attempt-0 preflight,
`preflight-evidence/`, and `preflight-evidence-final/`, including recursive
package-copy descendants.  Those locations must not be described as absent
top-level live residue.

At that point, the prescribed next attempt was a wholly fresh and separately
sealed chain.  Its seal verifier had to be cwd-independent and
package-scoped: resolve every entry below an explicit package root and
reject absolute or escaping paths.  After load-only smoke and declared
cleanup/freezing, it had to generate a provisional artifact reference,
input manifest and seal and make the package recursively read-only.  The
exact `collect.sh` then had to run in no-child dry-run mode from repository
root and from an unrelated cwd.  Each dry-run had to reach and retain a
successful scoped seal verification, recursive writable-path audit and
exact pre-child endpoint, then stop before invoking collector or
supervisor.  An outer wrapper was required to retain driver stdout, stderr
and status and run an unconditional final exact endpoint on success,
failure, or signal.

After those dry-runs, the protocol required regeneration of the final
artifact reference, input manifest and seal, restoration and re-audit of the
recursive read-only state, and status-bearing scoped seal, writable-path and
exact endpoint evidence immediately before supervisor benchmark GO.  Only a
complete calibration passing its frozen comparability gates could authorize
target collection or M2 interpretation.  The Task 7m/7n subsections record
what followed.

The external review resolution, exact reviewed-package references,
symlink-aware closure and byte-identical before/after Task 7l manifests are
retained under
`benchmarks/m2-v10-small-calibration-retry-final-review/`.  That directory is
postcollection review evidence and is not part of the Task 7l GO seal.

#### M2 Task 7m reviewed limited calibration and next diagnostic (2026-07-21)

Task 7m's separately reviewed v10 P38@4 calibration is authoritative only
for its predeclared `mixed/indeterminate` result.  Its balanced schedule
completed 20 fresh children, five per mode, with no retry.  The exact external
medians [full observed ranges] were A `9.189388257`
[`9.172840055--9.256204405`], B `9.237345589`
[`9.221508007--9.249071647`], C `11.027194246`
[`10.933404789--11.032468973`], and D `16.328066360`
[`16.296102393--16.332424610`] seconds.  Exact derived ratios were B/A
`1.005219`, C/A `1.199992`, and D/C `1.480709`; exact increments were D-A
`7.138678103`, C-A `1.837805989`, and D-C `5.300872114` seconds, and clock
share was `0.742557`.

All rows had outcome `none`, 22 attempts, search counters
`2507169,624,140,210,233,4,322,5446`, and identical ordered 37-field
signatures.  Each C/D row had exactly 61,486,260 clock reads, 22 terminal-
summary reads, and zero trace allocations and sequence-statistics reads.
B/A passed the frozen inclusive `[0.95,1.05]` sanity gate.  The frozen
clock-dominant predicate required clock share at least `.80` and D/C at least
`1.50`; the frozen aggregation-material predicate required C/A at least
`1.25`.  Neither predicate held, hence the predeclared result is
**mixed/indeterminate**.

This was a process-level ablation with no target.  It authorizes no target run
or target profile, projected speedup, optimization selection, capability
attribution, or M2 closure.  The external review-resolution erratum corrects
only cleanup chronology: the final live-artifacts compound command had no
`set -e`, ended with `! pgrep`, and regex-self-matched enclosing audit
payloads containing an earlier literal `/task7mcalibration.exe`.  Its status
cannot establish either preceding path-test status, and the original `.hol`
predicate attribution was wrong.  Cleanup authority instead rests on the
status-zero cleanup transaction, separate status-zero exact-argv endpoint,
and final/current absence of the live executable and `.hol` tree.  Future
cleanup checks must retain independent status-bearing path tests and a
separate status-bearing exact-argv endpoint audit, with no regex `pgrep`.

The authoritative package is retained under
`benchmarks/m2-v10-small-calibration-second-retry-final/`.  Its adjacent
`benchmarks/m2-v10-small-calibration-second-retry-final-review/` resolution
is postcollection review evidence, not part of the GO seal; its symlink-aware
before/after manifests establish that the package remained byte-identical.

At the time of Task 7m, the next M2 diagnostic was target-free,
low-frequency external statistical sampling of mode A interleaved with
unsampled equal-work controls.  It was to retain counter/signature equality
gates and a predeclared perturbation gate, add no per-event internal clocks,
and use an exact-count standalone clock microcalibration only if sampling was
unavailable.  Task 7n below records what happened.  This historical record
selected no optimization.  Later sections record the subsequent M3, M4 and
M5 outcomes; they do not retroactively close M2.

#### M2 Task 7n reviewed low-perturbation fallback (2026-07-21)

Task 7n's separately sealed
`benchmarks/m2-low-perturbation-diagnostic-final/` has an independent
external review resolution.  Its preferred no-benchmark capability probe used
`/usr/bin/perf`, `perf version 6.17.13`, and the fixed 9 Hz DWARF command
`perf record -F 9 -g --call-graph dwarf` around harmless `/bin/sleep 2`.
Host `perf_event_paranoid=4` denied monitoring: `perf record` exited 255 and
left a zero-byte `perf.data`.  `capability-probe.sh` consequently skipped
`perf report` and wrote synthetic sentinel `125` to `report.status`; 125 is
not a status returned by a report command.  There was no usable or readable
sample data, wrapper assessment, sample count, symbol/DSO attribution,
category result, or sampled P38 run.  The external erratum leaves the
authoritative `FINAL_REPORT.md` byte-identical while correcting its phrase
"no sample file" to "no usable or readable sample data".

The Task 7n decision explicitly supersedes and clarifies Task 7m's narrower
fallback-trigger wording.  The frozen exact-count fallback may be selected
when preferred sampling is unavailable because of host permission or
capability, or when usable symbols are inadequate, provided selection is
frozen before any diagnostic clock.  Task 7n used the permission-unavailable
branch.  This clarification changes no observation and grants no production,
optimization, target, capability-cause, or M2-closure authority.

The predeclared fallback then completed one balanced ten-child schedule
`Z,N,N,Z,Z,N,N,Z,Z,N`, with five fresh children per mode and no retry.  Every
row made and observed exactly 61,486,260 closure calls.  Z median external
elapsed was `0.511189289` seconds, with full range
[`0.509745717`, `0.511828761`]; N median was `6.090917808`, with full range
[`6.082526315`, `6.103101928`].  The median net N-Z was `5.579728519`
seconds.  Against authoritative Task 7m D-C `5.300872114`, the unrounded
ratio is `1.052605759769...`, reported as `1.052606`, inside the frozen
inclusive `[0.80,1.20]` consistency band.

The v10 supervisor's `elapsed_seconds` begins after disposable containment
preflight and controller setup, but before the live spawn.  It ends after
live cleanup and classification, but before durable status publication and
collector artifact/process audits.  It therefore includes live
fresh-process, bootstrap, loop, and cleanup costs.  Task 7m uses the same
timer domain.  Under that domain, Task 7n authoritatively supports only
limited standalone consistency with Task 7m.  Five observations per mode,
the wide band, and the different allocation, cache, locality, and control-
flow context forbid a production time-category, target-profile,
projected-speedup, optimization, capability-cause, or M2-closure claim.

Further M2 sampling is permitted only on a host with `CAP_PERFMON` or lower
`perf_event_paranoid`, as a wholly fresh, separately sealed ten-child P38
sampled/control run with the frozen equal-work parity, perturbation,
sample-count, symbol/DSO, and category-coverage gates.  If such a host is
unavailable, record the environmental block.  M3 capability audits may
proceed independently, without treating Task 7n or the then-open M2 record
as cause evidence.  At the time of this review, M3, Halting II and M5 were
future work; their later outcomes are recorded below.  At that point,
further M2 sampling remained conditional on the environment.  The
2026-07-23 owner-closure subsection supersedes that status.  No optimization
was selected.

The adjacent
`benchmarks/m2-low-perturbation-diagnostic-final-review/` directory is
external, non-sealed postcollection review evidence.  Its typed symlink-aware
before/after manifests establish that Task 7n remained byte-identical, and
its exact references retain the authoritative Task 7m package and external
review closure.

#### M2 owner closure (2026-07-23)

The owner decided that M2 closes once the complete benchmark suite and
Halting II pass because this host's `perf_event_paranoid` setting cannot be
lowered.  Accepted committed-state attempt-04 proves 48/48 Pelletier,
9/9 Table 1, 4/4 set problems and one kernel-valid Halting II success.
The decision's conditions are therefore met and M2 is closed.

This closure does not rewrite Task 7n.  The 9 Hz `perf` attempt remains
permission-blocked, and no usable kernel-profiler samples, symbol
attribution, time category or lowered setting exists.  That is an explicit
environmental limitation rather than an open milestone blocker.  None of
the earlier diagnostic records is retroactively promoted into an
optimization claim.

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

#### M3 independently reviewed outcome (2026-07-21)

The biconditional and gamma hypotheses were audited before changing
production behavior.  The biconditional audit verified the exact positive
and negative cases produced from `IFF_CELIM_THM`, then kernel-validated a
depth-4 proof whose script uses both a Skolem-dependent gamma step and iff
elimination.  The gamma review independently obtained kernel-valid public
proofs for P38@4 and P43@5 on their first reconstruction attempts, with
maximum resource costs 4 and 5 respectively, and the dedicated
Skolem-retention probe closed at depth 7.  These audits found no
biconditional conversion or gamma requeue/depth-accounting defect, so no
production change was made for either hypothesis.

The failure was instead in general rule replay.  Search already produced raw
proof scripts, but reconstruction could lose the exact instantiated rule
shape by stripping an implication-valued conclusion as though it were
another premise and by rebuilding replay from the pre-instantiation rule.
Commit `9c8195d67` preserves the instantiated normalized theorem, splits only
the recorded premise prefix, and carries that exact instance through the
ordinary, measured and timed replay paths.  Failing-first regressions cover
implication-valued targets, elimination majors containing engine
metavariables, generated elimination rules and parent eigenparameters.
After this general fix, P38, P41, P42 and P43 replay kernel-validly:
Pelletier rises from 42/48 to **46/48**, and Table-1 from 6/9 to **8/9**.

Independent review then found a second general exactness gap: beta/eta
normalization in assumption, contradiction and hypothesis-substitution
replay could return a theorem for a normalized target rather than the
caller's exact target.  Commit `7ea3b07fa` restores the original target via
kernel equalities and adds failing-first exact-conclusion/hypothesis
regressions in both classical and blast selftests.  It changes no benchmark
count.  P34 and P45 remain the only Pelletier failures, and P34@7 the only
Table-1 failure.  These reviewed results do not retroactively strengthen the
conditional/environment-blocked M2 performance diagnosis recorded above.

### M4 — Halting II

Attempt only after M1-M3.  It is the largest goal in the suite and
depends on γ-duplication and iff handling being right.  If it remains
out of reach, it stays an asserted expected failure with the M2
measurements recorded here as justification — **not** an answer lookup,
and not a quietly dropped test.

#### M4 independently reviewed outcome (2026-07-21)

At historical HEAD `7ea3b07fa`
(`7ea3b07fa511215294675b842a1361311dddb642`),
the focused acceptance harness made exactly the public
`tableauLib.BLAST_DEPTH_TAC 7 []` Halting II attempt under the unchanged
internal `Timeout.apply` budget of 120 seconds.  It timed out after
`120.001251000` seconds.  No proof was returned and kernel validation was
therefore not reached.  At that point Halting II remained unsolved within
the mandated budget, so its expected-failure entry remained unchanged for
M5.  The 2026-07-23 current section below supersedes that status with a
kernel-valid success.

The harness intentionally has stronger success acceptance than the
selftest's `blast_exceeds`: the selftest asks only whether
`Tactical.VALID` returns, whereas the harness additionally requires an
empty residual-goal list and invokes the returned validation with `[]`.
This distinction does not affect the timeout observation, but the harness
must not be described as having a success path identical to the selftest.

The authoritative original timing artifacts are retained under
`/tmp/isabelle-tactics-task7f-20260720-root/task12_m4_halting_fresh/`.
Independent review added clearly marked post-run supplemental evidence:
a fresh focused-harness `Holmake` build log and status (without rerunning
the proof), environment details, raw HEAD/status/index/`.agent-files`
tracking outputs, unchanged before/after hashes for the original timing
logs, and a verified deterministic SHA-256 manifest.  These supplements
postdate the timed run and are not claimed as contemporaneous timing
evidence.  No tracked source change, recognition mechanism, budget change,
or expected-failure/count change was made for M4.

### M5 — Restore honest counts

Shrink both expected-failure lists to whatever M1-M4 achieve, raise the
asserted counts to match, and re-run: `Holmake` + `./selftest.exe` in
all three directories, `bin/build -t --seq=tools/sequences/upto-auto`,
then `bin/build -F -t` as the phase-boundary gate.  Update
`PLAN_phase_1_2.md` §8.3.7 and the TASK_23/TASK_24 status record with the
achieved counts.  Reclose either task only when its unchanged acceptance
criteria are met, or after an explicit owner-approved exception.

#### M5 consolidation status (2026-07-21)

At blast-consolidation HEAD `7ea3b07fa`, source accounting was:

- Pelletier expected failures `[34, 45]`, hence **46/48**;
- Table-1 expected failures `[34]`, hence **8/9**;
- set problems **4/4**;
- Halting II retained as an asserted expected timeout at depth 7 under the
  unchanged 120-second budget.

The per-directory M5 gates were rerun sequentially with all six commands
exiting 0: `Holmake` then `./selftest.exe` in `src/auto/rules`,
`src/auto/classical` and `src/auto/blast`.  The selftests reported 77, 168
and 193 `OK` results respectively.  The default-level blast run observed P34
and P45 as Pelletier expected failures, P34@7 as the sole Table-1 expected
failure, and all four set problems as successes.  Halting II was not rerun by
that default-level suite; the independently reviewed M4 120-second timeout
above remains the governing level-2 evidence.

Review of production sources found no benchmark names or statements, former
recognition preprocessors, benchmark-only rewrite answers, or metis/accept
shortcuts.  The source-recognition audit and seed-theory structural guard
remain green.  No tracked source was changed during this consolidation.

#### M5 historical clean gates at `65250f8c3` (2026-07-22)

The first clean integrated attempt at `7ea3b07fa` passed
`bin/build -t --seq=tools/sequences/upto-auto`.  The following explicit
`bin/build -F -t`, however, failed reproducibly in
`src/probability/real_borelTheory` while proving
`in_borel_measurable_inv`.  This chronology is part of the gate record; the
integrated pass did not by itself complete M5.

The failure exposed a general simplifier semantic defect introduced earlier:
supplied global rewrite theorems were installed both statically and once per
traversal.  A naive dynamic-only candidate removed within-traversal
duplication but incorrectly refreshed `Once` across assumption and conclusion
traversals.  The principled repair is commit
`65250f8c38f59a46f4350cc33e837b3de2508bf3` (`Preserve global bounded
rewrite lifetimes`).  It decodes supplied bounded rewrites once into controls
shared by the invocation, compiles them through marker-adjusted local
simpsets, separates reducer from solver contexts, and preserves marker
semantics plus the underlying solver/dproc theorem context.  Failing-first
regressions cover the defect.  No probability proof was edited.

A fresh detached worktree at exact `65250f8c3`, starting with a fresh
`poly < tools/smart-configure.sml`, produced the final clean record:

- **Configure:** status 0; elapsed time 18.17 s; terminal/result evidence
  `Finished configuration!`.
- **`bin/build -t --seq=tools/sequences/upto-auto`:** status 0; elapsed time
  9m41.26s; terminal/result evidence `Hol built successfully.`
- **`bin/build -F -t`:** status 0; elapsed time 15m53.50s; terminal/result
  evidence `Hol built successfully.`

The full gate reported `real_borelTheory` `OK` in 14 seconds.  Its direct
theory log records saving and exporting `in_borel_measurable_inv`, and the
captured signature exports the theorem.

The audited package is
`/tmp/isabelle-tactics-task7f-20260720-root/task16_clean_full_gates_fresh/`.
It preserves the original gate logs and direct probability artifacts.  Its
final clean rereview manifest, `metadata/evidence-checksums.txt`, has 45
entries, passes checksum verification, and has SHA-256
`a6dde0623911ee486494b341ba9845c928f8fd1787c230b57134c95ae62e916b`.
The integrated `upto-auto` build includes the expected
`suspFastTheory ... F-CHEAT` result and zero `CHEATED` results.  The full
build includes the intentional pre-existing upstream
`src/num/theories/cv_compute/automation ... CHEATED` result, with three
`Saved CHEAT` entries from unchanged source, and zero `F-CHEAT` results.
Both builds passed terminally; these are classified disclosures, not gate
failures.
The historical build transcripts did not independently capture `TMPDIR`;
the empty task `TMPDIR` observed postflight is corroboration only.

The main tracked tree and index were clean at `65250f8c3`, with
`.agent-files` ignored and untracked.  The simplifier repair added no
recognition mechanism and changed no benchmark count or budget.  At that
revision M5's integrated and full gates were complete, but the whole plan
remained incomplete: M1 was met for only 3/6 workloads, P34 and P45 remained
outside TASK_23, and P34@7 plus Halting II remained outside TASK_24.  P34 is
an Isabelle Table-1 problem, while no report citation established P45 as out
of scope for Isabelle's blast; no owner exception had been approved.
TASK_23 and TASK_24 were therefore **REOPENED** at that revision.  The
conditional and environment-limited M2 conclusions remain exactly that; no
evidence-selected optimization is claimed retroactively.

#### Historical final clean gates at `5bc674569` (2026-07-22)

The preceding `65250f8c3` gate is retained as historical evidence.  The
authoritative wholly fresh v2 gate package for commit
`5bc6745695a3ac2f48b90c09ecfb2d6f4d785307` is
`/tmp/isabelle-tactics-task7f-20260720-root/task23_final_clean_gates_fresh/`.
Its recorded elapsed times are:

| Gate | Elapsed (s) | Result |
|---|---:|---|
| Fresh configure | 17.79 | success |
| Prerequisite setup | 206.35 | success |
| Rules `Holmake` / selftest | 15.54 / 12.08 | success |
| Classical `Holmake` / selftest | .19 / 16.21 | success |
| Blast `Holmake` / default selftest | .20 / 20.69 | success |
| Blast level-2 selftest | 141.20 | success |
| `upto-auto` | 244.10 | terminal success |
| Explicit full gate | 989.25 | terminal success |

The final reviewed live seal has 395 entries and digest
`2d66cab8b9db6c8a5e2c345a89c0ca2755b4a4d35cebc45cab9dedb2d507d3bc`;
the inventory has 394 entries and digest
`786c8d9c2f763ee342eaaee8c5f79659be0433013cc00d4f43ccc4445b8b3812`.
No top-level v2 driver was retained, so whole-schedule enforcement is not
independently proven; named wrapper intervals do not overlap, but unrecorded
activity in gaps is not excluded.  Process snapshots are scoped observations
only.  Copied probability and CHEAT direct artifacts are post-run
corroboration; the full log itself proves
`real_borelTheory` `OK`.  The old first attempt is rejected because its setup
overlapped the run by `0.497043743` seconds.  No claim is made that this
package proves nonmutation of `/tmp/Holmakefile`.

At that revision, production recognition/shortcut audits, the seed guard,
h4pedant, the integrated gate and the full gate were green.  The known
intentional CHEAT classifications were disclosed.  Together with the final
M1 evidence, the reviewed state was 48/48 Pelletier, 9/9 Table 1 and 4/4
sets.  TASK_23 was completed/reclosed.  Halting II was still an expected
failure at depth 7/120 seconds, so TASK_24 remained reopened.  M2 and
TASK_24 were the two blockers at that point.  The current section below
supersedes that status without rewriting its evidence.

#### Final committed-state gates at `f4fc8be66` (2026-07-23)

The preceding `5bc674569` section is historical.  Reviewed tracked source
commit `f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`, whose parent is
`d90554b5fd14f72527535d1b0085fe6d746ab0a5`, implements one centralized
capture-safe expansion for persistent metavariable bindings.  It expands
reachable dependency residues by whole-term substitution, preserving
binders, then uses that result for normalization, collapse, goal
normalization and blast hypothesis substitution.  Exact stored-rule replay
uses the final store without recognition or a fallback answer path.

Regressions cover capture collisions, indirect bindings, types, shared
dependencies, persistent binding semantics, exact intro/elim replay and all
16 public stored-rule APIs: ordinary, measured, timed v1 through v4,
sink/summary forms, and their selected-major variants.

Candidate 05 remains solely historical pre-commit functional evidence:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task32n_fcheat_disclosed_evidence_fresh/accepted-attempt-05/
```

Its historical manifest digest is
`95be727c037229af3514a85d2e2f11ea56b76cdf19b84c1aa5e5372c58322d07`.
The frozen patch digest is
`fb6b314cf8a215a5f38c4eec8c885589ce2ca2fa27db6a1cbe2a47e36d23fc2d`.
It was collected before commit from parent `d90554b5f`; a reverse apply
check at `f4fc8be66` confirmed that the commit contains exactly the frozen
six-file patch.  It is not the current gate evidence.

The accepted committed-state package is:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
```

It tests commit `f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`, tree
`9f9dd4c4d5c4e3f303a7fa71605ae7b87ca9aa55`, with clean tracked state
and index.  Its 18-command plan has SHA-256
`941435ac994a5dd43534b852c4f9508dce7161c2a0ecc96589fca3a92c403a00`.
All commands exited 0, without overlap, in 1799.992895 seconds.

Fresh configure, exact `upto-auto`, `upto-parallel`, direct Rules,
Classical, Blast level 1 and Blast level 2, h4pedant, diff and hygiene
checks all pass.  Both Blast levels record exactly 48/48 unique Pelletier,
9/9 unique Table-1 and 4/4 unique set successes.  Level 2 records exactly
one kernel-valid Halting II `OK`; level 1 does not run it.  No expected
corpus failure remains.

The exact `upto-auto` log has one expected, pre-existing
`suspFastTheory ... F-CHEAT`, zero `CHEATED` and zero `Saved CHEAT`.
These figures belong only to that integrated gate.  The last build/test
command is explicit `bin/build -F -t`; it exits 0 after 1132.087214 s and
ends `Hol built successfully.`  Its distinct disclosure is zero
`F-CHEAT`, one intentional pre-existing upstream
`cv_compute/automation ... CHEATED`, and exactly three `Saved CHEAT`
theorem names from the separate hash-bound artifact record.

TASK_23 remains completed.  TASK_24 is completed/reclosed because Table 1,
sets, Halting II and robustness now pass.  Under the owner's 2026-07-23
decision, the same complete-suite and Halting result closes M2 despite the
unavailable profiler.

The semantic audit and post-run identities pass.  The exact tested-tree
inventory has 32,933 entries and SHA-256
`21e331d3567063931f96bf897845cf131b252d3f7a80d08c8ffcde6ea678ae5e`;
the exact package manifest has 47 entries and SHA-256
`805cb6086f5fb65e0869dfd73722c9296cb0ec467fc150e8c410fe9d4e7e9c52`.
Its lexical checker passes and all 28 retained adversaries are rejected.

Independent task34d review accepted source and evidence.  Its transient
package `__pycache__` was removed and descendant bytes, types and hashes
restored; only package-root mtime changed, outside the manifest schema.
This supports no immutable-history, performance, profiler, resource,
security, process or atomicity claim.

The §6 audit finds every Green criterion met.  M1 remains closed on the
verified `5bc674569` milestone package.  Performance at `f4fc8be66` has
not been remeasured and is not claimed; that is a transparent non-blocking
follow-up.  The current plan is complete.

## 3. Structural guard against recurrence

Implemented at `c7f72c445`.  The current `src/auto/rules/selftest.sml`
computes `untagged_seed_theorems` from the theory exports and persistent
claset rule names, permits only `NOT_IMP_CELIM_THM`,
`NOT_FORALL_CELIM_THM` and `NOT_ELIM_THM`, and reports
`every seed theorem is a claset rule or permitted schema`.  An untagged,
non-rule theorem in the seed theory is exactly the shape the removed
instance seeds had, so the selftest fails on sight of one.

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
2. **Whether Phase 3 (`clasimp`/AUTO) may start before M5.**  Moot.  Phase 3
   work and historical M5 gates already occurred.  The newer
   `f4fc8be66` committed-state full gate now passes in accepted attempt-04;
   this chronology waived no acceptance criterion.
3. **M2 closure, 2026-07-23.**  Close M2 once the complete benchmark suite
   and Halting II pass because `perf_event_paranoid` cannot be lowered.
   Those conditions now pass.  The profiler limitation stays disclosed,
   but is not an open blocker.
4. **M1 closure, 2026-07-23.**  The original explicit acceptance criterion
   was milestone-local: preserve behaviour and measure improvement on all
   six listed workloads.  It did not require remeasurement after every
   later patch.  The verified `5bc674569` package satisfies that criterion,
   so M1 is closed.  Unmeasured `f4fc8be66` performance remains a
   transparent non-blocking follow-up, and no current-performance claim is
   made.

## 6. Final requirement audit (2026-07-23)

### 6.1 Evidence key and limits

`A04` below means this accepted committed-state evidence root:

```text
/tmp/isabelle-tactics-task7f-20260720-root/
task34c_hardened_final_gates_fresh/attempt-04/evidence-package/
```

The subject is commit
`f4fc8be6674ea37043a76f51ab7d8aa2f7f5ceb1`, tree
`9f9dd4c4d5c4e3f303a7fa71605ae7b87ca9aa55`.  `A04/PLAN.json`,
`A04/records/000.json` through `017.json`, and
`A04/logs/000-env.log` through `017-inventory.log` bind every command,
environment, status, elapsed time, log hash and before/after identity.
The frozen plan digest is
`941435ac994a5dd43534b852c4f9508dce7161c2a0ecc96589fca3a92c403a00`.
`A04/SEMANTIC-AUDIT.log` reports PASS for all 18 records and their
1799.992895-second aggregate.

`A04/WORKTREE-INVENTORY.jsonl` has exactly 32,933 entries and digest
`21e331d3567063931f96bf897845cf131b252d3f7a80d08c8ffcde6ea678ae5e`.
`A04/MANIFEST.jsonl` has exactly 47 entries and digest
`805cb6086f5fb65e0869dfd73722c9296cb0ec467fc150e8c410fe9d4e7e9c52`.
The exact inventory check, postseal package lexical checker and 28 retained
adversaries pass.

Independent task34d review accepted the source and package.  Its transient
package `__pycache__` was removed and descendant bytes, types and hashes
restored; the package-root mtime alone changed and is outside the manifest
schema.  This audit therefore claims verified current content and schema,
not immutable history.  It also makes no `f4fc8be66` performance,
profiler, resource, security, process or atomicity claim.

### 6.2 Milestone and governing-rule audit

- **M1 — PASS/CLOSED.**  The original criterion was behaviour preservation
  plus measured improvement on P34/P38/P41/P42/P43/P45.  The verified
  `5bc674569` package under
  `task22_m1_final_measurement_fresh/` has a 1,818-entry manifest, six
  `>=30s` baselines and all 18 kernel-valid production samples below
  `3.544s`.  This is milestone-local evidence.  No performance at
  `f4fc8be66` is claimed.
- **M2 — PASS/CLOSED.**  The 2026-07-23 owner rule requires the complete
  benchmark suite and Halting II because `perf_event_paranoid` cannot be
  lowered.  `A04/logs/009-blast-default.log` and
  `010-blast-level2.log` prove 48/48 Pelletier, 9/9 Table 1 and 4/4 sets;
  level 2 proves exactly one Halting II `OK`.  The unavailable profiler is
  disclosed, with no sample or causal claim.
- **M3 — PASS/COMPLETE.**  The independently reviewed capability audit
  found no biconditional or gamma defect.  General exact-rule and
  capture-safe replay repairs are present at the subject commit.
  `A04/logs/007-classical-test.log`, `009-blast-default.log`, and
  `010-blast-level2.log` revalidate exact replay, eigenvariable discipline,
  backtracking and all public stored-rule paths.
- **M4 — PASS/COMPLETE.**  The public depth-7, 120-second Halting II
  attempt is run at level 2 and kernel-valid in
  `A04/logs/010-blast-level2.log`; it is not an expected failure.
- **M5 — PASS/COMPLETE.**  Both expected lists are empty
  (`A04/logs/013-hygiene.log`).  Rules, Classical, Blast default and
  Blast level 2 pass in logs 005, 007, 009 and 010.  Exact `upto-auto`
  passes in log 002, `upto-parallel` in log 003, and the last build/test
  command is the successful full gate in log 014.
- **Recognition prohibition — PASS.**  The accepted source review found no
  recognition or fallback shortcut.  Log 013 rejects the former
  preprocessor names and binds both expected lists to `[]`.  A final
  `git grep` at the subject commit finds none of
  `blast_preprocess`, `halting_preprocess`, `pelletier_preprocess`,
  `goal_recognition`, or `recognise_pelletier` under `src/auto`.
- **Structural guard — PASS.**  `A04/logs/005-rules-test.log` passes
  `every seed theorem is a claset rule or permitted schema`; the current
  source computes `untagged_seed_theorems` and permits only the recorded
  general schemas.
- **Theorem validation — PASS.**  Classical log 007 checks every complete
  driver success through `Tactical.VALID` and exact zero-search replay.
  Blast logs 009/010 check public tactics through `Tactical.VALID`, kernel
  replay, exact stored-rule instances, reconstruction failure backtracking,
  weak-elim skipping and clean failure.
- **Style and structure — PASS.**  H4pedant over Rules, Classical and
  Blast is status 0 in log 011.  `git diff --check` is status 0 in log 012.
  The six-file subject diff contains only the general repair and its
  regressions; task34d independently accepted it.
- **Cheat separation — PASS.**  `upto-auto` has one expected
  `suspFastTheory ... F-CHEAT`, zero `CHEATED` and zero `Saved CHEAT`
  (log 002).  The full gate has zero `F-CHEAT` and one intentional
  pre-existing upstream `cv_compute/automation ... CHEATED` (log 014).
  Log 015 separately hash-binds exactly
  `cv_exp_size_alt_ind`, `cv_exp_size_alt_def`, and
  `cv_exp_size_alt_thm` as the three `Saved CHEAT` names.
- **Identity and provenance — PASS.**  Log 016 binds tested and main
  repositories to the subject commit/tree, clean tracked status and exact
  index hash.  Log 017 and both exact manifests pass.  `.agent-files` is
  intentionally ignored and uncommitted; no criterion requires otherwise.

### 6.3 Task acceptance audit

Every task-specific criterion remains satisfied.  The original acceptance
records are in `tasks_phase_1_2/PROGRESS.md`; attempt-04 revalidates the
current subject wherever the final replay repair could affect behaviour.

- **TASK_01–TASK_07 — CLOSED.**  Skeleton, store, unifier, goal/cascade,
  Phase-1 surface and all five selftest groups retain their recorded
  acceptance.  Current Classical build/selftest, `upto-auto` and h4pedant
  are logs 006, 007, 002 and 011.
- **TASK_08 — CLOSED.**  Its documentation/export/style acceptance remains
  recorded in `PROGRESS.md`; the full build's help-documentation phase
  completes in log 014.  No committed deliverable references
  `.agent-files`; the sole tracked grep match is the intentional
  `.gitignore` rule that keeps this governance tree out of source control.
- **TASK_09 — CLOSED.**  Its historical allowed pre-existing failure and
  PLAN gate record remain accurate.  The current full distribution now
  passes in log 014 and h4pedant passes in log 011.
- **TASK_10–TASK_16 — CLOSED.**  Unify mode, replay, wrappers, drivers,
  public surfaces, non-theorem battery and FAST strength floor retain their
  recorded criteria.  Current evidence is logs 006, 007, 002 and 011.
- **TASK_17 — CLOSED.**  The additive `REV_DUP_ELIM_RULE` goldens and Rules
  suite pass in log 005; current Rules build, integrated gate and style are
  logs 004, 002 and 011.
- **TASK_18–TASK_22 — CLOSED.**  Blast term/rule/search/reconstruction and
  public-surface criteria, including warnings, port mappings, kernel
  validation and backtracking, pass in logs 008–010, 002 and 011.
- **TASK_23 — CLOSED.**  Both Blast logs have the exact unique 48/48
  corpus, empty expected list and count assertion.  Logs 008–011 and 002
  satisfy its build, integrated and style criteria; no exception is used.
- **TASK_24 — CLOSED.**  Both Blast logs have exact unique 9/9 Table 1
  depths and 4/4 sets.  Log 010 also has the depth-accounting,
  robustness and sole kernel-valid Halting II success.  Logs 008–011 and
  002 satisfy all four unchanged criteria.
- **TASK_25 — CLOSED.**  Its export/doc/cross-reference criteria remain
  recorded in `PROGRESS.md`; full help documentation completes in log 014,
  h4pedant passes in log 011, and the same deliverable-reference audit as
  TASK_08 is clean.
- **TASK_26 — CLOSED.**  D21–D27, delivered status, freeze amendments and
  current evidence are accurately recorded in the three governing plans.
  This final governance update changes only ignored `.agent-files`
  Markdown.
- **TASK_27 — CLOSED.**  Criterion 1 is log 014's terminally successful
  `bin/build -F -t`; criterion 2 is log 011; criterion 3 is
  `PLAN.md` §11's authoritative gate record.

### 6.4 Conclusion

All Phase-1/2 task criteria, Green milestones, structural guards, theorem
validation, style checks, evidence-provenance checks and owner decisions are
met.  TASK_01–TASK_27, M1–M5, Phases 1/2, and this Green closure plan are
complete.  There is no blocker and no pending next task for this phase.
