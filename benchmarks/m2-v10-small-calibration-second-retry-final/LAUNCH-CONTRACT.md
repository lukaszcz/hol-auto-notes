# Frozen launcher and cwd contract

- Supervised cwd is repository root:
  `/home/lukasz/dev/HOL/worktrees/isabelle-tactics`.
- The one command vector ends in the absolute executable
  `/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-v10-small-calibration-second-retry-final/task7mcalibration.exe`.
- That launcher loads the absolute package module path ending in
  `task7mcalibration`.
- `T7M_RUN_KIND=load-only` selects smoke; `calibration` selects scheduled
  work.  It does not change cwd or command vector.
