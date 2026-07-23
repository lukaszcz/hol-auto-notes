# Preserved provisional-gate and dual dry-run failure

The first provisional preparation omitted `verify-go-seal.py` from the new
package.  Artifact-reference and seal generation succeeded, but the
status-bearing verification returned 2 because the verifier path was absent.
The ad-hoc outer preparation command did not use `set -e`; it printed an
incorrect local `provisional_seal=PASS` message after retaining the nonzero
verification status.  That message is explicitly void.

Both subsequent exact-driver dry-runs (repository-root cwd and unrelated cwd)
stopped at their first scoped-seal gate with driver status 1 and unconditional
final exact-endpoint status 0.  Neither reached the read-only gate, collector,
supervisor or child, and neither produced a diagnostic clock.  Complete
provisional commands/stdout/stderr/status and both dry-run transaction trees,
outer commands and statuses are retained here.

The repair vendors the reviewed cwd-independent `verify-go-seal.py`, then
requires a fresh full preflight, smoke reference/smoke, provisional seal, and
both no-child dry-runs.  No failed artifact or status is reused.
