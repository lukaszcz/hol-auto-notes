# Preserved first load-only smoke failure

The actual generated-launcher load-only smoke completed the harmless child
and v10 supervision successfully, but the new exact endpoint audit returned
status 1.  Its implementation counted the still-running collector itself,
whose argv necessarily contains the supervised launcher as the command-vector
argument.  The complete reference generation, outer command/cwd/stdout/
stderr/status, collector transaction, raw seal, supervisor record, artifact
audit, endpoint result and final status 125 are retained here.

The sole repair excludes the current collector PID from its post-reap exact
argv scan.  It does not exclude any other identity.  This attempt preceded
seal and every diagnostic clock and is not benchmark evidence.
