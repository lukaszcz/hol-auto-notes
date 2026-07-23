# Future protocol v6 resolution

This additive repair changes no tracked source, frozen input, raw collection
observation, historical original, or v1--v5 executable/test body. It collected
no benchmark timing and grants no authority to this retained failed package.

V5's recursive discovery was honest but not containment-safe under persistent
`/proc` failure: its discovery call preceded known pidfd/PGID signals. V6
records discovery errors independently and always attempts already-bound
signals. More importantly, every benchmark runs below an explicit namespace
PID 1 launched by the exact pinned unprivileged-user/PID-namespace `unshare`
command. Wrapper death delivers KILL to namespace PID 1; kernel PID-namespace
teardown kills all remaining members, including setsid and double-fork
escapes and processes forked while signals are handled.

The mandatory no-benchmark preflight verifies exact launcher identity and
performs a disposable live teardown proof. Unsupported creation or failed
teardown returns `preflight_unsupported`/125 before GO, with no v5 fallback.
The supervisor status and collector raw seal retain launcher provenance,
wrapper/init identities and pidfd-exit/reap proof. Persistent scan failures
and injected known-signal failures remain nonzero even when kernel containment
is proved. Uncleared containment is status 125 and blocks continuation.
