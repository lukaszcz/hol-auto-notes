# Pre-terminal-boundary-fix history

Everything in this directory is historical and non-authoritative for the
post-boundary timing result.  Nothing here is selected or reused by the
current validation or measurement chain.

The directory contains the complete pre-boundary `regenerated-final-*`
target, calibration, expectation, audit, checksum and environment evidence
that was current immediately before Task 7f moved the terminal clock read
ahead of diagnostic report aggregation.  It also contains the corresponding
pre-boundary repaired-final build/selftest logs and these records:

- `REPAIRED_FINAL_PREDECLARATION.md`: the superseded run declaration.
- `REPAIRED_BUILD_PROVENANCE.md`: the superseded source/build hashes.
- `TEMPORARY_HOLMAKE_RULES.txt`: the exact historical rules and invocations.
- `REGENERATED_FINAL_LOCKED_SUMMARY.md`: the superseded measured summary.
- `repaired-final-active-calibration-raw.tsv`: the abandoned pre-final ledger.
- `repaired-final-{build,rebuild,classical-build}.log` and
  `repaired-final-{blast,classical}-selftest.log`: historical build/test logs.

The historical checksum manifest and audit intentionally preserve their
then-current root-relative paths and are themselves archived evidence, not a
manifest of the package's current layout.  The current root manifests include
every artifact above by its `pre-boundary-fix-history/` path.

The complete original bodies and data are preserved.  The five narrative
records named above received the archival notices now visible at their heads,
so their present hashes intentionally differ from the pre-archive hashes in
`regenerated-final-checksums.sha256`.  A direct SHA-256 comparison against
that old manifest verifies byte identity only for these archived data/log
files: `regenerated-final-active-calibration-raw.tsv`,
`regenerated-final-attempts.tsv`, `regenerated-final-audits.log`,
`regenerated-final-calibration-raw.tsv`, `regenerated-final-environment.txt`,
`regenerated-final-expectations.tsv`, `regenerated-final-process-audit.txt`,
`regenerated-final-raw.tsv`, `repaired-final-active-calibration-raw.tsv`,
`repaired-final-blast-selftest.log`, `repaired-final-build.log`,
`repaired-final-classical-build.log`,
`repaired-final-classical-selftest.log`, and `repaired-final-rebuild.log`.
