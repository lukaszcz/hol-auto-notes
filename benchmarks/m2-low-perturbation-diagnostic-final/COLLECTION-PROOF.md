# Collection proof

Immediately before GO, status-bearing scoped-seal, recursive-read-only,
exact-argv endpoint, HEAD, index and tracked-worktree gates all returned zero.
The actual `collect.sh` ran from repository root through `run-driver.sh`; the
outer wrapper retains exact cwd/command/environment, stdout, stderr, numeric
driver status and unconditional final exact endpoint.

The fixed schedule created exactly ten ordered child transactions.  Every
child contains v10 supervisor JSON, stdout/stderr/status and durability seal,
artifact audit equal to the final reference, exact final endpoint and final
status zero.  `driver-status.tsv` is exactly sequences 1--10 with status zero;
no `STOPPED.tsv` exists.  The closed 12-line raw ledger, validation PASS,
immediate raw SHA-256 seal, summary and derived report are under
`collection/transaction/collection/`.  No row was imported, replaced,
censored or rerun.

