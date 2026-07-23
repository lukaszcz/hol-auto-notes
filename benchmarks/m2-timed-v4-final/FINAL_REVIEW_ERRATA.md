# Final review erratum and chronology

This file supersedes every claim in this package that calls the package or
its collection authoritative fresh evidence. It changes no historical raw
byte and authorizes no retroactive reconstruction of provenance.

## Classification

The package is a retained **failed-protocol/calibration observation**. It is
not an authoritative fresh evidence chain. No target was collected: the
active control and P34@7/P41@6/P45@11 schedule never started.

## Exact chronology and provenance limit

1. The input seal and the frozen bodies predate the attempted collection.
2. The frozen `collect.sh` launched the fourth representative under
   `set -e`. The frozen supervisor returned 125 because its immediate
   process-group probe was false after the leader had been reaped.
3. That nonzero return aborted `collect.sh` inside `run_child`. The collector
   did not reach its later `cp -R "$work" "$dir/collection"`, did not execute
   the later segment endpoint/finalization steps, and had no unconditional
   finalizer.
4. Commands used later to materialize the scratch work as `collection/` were
   not retained. There was no immediate seal of the raw scratch bytes.
5. The outer collector shell status was not retained. In the frozen code,
   supervisor 125 is assigned to `rc`; then `run_child` ends with the false
   test `[ "$rc" -eq 0 ]`. Under `set -e`, that failed function call aborts the
   collector with shell status 1. Thus the code-defined outer status would be
   1, not supervisor 125, but no contemporaneous outer-status artifact exists
   and neither value may be relabelled as the other.
6. The later process audit found PGID 2498 absent and no endpoint match. That
   later fact neither repairs the missing immediate finalization nor changes
   the earlier `group_gone=false` supervisor record.

The preserved collection bodies are useful for calibration and protocol
diagnosis, but their post hoc materialization and missing immediate raw seal
prevent them from serving as authoritative fresh evidence.

## Correct timing statements

P38@4 emitted comparable internal harness rows on equal observed work:
`1.652517000` seconds for v2 and `8.652819000` seconds for v4, a ratio of
`5.236145` (approximately **5.236**, not 5.235).

P43@5 emitted only a v2 internal harness row (`12.645914000` seconds). No v4
harness row exists, so **no comparable P43 internal-time ratio exists**. In
particular, the historical `>=3.558462` value divides an external watchdog
boundary by an internal harness time and is withdrawn.

A separately labelled external-process lower bound can be computed using
like domains: the v4 external watchdog boundary was at least 45 seconds and
the completed v2 supervisor elapsed time was `20.341200346` seconds. Thus the
external-process ratio is `>= 45 / 20.341200346 = >= 2.212259`. This is a
censored process-duration lower bound, not an internal instrumentation ratio
and not a completion time.

## Version mapping

- Historical collector/supervisor: live `collect.sh` and `supervise.py`, with
  sealed copies under `frozen-inputs/`; unchanged.
- Historical inadequate proposal: `SUPERVISOR_REVIEW.patch`; unchanged and
  explicitly superseded.
- Superseded future repair history: unchanged
  `future-protocol/supervise-v2.py` and `collect-v2.sh`, with their unchanged
  v2 tests and patches.
- Current future supervisor: `future-protocol/supervise-v3.py`, tested by
  `future-protocol/test-supervise-v3.sh`.
- Current future collector/finalizer and relocation-safe artifact auditor:
  `future-protocol/collect-v3.sh` and `audit-artifacts-v3.py`, tested by
  `future-protocol/test-collector-v3.sh`.
- Historical bounded validator: `verify-bounded.awk`; unchanged.
- Future bounded validator: `future-protocol/verify-bounded-v2.py`, tested by
  `future-protocol/test-bounded-v2.sh`.

Exact old-to-repaired full diffs are retained as
`future-protocol/{SUPERVISOR_V2,COLLECTOR_V2,BOUNDED_V2}.full.patch`.

These future files are infrastructure for a later fresh calibration. They
were not used to generate any observation retained here.

## Second rereview: future protocol v3

The v2 supervisor's original-PGID-only containment and its leader-zero
false-success lifecycle rule are superseded, not rewritten. V3 implements
only recursive ownership observable to its dedicated Linux subreaper:
`/proc` lineage plus direct adoption, pidfd identity/signalling, the original
PGID, complete owned-child reaping, and a bounded repeated-empty quiet proof.
It does not claim namespace or cgroup containment. Non-finite durations and
invalid poll/quiet values produce deterministic preflight status or a single
preflight diagnostic without launching a child. The v3 collector retains
every lifecycle anomaly as nonzero while still sealing and finalizing raw
artifacts.

## Third rereview: future protocol v4

V3 remains byte-for-byte superseded history. Additive v4 fixes four further
future-protocol findings without changing any frozen input, raw observation,
historical narrative, or v1--v3 body/test.

1. Ownership is keyed by `(pid,/proc starttime)` with separate active and
   retired identities and identity-verified pidfds. Same-snapshot current
   identities alone seed lineage. PGID records distinguish current owned
   groups from foreign/reused numeric groups and never signal the latter.
2. Every post-launch outcome enters one bounded cleanup machine. Unexpected
   exceptions and outer signals cannot re-raise past live children. Atomic
   status is best effort after cleanup, with honest stderr and status 125
   when the status medium remains unwritable.
3. The v4 collector forwards HUP/INT/TERM while the supervisor runs, waits for
   cleanup, and only then seals and audits. Requested, supervisor and final
   statuses are distinct; cleanup/audit failure wins.
4. Collector and auditor share one versioned realpath validator. Mutable
   work/tmp/output must be beneath scratch root but disjoint from ROOT and
   PACKAGE_DIR; disjoint copied-package/work siblings remain supported.

The deterministic and live controls are `test-supervise-v4.sh` and
`test-collector-v4.sh`; `future-protocol/V4_PATCH_MAPPING.md` maps each new
body. No benchmark timing was recollected.

## Fourth rereview: future protocol v5

V4 remains byte-for-byte superseded history. Additive v5 closes the four
later findings without changing any frozen input, raw observation, historical
narrative, or v1--v4 executable body/test.

1. A controller holding verified subreaper state and baseline direct-child
   identities now exists before launch. The child/PID/fresh PGID/pidfd are
   attached in the first post-`Popen` call. Failure at every subsequent
   construction boundary enters the ordinary bounded identity/PGID/adoptee
   discovery, TERM/KILL, quiet proof, reap/close and status path.
2. Exact identity closure separately records `supervisor_reaped`,
   `parent_reaped/exit_observed`, and `uncleared`. Identity-pidfd exit closes
   a non-adopted descendant reaped by its own parent, while adopted waitable
   zombies still require an identity-bound supervisor reap.
3. The Python collector captures HUP/INT/TERM from before launch through wait,
   raw seal, both audits and atomic publication. Finalization signals are
   ordered/deferred; cleanup/audit status 125 has honest precedence over the
   first separately retained requested 129/130/143. Signal blocking around
   atomic publication and `os._exit` closes the last delivery race.
4. The shared path policy explicitly allows canonical PACKAGE_DIR beneath
   ROOT or a copy elsewhere. Before residue, each mutable work/tmp/output path
   rejects equality, ancestry, descendancy or symlink resolution into either
   protected tree.

Current controls are `test-supervise-v5.sh`, `test-collector-v5.sh`, and the
independent `test-bounded-v2.sh`. `future-protocol/V5_PATCH_MAPPING.md` maps
every v5 body. No benchmark timing was recollected.

## Fifth rereview: future protocol v6

V5 remains byte-for-byte superseded executable/test history. Additive v6
closes the persistent-observation containment blocker without changing any
frozen input, raw observation, historical original, or v1--v5 executable/test
body and without recollecting benchmark timing.

The current supervisor requires an exact pinned unprivileged user/PID
namespace launcher and explicit namespace PID 1. Its no-benchmark preflight
verifies launcher path/version/hash/options and proves disposable teardown of
resistant setsid, double-fork and fork-on-signal endpoints. Unsupported
creation or teardown is `preflight_unsupported`/125 before benchmark GO; no
v5 fallback exists. Best-effort discovery failures are recorded separately
and cannot suppress signalling through bound wrapper/init pidfds or the
still-verified fresh PGID. Wrapper death uses `--kill-child=KILL`; namespace
PID-1 death invokes kernel PID-namespace member teardown. This is not a
cgroup claim.

Current lifecycle controls are `future-protocol/test-supervise-v6.sh` and
`future-protocol/test-collector-v6.sh`; the v2 bounded-ledger control remains
independent. `future-protocol/V6_PATCH_MAPPING.md` maps every additive v6
body, and `FUTURE_PROTOCOL_V6.md` is the concise resolution. No v6 body
collected a benchmark observation.

## Sixth rereview: future protocol v7

V6 remains byte-for-byte superseded executable/test history and stays an
active compatibility control. Additive v7 closes the remaining future
calibration transaction and edge-state findings without changing any tracked,
frozen, raw, historical-original, or v1--v6 executable/test byte and without
collecting benchmark timing.

The collector now accepts success only after exact closed-schema and semantic
validation of the supervisor record against the actual exit and command.
Every transaction write is atomic and guarded, destination writability is
tested before launch, and any write/schema/audit anomaly forces 125; persistent
unwritable media is reported on stderr without promising an impossible
primary status file. Every pidfd is closed before classification/status, and
close failures are retained and degrade to 125. A blocked-signal final drain
defines the GO commit point; pre-GO cancellation launches no benchmark.
Disposable preflight binds wrapper/init handles before risky work and uses
bounded identity-bound teardown on every exception.

Current controls are `future-protocol/test-supervise-v7.sh`,
`future-protocol/test-collector-v7.sh`, and the independent v2 bounded-ledger
test. `FUTURE_PROTOCOL_V7.md` states the exact limits and
`future-protocol/V7_PATCH_MAPPING.md` maps every new body.

## Seventh rereview: future protocol v8

V7 remains byte-for-byte superseded executable/test history and stays an
active compatibility control. Additive v8 closes the five later findings
without changing tracked, frozen, raw, historical-original, or v1--v7
executable/test bytes and without collecting benchmark timing.

The exact collector-derived full launch vector is now a required closed
semantic field; nonstandard JSON numbers, close contradictions, success
exceptions, generated cross-field contradictions, and degraded success
telemetry are rejected. A descendant-free control-pipe bootstrap cannot exec
unshare before its parent binds a pidfd and sends GO, and failure is boundedly
reaped without a stale-PID fallback. Signal capture remains active through
pidfd close and report construction; a blocked final drain defines a terminal
commit distinct from GO before durable status publication and `os._exit`.
Collector handlers precede every filesystem mutation, so setup failure and
early cancellation use the same accumulated transaction. Every accepted raw,
seal, auditor, endpoint, ledger, supervisor-status, and final-status material
is atomically replaced with file and parent-directory fsync; fsync failure is
125. `FUTURE_PROTOCOL_V8.md` and `future-protocol/V8_PATCH_MAPPING.md` give
the exact resolution and body map.

## Eighth rereview: future protocol v9

V8 remains byte-for-byte superseded executable/test history and stays an
active compatibility control. Additive v9 closes the final semantic-validator
finding without changing tracked, frozen, raw, historical-original, or
v1--v8 executable/test bytes and without collecting benchmark timing.

Supervisor and validator now use one pure exact classification/status
derivation with containment, cleanup, cancellation, exception, timeout,
nonzero/signal and success priority. Cancellation embeds the actual first
requested signal name; no prefix acceptance remains. The bootstrap field is
bound to the exact gate slot of the full launch vector, requested-signal
numerics exclude booleans and floats, and generated direct plus collector
adversaries cover the complete priority matrix. `FUTURE_PROTOCOL_V9.md` and
`future-protocol/V9_PATCH_MAPPING.md` give the exact resolution and body map.

## Ninth rereview: future protocol v10

V9 remains byte-for-byte superseded executable/test history and stays an
active compatibility control. Additive v10 closes the strict schema-typing
finding without changing tracked, frozen, raw, historical-original, or
v1--v9 executable/test bytes and without collecting benchmark timing.

One shared strict-integer contract now requires `type(value) is int` before
any range or literal comparison. Every integer-valued field in the closed
runtime record and its preflight, readiness, identity, reap, signal, status
and telemetry structures uses it. In particular, top-level version 10,
preflight version 8, readiness version 8 and namespace PID 1 reject booleans
and equal-valued floats before enforcing their literals. The producer binds
the namespace-init identity/pidfd before applying equivalent strict readiness
checks, so malformed readiness returns 125 with cleared containment and no
benchmark launch. Generated direct and real collector-gate controls reject
boolean/equal-float mutations for all 28 audited field/path categories with
one diagnostic and no success marker. The unchanged shared v9 classification
derivation prevents priority drift. `FUTURE_PROTOCOL_V10.md` and
`future-protocol/V10_PATCH_MAPPING.md` give the exact audit and body map.
