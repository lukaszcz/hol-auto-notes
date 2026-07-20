# M2 fixed-depth diagnosis

This directory is the auditable M2 evidence for the six Pelletier problems
still open at outer revision `16314dae0`: 34, 38, 41, 42, 43 and 45.  It is a
diagnosis only; no search code, capability code, expected-failure list or
budget was changed.

## Authoritative comparison source

The local copy of Lawrence C. Paulson's 1999 Blast paper is
`../../papers/paulson1999-blast.txt`.  Section 9 and Table 1 (text lines
580--639) define `depth` as the successful search depth and `branches` as the
search branches tried.  They report P34 at depth 7 with 100 branches, P38 at
depth 4 with 30 branches, and P43 at depth 5 with 24 branches.  The paper has
no Table-1 rows for P41, P42 or P45.  Its SHA-256 is recorded in
`checksums.sha256`.

The public API documentation at this revision permits only the configured
fixed depth and `branches_created` from a *completed fixed-depth run* to be
compared with those two Isabelle columns.  HOL4 `inferences_performed` is an
internal committed-transition counter, not Isabelle's tactic count.  Cache
counters and resource cost also have no published Isabelle counterpart.
Iterative totals are not used.

## Harness and run protocol

`m2benchmark.sml` contains exact copies of the six selftest propositions and
assembles the same invocation claset as `BLAST_DEPTH_TAC depth []`.  It calls
`blastSearch.searchGoalMeasured` once at an explicit depth.  Its stop predicate
uses the unchanged 30-second budget and is polled by the search engine.  A
successful tableau is accepted only after normal kernel reconstruction and
validation.  Each row reports API completion and proof presence separately,
then configured depth, maximum resource cost, inferences, branches created and
closed, choices pruned, cache hits and conversions, and stop-predicate polls.

For completed probes, `debug=true` retains the exact sequence of search states
only in memory.  The harness emits three compact exact summaries instead of a
large trace: state count, maximum simultaneously-live branches, and maximum
formula slots in one state.  `trace_states = stop_polls` in every completed
debug run.  Interrupted/debug-false runs correctly report zero trace-summary
fields.

The main schedule pairs the last observed completed bound with the next bound
that exposes the cost cliff.  The published depths themselves are used for
P34, P38 and P43.  With no published row for P41/P42/P45, the bounded probes
are P41 5/6, P42 3/4 and P45 10/11.  Probe ordering is fixed in `schedule.tsv`.
Every row runs in a fresh HOL process, sequentially.  `schedule-repeat.tsv`
repeats all eight completed diagnostic rows; all outcomes, counters, polls and
trace summaries, as well as debug and budget protocol fields, are
byte-for-byte identical between runs.  Wall times are retained for context but
are neither determinism criteria nor compared with the paper's different
1990s host.

The measured API polls at `prv` entry.  P34@7, P41@6 and P45@11 did not return
to a poll before the separate 60-second whole-process watchdog fired, despite
their internal deadlines having expired.  Their rows therefore say
`completion=unobserved`, `search_result=watchdog_killed`, and use `NA` for all
unavailable counters.  They are censored observations, not completed runs;
no comparison to Isabelle branch counts is made.  P42@4 did reach a poll and
returned `Interrupted` after 31.662 seconds.  Its counters are exact partial
counters for that run, but are time-censored and not claimed deterministic.
The overshoot and watchdog rows demonstrate only a polling blind spot in the
cooperative measured API: an inner interval between `prv` entries can outlast
the deadline.  They do not identify which inner operation dominates or
diagnose production timeout behavior.

Exact preparation and measurement commands, from the repository root:

```sh
chmod +x .agent-files/benchmarks/m2/run-m2.sh
cp .agent-files/benchmarks/m2/m2benchmark.sml \
  src/auto/blast/m2benchmark.sml
(cd src/auto/blast && ../../../bin/Holmake m2benchmark.uo)
.agent-files/benchmarks/m2/run-m2.sh
SCHEDULE=.agent-files/benchmarks/m2/schedule-repeat.tsv \
OUTPUT=.agent-files/benchmarks/m2/repeat.tsv M2_RUN=2 \
  .agent-files/benchmarks/m2/run-m2.sh
awk -f .agent-files/benchmarks/m2/verify-determinism.awk \
  .agent-files/benchmarks/m2/raw.tsv \
  .agent-files/benchmarks/m2/repeat.tsv
```

The driver asserts the internal budget is 30 seconds.  Its defaults are
`M2_BUDGET_SECONDS=30`, `M2_WATCHDOG_SECONDS=60`, and `--gcthreads=1`.

## Results and verdicts

`raw.tsv` and `repeat.tsv` contain all observations.  `summary.tsv` is the
per-problem digest.  The verdicts are:

- **P34 — indeterminate.**  Depth 6 completes without a proof after 160
  inferences, 37 branches and 3,300 conversions; the published depth-7 probe
  hits the measured API's unpolled-inner-interval watchdog.  M2 proves only
  that polling blind spot.  The fixed-budget cause remains indeterminate among
  accounting/ordering and inner-loop computational cost.  An earlier,
  unretained pre-M2 observation reportedly completed P34@7 with a lifted
  budget, so depth-7 capability is only reportedly known, not established by
  this retained artifact.  The target run is censored, so 37 is not compared
  with Isabelle's depth-7 count of 100.
- **P38 — indeterminate.**  The completed depth-4 HOL4 run exhausts without
  proof after 140 branches, versus Isabelle's completed successful depth-4
  count of 30.  The observed completed branch surplus is consistent with an
  accounting/ordering difference but does not exclude a capability
  difference.  The run performs 624 internal inferences, closes 210 branches,
  prunes 233 choices, and makes 5,478 rule conversions.
- **P41 — indeterminate.**  There is no published row.  Depth 5 completes
  without proof with 97 inferences, 6 branches and 1,082 conversions; depth 6
  is watchdog-censored inside unpolled work.  This establishes a cost cliff
  but cannot separate ordering/accounting from iff/gamma capability.
- **P42 — indeterminate.**  There is no published row.  Depth 3 completes
  without proof in about 12 seconds with 451 inferences, 34 branches and 6,084
  conversions.  Depth 4 reaches maximum resource cost 4 but is interrupted,
  with partial counts of 623 inferences, 35 branches and 7,856 conversions.
  The high inner work per created branch suggests repeated rule/gamma work,
  but no external comparator distinguishes ordering from capability.
- **P43 — indeterminate.**  The completed depth-5 HOL4 run exhausts without
  proof after 40 branches, versus Isabelle's completed successful depth-5
  count of 24.  The observed completed branch surplus is consistent with an
  accounting/ordering difference but does not exclude a capability
  difference.  The run performs 191 internal inferences and 2,833 conversions.
- **P45 — indeterminate.**  There is no published row.  Depth 10 completes
  without proof with 312 inferences, 115 branches and 2,477 conversions;
  depth 11 is watchdog-censored.  The bounded evidence shows depth-sensitive
  growth but cannot decide whether the absent proof is search order or a
  general capability gap.

These verdicts scope M3 evidence; they are not capability fixes.  In
particular, no row supports declaring a definite missing-inference capability.
