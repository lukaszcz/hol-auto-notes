# Task 7h timed-v3 measurement predeclaration

This package is the sole intended authoritative Task 7h measurement for
revision `d23e4ba254929547dd601186b9fb72b199706610`. It imports no timed row,
summary, or conclusion from Task 7g and changes no tracked source. All claims
below are frozen before any benchmark clock.

## Question and hypotheses

Timed-v2 selected two broad owners but no optimization. Timed-v3 asks which
operation-honest traversal subcomponent owns the coarse minor-unification
time, and whether AlternativeEnumeration time is accumulated across many
bounded pulls or dominated by outliers/residual time. The candidates are
persistent store lookup/walk, structural decomposition/recursion,
pattern/occurs/allow decisions, persistent binding/update, and explicit
traversal other. Normalization and immutable-store cleanup remain retained
controls. A null result (no component crosses the rule, an outlier dominates,
or residual is too large) is acceptable and selects only a smaller diagnostic.

## Immutable schedules and retry rule

All processes are fresh, sequential and use `--gcthreads=1` through the
generated HOL launcher. One atomic directory lock covers the full collection.
The representative schedule has exactly these 12 rows, in order: P38@4
v2,v3; P43@5 v2,v3; P43@5 v3,v2; P38@4 v3,v2; P38@4 v2,v3; P43@5 v2,v3.
The first pair in each semicolon-separated clause is one paired repetition.
The active schedule is exactly five paired 1,000-replay rows in alternating
order: v2,v3; v3,v2; v2,v3; v3,v2; v2,v3. The target schedule is exactly
P34@7 once, P41@6 three reconstruction attempts, and P45@11 once, in that
order. Every target process shares a 30-second cooperative deadline and has
an independent 60-second watchdog.

There is no timing retry. A valid calibration row, attempt row, summary, or
complete target block is never rerun. Any nonzero process/watchdog status,
malformed/incomplete row, artifact drift, endpoint match, or failed validator
aborts this package as incomplete; a replacement authoritative package would
be required. Before seal only, a protocol/build repair may be made after
preserving complete before/after bodies, all statuses/logs, the sole failure
diagnostic, and an exact diff, followed by the entire preflight from clean
state. Such a pre-seal repair is not a timing retry.

## Raw protocol and exact identities

Each target attempt retains the complete timed-v2 context: canonical target
literals, completion/result, latest outer and stored-rule contexts, all 37
detailed counters, observer counts, all 11 classical subphases plus total,
attempt/Alternative/replay/other/outer times, minor calls/failures, coarse
normalization/traversal/cleanup/minor times and maxima, and exact
classical+outer=attempt and Alternative+replay+other=outer identities.

Timed-v3 additionally retains event counts and total/max time for lookup/walk,
structural recursion, pattern/occurs/allow decisions, persistent binding, and
explicit other. Their times sum exactly to coarse traversal; normalization +
coarse traversal + zero cleanup equals minor time. Binding-operation failures
are bounded by binding events. Every component maximum is bounded by its
total and the overall minor maximum bounds every component maximum.

Alternative pulls retain completed, exhausted/failed and interrupted counts,
their totals and maxima, overall pull total/maximum, explicit residual,
classical elapsed snapshot count and sequence-statistics read count. Outcome
counts sum exactly to the retained Alternative-pull counter. Pull outcome
times sum to pull total; pull total + residual equals Alternative time. Every
outcome maximum is bounded by its total and by overall maximum. The snapshot
count is even and no larger than twice pull count (an Enter cutoff can own an
untimed interrupted pull). Sequence statistics are never read while pulling;
the source/selftests establish this and each report records exactly three
terminal reads per stored-rule sequence. Attempt residual is exactly zero.
Summaries mechanically retain sums/maxima for every preceding scalar plus
process residual, search counters, stop polls and all earlier identities.

Canonical positive scheduled numerals are `[1-9][0-9]*`; arbitrary natural
counters are `0|[1-9][0-9]*`; emitted time is exactly an unsigned integer,
dot, and nine digits. Modes are exactly `v2`/`v3`; target completions are the
fixed completed/interrupted schedule; result is `none`; outer/stored boundary,
phase, step, duplicate and rule-kind vocabularies are closed lists in the
validator. Each new scalar has an independent lexical adversary. Independent
semantic adversaries cover every new partition, count/read identity, zero,
maximum and summary relationship. Every adversary must produce exactly its
one intended diagnostic, nonzero status, and no `PASS`.

## Interpretation fixed before timing

A traversal subcomponent is a candidate only if it is at least 40% of coarse
traversal and at least 20% of attempt time on at least two targets. It is
described as volume-driven only if its maximum is at most 5% of its category
total on every target on which both candidate thresholds hold.

Alternative pull volume is a candidate only if AlternativeEnumeration is at
least 40% of attempt time on at least two targets and maximum pull is at most
5% of pull total on every such target. Alternative residual must be at most
5% of Alternative time on every such target; otherwise no specific pull
conclusion is permitted. Even when thresholds cross, a concrete optimization
is selected only if the winning bucket maps to one principled code mechanism.
If it remains a compound mechanism, the verdict states the next smaller
diagnostic and selects no optimization.

Paired outcomes, search counters and ordered 37-field reconstruction
signatures must match exactly before elapsed calibration is interpreted.
Representative v3/v2 median ratios must both lie in [0.95,1.05] for target
time-owner claims to be treated as causally comparable; otherwise target
figures are descriptive only. The active median/range is always reported. If
its absolute median change exceeds 25%, no micro-cost or projected speedup
claim may be made from pull or operation timing. Calibration never corrects
target observations.

## Pre-clock closure and gates

Before seal, the package freezes complete bodies and byte hashes for this
predeclaration, repair ledger, seal plan, all three harnesses, build file,
schedules, preparation/collection/runner scripts, closure manifest tool,
endpoint synthetic, validators, fixture generator/mutator, all 88 independent
adversaries, summarizers, summary verifier, read-only selfcheck and integrity
tools. Preflight force-cleans/builds classical, blast and all harnesses; runs
both level-2 selftests; runs positives/adversaries; and proves each endpoint
pattern detects both a wrapper and `bin/hol ... task7h...` child without
matching the audit process.

The runtime closure contains every regular file below `src/auto` (therefore
all source/UI/UO and loaded automation artifacts), harness SML/UI/UO/exes,
Holmakefile, exact `bin/hol`, `bin/Holmake`, `bin/hol.state0`, all four
configure/smart-configure bodies, and the exact resolved host tools used by
the frozen workflow. Repository paths are C-sorted, followed by declared-order
tool records. Pre/post manifests around representative, active and target
segments must each be byte-identical to the frozen closure. Immediate
non-self-matching endpoint snapshots must be clean. Final validation,
regenerated summaries, full seal, typed regular-file/symlink inventory,
checksums, two read-only selfchecks and final source/index identity are
mandatory.
