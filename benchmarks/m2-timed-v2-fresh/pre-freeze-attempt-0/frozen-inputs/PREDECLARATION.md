> **HISTORICAL / VOID:** Every later claim of authority in this file is void.
> This package is non-authoritative; use `../../../m2-timed-v2-final/`.

# Task 7g fresh authoritative timed-v2 predeclaration

This is a wholly fresh evidence chain. The earlier package at
`benchmarks/m2-timed-v2/` is retained as reviewed-pre-final history only. Its
missing original pre-repair bodies and incomplete post-collection provenance
make it non-authoritative and unverifiable for the reviewed claims; no old
numeric row is imported or selected here.

Before any fresh timing, `prepare-and-freeze.sh` force-builds the affected
classical/blast objects and the three harnesses, runs both level-2 selftests,
runs the validators against generated synthetic positive fixtures and 32
independent adversaries, then copies the complete byte bodies of this
predeclaration, all three harnesses, Holmakefile, schedules, collector,
runner, validators, fixture generator/mutator, summarizers, summary checker,
selfcheck, and preparation script into `frozen-inputs/`. `INPUTS.sha256`
seals every live input and frozen body; `INPUT-MANIFEST.tsv` records SHA-256,
byte size and nanosecond mtime for those inputs plus every source, UI, UO,
executable and named tool used by collection.

Collection may begin only if all frozen live-input hashes and all artifact
identities still match. Immediately before each representative, active and
target segment, the collector records hash, size and mtime for the exact
source/UI/UO/executable/tool set, compares it with the frozen artifact
identity, and fails before starting a clock on mismatch. Separate immediate
postsegment manifests are retained. The same atomic directory lock brackets
all three segments; each has non-self-matching pre/post process snapshots
immediately adjacent to its processes. Later checks are supplemental only.

The schedules are unchanged: 12 representative fresh processes for P38@4
and P43@5 in the frozen v1/v2 order; ten active fresh processes replaying the
stored-elimination fixture 1,000 times; then exactly one sequential target
block P34@7, P41@6, P45@11 with a shared 30-second cooperative deadline and
independent 60-second GNU timeout watchdog. Expected target attempts are
1/3/1 with Interrupted; Completed, Completed, Interrupted; Interrupted,
respectively, all with NONE. There is no rerun of valid data and no selection.

A retry is allowed only for watchdog 124, nonzero harness status,
malformed/truncated output, endpoint contamination, or validator failure
proved to be environmental/I/O rather than a valid observed result. Any retry
must preserve the failed block, exact command/statuses, before/after bodies
and diff chronologically, and rerun the complete target block once. No other
retry is permitted. Any repair after this seal must preserve full before and
after bodies, exact diff/status chronology, and requires resealing before any
new clock; fresh valid observations already collected remain immutable.

Calibration validation fixes the exact headers and field counts, nine-digit
decimal grammar, canonical literals, exact schedule projection and row order,
8-wide search counters, 37-wide ordered reconstruction signatures, 9-wide
active signatures, exact row counts and paired outcomes/work/signatures.
Summaries are generated and byte-compared mechanically. Target validation
fixes canonical position/problem/depth/attempt literals and exhaustive legal
outer boundary/phase, stored step kind, duplicate flag, stored boundary/phase,
rule kind and optional-context vocabularies and their counter/semantic
relationships, plus every timing partition, maximum, observer, summary,
poll/checkpoint and status identity. A first validator failure suppresses END
checks and PASS; every retained adversary must emit exactly its intended sole
diagnostic and no PASS.

Every build, level-2 selftest, validator and summary check has an explicit
status row. Every 12 representative and 10 active harness process has its own
status row. Each target has separate harness-process and watchdog status rows.
Exact runnable commands are retained in `command-status.tsv` and the runner
body is frozen. All scratch/log/output is physically below
`/tmp/isabelle-tactics-task7f-20260720-root/task7g-measure-fix/`; neither loose
`/tmp`, host `/var/tmp`, nor unrelated `/tmp/Holmakefile` is touched.
