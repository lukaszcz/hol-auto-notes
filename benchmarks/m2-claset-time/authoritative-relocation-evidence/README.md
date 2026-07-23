# Authoritative relocation evidence

These files are an exact compact subset of the successful current-script
namespace run at the host path documented in
`../NAMESPACE_RELOCATION_INVOCATION.md`.  No raw file in this directory was
rewritten while packaging it.  In particular, the zero-byte
`holmake-real-target.original-accesses.txt` is the actual result of matching
the 241-line strace for the original repository root, and
`relocation-diagnostic-target.txt` is the actual target payload created by
copied Holmake.

The transcript ends with status 0 after source-tree stability checks both
before and after disposable-copy cleanup.  The three complete whole-tree
manifests are not duplicated here because each is 6,384,248 bytes; they are
byte-identical and their common hash is pinned in
`OMITTED_ARTIFACT_HASHES.md`.  The same file pins the three bulky symlink
audits.  The full raw run remains beneath the single mandated host temporary
root; this compact package is the durable audit subset.
