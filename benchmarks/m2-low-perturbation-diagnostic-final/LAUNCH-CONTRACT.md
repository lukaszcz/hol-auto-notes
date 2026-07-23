# Frozen launcher and cwd contract

- Supervised cwd is repository root:
  `/home/lukasz/dev/HOL/worktrees/isabelle-tactics`.
- The command vector ends in the absolute executable
  `/home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-low-perturbation-diagnostic-final/task7nclock.exe`.
- That launcher loads the absolute package module path ending in
  `task7nclock`.
- `T7N_RUN_KIND=load-only` selects smoke; `calibration` selects the frozen
  standalone schedule.  Neither changes cwd or command vector.

