# M2 v10 small ablation calibration retry: frozen declaration

This wholly fresh package measures only source revision
`244b01d7189ac803df48e246a483c33b553e3daa`, imports no timing row, and
modifies no tracked source.  It is separate from both sealed Task 7k
packages.

The sole workload is Pelletier P38 at depth 4.  Modes are A ordinary detailed
measured reconstruction, B timed-v2 with `Time.now`, C timed-v4 with a
counting constant clock, and D timed-v4 with a counting `Time.now` clock.
The exact balanced 20-row schedule has five fresh sequential processes per
mode, a 25-second watchdog, and no retry.  Any nonzero status, timeout,
malformed row, artifact drift, endpoint match, seal drift, parity failure, or
other protocol failure stops collection without retry.

All rows must match exactly in outcome, attempt count, eight search counters,
and every ordered 37-field reconstruction signature.  C/D clock reads must
be equal and positive within each repetition and globally.  Each v4 attempt
must retain zero trace allocations, perform zero sequence-statistics reads,
and perform exactly one terminal summary-statistics read; row totals are
therefore zero, zero, and attempt-count respectively.  A/B v4 fields are NA.

For five external supervisor intervals, `T_A` through `T_D` are the third
sorted values; full minimum--maximum ranges are also reported.  `T_B/T_A`
must be in inclusive `[0.95,1.05]` for the independent sanity gate.  Fixed
ablation formulas are `D-A`, `C-A`, `D-C`, and clock share
`(D-C)/(D-A)` only for a positive denominator.  Clock-dominant requires
share at least `.80` and `D/C` at least `1.50`.  Aggregation-material
requires `C/A` at least `1.25`.  Both may hold; otherwise, including a
nonpositive denominator or failed B/A sanity, the result is
mixed/indeterminate.  No target, correction, optimization, or capability
claim is authorized.

The exact command vector for smoke and calibration is the absolute generated
`task7lcalibration.exe` path.  The reviewed v10 collector fixes supervised
cwd to repository root.  The generated launcher is mechanically rewritten at
build time to load the module by its frozen absolute package path.  The same
executable's `load-only` branch is selected before goal, claset, search, or
clock construction and prints only `LOAD_OK`.  Smoke is protocol evidence,
not calibration evidence.

The runtime auditor excludes exactly `ARTIFACT-REFERENCE.tsv` and
`GO-SEAL.txt` to avoid self-reference.  Collection lives only below the
mandated host scratch root until after collection.  Live executable, UI/UO,
lock, and make-dependency files exist during smoke and collection, are bound
by the artifact reference, and have byte copies under `frozen-inputs/`.
After collection or failure, all those live generated files and live
`.hol/locks`/`.hol/make-deps` metadata are removed.  “Live residue” means a
generated artifact at its build/runtime path, not the declared immutable
copy under `frozen-inputs/` and not retained scratch transaction evidence.
