# M2 v10 small calibration retry final report

Status: **stopped before calibration child 1; no timing attribution**.

The corrected full preflight and actual-launcher load-only smoke passed.  The
artifact reference was generated before and bound by the final GO seal, which
was verified after the package became read-only.  The collection driver then
failed its own seal check solely because it evaluated package-relative seal
paths from repository root.  The no-retry rule was honored: no collector,
supervisor, calibration process, search, or calibration clock ran.

Consequently there are no schedule results or A/B/C/D formulas to report.
See `COLLECTION_FAILURE.md`, the three retained pre-seal attempts, and
`smoke-evidence/`.  Tracked source, stage, commit, and both sealed Task 7k
packages remain untouched.  No optimization was selected.
