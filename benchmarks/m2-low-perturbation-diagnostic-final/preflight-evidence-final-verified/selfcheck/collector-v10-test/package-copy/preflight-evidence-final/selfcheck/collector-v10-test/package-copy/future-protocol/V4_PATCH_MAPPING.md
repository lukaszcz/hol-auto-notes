# Future protocol v4 additive patch mapping

V4 changes no v1--v3 file. The executable bodies and their superseded roles
are mapped below; this is a patch map, not an apply-ready rewrite of history.

| V4 body | Supersedes for future use | Responsibility |
|---|---|---|
| `supervise-v4.py` | `supervise-v3.py` | identity ownership, signals, bounded cleanup, atomic status |
| `collect-v4.sh` | `collect-v3.sh` | prompt outer forwarding and ordered finalization |
| `path_validation_v4.py` | split v3 checks | shared realpath/disjointness policy |
| `validate-paths-v4.py` | v3 collector-only validation | pre-mutation validator CLI |
| `audit-artifacts-v4.py` / `.sh` | v3 auditor | shared-validator artifact audit |
| `process-tree-fixture-v4.py` | additive to v3 fixture | resistant same-group/setsid/double-fork trees |
| `collector-signal-driver-v4.py` | none | outer-signal test driver |
| `synthetic-artifact-audit-v4.sh` | v3 synthetic auditor | v4 argument-shape control |
| `test-supervise-v4.sh` | v3 supervisor gate | reuse mocks, injection, live stress |
| `test-collector-v4.sh` | v3 collector gate | signals, ordering, status and paths |

`verify-bounded-v2.py` and `test-bounded-v2.sh` remain current for their
independent ledger schema. No v4 body collected a benchmark observation.
