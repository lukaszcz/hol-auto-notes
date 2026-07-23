# Pre-seal environment-provenance repair

The first preparation invocation completed the full clean classical and blast
builds, both level-2 selftests, all three harness builds, the wrapper/HOL-child
endpoint tests, and all positive and 34 adversarial validator tests with
status zero. It then hung before `SEAL_PLAN.md`, `INPUTS.sha256`,
`INPUT-MANIFEST.tsv`, or `ARTIFACTS-FROZEN.tsv` existed. No timing clock had
started.

The failing provenance pipeline was `poly --version 2>&1 | sed -n '1p'`.
Poly/ML printed no version because it continued as an interactive process
with the inherited terminal. The outer preparation command was manually
interrupted and returned exact status 1 with terminal output `^C`. The child
pipeline did not return a separately observable status, so none is claimed.
The partial `environment.txt` ends exactly at `poly=`.

`pre-seal-attempt-0/` retains all then-current input bodies, all completed
preflight logs and statuses, validator statuses/logs, endpoint logs, the
partial environment body, exact outer command/status chronology, and the
terminal output. The only executable repair redirects `poly --version` from
`/dev/null`, which was separately diagnosed to print `Poly/ML 5.9.2 Release`
and exit zero. It also records environment capture through the standard
preflight status helper and clears only the mandated scratch subdirectories
before a fresh preparation. This disclosure is added to the sealed inputs.
The complete repair diff and complete after-body are retained alongside the
before-body. No harness, schedule, workload, clock, boundary, validator,
threshold, runtime-closure rule, tracked source, or already-collected timing
was changed.
