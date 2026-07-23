# Post-boundary-fix regenerated-final locked summary

This is the reviewed summary of the one authoritative measurement chain after
the terminal timing-boundary repair.  The complete original bodies and data
of the earlier final chain are preserved under `pre-boundary-fix-history/`
and are historical only.  Its five narrative records (`README.md`,
`REGENERATED_FINAL_LOCKED_SUMMARY.md`, `REPAIRED_BUILD_PROVENANCE.md`,
`REPAIRED_FINAL_PREDECLARATION.md`, and `TEMPORARY_HOLMAKE_RULES.txt`) carry
explicit archival banners and therefore have new hashes.  The archived
ledgers and logs that still match their recorded pre-archive hashes are
identified precisely in `pre-boundary-fix-history/README.md`; no blanket
byte-identity claim is made for the chain.
`regenerated-final-expectations.tsv` pins every exact attempt field, and
`verify-final-expectations.awk` compares it mechanically in row order.

Build reproduction now uses a complete isolated source-tree copy outside the
repository, so downstream `classicalLib` and `tableauLib` rewrites never touch
the source tree and need no restoration.  Its hash/stat output covers
every named source/UI/UO/executable chain.  This strengthens reproduction
safety without changing or retrospectively expanding the hashes captured by
the completed authoritative measurement run.

The relocation repair is independently evidenced by a non-building
`--relocation-check`: it smart-configures inside the disposable copy, proves
copied Holmake/hol state and HOLDIR resolution, removes external assistant
metadata, rebases and categorizes absolute links, checks all build/source/
sigobj links, invokes copied Holmake on a real harmless target with ambient
preexec discovery disabled, rejects original-root resolution, audits a strict
PATH, pins the invoked current-script hash/size, and byte-compares
comprehensive original manifests before removing the copy.  The full-outer
synthetic signal suite is separate and makes no relocation claim: it signals
the published shell PID and requires statuses 129/130/143/143, retained output,
supervisor TERM/KILL and group-gone events, absent delayed markers and exact
source manifests.  Direct helper tests separately pin exit 7 and independent
SIGTERM normalization to 143.  Previous safety summaries are archived under
`pre-relocation-history/` and `pre-final-relocation-history/`; timing evidence
and conclusions are unchanged.

The corrected target audit held the atomic driver lock from 11:14:26 through
11:16:19 UTC.  Both endpoints ran `pgrep -af '[m]2clasetime'` and found no
matching process.  All three fresh sequential processes returned status 0;
none reached the 60-second watchdog.  The driver was invoked exactly once.

Exact target search vectors (stop polls, search checkpoints, inferences,
branches created/closed, choices pruned, max cost, cache hits, conversions):

    P34@7   3846666  3835238  503  100  100  489  7   467   9817
    P41@6  10761913  9979324 1576  245  645    5  6  2873  10807
    P45@11  3827294  3812018  739  237  237  717 11   246   7160

P34 has one Interrupted NONE attempt at outer Exit/AlternativeEnumeration and
stored Exit/RecordInsertion.  P41 has two Completed NONE attempts at outer
Exit/ReplayRecursion and stored Exit/MinorUnification, followed by one
Interrupted NONE attempt at outer Exit/AlternativeEnumeration and stored
Exit/RecordInsertion.  P45 has one Interrupted NONE attempt at outer
Enter/AlternativeEnumeration and stored Exit/EliminationMajorUnification.

`attempt_wall_time` is now captured at the terminal reconstruction outcome,
before statistics and classical snapshot aggregation.  Therefore attempts
minus classical excludes diagnostic report aggregation and denotes only
unmeasured outer reconstruction, observer and timing work up to that outcome.

| Problem | Process | Attempts | Classical | Process minus attempts | Attempts minus classical | Classical/process | Attempts/process |
|---|---:|---:|---:|---:|---:|---:|---:|
| P34@7 | 31.911690 | 31.390598 | 16.514289 | .521092 | 14.876309 | 51.75% | 98.37% |
| P41@6 | 30.005085 | 28.653267 | 20.338861 | 1.351818 | 8.314406 | 67.78% | 95.49% |
| P45@11 | 30.004055 | 29.492010 | 16.936954 | .512045 | 12.555056 | 56.45% | 98.29% |

| Phase | P34 seconds (% classical) | P41 seconds (% classical) | P45 seconds (% classical) |
|---|---:|---:|---:|
| attempt selection | .070192 (.43%) | 3.902464 (19.19%) | .260045 (1.54%) |
| freshening/setup | .017657 (.11%) | .426580 (2.10%) | .021707 (.13%) |
| minor unification | 13.380533 (81.02%) | 10.175967 (50.03%) | 12.349833 (72.92%) |
| major unification | 2.525362 (15.29%) | 1.816229 (8.93%) | 2.801778 (16.54%) |
| rule instantiation | .133132 (.81%) | .642962 (3.16%) | .467344 (2.76%) |
| child/store | .095001 (.58%) | .708543 (3.48%) | .271897 (1.61%) |
| direct result | .043166 (.26%) | 1.285381 (6.32%) | .065371 (.39%) |
| lazy yield | .000061 | .001231 | .000090 |
| child replacement | .160491 (.97%) | .854765 (4.20%) | .457197 (2.70%) |
| replay record | .000088 | .001480 | .000126 |
| record insertion | .088606 (.54%) | .523259 (2.57%) | .241566 (1.43%) |

Minor unification is the largest measured classical phase, but only 41.93%,
33.91% and 41.16% of total process time.  Each attempt block still has
8.31--14.88 seconds of unmeasured outer work.  This does not justify an
optimization; the next diagnostic conclusion is unchanged.

The generated calibration summary is locked in
`regenerated-final-calibration-summary.tsv`.  It is regenerated and
byte-compared by `validate-calibrations.sh`; the validator also retains exact
schedule, pair, work and result checks.

| Workload | Untimed median [full range] | Timed median [full range] | Timed/untimed; change |
|---|---:|---:|---:|
| P38@4 | 1.626393 [1.624928--1.687233] | 1.639761 [1.628874--1.680046] | 1.008219416; +.821941560% |
| P43@5 | 12.678592 [12.398727--12.718826] | 12.557997 [12.447331--12.614098] | .990488297; -.951170288% |
| P34@6 | .015938 [.015787--.015955] | .015898 [.015876--.015918] | .997490275; -.250972519% |
| active fixture | .029952 [.029760--.041088] | .044031 [.033360--.045169] | 1.470052083; +47.005208333% |

Both unchanged predeclared schedules ran once in the required active then
representative order, had no external watchdog, and reproduced exact paired
work/results.  P34 performs no reconstruction and remains startup noise.
Calibration quantifies perturbation only; no target time is corrected.

Locked SHA-256:

    d0807f87634b38be21a011d0ee296f532840476ab7faa303d3e9694dc24fada3  regenerated-final-raw.tsv
    e6b414df4c95ffa059e7fb184899dc053f4a1db95ed4eb0fe6f4f14bcfce1f1c  regenerated-final-attempts.tsv
    e6b414df4c95ffa059e7fb184899dc053f4a1db95ed4eb0fe6f4f14bcfce1f1c  regenerated-final-expectations.tsv
    2506bdf49c06603d79ae8fe331ab58975aac77ee9d68726db55e5ffef199cd92  regenerated-final-calibration-raw.tsv
    0e42e054680c7172737c08097da709141db0bba9da9345a4a3ef6bb747475cdb  regenerated-final-active-calibration-raw.tsv
    e25cc590a735032f8ce5a5eb3eab61b7de69c5a267594720bd2991b49e829fc0  regenerated-final-calibration-summary.tsv
    1a818e0b50d32373b0c168ed36a793c8fe78d27c47a68357b112afc99b22662e  regenerated-final-process-audit.txt
