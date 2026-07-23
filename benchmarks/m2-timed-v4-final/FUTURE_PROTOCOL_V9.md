# Future protocol v9 resolution

This additive future-only repair changes no tracked source, frozen input,
raw observation, historical original, or v1--v8 executable/test byte. It
collected no benchmark timing and grants no authority to the retained failed
timed-v4 package.

V9 closes the final semantic-validator gap left by the v8 review.

1. `classification_status_v9.py` is the one pure derivation used by both the
   supervisor and validator. Its exact priority is containment failure,
   cleanup degradation, the first requested cancellation, primary exception,
   timeout, missing/nonzero/signal exit, then success. The validator derives
   the sole classification/status pair from the complete record and requires
   exact equality. Cancellation names embed exactly the first signal name.
2. Runtime and disposable bootstrap records bind `bootstrap_program` to
   index 2 of the exact full gate vector, whose structure is interpreter,
   `-B`, gate, `--`, then the pinned launcher vector. The comparison remains
   byte-exact for canonical and copied package paths supplied by the collector.
3. Every requested-signal `sequence`, `signal_number`, and
   `requested_status` is a JSON integer with `type(value) is int`; booleans
   and floats are rejected. Nonstandard NaN and infinity tokens remain
   rejected.
4. Because every classification/status comes from the shared priority
   derivation, timeout, nonzero exit, and success cannot be asserted over a
   higher-priority containment, degradation, cancellation, or exception
   state. Generated direct-validator and real collector-gate adversaries
   cover each priority combination, forged bootstrap identity, wrong and
   extraneous cancellation suffixes, and boolean/float signal numerics.

V9 reuses the unchanged v8 atomic launch gate, bootstrap, namespace init,
containment preflight, pinned unshare record, and signal driver where their
contracts did not change. Current controls are
`future-protocol/test-supervise-v9.sh`,
`future-protocol/test-collector-v9.sh`, and the independent bounded-v2 test.
V8, v7, v6, and v5 remain active compatibility gates. V9 is infrastructure
for a later fresh small calibration; it has not run a benchmark target.
