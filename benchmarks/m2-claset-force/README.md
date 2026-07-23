# M2 exact stored-rule forcing experiment

This package records Task 7e on final uncommitted source based on outer
revision `699c8576ced289ad78a7d8ba1b856ef3b8f57040` and notes revision
`681adf67fb525ebc6d3528bcf5b417c928b0cbd5`.  It refines the lazy forcing
interval left by Task 7d without changing ordinary reconstruction, tactics,
search, Stats, or `clasetStep.blast_rule_step`.

## Measured-only adapter

`clasetStep.blast_rule_step_measured` is a caller-neutral parallel adapter for
the exact stored-rule path.  Its abstract lazy sequence can be pulled only by
`measured_rule_cases`, which returns empty, a yielded transition/tail, or
explicit cooperative interruption.  The adapter preserves ordinary result
order and shares the existing pure theorem, unification, goal and replay
helpers.  The only duplicated control logic is the measured exact `try_rule`
worker, positional attempt enumeration and direct-step lift.  Strong parity
tests cover intro/elim success, failed and multiple positional assumptions,
children/store/replay records, exact order, deep cutoff snapshots, callback
identity and repeated determinism.

Classical observations contain only goal position, intro/elim kind,
assumption position and phase.  The phases are:

- selected fixed theorem/current assumption and rendered goal;
- canonical freshening/setup;
- minor conclusion unification;
- elimination-major unification, when applicable;
- store collapse, theorem instantiation/normalization and hypothesis
  alignment;
- child/store construction;
- validation/action/direct-result construction;
- lazy result yield;
- direct child replacement;
- replay-record construction;
- record insertion.

Every Enter/Exit pair brackets one indivisible operation.  Failure or an
exception can leave an unmatched Enter.  Observer and stop exceptions are
wrapped only while crossing the legacy catch-all and then rethrown unchanged,
including `HOL_ERR`, non-HOL exceptions and runtime `Interrupt`.

`blastReconstruct.reconstructWithMeasuredDetailed` combines each classical
event with the caller-owned one-based script position and SafeRule/UnsafeRule
and duplicate labels.  Its `detailed_measured_result` retains both the outer
reconstruction snapshot and latest stored-rule snapshot plus exact aggregate
counters in `detailed_statistics`.  The Task 7d `statistics`,
`measured_result`, `reconstructWithMeasured` and `reconstructMeasured` API is
unchanged: its separate original worker uses ordinary stored-rule forcing,
has only the original outer checkpoints, and performs no Task 7e observation
or polling.  Ordinary entry points retain their original worker.

## Reproduction

From the repository root, install and build the retained harness, then run
the fixed schedule:

```sh
cp .agent-files/benchmarks/m2-claset-force/m2clasetforce.sml \
  src/auto/blast/m2clasetforce.sml
cmp .agent-files/benchmarks/m2-claset-force/m2clasetforce.sml \
  src/auto/blast/m2clasetforce.sml
(cd src/auto/blast && Holmake m2clasetforce.uo)
.agent-files/benchmarks/m2-claset-force/run-claset-force.sh
awk -f \
  .agent-files/benchmarks/m2-claset-force/verify-claset-force.awk \
  .agent-files/benchmarks/m2-claset-force/raw.tsv \
  > .agent-files/benchmarks/m2-claset-force/attempts.tsv
.agent-files/benchmarks/m2-claset-force/test-validator.sh
```

The schedule is exactly P34@7, P41@6 and P45@11.  Each row uses a fresh
sequential `--gcthreads=1` HOL process.  Search and every reconstruction
attempt share one 30-second cooperative deadline; `timeout` supplies an
independent 60-second whole-process watchdog.  The driver holds an atomic
schedule-wide lock from before its pre-run endpoint audit through its post-run
endpoint audit and cleanup.  That lock excludes an overlapping cooperating
invocation of this driver.  The two endpoint snapshots show no matching
harness process at those endpoints; they do not prove that no unrelated or
manual process existed throughout the interval.

`raw.tsv` is a compact 17-line protocol: attempt entry/result, one stdout row
and terminal status.  The harness counts outer and stored-rule observations
independently and checks its latest stored event against the returned report.
The external validator checks exact process/attempt order, the complete
56-field result schema, known phases, coherent optional stored context,
observer/counter identities, complete outer/stored phase and kind subtotals,
and the prefix relations implied by non-nested stored-rule observation.
Each problem block is fixed at one, three and one attempts respectively.  It
must begin with `attempt_enter`, contain every matching `attempt_result` in
exact order, and have no active or missing attempt when its sole stdout row
appears.  Stdout is a hard boundary: no later marker is permitted.  Exactly
one status row follows stdout and terminates the block; no later row is
permitted.  The three complete blocks remain in fixed schedule order.
It also checks that major-unification entries do not exceed minor-unification
entries, a concrete SafeRule snapshot is not marked duplicate, and every
concrete current outer/stored phase has a positive corresponding entry count
(with a positive aggregate exit count for an Exit snapshot).  It preserves
the prefix balances rather than requiring a failed or exceptional Enter to
have an Exit.  The global identity is `stop_polls = search checkpoints +
sum(reconstruction checkpoints)`.  `attempts.tsv` retains every stdout
counter and is derived only after those checks.

Fixed schedule/control numerals use exact canonical lexemes.  Positive
decimals have grammar `[1-9][0-9]*`.  This covers the outer row's fixed run,
position, problem, depth, budget and watchdog; the marker problem and attempt
identifier; and stdout's fixed run, position, problem, depth, budget and
attempt total.  Each value must also equal its scheduled literal; process
status is exactly `0`.  Thus signs and leading zeroes are rejected for those
fields.  Elapsed seconds instead use unsigned decimal grammar
`[0-9]+(\.[0-9]+)?` and are checked numerically in `[30,60)`; leading zeroes
and any fractional precision remain valid.  Arbitrary nonnegative counters
retain grammar `[0-9]+`, including leading zeroes.  Variable positive snapshot
positions use that digit grammar plus a numeric greater-than-zero check.  No
canonical claim is made for either class.

For the stored snapshot option, fields 8--14 are jointly absent or concrete;
field 15 is the nested assumption option (`none` for intro, positive for elim).
An absent snapshot has `none` in all eight serialized fields and zero stored
observer/classical counters (fields 17--19 and 39--56).  Outer setup can have
already occurred before the first lazy stored-rule event, so its separately
tracked outer phase counter is not conflated with stored observation.

`generate-validator-fixture.awk` mechanically supplies a valid interruption
before the first stored observation and at Enter and Exit for all eleven
classical phases.  `test-validator.sh` proves that all 23 synthetic prefixes
are accepted and reruns all 15 prior negatives.  Six further mechanically
generated-and-retained negatives cover stdout before any attempt, stdout
before an active attempt's result, a marker after valid stdout, and
noncanonical run, attempt-id and status numerals.  The test reproduces all
twelve generated retained fixtures byte-for-byte before requiring all 21
negatives to reject with a diagnostic.  These checks cover the stated
serialization, ordering, lexical and counter invariants; they are not a claim
that every semantically impossible state is excluded.

The raw capture is the chronologically first complete locked run after the
final API repair.  Its source/object/harness build finished before the
07:24:35 UTC lock acquisition; the lock was released at 07:26:26 after a clean
post-run endpoint snapshot.  The original completion-only validator rejected
this semantically valid capture because its deadline landed within partial
phase prefixes.  That raw capture and rejection provenance are retained.  A
later complete locked replication is retained separately as non-authoritative
endpoint/status evidence.  No capture was selected because its scheduled
cutoffs happened to satisfy completion-only counter equalities.

The authoritative lock audit is the 22-line `process-audit.txt`, byte-identical
to `rejected-schema-process-audit.txt`.  Before restoration, the contaminated
29-line file was preserved as `contaminated-appended-process-audit.txt`.  Its
first 22 lines are the authoritative ledger, followed by a 07:32:07 post-run
endpoint/release block.  The retained evidence establishes the content and
timestamp of that append but not the responsible process or mechanism, so its
cause is recorded as unknown.  The later replication audit/status files are
separate and non-authoritative.

## Results and limits

- P34@7: one Interrupted/NONE attempt.  It made 925 stored-rule attempts
  (18 intro, 907 elim) and yielded/recorded 158 direct results.  The cutoff
  was observed at outer `AlternativeEnumeration/Enter`; the latest classical
  event was script 348 UnsafeRule, duplicate, elim assumption 18,
  `MinorUnification/Exit`.
- P41@6: two Completed/NONE attempts made 1,024/1,046 stored-rule attempts
  and yielded 144/166 direct results.  Attempt three was Interrupted/NONE
  after 78,376 attempts (15 intro, 78,361 elim) and 5,335 yields.  It stopped
  at outer `AlternativeEnumeration/Enter`; the latest classical event was
  script 30 SafeRule, elim assumption 1, `ChildStoreConstruction/Exit`.
- P45@11: one Interrupted/NONE attempt.  It made 1,251 stored-rule attempts
  (32 intro, 1,219 elim) and yielded/recorded 234 direct results.  The cutoff
  was observed at outer `AlternativeEnumeration/Enter`; the latest classical
  event was script 378 SafeRule, elim assumption 1,
  `AttemptSelection/Exit`.

All processes returned status zero in 30.000--30.044 seconds and remained
below the watchdog.  These are instrumented protocol durations, not a
production performance baseline.  Counts measure work, not elapsed-time
dominance.  Cutoff counters and latest phases vary with deadline scheduling;
the last phase is explicitly noncausal and can be merely historical when the
outer cutoff is observed.  The evidence selects no optimization.

If another diagnostic is needed, the smallest supported next step is
measured-only elapsed-time accumulation across these existing subphases.  It
must determine time distribution before any attempt-count or unification
optimization is proposed.

## Verification scope

The retained final classical and default-level blast selftests are green.
They include all focused Task 7e regressions and unchanged default Pelletier,
Table-1 and set assertions.  Halting II is not exercised at default level and
remains for the parent `HOLSELFTESTLEVEL=2`/full gate.  The parent also owns
the broader `upto-auto` and full-distribution gates.

`integrity.log` records source/object freshness, commands, validators, style,
diff and empty harness-residue audits.  From the repository root, run:

```sh
sha256sum -c \
  .agent-files/benchmarks/m2-claset-force/checksums.sha256
```

This verifies the final source, plan and every retained artifact, including
the authoritative, contaminated, rejected-schema and later-replication audit
artifacts under their explicit labels above.
