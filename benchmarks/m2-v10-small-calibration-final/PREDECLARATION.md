# M2 v10 small ablation calibration: frozen declaration

This package measures only source revision
`244b01d7189ac803df48e246a483c33b553e3daa`.  It imports no timing row
from an earlier package and does not modify tracked source.

## Question and fixed work

The sole workload is Pelletier P38 at its published depth 4.  Every child
uses the literal formula in `task7kcalibration.sml`, the same invocation
claset, `searchGoalMeasured`, no search stop, and the same kernel-validation
continuation.  The fixed seed is the repository's unchanged claset at the
declared HEAD.  The expected outcome is completed exhaustion (`none`).

The four closed modes are:

- `A`: ordinary detailed measured reconstruction, with no timed diagnostic;
- `B`: timed-v2 reconstruction with direct `Time.now`;
- `C`: timed-v4 reconstruction with a counting clock that always returns
  `Time.zeroTime`;
- `D`: timed-v4 reconstruction with a counting `Time.now` clock.

The exact 20-child order is `schedule.tsv`: five repetitions, four modes per
repetition, fresh processes, sequential execution, no retry.  The first 16
children are a four-sequence Williams balance; the fifth block is fixed in
advance.  Each child has a 25-second v10 supervisor watchdog, one-second TERM
grace, one-second post-KILL grace, 0.05-second quiet interval and 0.01-second
poll.  Any watchdog, signal, nonzero status, malformed record, schema error,
artifact drift, endpoint match or other protocol failure stops the schedule
without retry.  Such an observation is censored and cannot enter ratios.

## Required parity and boundedness

Before timing is interpreted, all 20 rows must have exact equality of outcome,
attempt count, eight search counters and every ordered 37-field reconstruction
signature.  Each row must be P38@4 in exact schedule order.  C and D clock-read
counts must be equal and positive, both within each repetition and globally.
Every C/D reconstruction report must have zero sequence-statistics reads,
exactly one terminal summary-statistics read, and zero retained trace
allocations; row sums must therefore be `0`, `attempts`, and `0`.  The v4
implementation's own closed report construction additionally enforces pull
count and elapsed-partition invariants.  A/B must report these v4 fields as
`NA`.  No ratio is computed unless all parity and boundedness gates pass.

## Metrics and predeclared formulas

`T_A`, `T_B`, `T_C`, and `T_D` are medians of the five external supervisor
elapsed seconds; each mode also reports its full minimum--maximum range.  For
five values the median is the third numerically sorted value.  Diagnostic
internal attempt elapsed is reported only for B and D, whose clock is
`Time.now`; A and C report `NA`.

The low-overhead sanity ratio is `T_B/T_A` and is comparable only in inclusive
`[0.95,1.05]`.  The ablation quantities are fixed as:

- total timed-v4 increment: `T_D - T_A`;
- constant-clock/aggregation increment: `T_C - T_A`;
- real-clock acquisition increment: `T_D - T_C`;
- clock share: `(T_D - T_C) / (T_D - T_A)` only when the denominator is
  positive.

Classification is `clock-dominant` only if share is at least 0.80 and
`T_D/T_C` is at least 1.50.  `aggregation-material` applies when `T_C/T_A` is
at least 1.25.  Both predicates may hold (`both`).  If neither holds, or the
share denominator is nonpositive, classification is `mixed/indeterminate`.
The B/A gate is reported independently; failure makes the ablation
classification indeterminate rather than silently correcting observations.

These are process-level ablation observations.  Startup, collector overhead,
cache state, scheduling noise and interactions remain.  They do not prove a
microarchitectural cause and cannot select or authorize a source optimization.
They select only the next general diagnostic question.

## Protocol and stop rules

The package vendors the complete reviewed future-protocol directory from
`m2-timed-v4-final`, including v10 collector, supervisor, validator,
bootstrap, containment preflight, compatibility tests and dependencies.
Frozen input hashes and provenance are sealed before the first benchmark
clock.  The v10 collector owns each child transaction, exact PID-namespace
containment, raw durability/seal, supervisor schema gate, complete artifact
identity comparison and endpoint audit.  Final validation is exact-schema,
exact-order, closed-enum, canonical-number, EOF/no-append, cross-ledger and
work-signature validation.  Strong synthetic mutations must fail with one
diagnostic and no PASS before collection.

No P34, P41, P43 or P45 target exists in this protocol.  There is no long
target block, adaptive stop, replacement observation or retry.
