# M2 classical phase elapsed-time diagnosis

Archive note (2026-07-23): the diagnostic functions described below were
removed; consult git history for their implementation.

This package records Task 7f on final implementation source.  It adds no
search or proof capability.  The ordinary classical/reconstruction workers,
the Task 7d API, and the Task 7e untimed detailed API retain their behavior;
timing is available only through distinct diagnostic entry points.

## Current authoritative state

The authoritative evidence is the uniquely named post-terminal-boundary-fix
`regenerated-final-*` chain.  It follows forced UI/UO regeneration and full
level-2 classical/blast selftests.  The unchanged predeclared schedules ran
exactly once in active-calibration, representative-calibration, target order.
`POST_BOUNDARY_FIX_PREDECLARATION.md` identifies this current chain and its
inherited predeclared constraints.
`REGENERATED_FINAL_LOCKED_SUMMARY.md` contains the reviewed measurements,
contexts, counters, generated calibration summary, hashes and unchanged
diagnostic conclusion.  `regenerated-final-expectations.tsv` pins every exact
attempt value and the independent comparator passes.

The immediately preceding final chain and its complete build, selftest,
calibration, target, expectation, audit, checksum and environment artifacts
are frozen under `pre-boundary-fix-history/`.  They are clearly historical,
non-authoritative, and were not selected or reused.

The unprefixed raw/calibration/audit files below are retained pre-review
evidence.  Their target endpoint audit used `[m]2clasetforce`, not
`[m]2clasetime`; it therefore made no relevant endpoint-absence claim,
although its atomic lock still excluded cooperating drivers.
`pre-boundary-fix-history/repaired-final-active-calibration-raw.tsv` is a
later pre-final ledger invalidated by forced object regeneration.  None of
the historical evidence was selected or reused as final evidence.

## Timing contract

`clasetStep.blast_rule_step_timed` takes an injected clock.  An interval starts
after its phase Enter observer and cooperative stop poll, and is accumulated
immediately before the Exit observer and poll.  Failed/backtracked operations
are accumulated before their exception is re-raised, without fabricating an
Exit.  Enter interruption contributes no interval; Exit interruption sees the
already-recorded interval.  Clock/observer/stop HOL_ERR, custom exceptions and
Interrupt cross legacy catch-all boundaries unchanged.  A backwards clock is
reported as HOL_ERR.  Production measurements pass `Time.now`; wall-clock
non-monotonicity remains a platform assumption.  Clock reads and reference
updates are instrumentation overhead.

The eleven classical phases are non-nested.  Their exact `Time.time` sum is
`classical_time`.  Timed detailed reconstruction captures its terminal clock
immediately on Completed SOME, Completed NONE or Interrupted, before detailed
statistics and classical snapshots are aggregated.  Thus
`attempt_wall_time - classical_time` is unmeasured outer reconstruction,
observer and timing work only up to the terminal outcome; it excludes report
aggregation.  Process time minus the sum of attempts contains search, driver
and post-attempt work.  Neither remainder is attributed to a phase.

The fake-clock regression covers all three terminal outcomes with exactly two
outer clock reads and a fixed terminal value; a third read fails the test.
Clock exception identity, phase timing, untimed parity and ordinary paths are
otherwise unchanged.

## Post-boundary-fix authoritative calibration and target

`summarize-calibrations.awk` portably derives medians, full ranges,
timed/untimed ratios and percentage changes from the two final raw ledgers.
`validate-calibrations.sh` regenerates the TSV and `cmp`s it against
`regenerated-final-calibration-summary.tsv`, in addition to its exact schedule
and work checks.  The test driver changes only one elapsed value while leaving
schedule and work untouched; the locked-summary comparison rejects that
thirteenth adversary.

| Workload | Untimed median [range] s | Timed median [range] s | Change |
|---|---:|---:|---:|
| P38@4 | 1.626393 [1.624928--1.687233] | 1.639761 [1.628874--1.680046] | +.82% |
| P43@5 | 12.678592 [12.398727--12.718826] | 12.557997 [12.447331--12.614098] | -.95% |
| P34@6 | .015938 [.015787--.015955] | .015898 [.015876--.015918] | -.25% |
| active fixture | .029952 [.029760--.041088] | .044031 [.033360--.045169] | +47.01% |

The one target driver held its corrected `[m]2clasetime` audit lock from
11:14:26 through 11:16:19 UTC.  Both endpoints were clean and all status rows
were zero.  Process/attempt/classical seconds are P34@7
31.911690/31.390598/16.514289, P41@6
30.005085/28.653267/20.338861, and P45@11
30.004055/29.492010/16.936954.  Exact counters, phase totals, shares and
contexts are in the locked summary and attempts/expectations TSVs.

## Pre-review calibration (retained, non-authoritative)

The schedules were fixed in `CALIBRATION_PREDECLARED.md` before timing.  The
18 fresh-process representative rows compare detailed untimed versus timed
mode with exact outcome, search counters and every per-attempt Task 7e counter
vector equal.

| Workload | Untimed median [range] s | Timed median [range] s | Median change |
|---|---:|---:|---:|
| P38@4 (22 attempts) | 1.419929 [1.419052--1.599645] | 1.426992 [1.426971--1.653052] | +0.50% |
| P43@5 (2 attempts) | 12.590505 [12.358639--12.611430] | 12.582201 [12.395425--12.619564] | -0.07% |
| P34@6 (0 attempts) | 0.056378 [0.015914--0.057331] | 0.018904 [0.015883--0.057207] | -66.5% |

P34 is startup/no-reconstruction noise, not a speedup.  The reconstruction-
active stored-elimination fixture replays one identical kernel-valid tableau
1,000 times in each of five paired repetitions.  Every replay has identical
counters (48 checkpoints, 13/13 outer, 22 stored, 11/11 stored boundaries).
Untimed median is 0.029722 s [0.029544--0.030378], timed median is 0.033207 s
[0.033105--0.060614]: +11.7%.  The first timed value is retained as a high
outlier.  Calibration quantifies perturbation; no target time is corrected.
Calibration schedules did not predeclare external watchdogs; all completed
normally, but no calibration watchdog claim is made.

## Pre-review target run (superseded after review)

The first driver invocation failed before any target process because the
copied schedule contained literal escaped separators.  Its audit is retained
as `preflight-rejected-process-audit.txt`; no timing row existed.  After the
encoding-only repair, the chronologically first complete run is `raw.tsv`.
The atomic driver lock was held from 09:08:30 through 09:10:22 UTC across the
pre/post endpoint audits and sequential P34@7, P41@6, P45@11 processes.  The
retained endpoint snapshots used the wrong executable pattern, so they do not
show absence of this harness.  The lock excludes another cooperating driver,
not unrelated manual load.  All processes returned status zero under
the shared 30-second cooperative deadline and 60-second watchdog.

| Problem | Process | Attempt wall | Classical | Process minus attempts | Attempts minus classical |
|---|---:|---:|---:|---:|---:|
| P34@7 | 30.033079 | 29.515373 | 16.174146 | 0.517706 | 13.341227 |
| P41@6 | 30.001415 | 28.831875 | 20.434062 | 1.169540 | 8.397813 |
| P45@11 | 30.023683 | 29.477225 | 16.687511 | 0.546458 | 12.789714 |

Classical measured time is 53.85%, 68.11% and 55.58% of process time.
Reconstruction attempts are 98.28%, 96.10% and 98.18%.  P34/P45 have one
Interrupted attempt; P41 has two Completed NONE attempts and one Interrupted
attempt.  Every attempt and its snapshot/counters/times is retained.

| Phase | P34 seconds (% classical) | P41 seconds (% classical) | P45 seconds (% classical) |
|---|---:|---:|---:|
| attempt selection | .067098 (.41%) | 3.960235 (19.38%) | .260846 (1.56%) |
| freshening/setup | .016551 (.10%) | .419667 (2.05%) | .022302 (.13%) |
| minor unification | 13.054752 (80.71%) | 10.173177 (49.79%) | 12.160503 (72.87%) |
| major unification | 2.538504 (15.69%) | 1.803298 (8.82%) | 2.759457 (16.54%) |
| rule instantiation | .128909 (.80%) | .650933 (3.19%) | .467263 (2.80%) |
| child/store | .092026 (.57%) | .717909 (3.51%) | .271127 (1.62%) |
| direct result | .043147 (.27%) | 1.294988 (6.34%) | .062305 (.37%) |
| lazy yield | .000057 | .001081 | .000095 |
| child replacement | .154005 (.95%) | .876531 (4.29%) | .451228 (2.70%) |
| replay record | .000097 | .001617 | .000131 |
| record insertion | .079000 (.49%) | .534626 (2.62%) | .232254 (1.39%) |

Minor conclusion unification is the largest measured phase, but it is only
43.47%, 33.91% and 40.50% of total process time.  Meanwhile 8.40--13.34 s of
each attempt block remains unmeasured outer reconstruction.  The evidence does
not justify optimizing unification alone.

The smallest next diagnostic splits minor unification into normalization,
store walk/decomposition/binding and failure/rollback time, while separately
timing outer alternative enumeration/replay recursion excluding the already
timed classical intervals.  Per-call maxima or bounded histograms are needed:
P34/P45 totals suggest expensive tails, while P41 has many cheap attempts.
Only then can an optimization be selected without inferring cost from counts.

## Reproduction and validation

From the configured repository root, reproduce the exact harness setup,
forced classical/blast/harness rebuild, and both level-2 selftests with one
command and a new output directory:

    output=/tmp/isabelle-tactics-task7f-20260720-root/reproductions/fresh
    .agent-files/benchmarks/m2-claset-time/reproduce-post-boundary-build.sh \
      "$output"

The Linux preflight requires GNU `cp -a`, `realpath`, `stat`, `find`, and
`env`, plus `/usr/bin/python3` for its process-group supervisor and
`/usr/bin/strace` with ptrace permission for the real-target file-access
audit.  OUTPUT must
be a fresh absolute canonical path outside the entire source repository.  Dot
and dotdot spellings, symlinked parents, existing paths, and containment in
either direction are rejected.  It hashes and stats every authoritative
implementation, test, harness and rule input, both relevant Holmakefiles, the
required HOL tools/configuration, and baseline build artifacts.  It then makes
a type-preserving copy of the complete repository under `OUTPUT/worktree`,
removes copied top-level linked-worktree `.git` metadata and copied external
`.codex`, `.pi`, and `.claude` skill metadata before configuration, rebases
copied absolute internal symlinks, and categorizes every remaining absolute
link.  Build-relevant, source-internal and sigobj links must resolve inside
the copy; other absolute links are retained in the raw count/path audit
without a blanket containment claim.  It then runs the supported
`poly < tools/smart-configure.sml` in the copy with `HOLDIR` unset.

Copied `Holmake --dbg=startup --help` and `hol heapname` diagnostics prove
the startup HOLDIR, explicit state0, default state, sigobj and tools paths are
below the copy.  A tiny copied diagnostic Holmakefile then invokes copied
Holmake on one explicit harmless target with `--no_preexecs`, `--no-project`,
`--no_overlay`, and `--no_prereqs`.  Its debug/recipe output, Holmakefile and
created target are retained; the existing target canonicalizes below the copy
and regenerated launchers/configs and diagnostics may not resolve the
original root.  Only then may the full mode install harnesses or build.
Every external ancestor of the future copy is checked before copying and must
contain none of `Holmakefile`, `.hol_preexec`, `holproject.toml`, or
`holproject.local.toml`.  The real copied target runs under
`strace -f -e trace=file`; any syscall naming the original root fails the
preflight, including probes and reads as well as writes.  The raw trace and
zero-match audit are retained.
`PATH` is exactly COPY/bin plus validated `/usr/local/bin:/usr/bin:/bin`; no
inherited PATH or exported HOLDIR is used.  Comprehensive source manifests are
rechecked after copying and after the run; the copy manifest must match the
pre-copy source manifest.  Drift aborts with retained diagnostics.  The output
contains build/test logs, command statuses, removal/build-start evidence,
hashes, and non-strict timestamp checks for every direct prerequisite edge in
the classical, blast, selftest, and three harness chains.  Success, failure,
HUP, INT, TERM, and a repeated signal retain OUTPUT.  Every potentially
spawning command is owned by a Python supervisor in a new session/process
group.  Outer traps only forward every received signal to the active
supervisor PID and return.  The supervisor forwards TERM first, KILL on signal
count two or grace expiry, verifies group disappearance and reaps; the outer
shell then reaps it and accepts quiescence only from retained group-gone PASS
evidence.  An unsignaled child return of `-N` is normalized to `128+N`.
It does not run timing
measurements.  Use `--print` for a non-mutating description and `--self-check`
for a small isolated-copy safety test.

Use `--relocation-check FRESH-OUTPUT` for a real copy, smart-configuration and
copied-tool diagnostic with no HOL build/test; it removes the disposable copy
and retains raw evidence.  `test-reproduction-isolation.sh` is a synthetic
filesystem/control-flow suite, not relocation evidence.  It retains raw data
whole-source-tree before/after manifests for print/self-check, canonical path
aliases, symlink parents, existing/contained output, harness and orphan
conflicts, concurrent input mutation, HUP/INT/TERM, repeated signals, active
descendant suppression, and source-tree immutability.  Signal cases invoke the
full outer script, target its published actual shell PID, and retain per-case
stdout, stderr, status, supervisor events, process snapshots and script
hashes.  Direct-supervisor unit cases separately pin ordinary exit 7 and an
independently SIGTERM-killed child normalized to 143.  Current retained
summaries are `reproduction-relocation-preflight.log` and
`reproduction-adversarial-tests.log`.  The former describes the exact
current-script namespace run documented in
`NAMESPACE_RELOCATION_INVOCATION.md`; its compact raw files are under
`authoritative-relocation-evidence/`.  Superseded claims are under
`pre-relocation-history/` and `pre-final-relocation-history/`.
The exact appendable rule fragment is `POST_BOUNDARY_FIX_HOLMAKE_RULES.txt`.
The already completed authoritative build is described, not made runnable, in
`POST_BOUNDARY_FIX_COMMAND_STATUS_TRANSCRIPT.txt`; the script is the only
supported runnable procedure.  Provenance is in
`POST_BOUNDARY_FIX_BUILD_PROVENANCE.md`.

For a non-authoritative reproduction from the repository root, use fresh
outputs so the retained ledgers are never overwritten:

    tmpdir=$(mktemp -d \
      /tmp/isabelle-tactics-task7f-20260720-root/replication.XXXXXX)
    OUTPUT="$tmpdir/active.tsv" \
      .agent-files/benchmarks/m2-claset-time/run-active-calibration.sh
    OUTPUT="$tmpdir/representative.tsv" \
      .agent-files/benchmarks/m2-claset-time/run-work-calibration.sh
    awk -f .agent-files/benchmarks/m2-claset-time/summarize-calibrations.awk \
      "$tmpdir/representative.tsv" "$tmpdir/active.tsv" \
      > "$tmpdir/calibration-summary.tsv"
    .agent-files/benchmarks/m2-claset-time/validate-calibrations.sh \
      .agent-files/benchmarks/m2-claset-time \
      "$tmpdir/representative.tsv" "$tmpdir/active.tsv" \
      .agent-files/benchmarks/m2-claset-time/calibration-schedule.tsv \
      .agent-files/benchmarks/m2-claset-time/active-calibration-schedule.tsv \
      "$tmpdir/calibration-summary.tsv"
    OUTPUT="$tmpdir/target.tsv" AUDIT="$tmpdir/process-audit.txt" \
      .agent-files/benchmarks/m2-claset-time/run-claset-time.sh
    awk -f .agent-files/benchmarks/m2-claset-time/verify-claset-time.awk \
      "$tmpdir/target.tsv" > "$tmpdir/attempts.tsv"

Such a replication is not authoritative and must not replace or select a
cutoff over the retained run.  The calibration schedules had no external
watchdog.

`validate-calibrations.sh` requires exact paired work identities and an exact
regenerated calibration summary.
`verify-claset-time.awk` accepts the valid partial Enter/Exit prefixes and
checks the complete protocol, nonnegative times, exact phase sum (decimal
serialization tolerance), classical/attempt/process bounds, aggregate attempt
times and all Task 7e counter identities.  `test-validator.sh` accepts partial
timed target positives and exact calibration schedules, then rejects thirteen
retained time, bound, status, schema, order, schedule, mode, zero-count/time
and exact counter/context mutations, including elapsed-only summary drift.
Valid partial prefixes remain accepted.
