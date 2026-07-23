# Pre-timing runner repair

The first locked invocation stopped at `classical-selftest`, before either
calibration output or target output existed.  The build and executable were
successful; invocation from the repository root could not resolve
`selftest.ui`.  The retained scratch command-status ledger recorded statuses
0, 0, 1.  No elapsed calibration or target observation occurred.

Only the selftest working directories and the audit's mechanically expected
command count (eight, not nine) were repaired.  Schedules, harnesses,
validator, clocks, deadlines, hypotheses, thresholds and retry rules were not
changed.  `PREDECLARATION.sha256` remains the immutable hash ledger of the
original pre-run files rather than being rewritten.  `PRE_TIMING_REPAIR.sha256`
seals the two repaired scripts and this disclosure before timing.
