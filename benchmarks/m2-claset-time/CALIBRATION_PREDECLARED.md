# Calibration schedule (predeclared before timing)

The completed fixed-work calibration uses P38@4, P43@5 and predecessor
P34@6.  It runs three paired repetitions in fresh sequential HOL processes.
Repetitions 1 and 3 use problem order P38, P43, P34 and mode order untimed,
timed.  Repetition 2 reverses both problem order and mode order.  No process
overlaps another.  The schedule above was fixed before any calibration
timing was observed.  Raw ranges and medians are reported without correction;
the calibration quantifies perturbation only.

Those three completed no-proof searches may perform zero reconstruction, so
the 18-process schedule can quantify whole-driver timed-mode perturbation but
cannot by itself quantify the phase-clock overhead.  Before observing any
additional timing, a reconstruction-active schedule was therefore fixed for
the general stored-elimination proof `[p /\ q] |- p`.  Five paired fresh
process repetitions replay the identical searched tableau 1,000 times each.
Odd repetitions use untimed then timed; even repetitions reverse the mode
order.  Every replay must complete with identical detailed counters, result,
residue and kernel validation.  Raw ranges/medians quantify the added clock
reads and accumulator updates; they are not used to correct target times.

The final relocation and signal-containment repairs do not change or rerun
either calibration schedule.  Packaging revalidates the retained ledgers,
exact schedules and mechanically regenerated locked summary only; no new
elapsed observation can be selected into the authoritative calibration.
