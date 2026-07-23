# Post-boundary regenerated-final exact expectation protocol

After the single authoritative post-terminal-boundary target run is recorded
as `regenerated-final-raw.tsv` and validates through the generic protocol
validator, its mechanically extracted attempt table is written as
`regenerated-final-attempts.tsv`.  That reviewed table is locked byte-for-byte
as `regenerated-final-expectations.tsv`.  The locked table retains every exact
non-time field: problem/depth/attempt order, global search and reconstruction
counters, completion/result, outer and stored current contexts, all
observation/checkpoint/entry/exit values, and all per-phase and rule-kind
counters.  Only process/phase/attempt elapsed fields are excluded.

`verify-final-expectations.awk` independently compares the regenerated
attempt table against every retained field in row order.  Counter or context
mutation fixtures that preserve the broad algebraic identities must pass the
generic validator but fail this exact comparator.  The reviewed table,
summary and checksums are created once after the authoritative run; no target
rerun is permitted.

Final relocation/signal packaging reruns this comparator over the unchanged
retained attempt and expectation tables.  It does not invoke the target driver
or revise any exact expected field.
