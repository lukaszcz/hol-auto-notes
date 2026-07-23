# Future protocol v10 resolution

This additive future-only repair changes no tracked source, frozen input,
raw observation, historical original, or v1--v9 executable/test byte. It
collected no benchmark timing and grants no authority to the retained failed
timed-v4 package.

V10 closes the strict JSON-integer typing gap left by the v9 review.

1. `strict_integer_v10.py` is the single integer contract used by both the
   supervisor producer and closed validator: `type(value) is int`, followed
   by any range and literal constraints. Booleans and floats are never JSON
   integers, including equal-valued floats.
2. The validator routes every integer-valued supervisor field through that
   contract: top-level version/status; preflight version and identities;
   runtime, namespace, reap, scan and signal identities; PGID, readiness
   version/PID/inode, wrapper/reap statuses, requested-signal numerics,
   signal telemetry targets, and quiet-proof counts. Protocol literals are
   enforced only after strict type validation.
3. The producer binds the namespace-init identity and pidfd before fallible
   readiness semantics, then strictly validates readiness version 8,
   namespace PID 1 and the positive inode, plus the exact boolean PID-1
   proof. Boolean/equal-float literal fixtures return 125, launch no
   benchmark, and prove containment cleared.
4. Generated direct-validator and real collector-gate controls cover both a
   boolean and equal-valued float for all 28 audited field/path categories.
   Each CLI or collector failure has one diagnostic, no success output, and
   collector status 125.

V10 supervisor and validator both reuse the unchanged shared
`classification_status_v9.py` derivation, so containment/cleanup/
cancellation/exception/timeout/nonzero/signal/success priority does not
drift. V9, v8, v7, v6, and v5 remain active compatibility gates. V10 is
infrastructure for a later fresh small calibration; it has not run a
benchmark target.
