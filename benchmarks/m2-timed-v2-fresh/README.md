> **HISTORICAL / VOID:** Every later claim of authority in this file is void.
> This package is non-authoritative; use `../m2-timed-v2-final/`.

# Task 7g fresh authoritative timed-v2 evidence

This is the authoritative fresh Task 7g chain for revision
`b1c8700d2125cc2662bcb9ee348fe54143f3bee4`. It changes no tracked source,
implements no optimization, imports no earlier observation and had no timing
retry. The prior `../m2-timed-v2/` package is preserved only as
reviewed-pre-final history because its missing original repair bodies and
incomplete runnable provenance cannot be retroactively proved.

Before timing, complete input bodies were copied under `frozen-inputs/` and
sealed by `INPUTS.sha256`; `INPUT-MANIFEST.tsv` records hashes, sizes and
nanosecond mtimes. `ARTIFACTS-FROZEN.tsv` records the exact source, real
`.hol/objs` UI/UO, harness executable, HOL image and tool identities.
Preflight forced both affected builds, passed classical and blast level-2
selftests, built all harnesses, and passed synthetic positives plus 32
independent adversaries. The initial pre-freeze artifact-path failure and its
complete bodies/diff/status chronology are retained under
`pre-freeze-attempt-0/`; it occurred before the seal and before any clock.

The unchanged locked schedule then ran exactly once. All 12 representative,
10 active and three target harnesses exited 0; all three independent 60-second
watchdogs exited 0. There were no retries. Immediate pre/post endpoint
snapshots are clean for every segment and their separate artifact manifests
match the frozen identity. `collection-status.tsv` retains every exact command
and status.

## Fresh results

- P38@4 timed-v2 median [range] was 1.632407
  [1.625381--1.660721] versus v1 1.640508
  [1.635822--1.663227] seconds, -0.49%.
- P43@5 was 12.622675 [12.596808--12.624016] versus 12.590901
  [12.461458--12.592334] seconds, +0.25%.
- The active 1,000-replay fixture was .060769 [.037442--.061355] versus
  .037618 [.037333--.037918] seconds, +61.54%.

Every paired outcome, work counter and ordered reconstruction signature is
identical. Calibration quantifies perturbation only and does not adjust target
times.

| Problem | Process / attempts / residual s | Classical / Alternative / Replay / Other s | Minor calls/failures; normalization / traversal / cleanup s | Max traversal / max minor s |
|---|---:|---:|---:|---:|
| P34@7 | 30.033281 / 29.557630 / .475651 | 16.557207 / 12.185943 / .001409 / .813071 | 927/0; .003613 / 13.530240 / 0 | .083844 / .083929 |
| P41@6 | 30.002220 / 28.886708 / 1.115512 | 20.541524 / 7.079393 / .042280 / 1.223511 | 78,685/2; .102817 / 10.106333 / 0 | .006703 / .006707 |
| P45@11 | 30.044913 / 29.579849 / .465064 | 16.802537 / 12.459903 / .001775 / .315634 | 1,250/0; .005432 / 12.189651 / 0 | .064524 / .064563 |

AlternativeEnumeration is the largest exclusive outer category on every
target and is 41.23%, 24.51% and 42.12% of attempt time. It crosses the
predeclared outer threshold on P34/P45. Traversal/decomposition/binding is
99.97%, 98.99% and 99.96% of minor time and 45.78%, 34.99% and 41.21% of
attempt time. Its maxima are only .620%, .066% and .529% of category totals,
so the fresh evidence identifies accumulated volume rather than a few
expensive calls. Cleanup is exactly zero.

The verdict remains diagnostic, not an optimization choice: split general
minor traversal into store lookup, structural decomposition, pattern/occurs
checks and persistent binding, and add a per-pull maximum or bounded histogram
for AlternativeEnumeration. No particular optimization or capability fix is
justified yet.

## Validation and audit map

- `calibration-validation.log`, `target-validation.log` and
  `summary-validation.log` are PASS.
- `preflight-validator-logs/` contains positive logs and the sole diagnostic
  for every adversary; no failing log contains PASS.
- `preflight-status.tsv` and `collection-status.tsv` give explicit statuses
  for identity, build, selftest, validation, every fresh process and watchdog.
- `validator-status.tsv` gives the exact status for both synthetic positives
  and each of the 32 independent adversarial validator commands.
- `provenance/` contains immediate endpoint snapshots and distinct pre/post
  artifact identities; its later final snapshot is supplemental.
- `checksums.sha256` covers every current package file except itself and
  `SEAL_PLAN.md`, as declared before collection.
