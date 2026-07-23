# Final relocation namespace invocation

The final Linux relocation preflight uses a private user and mount namespace
so unrelated host `/tmp/Holmakefile` metadata cannot become a Holmake ancestor,
while every physical scratch file remains below the single mandated host root
`/tmp/isabelle-tactics-task7f-20260720-root/`.

The host directory `namespace-run` is bind-mounted over namespaced `/var/tmp`;
a fresh tmpfs is then mounted over namespaced `/tmp`.  The exact reproducer was
invoked with `/var/tmp/final-authoritative-relocation-ptrace`, which persists
on the host as
`namespace-run/final-authoritative-relocation-ptrace`.  The copied real target
is itself traced, and any syscall naming the original root is fatal.

Exact command shape (the retained command transcript records the concrete
paths, frozen hashes, status and assertions):

    unshare -Urnm sh -c '
      root=$1
      repo=$2
      mount --bind "$root" /var/tmp
      mount -t tmpfs tmpfs /tmp
      cd "$repo"
      exec ./.agent-files/benchmarks/m2-claset-time/reproduce-post-boundary-build.sh \
        --relocation-check /var/tmp/final-authoritative-relocation-ptrace
    ' sh /tmp/isabelle-tactics-task7f-20260720-root/namespace-run \
      /home/lukasz/dev/HOL/worktrees/isabelle-tactics

The retained host output is exactly:

    root=/tmp/isabelle-tactics-task7f-20260720-root
    $root/namespace-run/final-authoritative-relocation-ptrace

The compact raw subset is retained under
`authoritative-relocation-evidence/`.  Its input manifest records the current
reproducer hash
`5b113d27e8c5aa0490cf591df0876de0f2587c242f80e2477b2f787d7a27aa5b`
and supervisor hash
`277b483cd57650efdfe7077a4b2bb1bdc84f7f6d2b31fe58c72e6c232952d368`.
`OMITTED_ARTIFACT_HASHES.md` pins the byte counts, line counts, and hashes of
the bulky raw manifests and link audits that are not duplicated in the
package.

No HOL source build, selftest, calibration, target timing, or measurement
driver is part of this invocation.
