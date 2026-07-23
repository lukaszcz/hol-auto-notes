# M2 v10 P38 four-mode calibration final report

Status: **complete, valid calibration; mixed/indeterminate attribution**.

The exact frozen balanced schedule completed all 20 fresh P38@4 children once
with no retry.  Every collector status, supervisor status, final status, raw
seal, artifact audit, exact endpoint, driver status, and unconditional final
endpoint is zero/clean.  The closed validator passed exact schema/order/EOF,
cross-ledger identity, and all parity and boundedness gates.

All rows exhausted with `none`, 22 reconstruction attempts, identical search
counters `2507169,624,140,210,233,4,322,5446`, and identical ordered 37-field
signatures.  Every C and D row used exactly 61,486,260 clock reads; each used
22 terminal summary reads and zero trace allocations or sequence-statistics
reads.

| Mode | Median external s | Full range s |
|---|---:|---:|
| A | 9.189388257 | 9.172840055--9.256204405 |
| B | 9.237345589 | 9.221508007--9.249071647 |
| C | 11.027194246 | 10.933404789--11.032468973 |
| D | 16.328066360 | 16.296102393--16.332424610 |

The independent B/A sanity ratio is `1.005219`, inside `[0.95,1.05]`.
`D-A` is `7.138678103` s, `C-A` is `1.837805989` s, and `D-C` is
`5.300872114` s.  Clock share is `0.742557`, D/C is `1.480709`, and C/A is
`1.199992`.  Clock-dominant requires both share at least `.80` and D/C at
least `1.50`; aggregation-material requires C/A at least `1.25`.  Neither
predicate holds, so the predeclared classification is
**mixed/indeterminate**.

This process-level ablation does not prove a microarchitectural cause, select
an optimization, authorize a target run, or close M2.  Exact raw, summary,
validation, 20 child transactions, and the outer wrapper transaction are
under `collection/`.
