# Future protocol v7 additive patch mapping

V7 changes no v1--v6 executable body, test, fixture, frozen input, raw
observation or historical original. It is the current future-only gate.

| V7 body | Supersedes for future use | Responsibility |
|---|---|---|
| `UNSHARE_V7.json` | `UNSHARE_V6.json` | exact launcher path/version/hash/options |
| `containment-preflight-v7.py` | v6 preflight | bound-handle cleanup on every exception and close proof |
| `namespace-init-v7.py` | v6 namespace init | explicit PID 1 and GO barrier version |
| `supervise-v7.py` | `supervise-v6.py` | GO commit, close-before-status, kernel containment |
| `validate-supervisor-v7.py` | none | exact nested schema and semantic validation |
| `collect-v7.py` | `collect-v6.py` | validator gate and atomic error-accumulating transaction |
| `process-tree-fixture-v7.py` | v6 fixture | resistant containment endpoint |
| `supervisor-signal-driver-v7.py` | none | exact pre-GO queued-signal controls |
| `collector-signal-driver-v7.py` | v6 driver | exact finalization signal controls |
| `test-supervise-v7.sh` | v6 supervisor gate | preflight/GO/close/containment controls |
| `test-collector-v7.sh` | v6 collector gate | schema/write/signal/audit/relocation controls |

V6 and V5 remain active compatibility gates. The v5 path validator/artifact
auditor and v2 bounded-ledger validator remain independent dependencies. No
v7 body collected a benchmark observation.
