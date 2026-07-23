# Preserved final-audit `/var/tmp` traversal failure

All preceding final-audit gates passed.  The wrapper then recursively searched
two levels below host `/var/tmp`; `find` encountered unrelated systemd-private
directories that deny access and returned status 1.  Its stdout is empty, but
the retained stderr contains every permission diagnostic.  The wrapper stopped
before scratch inventory/copy and did not run a diagnostic child or clock.

The repaired audit checks the relevant top-level `/var/tmp` namespace for a
Task7n path, avoiding unrelated protected service subtrees.  It also retains
the explicit scoped scratch inventory and exact Git/residue gates.
