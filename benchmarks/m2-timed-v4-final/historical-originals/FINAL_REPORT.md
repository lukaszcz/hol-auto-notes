# Final report

## Result

The representative v2/v4 comparability chain failed before medians. P38@4
completed equal work with exact outcome, eight search-counter and ordered
reconstruction-signature parity: v2 `1.652517000` s, v4 `8.652819000` s,
v4/v2 `5.236145`. P43@5 v2 completed at `12.645914000` s; v4 emitted no row
before its 45-second watchdog, so it is honestly reported `>=45 s` and its
ratio only as `>=3.558462`.

Thus the gate did not pass. The active control and P34/P41/P45 target schedule
never started. There are no target bounded categories or pull distributions
to interpret and no principled optimization is selected.

## Exact gates and commands

Source identity was HEAD `244b01d7189ac803df48e246a483c33b553e3daa`.
Before collection the following all returned zero:

- `bin/Holmake -C src/auto/classical clean`, then default build, then
  `HOLSELFTESTLEVEL=2 ./selftest.exe` in that directory.
- `bin/Holmake -C src/auto/blast clean`, then default build, then
  `HOLSELFTESTLEVEL=2 ./selftest.exe` in that directory.
- `bin/Holmake -C .agent-files/benchmarks/m2-timed-v4-final clean`, then the
  three explicit harness executable targets.
- `test-validators.sh` (three positives and 88 independent negatives),
  `endpoint-preflight.sh`, and `test-v4-controls.sh` (bounded-summary, gate,
  exit/signal and TERM/KILL process-group controls).
- The final collection command was
  `ROOT=$PWD .agent-files/benchmarks/m2-timed-v4-final/collect.sh`; it returned
  125 at the fourth representative, as retained in `collection-status.tsv`.

The exact frozen schedules, formulas, formulas for median/range/ratio,
thresholds, watchdogs, censoring and stop/go rules are in `PREDECLARATION.md`.
`INPUTS.sha256` seals 25 live inputs and 25 byte-identical frozen bodies; the
runtime closure has 426 rows. Fresh closure manifests matched immediately
before collection and after the failed child.

## Process-control limitation

All four children had their own process group and watchdog. The first three
JSON ledgers record status zero, leader reap and group gone. On the fourth,
TERM reaped the leader with observed signal 15, but the frozen supervisor
checked the process group immediately and found it still present; it returned
125 without waiting the full grace on the remaining group or escalating.
The later final audit proves PGID 2498 gone and no task endpoint. This is a
real protocol limitation, not rewritten as PASS. `SUPERVISOR_REVIEW.patch`
is the retained minimal next repair.

The smallest next diagnostic is to repair whole-group grace/escalation, then
calibrate v4 on a much smaller fixed-work replay/profile that separates clock
frequency and operation volume from bounded-summary aggregation. P43@5 should
not be repeated until that diagnostic predicts a short bounded run.
