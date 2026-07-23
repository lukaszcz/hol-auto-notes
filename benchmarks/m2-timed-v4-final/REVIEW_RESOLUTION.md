# Independent-review resolution

This repair changes only ignored evidence/package infrastructure. It changes
no tracked source and recollects no timing.

1. **Mixed clocks:** `FINAL_REVIEW_ERRATA.md`, `CURRENT_ASSESSMENT.md`, and the
   corrected live reports withdraw `P43 internal ratio >=3.558462`. No v4
   internal row exists. The optional `>=2.212259` bound is explicitly labelled
   external-process to external-process. P38 is rounded to 5.236.
2. **Authority and chronology:** the package is classified as a retained
   failed-protocol/calibration observation. The erratum records the `set -e`
   abort, unretained later materialization, absent immediate seal, absent outer
   status, and the distinct supervisor-125 domain. Pre-review report bodies
   are byte-for-byte under `historical-originals/`; frozen/raw bytes are
   unchanged.
3. **Superseded first future process repair:**
   `future-protocol/supervise-v2.py` uses Linux
   subreaper semantics, TERM, monotonic whole-group grace polling, KILL,
   separate bounded post-KILL polling, ESRCH handling, per-PID leader/adopted
   descendant reap records, and terminal classification. Its deterministic
   test covers ordinary, nonzero, direct TERM exit, TERM-cleared timeout,
   TERM-resistant leader plus descendant requiring KILL, delayed group
   disappearance, ESRCH, and an uncleared-group failure. `collect-v2.sh`
   seals first and invokes endpoint/artifact audits in its unconditional
   finalizer. Second rereview found that v2 did not contain setsid escapes and
   could return success after cleaning a leader-zero lifecycle anomaly; it is
   retained only as history and replaced by v3 below. Original frozen scripts
   and the inadequate historical patch remain unchanged.
4. **Future bounded validation:** `verify-bounded-v2.py` requires exact
   `1/34/1`, `2/41/1..3`, `3/45/1`, immediate summaries, exact EOF and no
   append; it checks canonical identifiers, natural fields and closed enums,
   arithmetic, then binds attempt/read/allocation tuples to the main raw
   ledger. Strong negatives include summaries-before-attempts and arbitrary
   identifiers, raw/bounded drift and both-ledger EOF/append cases. No target
   was collected.
5. **Isolation and scratch:** live `selfcheck.sh` and `final-audit.sh` require
   validated `ROOT`, `PACKAGE_DIR`, scratch root and scratch directory. The
   copied-package selfcheck exercises the passed copy. A retargeted symlink in
   that copy is rejected. Every test receives explicit scratch, and the stale
   nonexistent `provenance/`/six-endpoint audit was replaced by the two
   materialized artifact endpoints and separately labelled later process
   audit.
6. **Build:** `build-gate/` retains the exact status-0
   `bin/build -t --seq=tools/sequences/upto-auto` log and provenance at HEAD
   `244b01d7189ac803df48e246a483c33b553e3daa`. It explicitly disclaims the
   full `bin/build -F -t` M5 gate.
7. **Rounding:** every current P38 narrative says approximately 5.236; the
   former 5.235 text exists only in the explicitly historical exact body.

The package checksum/inventory closure covers all regular files except the
checksum file itself and records all symlink targets. Original and copied
package selfchecks, integrity controls and adversaries passed after closure
generation; the copied symlink mutation was rejected. Their host scratch is
restricted to the assigned task directory.

## Second independent rereview resolution

The former v2 future gate is preserved unchanged and explicitly superseded.
The additive v3 gate closes setsid and double-fork/reparent escapes using
subreaper-owned lineage discovery and pidfds, makes every post-leader
descendant lifecycle a status-125 anomaly, validates every duration/poll/quiet
input for finiteness and range before launch, and uses an explicit-path,
relocation-safe real artifact auditor. Repeated escape controls, direct and
collector lifecycle controls, invalid-number controls, original/copy auditor
controls, and package-integrity controls are the current selfcheck.

## Third independent rereview resolution

The former v3 gate is preserved unchanged and superseded by additive v4.
V4 uses immutable process identities and same-snapshot lineage; funnels all
post-launch exceptions/signals through bounded cleanup and atomic status;
forwards outer HUP/INT/TERM promptly before final seal/audits; and shares a
realpath/disjointness validator between collector and auditor. Mocked PID
reuse counterexamples, injected failures, repeated live tree stress, all
three outer signals, repeated signals, exact finalization order, clean-env
original/copy operation, and overlap/symlink adversaries are mandatory in the
current selfcheck. This repair recollected no timing and changes no tracked
source, frozen/raw/history byte, or v1--v3 body/test.

## Fourth independent rereview resolution

V4 is preserved unchanged and superseded by additive v5. V5 constructs its
cleanup controller before launch and attaches the Popen child/PID/pidfd before
fallible full-session work; exact closure permits parent-reaped non-adopted
descendants only with pidfd exit evidence while retaining supervisor reap for
direct adoptees. The collector keeps signal capture active through every
finalization phase and uses blocked atomic publication plus `os._exit`.
Requested, supervisor, audit and final statuses remain separate with status
125 precedence. The shared validator now states and tests that canonical
PACKAGE_DIR may lie beneath ROOT, while every mutable work/tmp/output path is
rejected if equal to, above, below or symlink-aliased into either protected
tree. Construction-boundary failures, the WNOWAIT race, parent-reaped and
adopted-zombie cases, repeated rapid leader/double-fork/setsid escapes, all
late signal phases, repeated signals, original/copy operation and the complete
path relation matrix are the current selfcheck. No timing was recollected and
no tracked, frozen, raw, historical or v1--v4 executable/test byte changed.

## Fifth independent rereview resolution

V5 is preserved unchanged as superseded executable/test history. V6 makes
kernel containment mandatory through an exact pinned `unshare` user/PID
namespace, explicit namespace PID 1, `--kill-child=KILL`, and namespace-local
`/proc`. A no-benchmark disposable proof must pass before GO. Persistent
discovery failure cannot suppress already-bound init/wrapper pidfd or verified
fresh-PGID signalling; it still degrades the result to 125. Clearance is
proved from wrapper/init pidfd exit and wrapper reap, and the collector seals
that provenance before artifact/process audits and final publication.
Repeated persistent-scan, known-signal-failure and HUP/INT/TERM controls prove
kernel teardown or retain uncleared/degraded status 125. V6 recollected no
timing and changed no tracked, frozen, raw, historical-original or v1--v5
executable/test byte.

## Sixth independent rereview resolution

V6 is preserved unchanged and superseded by additive v7. The collector's
success path now requires an exact nested schema/semantic supervisor record,
including pinned launcher provenance, preflight proof, bound identities,
wrapper reap/exit consistency, containment proof, pidfd closes, command and
actual supervisor status. Missing or adversarial raw remains sealable but is
never success. All transaction writes are atomic and guarded after a
pre-launch destination test; write/audit/schema errors accumulate to 125 and
persistent medium failure is reported without claiming a primary status file.
The supervisor closes all pidfds before classification/status, defines GO at
the final empty blocked-signal drain, and cancels before GO without launching
the benchmark. Every disposable-preflight exception uses already-bound
wrapper/init pidfds for bounded teardown and proof. V7 collected no timing and
changed no tracked, frozen, raw, historical-original or v1--v6 body/test byte.

## Seventh independent rereview resolution

V7 is preserved unchanged and superseded by additive v8. V8 requires exact
full launch-vector equality and recursively closed semantic validation; adds
an atomically owned, descendant-free pre-unshare gate used by disposable and
live launch; keeps signals transactional through close/report construction
and defines a separate terminal-status commit; installs collector state and
handlers before the first filesystem mutation; and durably publishes every
accepted material with atomic replace plus file and parent-directory fsync.
Setup, signal, schema, close, numeric, telemetry and fsync adversaries all
fail closed. V8 collected no timing and changed no tracked, frozen, raw,
historical-original or v1--v7 executable/test byte.

## Eighth independent rereview resolution

V8 is preserved unchanged and superseded by additive v9. The supervisor and
validator use the same pure exact classification/status derivation; the
validator binds the bootstrap program to the exact full-vector gate slot,
requires real JSON integers for all requested-signal numerics, and admits no
cancellation suffix or lower-priority classification drift. Generated direct
validator and end-to-end collector controls reject each forged bootstrap,
signal-numeric, cancellation-name and priority-combination record, with the
collector retaining status 125. V9 collected no timing and changed no
tracked, frozen, raw, historical-original or v1--v8 executable/test byte.

## Ninth independent rereview resolution

V9 is preserved unchanged and superseded by additive v10. One shared helper
requires actual JSON integers before range/literal checks across every
integer-valued supervisor field and nested preflight/readiness/identity/reap/
signal/status/telemetry structure. The producer applies the same contract to
namespace readiness after binding exact cleanup handles but before benchmark
GO. Generated direct-validator and collector-gate boolean/equal-float
adversaries cover all 28 audited categories; producer readiness literals have
four separate malformed fixtures. Each applicable failure is contained,
status 125, singly diagnostic and cannot launch the benchmark. V10 reuses the
unchanged shared v9 classification derivation, collected no timing, and
changed no tracked, frozen, raw, historical-original or v1--v9
executable/test byte.
