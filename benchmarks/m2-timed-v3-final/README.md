# Task 7h final timed-v3 package

This is the intended authoritative Task 7h package for revision
`d23e4ba254929547dd601186b9fb72b199706610`. It contains no tracked source
change, commit or optimization. Its honest outcome is a sealed, validated
measurement failure: timed-v3 perturbation is too large for the fixed target
protocol, so no target owner or production change is selected.

`PREDECLARATION.md`, `SEAL_PLAN.md`, `INPUTS.sha256` and `frozen-inputs/`
freeze schedules, hypotheses, thresholds, interpretation, retry rule and all
29 input bodies. `ARTIFACTS-FROZEN.tsv` has 425 data rows plus header: 396
C-sorted repository paths followed by 29 declared-order resolved tools. It
contains every file below `src/auto`, all harness artifacts, exact heap/bin
and configuration inputs. All six segment endpoints match it.

The initial pre-seal endpoint failure and exact repair are fully retained in
`pre-seal-attempt-0/` and `PRE_SEAL_REPAIR.md`. The repaired clean preflight
passed forced builds, both level-2 suites, harness builds, wrapper/HOL-child
endpoint tests, three validator positives and 88 independent adversaries.

`calibration-raw.tsv`, `active-calibration-raw.tsv`,
`calibration-summary.tsv` and validations retain the complete successful
calibration. `raw.tsv`, `target-validation.*`, `collection-status.tsv`,
`process-logs/`, `provenance/` and `collection-attempt-0/` retain the exact
P34 watchdog failure and the fact that P41/P45 never ran.
`FINAL_REVIEW_ERRATA.md` is the authoritative status attribution, causal
limit and future-supervision addendum. `COLLECTION_FAILURE.md` states the
corrected result and interpretation.
`POST_COLLECTION_AUDIT.md` records post-clock processing.

`PACKAGE-INVENTORY.tsv`, `checksums.sha256` and the integrity helpers cover
all regular-file bytes except checksum self plus every exact symlink target.
The caller supplies an existing scratch root and strict descendant:

    root=/tmp/isabelle-tactics-task7f-20260720-root/task7h-measure
    .agent-files/benchmarks/m2-timed-v3-final/selfcheck.sh \
      "$root" "$root/manual-selfcheck"
