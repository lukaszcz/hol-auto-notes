# Frozen path-selection result

Decision: **fallback Z/N exact-count standalone microcalibration**.

The retained no-benchmark probe resolved `/usr/bin/perf`, reported `perf
version 6.17.13`, and captured the frozen 9 Hz DWARF configuration.  Its
actual harmless `/bin/sleep 2` recording failed because the host has
`perf_event_paranoid=4` and denies performance-monitoring access.  Therefore
there was no readable data file, sample count, symbol/DSO resolution result,
or basis for the v10 wrapper-compatibility probe.  The preferred-path gate
requires every criterion, so failure selected the fallback before diagnostic
clocks.  No sampled P38 benchmark is permitted or run in this package.

The capability probe is environment evidence only, not benchmark evidence.
Its exact command, cwd, path, version, kernel settings, configuration,
stdout/stderr, component statuses and overall status are retained under
`capability-probe/`.
