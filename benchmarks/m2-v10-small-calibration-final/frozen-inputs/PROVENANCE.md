# Provenance

- Repository HEAD: `244b01d7189ac803df48e246a483c33b553e3daa`.
- Reviewed source package:
  `.agent-files/benchmarks/m2-timed-v4-final/` at the same HEAD.
- `future-protocol/` is a byte-for-byte copy of that reviewed package's
  complete `future-protocol/` directory, not a rewritten subset.  Its v10
  entry points are `collect-v10.py`, `supervise-v10.py`,
  `validate-supervisor-v10.py`, `strict_integer_v10.py`,
  `test-collector-v10.sh`, and `test-supervise-v10.sh`; their v8/v9 and older
  support dependencies remain vendored alongside them.
- The P38 formula, invocation claset, search entry point and reconstruction
  signature follow the reviewed `task7jcalibration.sml` setup.  This package
  adds only the four predeclared ablation modes and counting clocks.
- Formal build/selftest logs, v10 selfcheck logs, source hashes, runtime
  artifact reference, every child transaction and final closure inventory
  are retained with the final package.

No source optimization is implemented or selected here.
