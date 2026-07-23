# Post-collection audit chronology

No timing was rerun and no frozen input, runtime artifact, raw row or status
was changed after the watchdog failure.

The automatic failure trap copied the whole collection work directory to
`collection-attempt-0/`. Post-processing copied its raw/calibration/status,
provenance and process logs to top level for the stable audit map, regenerated
the calibration summary with the frozen summarizer, byte-compared a second
regeneration, and retained the expected target-validator rejection and status.

The first orchestration command for that post-processing reached its final
local assignment `status=0`; zsh rejected the assignment because `status` is
read-only. The preceding copies, calibration-summary generation/comparison and
initial target-validator output redirection had already completed. No exact
numeric shell exit status or outer transcript is retained, so none is claimed.
The corrected command used local name `rc`, regenerated only the target
validator log/status, and observed status 1 with exactly the intended
`verify-target: status/order/value` diagnostic. This was evidence processing,
not a harness invocation or timing retry.

The current `selfcheck.sh` is a documented post-collection override of its
frozen pre-clock body. It verifies the frozen original and every other sealed
input, then validates this declared failure state, calibration regeneration,
closure endpoints, validator adversaries, package integrity and source/index
identity without changing the package.

Final review then corrected derived interpretation only. It added
`FINAL_REVIEW_ERRATA.md`, corrected README, failure-report and plan wording,
and strengthened the read-only selfcheck to pin the preserved raw/status
bytes, the collector's fallback branch and the erratum. The package inventory
and checksums were regenerated for those derived changes. No timing ran; no
frozen input, sealed collector, runtime body, raw observation, status ledger,
provenance record or historical log changed.
