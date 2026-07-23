# Authoritative outcome: stopped before calibration child 1

The final artifact reference and `GO-SEAL.txt` were created before collection.
The seal was verified successfully from the package directory, and the entire
package was made read-only.  The sole authoritative collection command then
invoked `collect.sh` from repository root with explicit ROOT, PACKAGE_DIR,
SCRATCH_ROOT, and ARTIFACT_REFERENCE.

`collect.sh` created only its collection directory, endpoint directory,
schedule copy, and `go-seal-check.log`.  Its first operation
`sha256sum -c "$dir/GO-SEAL.txt"` interpreted the seal's package-relative
paths from repository root.  All 19 bound paths were therefore reported
missing and the script exited 1 under `set -e`.  It did not reach the
read-only assertion, exact pre-child endpoint, collector, supervisor, GO,
child 1, harness, search, or any calibration clock.

The frozen rule stops without retry on any failure.  Accordingly the driver
was not repaired or rerun and children 1--20 never started.  There are no
A/B/C/D observations, medians, ranges, ratios, parity results, clock-read
comparisons, or attribution.  The only honest classification is
mixed/indeterminate for lack of calibration evidence; no optimization or
target is authorized.

The exact failed collection residue is under `failed-collection/`.  The tool
exit was 1.  The exact command was:

```
ROOT=/home/lukasz/dev/HOL/worktrees/isabelle-tactics \
PACKAGE_DIR=/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final \
SCRATCH_ROOT=/tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh \
ARTIFACT_REFERENCE=/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final/ARTIFACT-REFERENCE.tsv \
.agent-files/benchmarks/m2-v10-small-calibration-retry-final/collect.sh
```

Exact `/proc` final audits before and after generated-artifact cleanup are
both `matches=none` with retained status 0.  All live executable, UI/UO,
lock, and make-dependency paths were removed; immutable copies remain only
under `frozen-inputs/` and the pre-seal histories.
