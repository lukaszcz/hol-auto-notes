# Pre-measurement harness type repair

The second locked invocation completed the forced rebuild and both level-2
selftests, then the first representative calibration executable failed at
static elaboration.  Its only retained calibration ledger content was the
header; `val started = Time.now ()` was never evaluated and no elapsed row was
printed.  A direct diagnostic invocation reproduced three unresolved flexible
record-selector errors in the shared calibration `check` helper.  Inspection
found the same latent ambiguity in the active helper.

The only repair adds the public
`blastReconstruct.timed_detailed_measured_result` argument annotation to each
helper.  No schedule, workload, mode, clock, count, deadline, hypothesis,
threshold, target harness, validator, or collection order changed.  The
failed header and command/audit logs are retained under
`pre-measurement-failure/`.  `PRE_MEASUREMENT_TYPE_REPAIR.sha256` seals this
disclosure and the repaired calibration sources before any elapsed
calibration or target row exists.
