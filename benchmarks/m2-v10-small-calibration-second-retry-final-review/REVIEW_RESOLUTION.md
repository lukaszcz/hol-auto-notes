# External review resolution for the authoritative Task 7m calibration

## Authority and preservation boundary

This directory is an external postcollection review resolution for
`../m2-v10-small-calibration-second-retry-final/`.  It is adjacent to, and
not inside, that authoritative package.  It was created after collection and
final package closure.  It is not part of `GO-SEAL.txt`, is not a new or
replacement seal, and does not rewrite any byte or path in the authoritative
package.  Its checksums establish closure of this external resolution only.

`AUTHORITATIVE-PACKAGE-MANIFEST-BEFORE.tsv` was captured before this
resolution directory was created.  The after-manifest is captured only after
the resolution and plan update are complete.  Both are deterministic,
symlink-aware typed inventories of the authoritative package.  Their required
byte identity proves that no package byte, path, type, or symlink target
changed during review resolution.  `REVIEWED-PACKAGES.tsv` and
`REFERENCES.sha256` bind the exact Task 7m package references and the
preserved Task 7k and Task 7l packages and controlling external reviews.

This resolution records the sole low review finding.  The reviewed Task 7m
package otherwise remains authoritative for its limited
`mixed/indeterminate` calibration result.

## Cleanup-diagnostic chronology erratum

The final `final-cleanliness/live-artifacts/` command was one compound
`sh -c` command:

```sh
P="$1"; test ! -e "$P/task7mcalibration.exe"; test ! -e "$P/.hol";
! pgrep -af "[/]task7mcalibration[.]exe|task7mcalibration$"
```

That shell did not enable `set -e`.  The compound command ended with
`! pgrep`, so its retained status 1 is the status of that final negated
pipeline.  It does not establish the status of either preceding path test.

The retained stdout shows that `pgrep` matched the enclosing bwrap, zsh,
`record-command.py`, and inner `sh` command payloads.  Although the regex
shields its own executable spelling with `[/]`, those enclosing payloads
already contained the earlier literal `/task7mcalibration.exe` from the
first path test.  The regex therefore self-matched the audit machinery.
Attributing status 1 to the `.hol` predicate, as `FINAL-CLEANLINESS.md` did,
was wrong.  The compound status cannot distinguish or recover either path
test result.

## Why cleanup authority remains

No evidence was recollected and no benchmark child was rerun.  Cleanup
authority comes from three independent retained/current facts:

1. `postcollection-finalization/live-cleanup/` records status 0 for
   `cleanup-live.sh`.  That script uses `set -eu`, removes the declared live
   executable, UI/UO, lock, make-dependency, and log artifacts, and then
   independently tests every declared executable/UI/UO/lock/dependency path
   absent before printing `PASS`.
2. `final-cleanliness/exact-endpoint/` records status 0 and
   `final-cleanliness/exact-endpoint.txt` says `matches=none`.  Its auditor
   compares exact `/proc` argv elements against the absolute Task 7m
   executable and module identities; it does not use a regex process match.
3. The final authoritative typed inventory and current direct inspection
   contain neither the top-level `task7mcalibration.exe` nor the top-level
   `.hol` directory.  Thus the live executable and live `.hol` tree are
   absent despite the defective later compound diagnostic.

These facts preserve the package's cleanup conclusion.  They do not make the
failed compound diagnostic successful and do not infer its earlier path-test
statuses.

## Required future cleanup evidence

Future cleanup verification must retain each path predicate as an independent
status-bearing test, followed by a separate status-bearing exact-argv
endpoint audit.  Process cleanup checks must not use regex `pgrep`.  A
compound shell status must never be used to infer unretained statuses of
earlier commands.

## Limited calibration conclusion

Task 7m completed 20 fresh P38@4 children: five per mode, with no retry.  The
external medians were A `9.189388257`, B `9.237345589`, C `11.027194246`,
and D `16.328066360` seconds.  The exact derived ratios were B/A `1.005219`,
C/A `1.199992`, D/C `1.480709`, and clock share `0.742557`; increments were
D-A `7.138678103`, C-A `1.837805989`, and D-C `5.300872114` seconds.

All rows had outcome `none`, 22 attempts, counters
`2507169,624,140,210,233,4,322,5446`, and identical ordered 37-field
signatures.  Each C/D row had 61,486,260 clock reads, 22 terminal-summary
reads, and zero trace allocations and sequence-statistics reads.  B/A passed
its inclusive `[0.95,1.05]` sanity gate.  Clock-dominant required clock share
at least `.80` and D/C at least `1.50`; aggregation-material required C/A at
least `1.25`.  Neither predicate held, so the predeclared result is
`mixed/indeterminate`.

This calibration had no target.  It provides no target profile, projected
speedup, optimization selection, capability attribution, or M2 closure.

## Next diagnostic boundary

The next M2 diagnostic is target-free, low-frequency external statistical
sampling of mode A, interleaved with unsampled equal-work controls.  It must
retain counter/signature equality gates and a predeclared perturbation gate.
It must add no per-event internal clocks.  Only if available symbols are
inadequate may the work proceed to an exact-count standalone clock
microcalibration.  No optimization is selected by this resolution.
