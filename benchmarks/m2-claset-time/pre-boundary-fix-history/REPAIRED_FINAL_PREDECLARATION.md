# Historical pre-boundary repaired-final source run predeclaration

Historical/non-authoritative notice: this declaration governed the
pre-terminal-boundary chain only.  It is superseded by the post-boundary
`regenerated-final-*` chain at the package root.

Recorded before any repaired-final calibration or target timing was run.

The source repair changes the measured binary.  The unchanged representative
18-process schedule in `calibration-schedule.tsv` and the unchanged active
10-process schedule in `active-calibration-schedule.tsv` are therefore run
again once from the repaired final source, sequentially, with no external
watchdog and no tuning.  Their outputs are
`regenerated-final-calibration-raw.tsv` and
`regenerated-final-active-calibration-raw.tsv`.

After both calibrations validate, the chronologically first complete
repaired-final invocation of the unchanged P34@7, P41@6, P45@11 schedule is
authoritative.  It uses the predeclared 30-second cooperative budget and
60-second process watchdog and writes `regenerated-final-raw.tsv` plus
`regenerated-final-process-audit.txt`.  The endpoint audit command is corrected
to `pgrep -af '[m]2clasetime'`.  This run will not be rerun or selected for a
convenient cutoff.

The earlier `raw.tsv`, `attempts.tsv`, `process-audit.txt`, calibration raw
files and summaries remain retained as pre-review evidence.  In particular,
the old audit's `pgrep -af '[m]2clasetforce'` endpoint was invalid for the
`m2clasetime.exe` executable.  Its atomic lock still excluded overlapping
cooperating drivers, but its endpoint snapshots made no relevant executable
absence claim.

The earlier `repaired-final-active-calibration-raw.tsv` was started before a
forced regenerated-object audit.  It is retained as a pre-final failed ledger
and is not validated, selected, or reused.  After the regenerated rebuild and
full selftests, the uniquely named `regenerated-final-*` sequence above is the
only final active/representative/target schedule chain.
