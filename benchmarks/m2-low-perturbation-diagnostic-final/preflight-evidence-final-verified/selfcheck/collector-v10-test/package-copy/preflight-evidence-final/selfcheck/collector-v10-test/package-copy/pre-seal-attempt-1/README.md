# Preserved smoke-reference path failure

This first smoke-reference audit preceded smoke, seal and diagnostic clocks.
It returned status 2 with the sole retained diagnostic `audit-runtime: tmp
must be below work`.  The exact command, cwd, stdout, stderr and status are
present here.  The repair moved both `tmp` and output under the declared work
path.  No diagnostic process ran and no observation was produced.

