# Exact driver no-child dry-run proof

After provisional reference/manifest/seal generation, the package was made
recursively read-only.  The exact `collect.sh` then ran through
`run-driver.sh` from repository root and from the unrelated scoped cwd
`/tmp/isabelle-tactics-task7f-20260720-root/task7n_low_perturbation_diagnostic_fresh/unrelated-cwd-verified`.

Both transactions retain exact command, cwd, environment, stdout, stderr,
numeric driver status and unconditional exact-argv final endpoint.  Each
passed scoped seal verification, recursive read-only audit and exact pre-child
endpoint, then wrote `DRY-RUN-STOP.txt`.  Both driver and endpoint statuses are
zero.  The transaction trees contain no child directory, supervisor JSON,
raw seal, collector final status or benchmark row.  The complete provisional
seal and dry-run evidence is under `pre-go-evidence/`; final inputs are
regenerated after it.

