# Future protocol v8 additive patch mapping

V8 changes no v1--v7 executable body, test, fixture, frozen input, raw
observation, or historical original. It is the current future-only gate.

| V8 body | Supersedes for future use | Responsibility |
|---|---|---|
| `UNSHARE_V8.json` | `UNSHARE_V7.json` | exact launcher identity/options/version |
| `launch-gate-v8.py` | none | descendant-free control-pipe exec gate |
| `launch_bootstrap_v8.py` | none | first-action pidfd ownership and bounded gate abort |
| `containment-preflight-v8.py` | v7 preflight | gated disposable containment proof |
| `namespace-init-v8.py` | v7 namespace init | durable readiness and benchmark GO barrier |
| `supervise-v8.py` | `supervise-v7.py` | gated live launch and terminal-status commit |
| `validate-supervisor-v8.py` | v7 validator | exact launch vector and closed semantic schema |
| `collect-v8.py` | `collect-v7.py` | guarded setup and durable accumulated transaction |
| `supervisor-signal-driver-v8.py` | v7 driver | close/classification/status-boundary signals |
| `collector-signal-driver-v8.py` | v7 driver | setup/finalization signal controls |
| `test-supervise-v8.sh` | v7 supervisor gate | bootstrap, terminal commit, close and fsync controls |
| `test-collector-v8.sh` | v7 collector gate | exact schema, setup, durability, signal and relocation controls |

V7, v6, and v5 remain active compatibility gates. The v5 shared path and
artifact auditor and the bounded-v2 validator remain independent dependencies.
No v8 body collected a benchmark observation.
