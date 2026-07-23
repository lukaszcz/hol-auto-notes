# Task 7n target-free low-perturbation diagnostic: frozen protocol

This package diagnoses only the instrumentation cost left open by Task 7m at
source revision `244b01d7189ac803df48e246a483c33b553e3daa`.  It changes no
tracked source, targets no P34/P41/P45 workload, selects no optimization, and
imports no new benchmark row from another package.

## Frozen path selection

The preferred path is low-frequency external statistical sampling of ordinary
mode A on P38@4, interleaved with unsampled ordinary equal-work controls.  The
only candidate host sampler is the exact `perf` path resolved by
`capability-probe.sh`.  Its frozen configuration is `perf record -F 9 -g
--call-graph dwarf`, with five sampled and five control fresh processes in
balanced order `C,S,S,C,C,S,S,C,C,S`.  Sampling frequency is 9 Hz.  A sampled
run is usable only if all ten rows have identical outcome, attempt count,
eight search counters and ordered 37-field reconstruction signature; the
median sampled/control external elapsed ratio lies in inclusive `[0.95,1.05]`;
each sampled child completes with a readable perf data file; each has at least
20 samples; at least 90% of samples have both a non-unknown symbol and a
non-unknown DSO; and the frozen categories below cover at least 90% of usable
samples.  The category map, fixed before any sampled result, is:

- HOL4 automation: symbols/DSOs attributable to the generated harness or
  `blastSearch`, `blastReconstruct`, `blastRule`, `blastTerm`, `clasetStep`,
  `clasetRules`, `clasetLib`, or `tableauLib`;
- Poly/ML runtime and garbage collection: Poly/ML/runtime/GC symbols or DSOs;
- kernel and system libraries: kernel, libc, libpthread, libm, loader, system
  calls, or other named host libraries;
- unresolved/other: everything else, including unknown symbols or DSOs.

The sampler is permitted only if the retained no-benchmark capability probe
has status zero for exact path/version/config capture, an actual 9 Hz DWARF
recording, readable report generation, at least 10 samples, at least 90%
symbol+DSO resolution, and a v10-compatible wrapper assessment.  The latter
requires that the sampler can be the supervised launch-vector program around
a harmless nonbenchmark child without escaping the reviewed v10 namespace,
process-group cleanup, exact endpoint, or artifact-audit model.  Failure of
any capability or symbol criterion selects the fallback before diagnostic
clocks.  In that event no sampled P38 benchmark is run.

There is no retry, replacement, warm-up deletion, outlier deletion, or
censoring on either path.  Any post-GO nonzero status, timeout, malformed
record, seal/artifact/endpoint drift, parity failure, or protocol failure
stops the schedule without replacement.  Profiles are interpreted only after
both work parity and perturbation gates pass.

## Frozen fallback

If the preferred path is unavailable, the sole diagnostic is a standalone
exact-count clock microcalibration, not a production optimization.  A fresh
HOL process executes exactly `61,486,260` loop iterations in each mode.  Both
modes use the same recursive loop, mutable call counter, closure invocation,
returned-value consumption, output schema, and v10 collection machinery.
Mode Z calls a counting closure returning `Time.zeroTime`; mode N calls a
counting closure returning `Time.now ()`.  The balanced ten-process order is
`Z,N,N,Z,Z,N,N,Z,Z,N`, five fresh processes per mode.  The exact-count and
mode-count gates must pass for every row and globally.

For each mode, report the median external v10 supervisor elapsed interval and
full observed range.  Report net `median(N)-median(Z)` and the ratio of that
net to authoritative Task 7m `D-C = 5.300872114` seconds.  Explanatory
consistency is the frozen inclusive ratio band `[0.80,1.20]`; a nonpositive
net is inconsistent.  This comparison is descriptive only.  It includes
fresh-process startup, the standalone loop, closure dispatch, counter update,
Time-value consumption, runtime/GC and v10 wrapper overhead, while Task 7m's
clock reads occurred inside real reconstruction with different allocation,
cache, locality and control-flow context.  It cannot identify a production
source change or project a target speedup.

## Protocol and evidence boundary

The reviewed Task 7m v10 collector/supervisor closure is vendored byte for
byte.  Before GO the package must pass: source/HEAD/index checks; predecessor
and external-review closure checks; actual generated-launcher load-only smoke;
protocol selftests; harness build; positive schema/order/cross-ledger/raw-seal
checks; independent adversaries; provisional artifact reference and input
manifest; scoped cwd-independent seal; recursive read-only audit; and exact
no-child dry-runs from repository root and an unrelated cwd.  The reference,
manifest and seal are regenerated after dry-runs, the package is recursively
sealed again, and status-bearing final seal/read-only/exact-endpoint evidence
is retained immediately before GO.

The actual driver retains exact cwd/argv/environment, stdout, stderr, numeric
status and an unconditional final exact endpoint.  Each child retains v10
supervisor JSON, raw stdout/stderr/status and durability seal, artifact audit,
final exact endpoint and status.  Cleanup retains independent status-bearing
tests for every live path and a separate status-bearing exact-argv endpoint;
regex `pgrep` is forbidden.  Every pre-seal failure is preserved completely.
Final inventory is typed and symlink-aware; checksums cover every regular file
except checksum self.  All host scratch/status state is confined below
`/tmp/isabelle-tactics-task7f-20260720-root/task7n_low_perturbation_diagnostic_fresh/`.

