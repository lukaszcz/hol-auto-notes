# Preserved pre-seal implementation failure

Before any seal or diagnostic clock, the first `apply_patch` that attempted to
adapt copied Task 7m helper files failed atomically with status 1 and:

```
Failed to write file /home/lukasz/dev/HOL/worktrees/isabelle-tactics/.agent-files/benchmarks/m2-low-perturbation-diagnostic-final/endpoint-audit.py
```

The copied predecessor package had recursive read-only modes.  The failed
patch changed no file.  The exact repair was `chmod -R u+w` on this new Task
7n package only, after which the same patch applied.  No predecessor byte,
tracked source, seal, smoke, benchmark process, or diagnostic clock existed or
changed at this point.

