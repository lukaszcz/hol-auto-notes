# Task 7g final authoritative timed-v2 predeclaration

This is a third, wholly fresh evidence chain. Both earlier packages,
`../m2-timed-v2/` and `../m2-timed-v2-fresh/`, are historical and void for
current authoritative claims. No observation from either package may be
imported, selected, or used to tune this run.

Before any fresh clock starts, `prepare-and-freeze.sh` force-builds the
affected classical and blast objects and all three harnesses, runs both
level-2 selftests, and runs positive and negative synthetic validator tests.
It also proves that the non-self-matching endpoint patterns
`[t]ask7gcalibration`, `[t]ask7gactive`, and `[t]ask7gmeasurement` detect both
wrapper-style command lines and `bin/hol ... task7g...` child command lines,
while the audit process itself is absent from its own match set.

The freeze retains complete byte bodies for this predeclaration,
`SEAL_PLAN.md`, the harnesses, Holmakefile, schedules, collector, runner,
complete-closure manifest generator, endpoint test, validators, fixture
generator and mutator, summarizers, summary checker, selfcheck, and
preparation script. `INPUTS.sha256` seals each live input and frozen body.
`INPUT-MANIFEST.tsv` records its hash, size, nanosecond-resolution mtime, and
frozen copy.

`ARTIFACTS-FROZEN.tsv` is an overinclusive runtime-closure manifest. It
contains every regular file under `src/auto` after the forced builds,
including every source and every `.hol/objs` UI/UO; all harness SML,
Holmakefile, UI/UO and executable files; `bin/hol`, `bin/Holmake`, the exact
used `bin/hol.state0` heap; configure sources; and the identities of relevant
host tools. Thus it necessarily includes `blastSearch`, `blastRule`,
`blastTerm`, `tableauLib`, `clasetLib`, and `clasetSeedTheory`. Imports below
`src/auto` that are already loaded in `hol.state0` are closed by the exact
saved-heap hash: the harnesses run the hashed `bin/hol` with that hashed heap,
and all automation modules loaded after the heap are independently included.
The manifest is deterministic and sorted by path, with SHA-256, byte size and
nanosecond-resolution mtime for every row.

Collection may begin only if frozen live-input hashes and the complete
runtime closure still match. Byte-identical manifests immediately bracket
each representative, active, and target segment; both endpoints are compared
with the frozen manifest. The same atomic directory lock covers all three
segments. Each endpoint snapshot uses the pattern without `.exe`, so it
matches wrapper and HOL-child forms. It is adjacent to its segment, but is
not a claim about unrelated processes between snapshots.

The schedules are fixed at 12 representative fresh processes for P38@4 and
P43@5 in the exact v1/v2 order; ten active fresh processes replaying the
general stored-elimination fixture 1,000 times; then exactly one sequential
target block P34@7, P41@6, P45@11. Every target attempt shares its process's
30-second cooperative deadline and has an independent 60-second GNU timeout
watchdog. Expected target attempts are exactly 1/3/1 with outcomes
Interrupted; Completed, Completed, Interrupted; Interrupted, all with NONE.
There is no rerun of valid data and no selection.

A retry is allowed only for watchdog status 124, nonzero harness status,
malformed/truncated output, endpoint contamination, or a validator failure
proved to be environmental/I/O rather than a valid observed result. Any retry
must retain the failed full ledger, exact commands and statuses, complete
before/after bodies, and full diffs for every changed file, then rerun the
entire target block once. Any pre-seal failure or repair has the same complete
chronology requirement and requires resealing before a clock starts. No
schedule, threshold, or valid observation may be changed after inspection.

## Calibration decision rule

Timed-v2 perturbation is compared with timed-v1 on the same work. P38@4 and
P43@5 each run three paired repetitions; the active fixture runs five paired
repetitions. Every pair must have identical outcomes, attempts, search
counters, ordered reconstruction signatures, and, for the active fixture,
residue and successful kernel validation. Medians, full ranges, ratios, and
percent changes are mechanically derived. Calibration values quantify
observer perturbation only; they never correct target values. There is no
performance pass threshold.

## Descriptive hypotheses and decision rules

H1: exclusive outer reconstruction, especially AlternativeEnumeration or
ReplayRecursion, accounts for material time left outside classical work.
AlternativeEnumeration is descriptively dominant only when it is the largest
exclusive outer category and is at least 40% of attempt time on at least two
of the three targets.

H2: minor traversal/decomposition/binding is descriptively dominant only
when it is at least 60% of minor time and at least 25% of attempt time on at
least two targets. A dominant minor component is classified as volume-driven
only when its largest single call is at most 5% of that component's total on
each target used for the dominance finding. A maximum above 5% prevents the
volume classification; a maximum of at least 25% is descriptive evidence of
an outlier-driven category.

H3: all current timed-v2 owners are broad buckets. Crossing a dominance or
volume threshold selects only a deeper diagnostic split. It never selects an
optimization until that bucket is split enough to distinguish the general
mechanisms inside it. If thresholds are not met, or perturbation, residuals,
maxima, or censoring prevent isolation, the verdict is indeterminate and no
optimization is selected. Percentages use exact retained decimal seconds and
are not calibration-corrected.

## Mechanical validation

Calibration validation fixes exact schemas, row order, canonical literals,
nine-digit decimal grammar, 8-wide search counters, 37-wide ordered
reconstruction signatures, 9-wide active signatures, exact counts, and
paired work identity. Target validation fixes exact string literals for
position, problem, depth, and attempt (so `34` differs from `034`, and `7`
differs from `7.0`), exhaustive vocabularies and context relationships,
timing partitions, maxima, observer identities, summaries, checkpoints, and
statuses. Synthetic negatives include wrong-value and noncanonical-equivalent
adversaries for problem and depth, at least ten further target adversaries,
and summary drift. Each failing command must emit its single intended
diagnostic and no PASS.

Every build, selftest, validator, 12 representative processes, ten active
processes, three target processes, and three watchdogs has an explicit status
and command in `preflight-status.tsv` or `collection-status.tsv`. The final
selfcheck accepts a caller-provided scratch root and is read-only with respect
to the package. A complete package manifest taken before and after it must be
byte-identical.

All scratch, logs, generated fixtures, and transient output are physically
under `/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure-final-fix/`.
No loose `/tmp`, host `/var/tmp`, or `/tmp/Holmakefile` is used or touched.
