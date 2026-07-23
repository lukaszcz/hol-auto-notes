# Historical, superseded predeclaration

This live top-level document is retained only as the historical declaration
for the failed timed-v4 collection attempt. It is not a current claim that
this package is "wholly fresh" or authoritative. `FINAL_REVIEW_ERRATA.md`
and `CURRENT_ASSESSMENT.md` control the retained observation; the exact
pre-collection body remains frozen byte-for-byte at
`frozen-inputs/PREDECLARATION.md`.

The original historical body follows unchanged below.

---

# Task 7j bounded timed-v4 predeclaration

This wholly fresh evidence package is for exact source revision
`244b01d7189ac803df48e246a483c33b553e3daa`. It imports no timing row from
timed-v2 or timed-v3. Existing timed-v2 is the only baseline; timed-v3 is not
a baseline because its catastrophic observer cost failed comparability.

## Question, fixed schedules, and formulas

The question is whether the new bounded O(1) timed-v4 summary restores
causal timing comparability with timed-v2 while retaining operation-honest
minor-unification and Alternative-pull distributions. All children are fresh,
sequential, single-GC-thread HOL processes.

Representative calibration is exactly 12 children in schedule-file order:
P38@4 v2,v4; P43@5 v2,v4; P43@5 v4,v2; P38@4 v4,v2;
P38@4 v2,v4; P43@5 v2,v4. Thus each problem/mode has three observations.
P38 and P43 are the unchanged Pelletier formulas embedded in
`task7jcalibration.sml`. Each fixed-depth search must exhaust with `none`,
and paired outcome, attempt count, eight search counters, and every ordered
37-field reconstruction signature must match exactly.

The active control is exactly ten children: five paired repetitions of the
same 1,000-replay stored-elimination fixture, ordered v2,v4; v4,v2; v2,v4;
v4,v2; v2,v4. Paired nine-counter signatures must match exactly.

The downstream schedule, and only that schedule, is P34@7 once, P41@6 with
its pre-existing three reconstruction attempts, and P45@11 once, in that
order. The formulas are embedded literally in `task7jmeasurement.sml`.

## Metrics, arithmetic, and stop/go rule

For three observations, the median is the second element after numeric sort;
range is minimum through maximum. The reported perturbation ratio is
`v4 median / v2 median`; percent change is `100 * (ratio - 1)`.

The representative causal-comparability gate passes only if both P38@4 and
P43@5 median ratios lie in inclusive `[0.90,1.10]`, after exact paired parity
passes. This wider band than the earlier exploratory 5% band is fixed to
avoid deciding from three noisy observations while still rejecting material
observer perturbation. The independent active-control gate passes only if
its absolute median change is at most 25%. Both gates must pass. Any failed
gate stops collection before P34/P41/P45; the calibration, censoring/status,
failed gate, process audits, validation and package closure remain the result.
No target time-owner, projected-speedup, micro-cost, capability or optimization
claim is allowed after a failed gate.

If both gates pass, targets run exactly once. The v3 interpretation thresholds
are retained: a traversal component is a candidate only if it owns at least
40% of coarse traversal and 20% of attempt time on at least two targets, and
is volume-driven only when its maximum is at most 5% of its total on each
qualifying target. Alternative-pull volume is a candidate only if Alternative
owns at least 40% of attempt time on two targets, maximum pull is at most 5%
of pull total, and pull residual is at most 5% of Alternative time on each.
Even crossing thresholds selects an optimization only when the bucket maps to
one general principled mechanism; otherwise the conclusion is diagnostic.

## Timeouts, censoring, and process control

Every representative child has an independent 45-second watchdog; every
active child has 15 seconds. Each target shares the unchanged 30-second
cooperative search/reconstruction deadline and has an independent 45-second
watchdog. A watchdog expiration is right-censoring, never a completion time.
There is no timing retry and no default/inferred child status. A nonzero exit,
signal, timeout, malformed or incomplete output, artifact drift, or process
audit failure terminates the chain and is retained honestly.

Every child is launched by the frozen `supervise.py` in a new process group.
At watchdog expiry it sends TERM to the whole group, waits the fixed three-
second grace, sends KILL if needed, calls `wait` to reap the group leader,
records the observed wait return code and exact exit status or signal, and
verifies `killpg(pgid, 0)` reports the group gone. Calibration uses this same
policy. Immediate pre-collection, post-calibration and post-target endpoint
audits are mandatory.

## Schema, boundedness, validation, and closure

Canonical scheduled positive numerals use `[1-9][0-9]*`; natural counters use
`0|[1-9][0-9]*`; elapsed fields use an unsigned integer plus exactly nine
fractional digits. Modes, outcomes, boundaries, phases, step/rule kinds and
duplicates use closed enums. Existing v3 arithmetic checks are reused for
the same v4 operation scopes and pull fields. Each v4 attempt additionally
records sequence-statistics reads, summary-statistics reads, and retained
trace allocations; exactly one terminal summary read and zero retained trace
allocations are required per reconstruction report, with attempt/summary sums.

Before any clock, complete protocol inputs are SHA-256 sealed. Forced
classical/blast builds and both level-2 selftests, harness builds, positive
fixtures, independent malformed/adversarial fixtures (including gate,
supervision and bounded-summary failures), clean source/index checks, runtime
closure identity and no-append checks must pass. Validators emit one primary
diagnostic and no PASS on failure. Historical bodies are never overwritten;
any repair retains the old complete body and exact patch. Final checksums,
package inventory, process audit, source/index cleanliness, and proof that
`.agent-files` remains ignored/untracked close the package.
