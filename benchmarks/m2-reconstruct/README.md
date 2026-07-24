# M2 measured-reconstruction experiment

Archive note (2026-07-23): the diagnostic functions described below were
removed; consult git history for their implementation.

This package records Task 7d on final uncommitted source based on outer
revision `9b88306e84b511cdd107085e8d94b43d11e54b8a` and notes revision
`700252f126d5d2abe16d1860a868c20d1d8742b0`.  It closes the observability gap
left by Task 7c: P34@7, P41@6 and P45@11 had entered reconstruction but were
previously killed by the 60-second watchdog before returning a snapshot.

## Source experiment

`blastReconstruct.reconstructWithMeasured` is a diagnostic-only worker.  It
accepts a cooperative stop predicate and an optional observation callback,
and returns completion, result, current `Enter`/`Exit` phase and exact phase
counters.  `TypedStep` covers setup of a typed step's lazy sequence.
`AlternativeEnumeration` covers `seq.cases`, including lazy forcing needed to
expose the next engine node.  `StoredRuleTransition` starts after a node has
been yielded and covers child counting plus possible duplicate movement; it
is not the stored-rule engine call.  The remaining constructors distinguish
replay recursion, stored-rule sequence setup, duplicate movement, finish
checks, grounding and kernel replay.  Callback exceptions are wrapped across
legacy catch-all `total` boundaries and rethrown unchanged.

The existing `reconstruct`, `reconstructWith`, tactics and Stats path continue
to call the original unmeasured worker.  Focused regressions cover exact
completed close-assume and close-contradiction counters and kernel boundaries,
explicit interruption, deep stop/observer exception identity, all six typed
step counters across the focused fixtures, ordinary/measured reconstruction
parity, post-yield stored-rule processing and duplicate-child movement.

Every bracketed operation is indivisible between surrounding cooperative
polls.  Lazy sequence forcing, external typed transitions, grounding and
`Tactical.VALID` are especially relevant examples.  Exceptions and ordinary
replay backtracking can leave an `Enter` without a matching `Exit`.  The API
therefore exposes honest boundary history; it does not promise a hard
real-time limit or identify the cause of time spent from the last boundary.

## Reproduction

From the repository root, install the retained source as a temporary harness,
compile it, and verify the copy before running:

```sh
cp .agent-files/benchmarks/m2-reconstruct/m2reconstruct.sml \
  src/auto/blast/m2reconstruct.sml
cmp .agent-files/benchmarks/m2-reconstruct/m2reconstruct.sml \
  src/auto/blast/m2reconstruct.sml
(cd src/auto/blast && ../../../bin/Holmake m2reconstruct.uo)
.agent-files/benchmarks/m2-reconstruct/run-reconstruction.sh
awk -f .agent-files/benchmarks/m2-reconstruct/verify-reconstruction.awk \
  .agent-files/benchmarks/m2-reconstruct/raw.tsv \
  > .agent-files/benchmarks/m2-reconstruct/attempts.tsv
.agent-files/benchmarks/m2-reconstruct/test-validator.sh
```

The driver uses a fresh sequential `--gcthreads=1` HOL process per schedule
row.  Search and all reconstruction attempts share one 30-second cooperative
deadline; `timeout` supplies an independent 60-second whole-process watchdog.
The accepted run began and ended with no benchmark runner or harness process
present, as recorded in `process-audit.txt`.

`raw.tsv` retains every flushed phase boundary, attempt entry/result, stdout
row and process status.  The validator checks exact block/attempt order,
protocol fields, terminal status, current snapshot against the last observed
boundary, observer counts against checkpoints, `entries + exits`, typed-step
subtotals and complete phase-entry subtotals.  `attempts.tsv` is generated
only after those checks.  Three negative fixtures show that malformed headers,
unknown phases and inconsistent counters are rejected with diagnostics.
Its `process_seconds` column repeats the whole fresh-process duration on each
attempt row; it is not an attempt-local duration.
Flushing every boundary is intentional diagnostic overhead, so the elapsed
times and work counts are evidence for this protocol, not a production-speed
baseline.

## Result and limit of the evidence

- P34@7: one `Interrupted/NONE` attempt, 2,568 reconstruction checkpoints.
- P41@6: two `Completed/NONE` attempts, then one `Interrupted/NONE` attempt
  with 140,206 reconstruction checkpoints.
- P45@11: one `Interrupted/NONE` attempt, 3,084 reconstruction checkpoints.

All three fresh processes exited normally below the 60-second watchdog.  The
accepted P34/P41 snapshots ended at `AlternativeEnumeration/Exit`; P45 stopped
at `StoredRuleTransition/Enter`.  Here alternative enumeration includes lazy
engine-transition forcing, while stored-rule transition denotes post-yield
processing.  Discarded preliminary captures placed the
P34/P41 deadline at different adjacent boundaries.  A last boundary is where
the deadline was observed, not a causal attribution.  The full counters show
substantial repeated typed replay and alternative enumeration, but select no
optimization and establish no capability improvement.

The smallest justified follow-up targets lazy forcing inside `clasetStep`, or
a measured adapter around it, tagged with typed step kind and script position.
Subphases should distinguish `try_rule`/unification, direct child construction
and replay-record construction before any optimization is considered.

## Verification and cleanup

The final blast selftest is retained in `default-selftest.log`.  No expected
failure, count or budget changed.  Generated harness source and build residue
are removed after capture.  `integrity.log` records the focused verification,
style/diff checks, validator result and residue audit.  From the repository
root, `sha256sum -c .agent-files/benchmarks/m2-reconstruct/checksums.sha256`
checks final source, plan and every retained evidence file.
