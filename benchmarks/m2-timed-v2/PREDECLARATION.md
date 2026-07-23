> **HISTORICAL / VOID:** Every later claim of authority in this file is void.
> This package is non-authoritative; use `../m2-timed-v2-final/`.

# Task 7g timed-v2 measurement predeclaration

Frozen before any Task 7g calibration or target timing was collected on
2026-07-20.  `PREDECLARATION.sha256` seals this file, the three schedules,
the harness sources, runners, validator and summarizer.  Results are append-
forbidden: every runner refuses an existing output and the final checksum
manifest seals the completed package.

## Isolation, clocks, and build

All scratch files, command logs and transient output are physically below
`/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure/`.  No command in
this protocol uses loose `/tmp`, host `/var/tmp`, or `/tmp/Holmakefile`.
One atomic `mkdir` lock at
`/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure/schedule.lock`
is held across the rebuild, selftests, both calibration schedules, and the
authoritative target schedule.  Runs are sequential and fresh-process.
Endpoint audits use `pgrep -af '[t]ask7gmeasurement'`, which cannot match the
literal audit command itself.  The lock excludes cooperating runs; endpoint
snapshots cannot prove absence of unrelated processes between snapshots.

Before timing, force-regenerate the affected classical UI/UO and selftest,
then blast reconstruction UI/UO, selftest and the three harness executables.
Retain source/object/executable SHA-256 hashes, mtimes, commands and statuses.
Run both level-2 selftests.  No supported-build reproducer is added: the
immediately prior package already retains its audited disposable-copy
reproducer, while this run retains current rebuild provenance and hashes.

The injected and process clock is `Time.now`.  Target search and every replay
attempt share the same 30-second cooperative deadline, measured from process
work start.  GNU `timeout 60s` is the independent watchdog.  The target order
is exactly P34@7, P41@6, P45@11 with debug false and one authoritative run.
Expected attempt schedules from immediately prior final evidence are exactly
P34: one Interrupted/NONE; P41: Completed/NONE, Completed/NONE,
Interrupted/NONE; P45: one Interrupted/NONE.  These expectations constrain
validation, never runtime selection.

No target retry is permitted except: watchdog status 124, nonzero harness
status, malformed/truncated output, endpoint contamination, or validator
failure caused by an environmental/I/O fault rather than a valid measured
result.  A retry must preserve the failed ledger and audit, be explicitly
numbered, and cannot replace a valid run merely because its timings or cutoff
are inconvenient.  Otherwise the chronologically first complete locked run
is authoritative.  No schedule or threshold changes after observation.

## Calibration

Timed-v2 perturbation is compared directly with the immediately prior
timed-v1 entry point.  The representative completed workloads are P38@4 and
P43@5, each in three paired repetitions in fresh processes.  Odd repetitions
run P38 then P43 and v1 then v2; the even repetition reverses both.  The
active fixture is the general stored-elimination proof `[p /\ q] |- p`,
replayed 1,000 times in each of five paired fresh processes; odd repetitions
run v1 then v2 and even repetitions reverse.  There is no calibration
watchdog or deadline.  Exact schedules are in `calibration-schedule.tsv` and
`active-calibration-schedule.tsv`.

Every paired mode must have identical outcome, attempts, search counters,
ordered reconstruction counter signatures, and (for the active fixture)
residue and successful kernel validation.  Medians (middle of 3 or 5), full
ranges, v2/v1 ratios and percentage changes are derived mechanically.  Raw
values are reported without correction and cannot be used to adjust targets.
The calibration is acceptable if all work identities match and every process
exits zero; there is no performance pass threshold because it quantifies
observer perturbation rather than certifying production speed.

## Hypotheses and interpretation

H1: exclusive outer reconstruction, especially AlternativeEnumeration or
ReplayRecursion, accounts for the material remainder Task 7f left outside
classical work.  H2: minor unification is volume-driven if totals are large
but the reported per-call maxima are a small share; it is outlier-driven if
a maximum is at least 25% of its category total.  H3: within minor
unification, a component is dominant only if it is at least 60% of minor time
and at least 25% of attempt time on at least two of three targets.  An outer
category is dominant only if it is at least 40% of attempt time on at least
two targets and is the largest exclusive outer category there.

Percentages use exact retained decimal seconds and are descriptive, not
corrected for calibration.  If neither threshold is met, or if perturbation,
residuals, maxima, or censoring prevent isolation, the verdict is
indeterminate and no optimization is selected.  Even a threshold crossing
justifies at most a specifically named next experiment unless the same
general component dominates multiple targets without a few-call maximum.

## Mechanical validation

The validator requires exact TSV schema, schedule order and literals,
one stdout summary and status zero per process, the locked attempt schedule,
terminal EOF marker, and no rows after it.  It checks all nonnegative decimal
times and natural counters; outer = Alternative + Replay + Other;
attempt = outer + classical; minor = normalization + traversal/decomposition/
binding + zero cleanup; cleanup and its maximum are exactly zero; failures
are at most calls; every maximum is at most its category total and overall
minor maximum is at least each component maximum; process residual equals
process elapsed minus summed attempt wall; summary sums equal attempt rows;
observer and phase entry/exit inequalities and stored context coherence hold.

Adversarial fixtures independently corrupt each new total, component,
maximum, calls/failures relation, cleanup-zero rule, outer partition, attempt
partition, process residual, context, status, order, lock/schedule literal,
and terminal/no-append rule.  Each must be rejected with a diagnostic.  The
package selfcheck regenerates summaries, fixtures and checksum input lists,
byte-compares derived output, checks source immutability and tracked scope,
and verifies every retained hash.
