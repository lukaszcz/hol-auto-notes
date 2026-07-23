# Pre-seal attempt 0: review verifier invocation failure

The first formal preflight exited 1 before any build, harness, smoke,
collector, supervisor, search, or benchmark clock.  Its Task7k external-review
closure subcommand returned 126 because the adjacent immutable
`verify-closure.sh` is not executable and was invoked directly.

The complete wrapper command/cwd/environment/stdout/stderr/status, formal
preflight status table and logs, involved before/after bodies and hashes, and
exact repair diff are retained under `pre-seal-attempt-0/`.  The sole repair
adds `sh` before each adjacent review verifier path.  Neither reviewed package
nor review package changed.
