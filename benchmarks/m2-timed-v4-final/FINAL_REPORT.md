# Corrected final report

This package is a retained failed-protocol/calibration observation, not
authoritative fresh evidence. The complete pre-review report is preserved
byte-for-byte at `historical-originals/FINAL_REPORT.md`; its authority claim
and mixed-clock P43 ratio are withdrawn by `FINAL_REVIEW_ERRATA.md`.

P38@4 has comparable internal harness rows on equal observed work:
`1.652517000` seconds for v2 and `8.652819000` seconds for v4, giving
v4/v2 `5.236145` (approximately 5.236). P43@5 has no v4 harness row and
therefore no comparable internal-time ratio. Separately, the external v4
watchdog bound and external v2 supervisor elapsed time give the censored
external-process lower bound `45 / 20.341200346 >= 2.212259`.

The frozen collector aborted under `set -e` after supervisor status 125 made
`run_child`'s final test fail; the code-defined outer shell status would be 1.
No outer status was retained, the later materialization commands were not
retained, and no immediate raw seal exists. A later clean endpoint does not
repair that chronology. The representative schedule is incomplete; active
calibration and all targets never started. No optimization or capability
claim is selected.

The original collector, supervisor, raw collection bytes, and sealed inputs
are unchanged. Versioned future-protocol repairs and deterministic tests are
separate under `future-protocol/` and collected no target.
