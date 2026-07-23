# Reviewed v10 provenance and exact-endpoint delta

`future-protocol/` was copied from the reviewed protocol closure vendored by
the authoritative Task 7m package.  Every file is byte-identical to that
closure except `collect-v10.py`.  Task 7n replaces only its post-reap regex
`pgrep` endpoint check with an exact `/proc/<pid>/cmdline` argv-element audit
for the supervised executable and its generated module identity; no
supervision, namespace, signal, cleanup, status, durability, schema, artifact,
or classification behavior is changed.  The retained base v10 selftests and
Task 7n exact-endpoint adversaries cover the delta.  No regex `pgrep` is
executed by the Task 7n collection path.

