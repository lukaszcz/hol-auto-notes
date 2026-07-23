# Authoritative Task 7h collection outcome

This sealed chain did not produce a valid target measurement and was not
retried. The result is an authoritative failed measurement, not a partial
target dataset and not evidence selecting an optimization.

All 12 fresh representative processes and all ten fresh active processes
returned status zero in the exact frozen order. Paired outcomes, search
counters and ordered reconstruction signatures match exactly. Mechanical
medians [full ranges] are:

| Workload | timed-v2 seconds | timed-v3 seconds | v3/v2 | change |
|---|---:|---:|---:|---:|
| P38@4 | 1.645494 [1.622249--1.647912] | 17.381038 [17.283753--17.555089] | 10.562808 | +956.28% |
| P43@5 | 12.568361 [12.396127--12.638378] | 756.408587 [454.547679--779.761296] | 60.183550 | +5918.36% |
| active 1,000 replay | .037177 [.037103--.068938] | .053581 [.053528--.053775] | 1.441241 | +44.12% |

Both representative ratios are far outside the frozen [0.95,1.05] causal
gate, and active change exceeds the frozen 25% micro-cost gate. Calibration
therefore forbids causal target time-owner, micro-cost, projected-speedup or
optimization claims from timed-v3.

The target segment then began P34@7 under the frozen 30-second cooperative
deadline and independent 60-second watchdog. The process emitted no ATTEMPT,
SUMMARY, stdout or stderr before the directly observed watchdog exit 124.
After termination, the child status file was absent, so the collector used its
explicit default 143. Thus raw `STATUS|1|34|143` and the `target-process` 143
ledger field are collector-inferred values, not an observed child exit. The
ordinary target validator rejects that exact two-line raw ledger with its sole
diagnostic `verify-target: status/order/value`. The target post-closure
manifest still matched, the immediate process endpoint audit was clean, and
P41/P45 were never started.

Per the frozen no-retry rule, no process or valid row was rerun. Catastrophic
perturbation and target censoring are measured. Source inspection identifies
unbounded trace retention/concatenation, clock frequency, allocation and other
timed-v3 observer work only as candidate causes; no ablation or profile
separated them. Bounded O(1) hot-path aggregation with no unbounded operation
trace is therefore a conservative constraint on the next diagnostic, not a
measured trace-cause diagnosis.

Any replacement protocol must supervise an explicit process group, send TERM,
wait a frozen grace interval, escalate to KILL if needed, prove the group gone,
reap it, and immediately audit the endpoint. The current post-watchdog process
and artifact endpoints were clean, so this future constraint does not alter
the historical evidence or justify rewriting the sealed collector. No
production optimization or capability fix is selected. See
`FINAL_REVIEW_ERRATA.md` for the authoritative review correction.
