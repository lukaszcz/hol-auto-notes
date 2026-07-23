# Frozen launcher and cwd contract

- Supervisor cwd: `/home/lukasz/dev/HOL/worktrees/isabelle-tactics`.
- Collector command vector (both smoke and calibration):
  `/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final/task7lcalibration.exe`.
- The executable invokes `bin/hol` with the absolute module path
  `/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-retry-final/task7lcalibration`.
- Run selection and scheduled fields are inherited environment values and do
  not change the command vector.
- Smoke uses `T7L_RUN_KIND=load-only`; collection uses
  `T7L_RUN_KIND=calibration`.
