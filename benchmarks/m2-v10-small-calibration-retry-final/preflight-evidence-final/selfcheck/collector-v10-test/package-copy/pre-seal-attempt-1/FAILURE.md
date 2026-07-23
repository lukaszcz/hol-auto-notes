# Retained pre-seal attempt 1

The exact standalone runtime-artifact reference command used the final
auditor wrapper with explicit `--root`, `--package-dir`, `--scratch-root`,
`--work`, `--scratch-dir`, and `--output` paths, all shown below:

```
ROOT=/home/lukasz/dev/HOL/worktrees/isabelle-tactics \
PACKAGE_DIR=/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final \
SCRATCH_ROOT=/tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh \
./audit-runtime.sh \
--root /home/lukasz/dev/HOL/worktrees/isabelle-tactics \
--package-dir /home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final \
--scratch-root /tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh \
--work /tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh/smoke-reference-work \
--scratch-dir /tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh/smoke-reference-work/tmp \
--output /tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh/smoke-reference-work/audits/reference.tsv
```

It exited 1 with `ModuleNotFoundError: No module named
'path_validation_v5'`.  It created no reference, launched no collector or
child, and preceded smoke, seal, GO, and every calibration clock.
`full-bodies/` preserves the auditor bytes.  The repair only adds the exact
vendored `future-protocol/` directory to Python's import path.
