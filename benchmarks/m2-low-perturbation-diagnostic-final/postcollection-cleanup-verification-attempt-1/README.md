# Preserved split-verification environment failure

All eight independent absence predicates returned status 0.  In the zsh
wrapper, the function variable named `path` overwrote zsh's special command
search array.  The following separate exact-endpoint command therefore failed
with status 127 and retained diagnostic `command not found: python3`; it did
not test the endpoint.  The wrapper stopped before Git checks.

The repair renames the function variable, executes `/usr/bin/python3` by exact
path, and repeats only read-only cleanup/endpoint/Git verification.  No
diagnostic child or clock is rerun.
