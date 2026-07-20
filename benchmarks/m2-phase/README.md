# M2 phase-local follow-up diagnosis

This directory retains the Task 7b evidence collected at outer revision
`8264571bef871399630aed07c36abb7bb486c36b`, starting from notes revision
`04e8297ca837fcd040a46086db83107319f6fdea`.  It is diagnosis only: no outer
source, expected-failure list, proof budget, or search behavior was changed.

## Protocol and schema

`m2phase.sml` copies the six propositions from the blast selftest and builds
the same invocation claset as `BLAST_DEPTH_TAC depth []`.  It calls
`searchGoalMeasured` once at one explicit depth in a fresh process.  The stop
predicate retains the unchanged 30-second cooperative deadline; the shell's
60-second watchdog is only a safety net.  Runs are sequential and use
`--gcthreads=1`.

The primary schedule is exactly P34@7, P38@4, P41@6, P42@4, P43@5 and P45@11.
P38 and P43 use bounded debug traces because these published-depth rows were
already known to complete.  The critical rows do not retain a growing trace.
`raw.tsv` and `repeat.tsv` contain two full passes.  The short completed
predecessors P34@6, P41@5 and P45@10 were also run twice to provide phase
profiles adjacent to the three still-opaque cliffs.

The 32-column schema retains all earlier M2 fields and adds the measured
phase fields: API cooperative checkpoints; candidate rules and conversion
attempts; safe/unsafe rule attempts; rule-unification attempts/successes;
equality-substitution attempts/successes; and literal-close
attempts/successes.  The harness's independent `stop_polls` must equal the API
checkpoint counter on an observed row.  It also retains configured/resource
depth, cache hit/conversion counters, and bounded trace state/live-branch/
formula-slot summaries.  Time is excluded from determinism comparisons.

## Exact commands

From the repository root:

```sh
chmod +x .agent-files/benchmarks/m2-phase/run-m2-phase.sh
cp .agent-files/benchmarks/m2-phase/m2phase.sml \
  src/auto/blast/m2phase.sml
(cd src/auto/blast && ../../../bin/Holmake m2phase.uo)
.agent-files/benchmarks/m2-phase/run-m2-phase.sh
M2P_RUN=2 OUTPUT=.agent-files/benchmarks/m2-phase/repeat.tsv \
  .agent-files/benchmarks/m2-phase/run-m2-phase.sh
SCHEDULE=.agent-files/benchmarks/m2-phase/schedule-predecessors.tsv \
  OUTPUT=.agent-files/benchmarks/m2-phase/predecessors.tsv M2P_RUN=1 \
  .agent-files/benchmarks/m2-phase/run-m2-phase.sh
SCHEDULE=.agent-files/benchmarks/m2-phase/schedule-predecessors.tsv \
  OUTPUT=.agent-files/benchmarks/m2-phase/predecessors-repeat.tsv M2P_RUN=2 \
  .agent-files/benchmarks/m2-phase/run-m2-phase.sh
awk -f .agent-files/benchmarks/m2-phase/verify-determinism.awk \
  .agent-files/benchmarks/m2-phase/raw.tsv \
  .agent-files/benchmarks/m2-phase/repeat.tsv
awk -f .agent-files/benchmarks/m2-phase/verify-observations.awk \
  .agent-files/benchmarks/m2-phase/raw.tsv \
  .agent-files/benchmarks/m2-phase/repeat.tsv
awk -f .agent-files/benchmarks/m2-phase/verify-predecessors.awk \
  .agent-files/benchmarks/m2-phase/predecessors.tsv \
  .agent-files/benchmarks/m2-phase/predecessors-repeat.tsv
```

The first verifier is intentionally strict and reports P42's partial-counter
nondeterminism.  The second verifies that status/result pairs reproduce, that
completed counters reproduce, and identifies the time-censored P42 exception.
The predecessor verifier checks every non-time field.  The exact outputs and
exit statuses are retained in `integrity.log`.

## Evidence and diagnosis

P38@4 and P43@5 complete without proof.  Their outcomes, all counters, polls
and compact trace summaries reproduce exactly.  Their completed branch counts
remain 140 and 40, compared with Isabelle's published 30 and 24.  As in the
original M2 record, HOL4's internal inference and phase counters have no
Isabelle counterpart, and a branch surplus is consistent with but does not
prove an accounting/ordering difference.  No causal claim follows.

P42@4 returns `Interrupted` with no proof in both runs.  Only that completion/
result pair reproduces.  Its elapsed-time-selected partial work counters do
not: for example, inferences are 617/620 and checkpoints are
3,534,805/3,544,691.  No cutoff state or search-path-prefix reproduction is
claimed.  This is time-censored work, not deterministic completed work; the
mismatch is retained rather than hidden.

P34@7, P41@6 and P45@11 still do not return before the 60-second watchdog, in
either pass.  Consequently they have no coherent snapshot and no exact
run-time phase counter.  The new code checkpoints all named inner phases, but
its public contract excludes an indivisible HOL/kernel primitive, emergency
rollback cleanup, and the caller continuation's reconstruction/validation
interval from its latency guarantee.  With no snapshot, the artifact cannot
distinguish those three cases and does not claim an exact active phase.

The completed predecessor phase profiles reproduce exactly.  They show mixed
work: candidate conversion, rule iteration/unification, equality probes,
literal closing, and search transitions all occur.  P42 and P45 have the
largest raw counts in literal-close attempts, while candidate conversion is
also repeated 1,069--7,807 times across observable rows.  Cache hits are only
3--12 percent of conversions.  These are work quantities, not phase-local
times.  They therefore do not establish that enumeration/net traversal,
canonical conversion, cache copying, rule iteration, unification, equality,
literal closing, or premise/search transitions dominate elapsed time.

## Ranked, bounded follow-up

1. **Selected Task 7c: test the emergency-rollback hypothesis.**  Make that
   cleanup observable and bounded while preserving state safety and ordinary
   search behavior, then rerun P34@7, P41@6 and P45@11 at the same
   30/60-second boundaries.  This does not guarantee that the rows return.  If
   a watchdog remains, instrument the caller-continuation boundary to separate
   reconstruction/validation from the remaining indivisible search interval
   before attempting any search optimization.
2. **Candidate only: memoize immutable canonical theorem forms per search.**
   Observable rows perform thousands of candidate conversions with little
   formula-cache reuse, so this is a small general experiment.  Counts alone
   do not show that canonical work costs the time, so do not select or land it
   until post-rollback and, if needed, continuation-boundary evidence or
   phase-local timing demonstrates benefit.  It remains unselected.
3. **Lower-ranked candidate: index complementary literal closing.**  P42 and
   P45 have the largest literal attempt counts, but the gap over other work is
   not a timing result.  Consider this only after item 1 and a measurement
   separating literal scans from unification and transition work.

No search/capability fix is justified by this artifact yet.
