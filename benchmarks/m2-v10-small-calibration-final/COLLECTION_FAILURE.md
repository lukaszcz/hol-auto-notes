# Authoritative collection outcome: stopped before calibration

The sole sealed collection began with schedule child 1, repetition 1, mode A,
P38@4.  The reviewed v10 collector and supervisor completed their transaction
and returned the observed child status 1.  The child did not load the harness:

```
Cannot find file task7kcalibration.ui
error in load task7kcalibration : Fail "Cannot find file task7kcalibration.ui"
Uncaught exception at poly/poly-init2.ML:42: Fail "Cannot find file task7kcalibration.ui"
```

The generated `task7kcalibration.exe` launcher names the module without an
absolute load path and therefore requires the package as its working
directory.  The frozen collector invokes the command from repository ROOT.
Formal build and selftests did not execute that launcher through the frozen
collector, so this integration defect escaped preflight.

The supervisor record is a valid v10 runtime record with observed wrapper
return/status 1, classification `completed_exit_nonzero`, no timeout or
signal, `containment_cleared=true`, and external transaction elapsed
`0.448013836` seconds.  Collector schema, raw durability, raw seal, artifact
identity and endpoint status are all zero/success.  Immediate failure endpoint
is `matches=none`.  Harness stdout is empty.  The failure occurred during HOL
module loading, before evaluation of the SML body and therefore before its
first benchmark clock.

The predeclared rule says any nonzero/protocol failure stops without retry.
Accordingly children 2--20 did not start.  No protocol body, schedule or
launcher was repaired, and no observation was rerun.

There are no valid A/B/C/D timing rows, medians, ranges, ratios, clock counts,
work-parity comparison or attribution.  None of clock acquisition, bounded
aggregation, both, or neither can be selected from this package.  The only
supported next action is a wholly new, separately sealed protocol whose
preflight executes the exact launcher under the exact collector working
directory before allowing a benchmark clock.
