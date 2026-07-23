> **HISTORICAL / VOID:** Every later claim of authority in this file is void.
> This package is non-authoritative; use `../m2-timed-v2-final/`.

# Target retry 1: predeclared nonzero-harness condition

The first target driver invocation occurred only after both authoritative
calibration ledgers completed.  P34's harness exited status 1 during static
elaboration, before search and before any `ATTEMPT` or `SUMMARY` row.  The
status-only raw ledger and stderr are retained under `target-attempt-0/`.
This meets the predeclared nonzero-harness retry condition; it is not a timing
or cutoff selection.

The error was the empty assumption list in `val goal = ([], proposition
number)` retaining a free monotype at one phrase before the later public API
application.  The only repair is `val goal : goal = ...`.  Calibration data,
target order, deadlines, clocks, harness logic, schema, validator, hypotheses
and thresholds are unchanged.  `run-target-retry-1.sh` permits no existing
retry raw ledger and holds the atomic lock across the complete P34/P41/P45
block.  No second retry is authorized by this repair document.
