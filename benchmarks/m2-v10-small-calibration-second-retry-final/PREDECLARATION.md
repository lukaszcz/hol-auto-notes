# M2 v10 P38 four-mode calibration: final frozen declaration

This is a wholly new evidence-only package for source revision
`244b01d7189ac803df48e246a483c33b553e3daa`.  It imports no timing row,
changes no tracked source, stage, or commit, and does not modify or retry any
earlier sealed or reviewed package.

The sole workload is Pelletier P38 at depth 4.  Mode A is ordinary detailed
measured reconstruction; B is timed-v2 with direct `Time.now`; C is timed-v4
with a counting clock returning `Time.zeroTime`; D is timed-v4 with a counting
`Time.now` clock.  `schedule.tsv` fixes a balanced 20-child order, five fresh
sequential children per mode.  Every child has a 25-second v10 watchdog and
there is no retry.  Any post-GO nonzero status, timeout, malformed record,
artifact or seal drift, endpoint match, parity failure, or protocol failure
stops the schedule without replacement.

All 20 rows must agree exactly in outcome, attempt count, eight search
counters, and every ordered 37-field reconstruction signature.  C and D
clock-read totals must be equal and positive within every repetition and
globally.  Each C/D attempt must have zero retained trace allocations, zero
sequence-statistics reads, and exactly one terminal summary-statistics read;
the corresponding row totals are zero, zero, and attempt-count.  A/B expose
those v4-only fields as `NA`.

For each mode, the external result is the third of five numerically sorted
v10 supervisor elapsed intervals, with the full minimum--maximum range.
`T_B/T_A` must lie in inclusive `[0.95,1.05]`.  The fixed quantities are
`T_D-T_A`, `T_C-T_A`, `T_D-T_C`, and `(T_D-T_C)/(T_D-T_A)` only for a positive
denominator.  Clock-dominant requires share at least `.80` and `T_D/T_C` at
least `1.50`; aggregation-material requires `T_C/T_A` at least `1.25`; both
may hold.  A failed B/A gate, nonpositive share denominator, or neither
predicate is `mixed/indeterminate`.  This protocol has no target and cannot
select an optimization or capability conclusion.

The load-only branch is selected before scheduled fields, goal, claset,
search, or clock construction.  Smoke and calibration use the same absolute
generated launcher, repository-root supervised cwd, vendored v10 collector,
supervisor, runtime auditor, and command vector.  The launcher loads the UI
from its frozen absolute package path.

Before a calibration child, a provisional scoped seal is tested by the exact
`collect.sh` with `DRY_RUN=1` from repository root and an unrelated cwd.  Each
dry-run must verify the package-scoped seal, recursively reject writable
package paths, retain an exact pre-child `/proc` endpoint and stop before the
collector or supervisor.  Smoke and both dry-run transactions are then bound
by the regenerated final artifact reference, input manifest, and GO seal.
The package is again recursively read-only, and final status-bearing seal,
read-only, and endpoint gates run immediately before child 1.

Metadata policy: live executable, UI/UO, lock, make-dependency, and `.hol`
log files are required and artifact-bound during collection.  Immutable
pre-GO copies are retained under `frozen-inputs/generated/`.  After collection
or failure those live paths are removed; frozen copies and scratch transaction
evidence are disclosed evidence, not live build residue.
