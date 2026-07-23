# M2 v10 small calibration final report

Status: **stopped before calibration; no timing attribution**.

The exact planned schedule was 20 fresh sequential P38@4 children in modes
A/B/C/D, five per mode.  Only child 1 was launched.  Its v10-contained process
exited 1 while loading the harness UI from the wrong working directory.  It
produced no calibration row and never evaluated a benchmark clock.  The
0.448013836-second supervisor elapsed value describes this failed transaction,
not P38 work.

All containment and evidence endpoints closed cleanly, and the frozen no-retry
rule was honored.  Therefore the predeclared formulas are not evaluated and
the clock-versus-aggregation attribution is indeterminate for lack of data.
See `COLLECTION_FAILURE.md` and `collection/child-1/` for the exact evidence.

No tracked source was modified and no optimization was selected.
