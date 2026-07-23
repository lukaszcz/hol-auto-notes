# Task 7n final report

Status: **complete target-free fallback; standalone clock cost is consistent
with authoritative Task 7m D-C under the frozen rule**.

The preferred external-sampling path was not usable.  The retained harmless
capability probe resolved `/usr/bin/perf`, reported `perf version 6.17.13`,
and attempted the predeclared 9 Hz DWARF recording.  Host
`perf_event_paranoid=4` denied monitoring, so there was no sample file, sample
count, symbol/DSO attribution, category result or v10 wrapper probe.  The
fallback was selected before diagnostic clocks, and no sampled P38 benchmark
ran.

The one frozen balanced fallback schedule completed ten fresh v10-contained
HOL children, five per mode, with no retry.  Every row made and observed
exactly `61,486,260` closure calls.  All supervisor/collector/final statuses
are zero, containment is cleared, and exact schema/order/global count,
cross-ledger, raw-seal, artifact-reference and exact-endpoint gates pass.

| Mode | Median external s | Full observed range s |
|---|---:|---:|
| Z, counting constant clock | 0.511189289 | 0.509745717--0.511828761 |
| N, counting `Time.now` | 6.090917808 | 6.082526315--6.103101928 |

The external median net `N-Z` is `5.579728519` seconds.  Relative to the
authoritative Task 7m `D-C = 5.300872114`, the ratio is `1.052606`, inside the
frozen inclusive explanatory-consistency band `[0.80,1.20]`.  Thus standalone
clock cost is consistent with the Task 7m increment under this limited test.

This is not a production profile.  The standalone figures include process
startup, the tight loop, closure dispatch, counter mutation, Time-value sink,
runtime/GC and v10 wrapping.  Task 7m performed clock reads inside real
reconstruction with different allocation, cache, locality and control-flow
context.  No time category within production search/reconstruction is
identified, no target profile or projected speedup is supported, and no
source optimization or capability conclusion is selected.  M2 remains open
for later evidence.

