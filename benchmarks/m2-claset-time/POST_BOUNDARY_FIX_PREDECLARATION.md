# Post-boundary-fix run protocol and predeclared constraints

The current authoritative measurement evidence is the post-terminal-boundary
`regenerated-final-*` chain at this package root.  The pre-boundary chain and
its earlier run declaration are historical only under
`pre-boundary-fix-history/`.

The representative 18-process and active 10-process schedules remained the
ones fixed in `CALIBRATION_PREDECLARED.md`; the boundary repair did not change
their order, work, modes, or no-watchdog policy.  Because the terminal-clock
change altered the measured binary and the meaning of attempt wall time, no
pre-boundary timing was reused.  After forced source/object regeneration and
the full classical and blast level-2 selftests, the schedules ran once in
active-calibration then representative-calibration order, without tuning or
selection.  Their current outputs are
`regenerated-final-active-calibration-raw.tsv` and
`regenerated-final-calibration-raw.tsv`.

After both calibrations validated, the unchanged P34@7, P41@6, P45@11 target
schedule ran exactly once with the fixed 30-second cooperative budget and
60-second process watchdog.  It wrote `regenerated-final-raw.tsv` and
`regenerated-final-process-audit.txt`; both endpoint checks used the corrected
`pgrep -af '[m]2clasetime'` command.  The mechanically extracted attempts are
locked as `regenerated-final-expectations.tsv` and independently compared.

The current chain is summarized in `REGENERATED_FINAL_LOCKED_SUMMARY.md` and
uses the source/build hashes in `POST_BOUNDARY_FIX_BUILD_PROVENANCE.md` and
`environment.txt`.  Reproduction must use fresh output paths and cannot
replace the retained authoritative evidence.  The supported reproducer
requires a fresh canonical location outside the repository, copies the whole
source tree there with GNU `cp -a`, and builds/tests only that copy.  It
captures downstream `classicalLib`/`tableauLib` plus harness
source/UI/UO/executable freshness and proves relevant source inputs unchanged.
Its reconstructed historical transcript is descriptive only.

The current safety claim additionally requires the retained real
`--relocation-check`: in-copy smart-configuration, copied Holmake/hol
diagnostics, an existing harmless explicit Holmake target with ancestor
preexecs disabled, external metadata neutralization, categorized absolute-link
and launcher containment, sanitized PATH, and exact whole-source before/after
manifests.  The exact invoked script hash/size must match the current script.
Synthetic adversaries invoke the full outer reproducer and signal its
published shell PID for HUP/INT/TERM/repeated TERM; they validate outer
statuses, supervisor TERM/KILL events, group disappearance, delayed-marker
absence and source immutability, but cannot establish HOL4 relocation.  Direct
supervisor normalization unit cases are labeled separately.  Earlier safety
logs are non-authoritative under `pre-relocation-history/` and
`pre-final-relocation-history/`.  None of these checks reruns a timing schedule.
