# Actual-launcher load-only smoke proof

The repaired smoke used the reviewed vendored v10 collector and supervisor,
the final runtime auditor, repository-root supervised cwd, and the same
single absolute executable command vector declared for calibration.  Only
inherited `T7L_RUN_KIND` selected `load-only`.

The transaction under `smoke-evidence/smoke-transaction/` has exact stdout
`LOAD_OK\n`, empty stderr, observed supervisor status 0 and classification
`completed_exit_0`, cleared PID-namespace containment, zero collector schema,
durability, seal, artifact, and endpoint statuses, and final status 0.  Its
artifact output is byte-equal to the temporary pre-smoke reference.  Exact
external `/proc` audits before and after have `matches=none` and retained
status 0.  The smoke wrapper also proved stdout/stderr contained no
`V10CAL2`, `Time.now`, `searchGoal`, or search-row marker.

The branch is selected before construction of sequence fields, goal,
proposition, claset, search, or clocks.  This is precollection load-path and
protocol evidence only; its supervisor interval is not calibration evidence.
