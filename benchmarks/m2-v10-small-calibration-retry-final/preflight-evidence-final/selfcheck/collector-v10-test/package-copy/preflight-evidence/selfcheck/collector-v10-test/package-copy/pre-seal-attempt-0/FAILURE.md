# Retained pre-seal attempt 0

Exact command:

```
ROOT=/home/lukasz/dev/HOL/worktrees/isabelle-tactics \
PACKAGE_DIR=/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final \
.agent-files/benchmarks/m2-v10-small-calibration-retry-final/preflight.sh \
/tmp/isabelle-tactics-task7f-20260720-root/task7l_v10_small_calibration_retry_fresh/preflight
```

The forced builds, both level-2 selftests, harness build, result-validator
adversaries, and reviewed v10 supervisor/collector suites passed.  The
package selfcheck then returned 1 because its final launcher assertion found
that the generated executable contained `/task7lcalibration`, not the
package's absolute module path.  Holmake expanded `$(CURDIR)` as `/` in this
invocation.  No smoke, final seal, benchmark GO, or calibration clock existed.

`full-bodies/` preserves every package body involved in this attempt,
including the generated failing launcher.  `logs/` preserves the complete
preflight output/status tree.  The repair changes only the Holmake rewrite
replacement to the literal frozen package module path, then reruns the entire
preflight.
