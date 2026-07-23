# External review resolution for authoritative Task 7n

Review result: **findings resolved by external errata and governance
clarification; the authoritative package remains unchanged**.

## Authority and preservation boundary

This directory is external postcollection review evidence for
`../m2-low-perturbation-diagnostic-final/`.  It is adjacent to, and not
inside, the authoritative Task 7n package.  It is non-sealed, was created
after collection, and is not part of `GO-SEAL.txt` or a replacement seal.
It changes no byte, path, type, symlink target, schedule, observation, stage,
commit, or conclusion in the authoritative package.

The before/after manifests are deterministic, typed and symlink-aware full
inventories of the authoritative package.  They include the package's own
inventory and checksum manifest.  Their byte identity proves that Task 7n
remained unchanged while this external resolution and the governing plan
chronology were added.  `REVIEWED-PACKAGES.tsv` and `REFERENCES.sha256` bind
the exact Task 7n package and the authoritative Task 7m package and external
review on which the standalone comparison depends.

## Reviewed capability gate

The preferred sampler gate used `/usr/bin/perf`, `perf version 6.17.13`, and
the fixed harmless command `perf record -F 9 -g --call-graph dwarf` around
`/bin/sleep 2`.  Host `perf_event_paranoid=4` denied monitoring.  Recording
exited 255 and left a zero-byte `perf.data`.  Because recording failed,
`capability-probe.sh` skipped the `perf report` command and wrote `125` to
`report.status` as a synthetic sentinel; `125` is not a status returned by
`perf report`.  The probe therefore produced no usable or readable sample
data, sample count, symbol/DSO result, wrapper assessment, or sampled P38
run.  This is an environmental sampler block, not a HOL4 capability
conclusion.

## External wording erratum

The authoritative `FINAL_REPORT.md` remains byte-for-byte unchanged.  Its
phrase "there was no sample file" is corrected externally to "there was no
usable or readable sample data": the retained sample path exists as a
zero-byte `perf.data`.  Any reading that `perf report` returned status 125 is
also corrected by the execution chronology above: the command was skipped
and the script supplied the sentinel.

## Reviewed fallback result

The frozen balanced `Z,N,N,Z,Z,N,N,Z,Z,N` fallback completed ten fresh
children without retry, five per mode.  Every row made and observed exactly
61,486,260 closure calls.  Median external elapsed and full observed ranges
were:

- Z: `0.511189289` [`0.509745717`, `0.511828761`] seconds;
- N: `6.090917808` [`6.082526315`, `6.103101928`] seconds.

The median net N-Z was `5.579728519` seconds.  Authoritative Task 7m D-C was
`5.300872114` seconds.  Their unrounded ratio was
`1.052605759769...`, reported as `1.052606`, inside the frozen inclusive
consistency band `[0.80,1.20]`.

The v10 `elapsed_seconds` interval begins after disposable containment
preflight and controller setup, but before the live spawn.  It ends after
live cleanup and classification, but before durable status publication and
collector artifact/process audits.  It therefore includes live
fresh-process, bootstrap, loop, and cleanup costs.  Task 7m uses the same
supervisor interval domain.

The authority is limited to standalone consistency under five samples per
mode and the deliberately wide frozen band.  The fallback and Task 7m differ
in allocation, cache, locality, and control-flow context.  The result names
no production time category, target profile, projected speedup, source
optimization, HOL4 capability cause, or M2 closure.

## Governing path-selection clarification

The Task 7n decision explicitly supersedes and clarifies Task 7m's narrower
fallback-trigger wording.  The frozen exact-count fallback may be selected
when preferred sampling is unavailable because of host permission or
capability, or when sampling runs but usable symbols are inadequate, provided
the path is frozen before any diagnostic clock.  Task 7n used the
permission-unavailable branch: `perf_event_paranoid=4` prevented recording.
This clarification changes no observation and grants no production,
optimization, target, capability-cause, or M2-closure authority.

## Next evidence boundary

Further M2 sampling is permitted only on a host with `CAP_PERFMON` or a lower
`perf_event_paranoid` setting.  It must be a wholly fresh, separately sealed
ten-child sampled/control P38 run with the frozen equal-work parity,
perturbation, sample-count, symbol/DSO, and category-coverage gates.  If such
a host is unavailable, record the environmental block; do not substitute a
production conclusion.

M3 capability audits may proceed independently.  They must not treat Task 7n
or the still-open M2 record as evidence that any candidate M3 mechanism is a
cause.
