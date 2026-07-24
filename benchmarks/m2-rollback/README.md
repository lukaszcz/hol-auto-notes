# M2 rollback-ownership experiment

Archive note (2026-07-23): `searchTermsMeasured` was removed; consult git
history for its implementation.

This package records Task 7c on final uncommitted source based on outer
revision `8264571bef871399630aed07c36abb7bb486c36b` and notes revision
`6d5f079ec441c4216f817f15d82aaa90b8bb5758`.  It tests whether emergency
trail rollback caused the three previously opaque 60-second watchdogs.

## Source experiment

`searchGoalMeasured` owns the prototerms translated from its HOL goal.  Its
explicit `Interrupted` path may abandon those assignments, while
`searchTermsMeasured` restores caller-owned prototerms.  Stop-predicate and
continuation exceptions restore and propagate unchanged for both entry
points.  With debug enabled, the returned trace can expose engine-owned
prototerms with their cutoff-time assignments intact.

The cleanup counter is allocated only by measured instrumentation.  Base
`blastTerm.state`, ordinary search, and Stats search carry no counter or
cleanup hook.  Focused regressions cover:

- exact interruption with 256 live goal-owned assignments, zero cleanup
  traversal, no continuation, and four identical repeat snapshots;
- restored caller-owned term references;
- a debug trace exposing coherent assigned goal-owned state;
- exact goal continuation-exception identity and restoration of assignments
  reachable through an externally saved proof;
- exact goal stop-exception identity at a calibrated live-assignment
  checkpoint; and
- unchanged completed ordinary, Stats, and measured outcomes/counters.

The final-source default blast selftest passed with unchanged honest
outcomes: Pelletier 42/48, published Table 1 6/9, and set problems 4/4.  No
expected failure or budget changed.  `default-selftest.log` is the retained
output.

## Reproducing the rollback schedule

`m2rollback.sml` is a self-contained byte-for-byte copy of the retained M2
phase harness.  From the repository root:

```sh
cp .agent-files/benchmarks/m2-rollback/m2rollback.sml \
  src/auto/blast/m2rollback.sml
cmp .agent-files/benchmarks/m2-rollback/m2rollback.sml \
  src/auto/blast/m2rollback.sml
(cd src/auto/blast && ../../../bin/Holmake m2rollback.uo)
.agent-files/benchmarks/m2-rollback/run-rollback.sh
```

`run-rollback.sh` fixes the cooperative deadline at 30 seconds, the process
watchdog at 60 seconds, uses a fresh sequential `--gcthreads=1` HOL process
per schedule row, and writes `raw.tsv`.  All three rows remain
`watchdog_killed` at `>=60.000000`; abandoning goal-owned rollback is not
sufficient to make them return a snapshot.

## Reproducing the continuation boundary schedule

`m2continuation.sml` is the exact retained marker derivative.  It flushes
problem-labelled stderr markers before reconstruction, before validation, on
reconstruction rejection, and on successful exit.  A direct `diff -u` against
`m2rollback.sml` audits the only source change.

```sh
cp .agent-files/benchmarks/m2-rollback/m2continuation.sml \
  src/auto/blast/m2continuation.sml
cmp .agent-files/benchmarks/m2-rollback/m2continuation.sml \
  src/auto/blast/m2continuation.sml
(cd src/auto/blast && ../../../bin/Holmake m2continuation.uo)
.agent-files/benchmarks/m2-rollback/run-continuation.sh
awk -f .agent-files/benchmarks/m2-rollback/summarize-continuation.awk \
  .agent-files/benchmarks/m2-rollback/continuation.raw.tsv \
  > .agent-files/benchmarks/m2-rollback/continuation.tsv
```

`continuation.raw.tsv` retains every flushed marker, every per-process exit
status, any stdout row, and the complete 30/60 protocol.  The AWK program
validates the schema, schedule, labels, per-problem event order, event
whitelist, absence of stdout, exactly one terminal status 124, and absence of
records after that status before generating `continuation.tsv`.

Four retained negative fixtures prove that unknown events, reordered events,
stdout rows, and nonterminal status records are rejected with diagnostics:

```sh
.agent-files/benchmarks/m2-rollback/test-continuation-validator.sh
```

P34 and P45 each enter `reconstructWith` and remain there until killed.  P41
has two reconstructions return `NONE`, enters a third, and remains there until
killed.  No row reaches validation.  The observed watchdog interval is
therefore after a found tableau and inside proof reconstruction, not in
emergency rollback.  No search/capability optimization follows from this
result.

## Cleanup and verification

Generated harness sources and compiled residue were removed after capture.
The retained empty-output check is reproduced with:

```sh
find src/auto/blast -maxdepth 3 \
  \( -iname 'm2phase*' -o -iname 'm2rollback*' \
     -o -iname 'm2continuation*' \) -print
```

Run `sha256sum -c checksums.sha256` from the repository root.  The manifest
includes final source/tests/plan, every harness and driver, all raw and
generated evidence, the test log, environment, and integrity record.
