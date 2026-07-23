# Future protocol v6 additive patch mapping

V6 changes no v1--v5 executable body, test, fixture, frozen input, raw
observation or historical narrative. It is a future-only replacement gate.

| V6 body | Supersedes for future use | Responsibility |
|---|---|---|
| `UNSHARE_V6.json` | none | exact launcher path/version/hash/options |
| `containment-preflight-v6.py` | v5 capability checks | no-benchmark disposable kernel-teardown proof |
| `namespace-init-v6.py` | none | explicit namespace PID 1 and local `/proc` contract |
| `supervise-v6.py` | `supervise-v5.py` | known-signal independence and kernel containment |
| `collect-v6.py` | `collect-v5.py` | containment provenance in raw seal/final status |
| `process-tree-fixture-v6.py` | v5 fixture | resistant setsid/double-fork/fork-on-signal tree |
| `collector-signal-driver-v6.py` | v5 driver | exact v6 collector-phase signal injection |
| `test-supervise-v6.sh` | v5 supervisor gate | preflight and persistent-observer adversaries |
| `test-collector-v6.sh` | v5 collector gate | containment/audit/finalization adversaries |

V5 path validation and artifact audit, and v2 bounded-ledger validation, are
schema-independent retained dependencies. No v6 body collected a benchmark.
