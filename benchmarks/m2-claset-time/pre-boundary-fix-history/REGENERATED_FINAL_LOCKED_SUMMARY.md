# Historical pre-boundary regenerated-final locked summary

Historical/non-authoritative notice: this summary predates the terminal-clock
boundary fix and is not the current measured result.  The current summary is
`../REGENERATED_FINAL_LOCKED_SUMMARY.md`.

This is the reviewed summary of the single regenerated-final authoritative
run.  `regenerated-final-expectations.tsv` pins every exact non-time field and
`verify-final-expectations.awk` compares them mechanically in row order.

The corrected audit held the atomic driver lock from 10:30:40 through
10:32:32 UTC.  Both endpoints ran `pgrep -af '[m]2clasetime'` and found no
matching process.  All three fresh sequential target processes returned
status 0; none reached the 60-second watchdog.

Exact target search vectors (stop polls, search checkpoints, inferences,
branches created/closed, choices pruned, max cost, cache hits, conversions):

    P34@7  3846595 3835238 503 100 100 489 7 467 9817
    P41@6 10759499 9979324 1576 245 645 5 6 2873 10807
    P45@11 3827252 3812018 739 237 237 717 11 246 7160

Attempt protocol and current contexts are exact: P34 has one Interrupted NONE
attempt at outer Enter/AlternativeEnumeration and stored
Exit/MinorUnification; P41 has two Completed NONE attempts at outer
Exit/ReplayRecursion and stored Exit/MinorUnification, followed by one
Interrupted NONE attempt at outer Enter/AlternativeEnumeration and stored
Exit/AttemptSelection; P45 has one Interrupted NONE attempt at outer
Enter/AlternativeEnumeration and stored Exit/MinorUnification.  The locked
expectations TSV contains every remaining exact observation, entry/exit,
checkpoint, phase, rule-kind and reconstruction counter.

| Problem | Process | Attempts | Classical | Process minus attempts | Attempts minus classical | Classical/process | Attempts/process |
|---|---:|---:|---:|---:|---:|---:|---:|
| P34@7 | 30.055021 | 29.498945 | 16.624000 | 0.556076 | 12.874945 | 55.31% | 98.15% |
| P41@6 | 30.001364 | 28.781906 | 20.436422 | 1.219458 | 8.345484 | 68.12% | 95.94% |
| P45@11 | 30.002653 | 29.455225 | 16.737128 | 0.547428 | 12.718097 | 55.79% | 98.18% |

| Phase | P34 seconds (% classical) | P41 seconds (% classical) | P45 seconds (% classical) |
|---|---:|---:|---:|
| attempt selection | .069726 (.42%) | 3.926697 (19.21%) | .259811 (1.55%) |
| freshening/setup | .017238 (.10%) | .417880 (2.04%) | .022742 (.14%) |
| minor unification | 13.605446 (81.84%) | 10.220310 (50.01%) | 12.267324 (73.29%) |
| major unification | 2.433251 (14.64%) | 1.822324 (8.92%) | 2.722885 (16.27%) |
| rule instantiation | .130033 (.78%) | .655651 (3.21%) | .461326 (2.76%) |
| child/store | .093990 (.57%) | .723712 (3.54%) | .266479 (1.59%) |
| direct result | .039859 (.24%) | 1.285292 (6.29%) | .061410 (.37%) |
| lazy yield | .000077 | .001173 | .000100 |
| child replacement | .148247 (.89%) | .850894 (4.16%) | .443198 (2.65%) |
| replay record | .000069 | .001331 | .000135 |
| record insertion | .086064 (.52%) | .531158 (2.60%) | .231718 (1.38%) |

Minor unification is the largest measured classical phase, but only 45.27%,
34.07% and 40.89% of total process time.  Each attempt block still has
8.35--12.87 seconds of unmeasured outer reconstruction.  The result therefore
does not justify optimizing unification alone; the plan conclusion remains to
split minor unification and separately time outer enumeration/replay before
selecting an optimization.

Regenerated representative calibration medians [ranges] are P38@4 untimed
1.444847 [1.433778--1.451777], timed 1.462416
[1.448057--1.466207] (+1.22%); P43@5 untimed 12.635443
[12.475540--12.710936], timed 12.506453
[12.505895--12.734680] (-1.02%); and P34@6 untimed .015865
[.015829--.019764], timed .018709 [.016093--.019555] (+17.93%, startup/no
reconstruction noise).  Active fixture medians [ranges] are untimed .029825
[.029518--.069834] and timed .033556 [.033305--.063459], +12.51%.  Both exact
predeclared schedules had no external watchdog and validated exact paired
work/results; no time was corrected and all outliers are retained.

Locked SHA-256:

    7ca41fd97f7986c34fce47f9029a3ba0ca6123dc8fc41767aaa09e5f24146c5f  regenerated-final-raw.tsv
    bd6e566ca48eac14aabcc3595462164b814dde052788bcc1f92cda4690a634a0  regenerated-final-attempts.tsv
    bd6e566ca48eac14aabcc3595462164b814dde052788bcc1f92cda4690a634a0  regenerated-final-expectations.tsv
    4f9fa22cfd09def840c21aa164943fcc441790efb99259c4ad95690b26a888a1  regenerated-final-calibration-raw.tsv
    924c131747ffa3da21ee4f743c1dfe5a6dd2b6a04e577a36cc61e4e82da55180  regenerated-final-active-calibration-raw.tsv
    051af62579595b4a3bbfbebe380a657fb99ab8358249db7510af4ecf35c025be  regenerated-final-process-audit.txt
