# Future protocol v7 resolution

This additive future-only repair changes no tracked source, frozen input,
raw observation, historical original, or v1--v6 executable/test byte. It
collected no benchmark timing and grants no authority to this retained failed
package.

V7 makes the supervisor JSON a closed protocol rather than advisory
telemetry. `validate-supervisor-v7.py` rejects duplicate or unknown fields,
missing/truncated/malformed records, type and enum violations, inconsistent
classification/launch/exit state, incomplete containment or pidfd-close
proof, wrapper/init/reap mismatch, wrong command or actual supervisor exit,
and any launcher path/hash/version/options drift. `collect-v7.py` invokes that
validator on the sealed record before success is possible. An absent raw file
may be recorded as `ABSENT` for forensics, but is always failure/125.

All collector materialization uses atomic replace plus file and directory
fsync. The work transaction is exercised before supervisor launch. Each
order-ledger, raw-seal, endpoint-audit, outer-signal and final-status write is
guarded; failures accumulate and force 125 while cleanup and later audits
continue. A one-shot final-status failure receives one honest 125 retry. If
the medium remains unwritable, no primary status file is promised: stderr and
process status 125 are the remaining channels.

The supervisor closes the temporary capability pidfd, every disposable
preflight pidfd, and the live wrapper/init pidfds before final classification
or status. Close errors are recorded and degrade to 125. Close is not retried:
after a real `close(2)` error such as EINTR the numeric descriptor may already
have been reused; process exit is the last owner of a descriptor whose close
could not be proved. Injected controls close first and then simulate an error,
so they test classification without leaking a test descriptor.

Handled signals are blocked before supervisor readiness. After wrapper and
init identity binding, a final nonblocking `sigtimedwait` drain while blocked
is the GO commit linearization point. A signal drained before that point
prevents GO and benchmark launch; signals queued after the final empty drain
are defined as post-GO cancellation and receive ordinary bounded cleanup.
The subsequent atomic GO-file replace is not falsely claimed to be ordered
atomically with kernel signal generation. Standard signals of the same number
may coalesce while blocked; distinct HUP/INT/TERM requests retain the observed
drain order.

Disposable preflight binds the wrapper pidfd immediately and the namespace
init identity/pidfd before later discovery/proof work. Every exception path
uses those bound handles for bounded namespace teardown, wrapper reap,
pidfd-exit proof and close; numeric-PID-only cleanup is never a fallback.
Failure after wrapper bind, after init bind, or during readiness, discovery,
signal, teardown or close is unsupported/125 and cannot launch the benchmark.

This remains unprivileged user/PID-namespace containment, not a cgroup claim.
The pinned launcher and mandatory disposable proof remain prerequisites.
