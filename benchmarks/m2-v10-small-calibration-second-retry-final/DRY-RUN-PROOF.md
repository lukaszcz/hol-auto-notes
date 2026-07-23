# Exact driver dry-run proof

After the provisional artifact reference, input manifest, and package-scoped
GO seal were generated, the package was recursively made read-only and
status-bearing seal/read-only checks passed.  The exact final `collect.sh` was
then run with `DRY_RUN=1` through `run-driver.sh`, first from repository root
and then from the unrelated cwd retained in
`pre-go-evidence/dry-run-unrelated/driver-evidence/cwd.txt`.

Both transactions retain command, cwd, declared environment, driver stdout,
driver stderr, driver numeric status, machine status, and unconditional final
exact endpoint.  Each passed scoped seal verification, a recursive audit of
728 directories and 2,535 regular files with no writable paths or symlinks,
and the exact pre-child endpoint.  Each then wrote `DRY-RUN-STOP.txt` and
stopped.  Driver and final endpoint statuses are zero and both exact endpoints
say `matches=none`.  Neither tree contains a child directory, supervisor JSON,
raw seal, collector final status, or supervisor/collector transaction
artifact; the explicit stop ledger records collector/supervisor/child as
`no`.

The provisional seal/reference/manifest and complete dry-run transactions are
retained under `pre-go-evidence/`.  They are inputs to, not replacements for,
the regenerated final seal.
