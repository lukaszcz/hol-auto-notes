# Future protocol v5 additive patch mapping

V5 changes no v1--v4 executable body, test, fixture, patch, frozen input, raw
observation, or historical narrative. This is a version map, not a rewrite of
the superseded v4 files.

| V5 body | Supersedes for future use | Responsibility |
|---|---|---|
| `supervise-v5.py` | `supervise-v4.py` | pre-launch bootstrap controller, exact identity closure, common cleanup |
| `collect-v5.py` | `collect-v4.sh` | pre-launch-through-publication signal capture and race-closed final status |
| `path_validation_v5.py` | `path_validation_v4.py` | exact protected/mutable relationship policy |
| `validate-paths-v5.py` | `validate-paths-v4.py` | pre-mutation shared-validator CLI |
| `audit-artifacts-v5.py` / `.sh` | v4 auditor | v5 shared-validator artifact audit |
| `process-tree-fixture-v5.py` | v4 fixture | construction, reap, rapid-exit and resistant live trees |
| `collector-signal-driver-v5.py` | v4 driver | exact supervisor/finalization phase signal injection |
| `synthetic-artifact-audit-v5.sh` | v4 synthetic auditor | v5 argument-shape control |
| `test-supervise-v5.sh` | v4 supervisor gate | bootstrap, closure, WNOWAIT, rapid escape controls |
| `test-collector-v5.sh` | v4 collector gate | late signals, order, precedence, exact paths and relocation |

`verify-bounded-v2.py` and `test-bounded-v2.sh` remain the current independent
bounded-ledger schema gate. No v5 body collected a benchmark observation.
