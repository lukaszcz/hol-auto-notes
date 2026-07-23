# Retained pre-seal attempt 2: load-only smoke rejection

The exact `smoke.sh` body and all launch/auditor/collector-facing bodies are
under `full-bodies/`.  The complete v10 transaction, exact external endpoint
audits/statuses, command vector, child cwd, and collector status are under
`smoke-evidence/`.

The absolute launcher/module path succeeded, but HOL elaborates the entire
module before running its branch.  It rejected `finish base proof` in modes B
and C/D because `base` is a `timed_detailed_measured_result`, while the helper
was annotated as `detailed_measured_result`.  Collector status was 1 with
classification `completed_exit_nonzero`; raw durability/seal, schema,
artifact identity, containment, internal endpoint, and both exact external
endpoints passed.  stdout was empty and stderr retained the static errors.
Thus no `LOAD_OK`, search row, search construction, or benchmark clock
occurred.  This preceded final artifact stabilization and GO seal.

The repair passes completion, result, and detailed statistics explicitly to
the helper, preserving both record shapes and all calibration semantics.  A
full formal preflight and a new smoke are required.
