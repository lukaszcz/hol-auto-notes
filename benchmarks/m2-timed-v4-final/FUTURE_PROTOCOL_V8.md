# Future protocol v8 resolution

This additive future-only repair changes no tracked source, frozen input,
raw observation, historical original, or v1--v7 executable/test byte. It
collected no benchmark timing and grants no authority to the retained failed
timed-v4 package.

V8 closes the five findings left by the v7 review.

1. The collector derives the one exact expected full launch vector. The
   validator requires byte-for-byte JSON-array equality for the Python
   interpreter, versioned bootstrap, separator, pinned unshare path/options,
   namespace-init interpreter and body, work-specific ready/GO paths, second
   separator, and benchmark command. JSON objects are closed recursively;
   duplicate keys and non-standard numeric constants are rejected. Numeric,
   exception, close, classification, containment, reap, signal, telemetry,
   GO, terminal-commit, and success invariants are fail-closed.
2. GO and terminal status have distinct commits. Signal capture stays active
   through cleanup, pidfd close and report construction. HUP/INT/TERM are
   blocked and drained at close, classification, and the status-write
   boundary. The final empty drain is the terminal commit; durable status is
   then published and the process uses `os._exit` without unblocking. Signals
   generated after that documented commit are outside the transaction.
3. `launch-gate-v8.py` is a descendant-free stdin control-pipe gate. Its
   parent attempts `pidfd_open` as the first action after `Popen`; only a
   one-byte GO can permit exec of the exact pinned unshare vector. Failure
   closes the pipe and boundedly reaps the direct child, using its numeric PID
   only while it remains the stable unreaped direct child. The same gate is
   mandatory for disposable preflight and live supervision; the pidfd remains
   bound to the same PID/starttime across exec.
4. The collector initializes signal and transaction state and installs
   handlers before any filesystem mutation. Directory creation, destination
   probes, early cancellation, and every setup I/O failure enter the same
   accumulated status path. If no writable durable status medium can be
   created, stderr and exit 125 are the honest remaining channels.
5. Every accepted material is atomically published and both its file and
   parent directory are fsynced. This includes republished raw files and raw
   directory state, the raw seal, real auditor output, endpoint audit, order
   and signal ledgers, supervisor status, and final collector status. Any
   injected or real fsync failure degrades the transaction to 125.

Current controls are `future-protocol/test-supervise-v8.sh`,
`future-protocol/test-collector-v8.sh`, and the independent bounded-v2 test.
V7, v6, and v5 remain active compatibility gates. V8 is infrastructure for a
later fresh small calibration; it has not run a benchmark target.
