# Retained failed-protocol collection observation

The collection attempt is not an authoritative fresh chain. The frozen
collector aborted under `set -e` when the fourth representative supervisor
returned 125. Later commands that materialized `collection/` were not
retained, the raw scratch bytes were not immediately sealed, and no outer
collector status was retained. See `FINAL_REVIEW_ERRATA.md` for the exact
chronology. The complete former body is preserved byte-for-byte as
`historical-originals/COLLECTION_FAILURE.md`.

P38 repetition 1 did emit equal-work internal harness rows: v2
`1.652517000` seconds and v4 `8.652819000` seconds, ratio `5.236145`
(approximately 5.236). P43 emitted a v2 internal row but no v4 internal row,
so no comparable P43 internal-time ratio exists. The separately labelled
external-process censored lower bound is `>=2.212259`, comparing the v4
45-second watchdog boundary with v2 supervisor elapsed `20.341200346`.

The representative schedule was incomplete. Active calibration and every
target were forbidden and never ran. No target result, causal attribution,
projected speedup, optimization, or capability conclusion is supported.
