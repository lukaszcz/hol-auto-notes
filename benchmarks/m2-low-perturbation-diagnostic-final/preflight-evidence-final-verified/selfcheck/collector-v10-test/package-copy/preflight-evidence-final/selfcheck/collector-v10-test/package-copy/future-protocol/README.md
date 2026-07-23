# Future protocol v10 (no collected target)

`supervise-v10.py`, `validate-supervisor-v10.py`, and `collect-v10.py` are
the current future gate. They share `strict_integer_v10.py` for every
integer-valued record field and for producer readiness, while reusing the
unchanged exact v9 classification/status derivation. The exact claims and
audit are in `../FUTURE_PROTOCOL_V10.md`; body mapping is in
`V10_PATCH_MAPPING.md`. V10 collected no benchmark.

## Superseded v9 design

`supervise-v9.py`, `validate-supervisor-v9.py`, and `collect-v9.py` are the
superseded v9 gate. They share one pure exact classification/status
derivation, bind the recorded bootstrap program to the exact gate-vector
slot, require strict JSON integers for requested-signal numerics, and reject
every generated priority contradiction. The exact claims and limits are in
`../FUTURE_PROTOCOL_V9.md`; body mapping is in `V9_PATCH_MAPPING.md`. V9
collected no benchmark.

## Superseded v8 design

`supervise-v8.py`, `validate-supervisor-v8.py`, and `collect-v8.py` are the
superseded future gate. They add atomic pre-unshare pidfd ownership through a
descendant-free control-pipe gate, exact full-launch-vector validation, a
terminal-status commit distinct from GO, handler-first guarded setup, and
atomic file-plus-parent-directory durability for every accepted material.
The exact claims and limits are in `../FUTURE_PROTOCOL_V8.md`; body mapping is
in `V8_PATCH_MAPPING.md`. V8 collected no benchmark.

## Superseded v7 design

`supervise-v7.py`, `validate-supervisor-v7.py`, and `collect-v7.py` are the
superseded future gate. They add an exact supervisor-record success validator, a
preflighted atomic collector transaction whose write failures accumulate to
125, close-before-classification pidfd evidence, a precisely linearized
blocked-signal GO commit, and exception-safe disposable-preflight teardown.
The exact claims and limits are in `../FUTURE_PROTOCOL_V7.md`; body mapping is
in `V7_PATCH_MAPPING.md`. V7 collected no benchmark.

## Superseded v6 design

These files are unexecuted-by-benchmark infrastructure for a later fresh,
smaller calibration. They do not repair or replace any historical byte and
must not be cited as a completed collection.

`supervise-v6.py` was the v6 supervisor. Before any benchmark launch it
verifies the exact `/usr/bin/unshare` path, util-linux version, executable
hash and required option spellings frozen in `UNSHARE_V6.json`, then performs
a disposable teardown proof. The proof creates an unprivileged user and PID
namespace with `--fork --kill-child=KILL --mount-proc`, binds the wrapper and
namespace-init identities/pidfds, and verifies that resistant setsid,
double-fork and fork-on-signal endpoints all die when the wrapper is killed.
Failure is deterministic `preflight_unsupported`/125 and launches no
benchmark; there is no uncontained fallback.

For a real child, the supervisor binds the fresh-session wrapper and explicit
namespace PID 1 before publishing GO. The PID-namespace init owns a local
`/proc`. Killing the identity-bound unshare wrapper causes its exact
`--kill-child=KILL` contract to kill namespace PID 1; Linux then kills every
remaining process in that PID namespace. This is PID-namespace containment,
not a cgroup claim.

Best-effort discovery is independent from signalling: a persistent `/proc`
scan exception is recorded and degrades status to 125, but cannot suppress
TERM/KILL attempts through either bound pidfd or the fresh PGID still verified
by the live wrapper pidfd. Clearance requires wrapper and init pidfd exit plus
wrapper reap. `collect-v6.py` embeds the preflight provenance in the sealed
supervisor JSON and publishes containment kind/status plus launcher path/hash
in final status. HUP/INT/TERM remain captured through final publication and a
cleanup/audit failure retains status-125 precedence.

Current lifecycle controls are `test-supervise-v6.sh` and
`test-collector-v6.sh`. `V6_PATCH_MAPPING.md` maps the additive bodies. The
v5 path validator/auditor and v2 bounded validator remain independent current
dependencies.

## Superseded v5 design

`supervise-v5.py` was the v5 supervisor. A cleanup controller, verified
subreaper state, and the supervisor's baseline direct-child identities exist
before launch. The first call after `Popen` attaches the child, PID, fresh
PGID and pidfd before fallible identity/full-session construction. Therefore
bootstrap attachment or construction failure uses the same bounded recursive
discovery, TERM/KILL, quiet proof, reap/close and best-effort status machine
as ordinary supervision; there is no PGID-only fallback.

Ownership remains the immutable
`(pid,/proc starttime)` identity, split into active and retired maps, with an
identity-verified pidfd. Only active identities present in the same `/proc`
snapshot seed lineage. Direct adoptees with reused numeric PIDs are admitted
as new identities; unrelated children of reused retired PIDs are not. PGID
operations record owned/foreign current identities and skip signalling when
numeric-group reuse could target an unrelated group.

V5 identity closure distinguishes `supervisor_reaped`,
`parent_reaped/exit_observed`, and `uncleared`. A non-adopted descendant whose
own parent consumed its wait status closes only when its exact identity pidfd
reports exit. A child adopted directly by the supervisor must still be
wait-bound and supervisor-reaped; WNOWAIT keeps that consumption tied to its
exact current identity.

Every post-launch outcome enters one bounded discover/TERM/rescan/KILL/
quiet/reap/pidfd-close/atomic-status machine. HUP/INT/TERM and unexpected
wait, scan, poll, signal or status failures cannot bypass cleanup.
`collect-v5.py` installs HUP/INT/TERM handlers before supervisor launch,
defers early delivery until the supervisor publishes readiness, forwards
signals while it runs, and keeps capture active through supervisor wait, raw
seal, artifact audit, process audit and atomic final-status publication.
Signals during finalization are recorded rather than aborting remaining
steps. Publication blocks handled signals, freezes the ordered signal ledger,
atomically replaces status, and exits without reopening a delivery race.
Requested outer, actual supervisor, cleanup/audit and final statuses remain
distinct; cleanup/audit failure has precedence over the first requested
129/130/143 status.

`path_validation_v5.py` is shared by collector and auditor. The canonical
PACKAGE_DIR is intentionally allowed beneath ROOT, and a copied PACKAGE_DIR
may be elsewhere. Resolved work/tmp/output paths must be strict descendants
of SCRATCH_ROOT and may not equal, contain, be contained by, or resolve via a
symlink into either ROOT or PACKAGE_DIR. A copied package and work remain
valid as disjoint siblings.

## Superseded v4 design

The v4 bodies and tests remain byte-for-byte superseded history. V4 added
immutable identities, a common post-session cleanup machine, prompt shell
signal forwarding and shared path validation. It did not establish a cleanup
controller before launch/session attachment, conflated disappearance with
supervisor wait ownership, disabled collector signal capture during
finalization, and left the permitted ROOT/PACKAGE_DIR relationship implicit.
V5 repairs those future-only gaps without changing any v4 byte.

## Superseded v3 design

`supervise-v3.py` was the v3 supervisor. A dedicated Linux subreaper
discovers ownership by `/proc` parent-lineage closure seeded by the leader and
by children subsequently adopted directly by the supervisor. Every live
discovered identity requires a pidfd; the supervisor uses pidfds for
identity-preserving signals in addition to signalling and proving disappearance
of the original PGID. It rescans before, during, and after TERM/KILL, reaps all
owned children, and accepts clearance only after repeated empty scans over a
finite quiet interval. The status records identities, pidfd results, signals,
reaps, scans, quiet proofs, PGID probes, and the terminal classification.
Pidfd/subreaper unavailability is status-125 unsupported/failure, not a weaker
containment claim.

A leader exit never defines success by itself. If a group member or owned
descendant remains after leader exit, v3 returns 125 with distinct
`lifecycle_anomaly_term_owned_tree_cleared`,
`lifecycle_anomaly_kill_owned_tree_cleared`, or
`lifecycle_anomaly_owned_tree_uncleared` classification. `collect-v3.sh`
preserves that segment status while sealing raw stdout/stderr/status before
its unconditional endpoint and artifact finalizer.

`audit-artifacts-v3.py`/`.sh` accepts explicit `--root`, `--package-dir`,
`--scratch-root`, `--scratch-dir`, and `--output`; it contains no canonical
package path. `collect-v3.sh` creates its own `work/tmp` and invokes the
default auditor with all paths explicitly in both environment and arguments.
The real auditor is tested from the original and a copied package in a clean
environment without inherited `TMPDIR`.

The bounded-ledger validator remains the independently versioned
`verify-bounded-v2.py`: its schema did not participate in this lifecycle v3
repair. It pins the exact 1/34/1, 2/41/1..3, 3/45/1 attempt sequence,
immediate summaries and EOF, and binds reads and allocations to the main raw
ledger.

The original frozen scripts remain `../frozen-inputs/{collect.sh,
supervise.py,verify-bounded.awk}`. The live historical copies at `../` remain
unchanged. `../SUPERVISOR_REVIEW.patch` is retained as an inadequate
historical proposal and is superseded only for future runs.

The v2--v9 executable/test bodies are unchanged superseded history. V5
through V9 remain active compatibility controls. The current gate is
`test-supervise-v10.sh`, `test-collector-v10.sh`, and the schema-independent
`test-bounded-v2.sh`, run by package selfcheck. Exact v10 mapping is in
`V10_PATCH_MAPPING.md`; the earlier maps remain history.
