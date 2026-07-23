# Preserved cleanup-verification wrapper failure

The cleanup transaction itself completed with retained status 0 and removed
all declared live paths.  The following ad-hoc split-verification wrapper then
stopped before its first path predicate because this host has no `tr` command:

```
zsh:15: command not found: tr
```

Its partial split ledger contains only the header.  No diagnostic child or
clock was rerun.  The repaired verification uses fixed explicit labels, keeps
the original successful cleanup transaction, records every path predicate
status independently, and runs the exact-argv endpoint separately.
