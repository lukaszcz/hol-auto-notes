> **HISTORICAL / VOID:** Every later claim of authority in this file is void.
> This package is non-authoritative; use `../m2-timed-v2-final/`.

# Task 7g timed-v2 evidence package

This ignored package is the authoritative measurement for commit
`b1c8700d2125cc2662bcb9ee348fe54143f3bee4`.  It implements no optimization
and modifies no tracked source.  `PREDECLARATION.md` fixes the schedules,
clocks, deadlines, calibration, thresholds and retry rules before timing;
the successive repair ledgers preserve every harness/validator issue rather
than replacing evidence silently.

## Results

The mechanically derived target table is `target-summary.tsv`; exact attempt
vectors and contexts are in `raw.tsv`, sealed independently by
`AUTHORITATIVE_RAW.sha256`.  All target statuses are zero and outcomes follow
the exact predeclared 1/3/1 attempt schedule.  Process residuals are .644602,
1.314545 and .618039 seconds for P34/P41/P45.

AlternativeEnumeration is the largest exclusive outer owner on all targets:
44.35%, 24.77% and 41.54% of attempt time.  Minor traversal/decomposition/
binding is 99.97%, 99.01% and 99.96% of minor time and 42.86%, 35.33% and
41.45% of attempt time.  Its per-call maxima are only .601%, .081% and .527%
of category total across 928, 78,884 and 1,251 calls, establishing volume
rather than a few expensive calls.  Cleanup is exactly zero.

Timed-v2 versus timed-v1 medians were -.22% on P38@4, +.03% on P43@5 and
+12.47% on the active 1,000-replay fixture.  Work, outcomes, counters and
ordered signatures match exactly; these figures quantify perturbation and do
not correct target data.

The evidence selects minor traversal/decomposition/binding as a general
diagnostic target and AlternativeEnumeration as a second outer owner, but not
a specific optimization.  The traversal bucket still combines store lookup,
decomposition, pattern/occurs checks and binding; the outer API has no
per-pull maximum.  The next narrow experiment should split the former and add
an AlternativeEnumeration maximum or bounded histogram.  No capability fix
is supported by elapsed-time evidence.

## Audit map

- `PREDECLARATION.md` and `PREDECLARATION.sha256`: immutable original protocol.
- `PRE_TIMING_REPAIR*`, `PRE_MEASUREMENT_TYPE_REPAIR*`,
  `POST_REPRESENTATIVE_PARSE_REPAIR*`, `TARGET_RETRY_1*`: chronological
  disclosures and hashes.
- `calibration-raw.tsv`, `active-calibration-raw.tsv`,
  `calibration-summary.tsv`: exact calibration ledgers and mechanical summary.
- `raw.tsv`, `target-summary.tsv`: authoritative raw and derived target data.
- `verify-target.awk`, `validate-calibration.sh`, `selfcheck.sh`: gates.
- `fixtures/`: 24 independent corruptions, all rejected.
- `process-audit.txt`, `command-status.tsv`, `source-before.sha256`,
  `source-after.sha256`, `build-provenance.txt`: lock, endpoints, statuses,
  immutability and source/object/executable provenance.
- `pre-measurement-failure/`, `pre-active-failure/`, `target-attempt-0/`:
  retained non-authoritative failures.

Run from repository root:

    .agent-files/benchmarks/m2-timed-v2/selfcheck.sh

The supported-build reproducer is intentionally not expanded here.  The
immediately prior `m2-claset-time` package retains its audited disposable-copy
reproducer; current forced rebuild hashes and source immutability are retained
locally in this package.
