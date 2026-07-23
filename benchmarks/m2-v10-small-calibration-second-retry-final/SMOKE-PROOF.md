# Exact final-launcher load-only smoke proof

The actual absolute generated launcher ran from the frozen repository-root
supervised cwd through the exact vendored v10 collector and supervisor and
the final runtime auditor.  Its transaction is retained under
`smoke-evidence/`; the outer invocation is under
`pre-go-transactions/load-only-smoke/`.

Raw stdout is exactly `LOAD_OK\n`, raw stderr is empty, the supervisor is
`completed_exit_0`, containment is cleared, all collector schema/durability/
seal/artifact/endpoint statuses and final status are zero, and the final
artifact output is byte-equal to the temporary pre-smoke reference.  Exact
external `/proc` endpoints before and after are `matches=none` with status
zero.  No `V10CAL2`, `Time.now`, `searchGoal`, or search-row marker occurs.
The SML branch precedes scheduled-field, proposition, goal, claset, search,
and clock construction; this is load-path evidence only.
