# Future protocol v9 additive patch mapping

V9 changes no v1--v8 executable body, test, fixture, frozen input, raw
observation, or historical original. It is the current future-only gate.

- `classification_status_v9.py` supersedes duplicated v8 derivations with the
  pure exact classification/status priority.
- `supervise-v9.py` supersedes `supervise-v8.py` and uses that derivation at
  terminal commit.
- `validate-supervisor-v9.py` supersedes `validate-supervisor-v8.py` with the
  exact derived status, bootstrap binding and strict signal integers.
- `collect-v9.py` supersedes `collect-v8.py` with the v9 validator gate and
  generated record adversaries.
- `collector-signal-driver-v9.py` specializes the v8 driver for exact v9
  collector-phase signal injection.
- `test-supervise-v9.sh` supersedes the v8 supervisor gate with emitted-record
  and exact-cancellation controls.
- `test-collector-v9.sh` supersedes the v8 collector gate with direct and
  end-to-end semantic adversaries.

The unchanged v8 launch gate/bootstrap, namespace init, containment preflight,
pinned launcher record and supervisor signal driver remain v9 dependencies.
V8, v7, v6, and v5 remain active compatibility gates; the v5 shared path and
artifact auditor and bounded-v2 validator remain independent dependencies.
No v9 body collected a benchmark observation.
