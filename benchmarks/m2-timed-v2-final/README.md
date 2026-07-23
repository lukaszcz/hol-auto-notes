# Task 7g final authoritative timed-v2 evidence

This is the sole authoritative Task 7g evidence chain for revision
`b1c8700d2125cc2662bcb9ee348fe54143f3bee4`. The two preceding packages are
historical and void; their observations are not imported or selected here.
This package changes no tracked source and contains no optimization.

The final preflight force-built classical, blast, and all three harnesses;
both level-2 selftests passed. Synthetic positive validation and 34 independent
adversaries passed, including wrong and noncanonical-equivalent problem/depth
literals and summary drift. Endpoint tests proved that each pattern without
`.exe` detects both wrapper-style and `bin/hol ... task7g...` child processes
without matching the audit process.

`ARTIFACTS-FROZEN.tsv` has 413 data rows plus its header in deterministic
sectional order: 398 repository paths are C-sorted first, followed by 15 tool
records in deterministic declared order. It is not globally path-sorted. It
freezes every regular file below `src/auto`, all harness sources/Holmakefile/
UI/UO/executables, `bin/hol`, `bin/Holmake`, `bin/hol.state0`, configure
identities, and relevant tools. All representative, active, and target
pre/post manifests are byte-identical to it. The exact heap hash closes
preloaded dependencies; all automation modules loaded after that heap are
independently present. `FINAL_AUDIT_ERRATA.md` is the authoritative
post-collection correction to the frozen predeclaration's false phrase
"sorted by path"; it changes no membership, identity, or comparison.

## Results

The locked collector ran the unchanged 12 representative processes, ten
active processes, and one P34@7/P41@6/P45@11 target block with exact 1/3/1
attempts. Every process and 60-second watchdog exited zero. All immediate
endpoint audits were clean. There was no retry, selection, or tuning.

Representative timed-v2 versus timed-v1 medians [full ranges] are P38@4
1.649530 [1.642255--1.660204] versus 1.633429
[1.632719--1.667271] seconds (+0.99%), and P43@5 12.578063
[12.281841--12.629820] versus 12.568258
[12.458797--12.569931] seconds (+0.08%). The active 1,000-replay fixture is
.060740 [.037328--.061652] versus .037840 [.033335--.038100] seconds
(+60.52%). Paired work, outcomes, counters, and signatures match. These
figures quantify perturbation only and do not adjust target observations.

| Problem | Process / attempts / residual s | Classical / Alternative / Replay / Other s | Minor calls/failures; normalization / traversal / cleanup s | Max traversal / max minor s |
|---|---:|---:|---:|---:|
| P34@7 | 30.027199 / 29.538150 / .489049 | 16.586384 / 12.125281 / .001409 / .825076 | 923/0; .003528 / 13.570925 / 0 | .082677 / .082759 |
| P41@6 | 30.002148 / 28.877672 / 1.124476 | 20.534149 / 7.080400 / .041838 / 1.221285 | 78,639/2; .103063 / 10.101888 / 0 | .006659 / .006662 |
| P45@11 | 30.024981 / 29.559788 / .465193 | 16.786278 / 12.458241 / .001740 / .313529 | 1,250/0; .005168 / 12.177085 / 0 | .064477 / .064515 |

AlternativeEnumeration is the largest exclusive outer category and is
41.05%, 24.52%, and 42.15% of attempt time. It crosses the predeclared
40%-on-two-targets rule on P34/P45. Traversal/decomposition/binding is 99.97%,
98.99%, and 99.96% of minor time and 45.94%, 34.98%, and 41.19% of attempt
time, crossing the predeclared minor rule on all three. Its maxima are only
.609%, .066%, and .529% of category totals, below the predeclared 5% ceiling,
so the category is descriptively volume-driven. Cleanup is exactly zero.

These are still broad buckets. Per the frozen rule, the result selects only a
deeper diagnostic split: split minor traversal among store lookup, structural
decomposition, pattern/occurs checks, and persistent binding; add a per-pull
maximum or bounded histogram for AlternativeEnumeration. It does not select a
specific optimization or capability fix.

## Audit map

- `PREDECLARATION.md`, `SEAL_PLAN.md`, `INPUTS.sha256`, `frozen-inputs/`:
  pre-clock hypotheses, thresholds, schedules, and complete bodies.
- `PRE_SEAL_REPAIR.md`, `pre-seal-attempt-0/`: complete chronology, bodies,
  statuses, and diffs for the sole pre-seal protocol failure and repair.
- `ARTIFACTS-FROZEN.tsv`, `provenance/`, `environment.txt`: complete runtime
  closure and all six immediate byte-identical manifest endpoints.
- `preflight-status.tsv`, `validator-status.tsv`,
  `preflight-validator-logs/`, `endpoint-preflight/`: builds, selftests,
  exact positive/negative validator outcomes, and process-pattern evidence.
- `calibration-raw.tsv`, `active-calibration-raw.tsv`, `raw.tsv`, summaries,
  validation logs, `collection-status.tsv`, and `process-logs/`: exact one-shot
  collection evidence.
- `HISTORICAL_BANNER_HASHES.tsv`: hashes for every old document changed only
  by a historical/void banner.
- `FINAL_AUDIT_ERRATA.md`, `final-audit.sh`: authoritative correction,
  chronology, and mechanical proof of the two closure-manifest sections and
  all six frozen/pre/post comparisons.
- `PACKAGE-INVENTORY.tsv`, `package-inventory.sh`,
  `verify-package-integrity.sh`: regular-file hashes and exact symlink-target
  inventory. The inventory omits itself and `checksums.sha256` to avoid the
  mutual hash cycle; `checksums.sha256` hashes every regular file except
  itself and includes the inventory. Together they cover all regular files
  except checksum self, plus every symlink target.
- `validate-scratch-path.sh`, `test-package-integrity.sh`: canonical scratch
  containment checks and disposable regressions for direct, nested, relative,
  equality, prefix-sibling, parent-reference, repeated-trailing-slash, and
  symlink-component paths (including trailing-slash scratch and root
  symlinks); proof that ordinary selfcheck is read-only; and rejection of a
  changed package symlink target. Inventory and integrity regressions also
  prove identical results for canonical, trailing-slash, and safe relative
  package directory spellings.

The selfcheck requires a caller-provided existing scratch root and a separate
scratch directory that is a strict canonical descendant. It rejects root
equality, prefix siblings, `..`, an existing scratch symlink, and any symlinked
intermediate component before its validated canonical descendant can be an
`rm -rf` target. Trailing slashes are removed lexically before that component
inspection, so they cannot hide an exact symlink entry. It makes no assumption
about the reviewer's chosen root and changes no package file. It records all
regular-file bytes and exact symlink targets before and after all checks and
requires byte identity. The current selfcheck is an explicitly documented
post-collection override; its frozen original and immutable `INPUTS.sha256`
remain unchanged.

    scratch_root=/tmp/my-existing-review-root
    scratch=$scratch_root/manual-selfcheck
    .agent-files/benchmarks/m2-timed-v2-final/selfcheck.sh \
      "$scratch_root" "$scratch"
