# M1 equal-work benchmark

This directory retains the source, commands, raw observations and summary for
the fixed-depth comparison between baseline `be308c56d` and M1 `c7f72c445`.
The benchmark is separate from the required unchanged 30-second full-search
test documented in `PLAN_phase_1_2_green.md`.

The asserted, pre-measurement depth schedule is P34 at depth 4 and P38, P41,
P42, P43 and P45 at depth 3.  These bounds are below the known censored
published-depth cases and were chosen before comparative samples were
collected.  The schedule must not be changed in response to timing outcomes.
At each bound both revisions deterministically exhaust the fixed-depth search
without a proof and return below 30 seconds.  Thus each paired row runs the
same configured tactic, theorem arguments, goal and explicit depth bound.
The common complete counters (`branches_created`, `branches_closed`, and
`choices_pruned`) check that the search-space work is unchanged.  They do not
claim that these bounds are the formulae's minimum proof depths.

A current-only calibration, performed before any baseline timing was observed,
showed that five single searches take only 1--8 ms and would therefore be
dominated by timer and scheduler noise.  The timed samples consequently use
the following predeclared batches: P34 500, P38 150, P41 300, P42 1, P43 600,
and P45 500 identical searches.  P42's one search took about 12 seconds in the
calibration; the others target at least roughly half a second per sample.
The harness checks that every iteration in a batch has the same outcome and
common counters, and prints both per-run and aggregate counters.  Each
iteration also reconstructs the invocation claset, matching a fresh
`BLAST_DEPTH_TAC depth []` call; the internal timer covers the whole batch but
still excludes process startup and heap loading.  Batch sizes are identical
between revisions and are not retuned after baseline results.

Exact preparation commands (from repository roots):

```sh
git worktree add --detach /tmp/hol4-m1-be308c56d be308c56d
(cd /tmp/hol4-m1-be308c56d && poly < tools/smart-configure.sml)
(cd /tmp/hol4-m1-be308c56d && bin/build --seq=tools/sequences/upto-auto)
cp .agent-files/benchmarks/m1/m1benchmark.sml \
  /tmp/hol4-m1-be308c56d/src/auto/blast/m1benchmark.sml
cp .agent-files/benchmarks/m1/m1benchmark.sml src/auto/blast/m1benchmark.sml
(cd /tmp/hol4-m1-be308c56d/src/auto/blast && \
  ../../../bin/Holmake m1benchmark.uo)
(cd src/auto/blast && ../../../bin/Holmake m1benchmark.uo)
REPETITIONS=3 .agent-files/benchmarks/m1/run-alternating.sh
START_REPETITION=4 REPETITIONS=9 \
  .agent-files/benchmarks/m1/run-alternating.sh
```

The generated `m1benchmark.sml`, `.uo`, `.ui`, `.o` and dependency files in
both `src/auto/blast/` directories are temporary residue and are removed after
the raw data are saved.  `environment.txt` records the host and toolchain;
`raw.tsv` is the original process output; `summary.tsv` is derived from it
without manual timing transcription:

```sh
awk -f .agent-files/benchmarks/m1/summarize.awk \
  .agent-files/benchmarks/m1/raw.tsv \
  > .agent-files/benchmarks/m1/summary.tsv
```

`calibration.tsv` retains the pre-measurement feasibility observations used to
fix the batch sizes.  In that preliminary harness revision the invocation
claset was built once outside the internal timer.  It is not part of the final
performance result.  The retained final harness instead rebuilds the claset
inside every timed iteration, matching complete fixed-depth tactic calls.

The current level-2 verification was rerun and retained exactly as
`verification-level2.log`:

```sh
(cd src/auto/blast && HOLSELFTESTLEVEL=2 ./selftest.exe) \
  > .agent-files/benchmarks/m1/verification-level2.log 2>&1
```

It confirms Pelletier 42/48 with the same six expected failures, published
Table-1 depths 6/9 with the same three expected failures, set problems 4/4,
and Halting II still failing as asserted at depth 7 within 120 seconds.

## Result

All 108 measured rows exhausted normally below 30 seconds per constituent
search.  For every formula, revision and repetition, the per-search and
aggregate counters are identical between revisions.  Current median batched
wall time is lower for P34 (18.4%), P42 (1.2%) and P43 (7.5%), but higher for
P38 (6.4%), P41 (5.7%) and P45 (25.8%).  The nine raw samples, full ranges and
ratios are in `summary.tsv`.  The slower-current distributions overlap their
baselines, so this does not establish statistical regressions; equally, it
does not demonstrate improvement for those three formulae.  M1's performance
criterion remains unmet for P38, P41 and P45.  These observations do not
establish proof at the full 30-second budget, a minimum proof depth, or a
universal speedup.
