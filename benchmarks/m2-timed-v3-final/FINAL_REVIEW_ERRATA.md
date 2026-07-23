# Final review errata

This is the authoritative post-collection interpretation of the Task 7h
failure. It supersedes only derived wording. It does not alter a frozen input,
collector, schedule, runtime artifact, raw byte, status ledger or historical
log.

## Status attribution

The directly observed timeout/watchdog exit was 124. After watchdog
termination, the child status file expected by `collect-locked.sh` was absent.
The sealed collector therefore took its explicit fallback branch
`else process_rc=143`.

Consequently, `STATUS|1|34|143` in `raw.tsv` and status 143 on the
`target-process` row in `collection-status.tsv` are collector-inferred default
values. They are not an observed child exit and do not establish the child's
exit code or terminating signal. The raw and status-ledger bytes remain
preserved exactly because they are historical collector output.

The target was nevertheless censored as directly observed: P34 emitted no
ATTEMPT, SUMMARY, stdout or stderr before watchdog exit 124, and P41/P45 never
started. The ordinary target validator rejects the two-line raw ledger. The
immediate post-watchdog artifact check passed and the process endpoint audit
reported `matches=none`, so the observed process was quiescent and the
endpoint was clean at that audit.

## Causal limits

The calibration measured catastrophic timed-v3 perturbation, and the target
run measured censoring at the watchdog boundary. Those observations do not
identify which timed-v3 observer cost caused the perturbation or censoring.

Source inspection exposes unbounded trace retention/concatenation, clock-call
frequency, allocation and other timed-v3 observer work as candidate causes.
No ablation or profile separated those candidates. In particular, this
package does not diagnose unbounded trace retention as the measured cause.

For any replacement diagnostic, bounded O(1) hot-path aggregation with no
unbounded operation trace is a conservative design constraint. It limits a
known class of observer risk; it is not a causal conclusion from this
measurement. No production optimization or capability change is selected.

## Replacement supervision constraint

Any future replacement protocol must put the launched command and descendants
in an explicitly supervised process group. On deadline it must signal TERM to
the group, wait a frozen grace interval, escalate to KILL if needed, prove the
group is gone, reap the supervised process, and then perform an immediate
endpoint audit. The protocol and grace interval must be frozen before the new
collection.

The sealed Task 7h collector did not retain that process-group/reap proof and
is not rewritten after the fact. Its observed clean post-watchdog process and
artifact endpoints remain valid historical evidence; the stronger rule is a
constraint on a future replacement protocol.
