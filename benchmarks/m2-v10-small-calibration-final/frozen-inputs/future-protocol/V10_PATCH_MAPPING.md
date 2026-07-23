# Future protocol v10 additive patch mapping

V10 changes no v1--v9 executable body, test, fixture, frozen input, raw
observation, or historical original. It is the current future-only gate.

- `strict_integer_v10.py` supplies the one producer/validator strict JSON
  integer contract.
- `supervise-v10.py` supersedes `supervise-v9.py`, validating init readiness
  strictly after exact containment handles are bound.
- `validate-supervisor-v10.py` supersedes `validate-supervisor-v9.py`, routing
  every integer-valued record field through the shared strict contract.
- `collect-v10.py` supersedes `collect-v9.py` with the v10 validator and
  generated field/category mutations.
- `collector-signal-driver-v10.py` specializes the v9 driver for v10 phase
  injection.
- `test-supervise-v10.sh` adds producer readiness bool/float containment
  fixtures while retaining the v9 classification and lifecycle controls.
- `test-collector-v10.sh` adds generated direct and real collector-gate
  bool/equal-float adversaries for all 28 audited integer categories.

The unchanged v9 classification derivation and v8 launch gate/bootstrap,
namespace init, containment preflight and pinned launcher record remain v10
dependencies. V9 through v5 remain active compatibility controls. No v10
body collected a benchmark observation.
