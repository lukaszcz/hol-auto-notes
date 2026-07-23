# External review resolution for the failed Task 7l calibration retry

## Authority and preservation boundary

This directory is an external postcollection erratum for the independently
reviewed package `../m2-v10-small-calibration-retry-final/`.  It is adjacent
to, and not inside, that package.  It was created after the failed collection
and final package closure.  It is not part of `GO-SEAL.txt`, does not rewrite
that seal, and grants no retroactive authority to any original claim.

`SEALED-PACKAGE-MANIFEST-BEFORE.tsv` was captured before this resolution
directory was created.  `SEALED-PACKAGE-MANIFEST-AFTER.tsv` was captured after
the documentation changes.  They are byte-identical, symlink-aware typed
inventories of the reviewed package: 4,895 directories, 16,209 regular files,
and no symlinks.  Their common SHA-256 is
`4b6ce4c06da1c7c5311c0b8df4a0acb692e7eff8805f93fab7d240e7210f7b4f`.
Thus no byte, path, type, or symlink target inside the sealed package changed
during this resolution.

`REVIEWED-PACKAGES.tsv` gives the exact inventory and checksum-manifest
references for Task 7l and its preserved, separately reviewed Task 7k
predecessor.  This erratum does not make either package more authoritative
than its controlling review documents.

## Review finding 1: seal and read-only evidence chronology

The sealed narrative reports that the final 19-entry `GO-SEAL.txt` was
successfully verified from the package directory and that the package was
then made read-only.  No status-bearing record, stdout/stderr capture, or log
of either operation was retained.  Those historical successes are therefore
narrative claims, not machine-retained results.  This erratum makes no
retrofit verification or read-only claim.

The 19 seal hashes remain reconstructable: 18 bound files are present at
their original top-level paths, and the missing top-level
`task7lcalibration.exe` has an intentional frozen copy at
`frozen-inputs/generated/task7lcalibration.exe`.  That frozen file has the
seal's exact SHA-256,
`119c19bc5cd7096a09e8f93a1b008726d634faeb60440ae583fcaef9a2637b39`.
This reconstructability does not make the current seal pass.  After the
recorded live-artifact cleanup, a package-root check returns status 1 because
the top-level executable is absent; restoring it would rewrite the closed
package and is forbidden.

The authoritative collection invoked `collect.sh` from repository root.
Its package-relative seal paths were consequently resolved from repository
root, all 19 entries were reported missing, and `set -e` stopped the script.
The retained `failed-collection/go-seal-check.log` establishes those failed
lookups.  The reported driver exit 1 is inferred from this shell code path and
log, because no machine-retained outer driver-status record exists.

The next statement in `collect.sh` was only `test ! -w "$dir"`: it tested
the package directory itself, not every descendant path.  The failing seal
check meant even that limited assertion was never reached.  Thus Task 7l has
neither a retained status for the historical read-only operation nor a
recursive writable-path audit in its postcollection closure.

The next fresh protocol must use a cwd-independent, package-scoped seal
verifier.  It must anchor every seal entry below the explicit package root,
reject absolute and escaping paths, and retain the verifier's exact command,
cwd, stdout, stderr, and status.  Its read-only gate must recursively inventory
and reject every writable package directory, regular file, and symlink-aware
path condition defined by the protocol.  The recursive audit bytes, stdout,
stderr, and status must be part of the postcollection closure.

## Review finding 2: outer driver status and final endpoint

Task 7l retains the exact intended collection command and the seal-check log,
but no wrapper-retained driver stdout, driver stderr, or driver exit status.
It also has no unconditional outer final endpoint tied to that driver
transaction.  The separate later `final-endpoints/` records are clean and
status-bearing, but they do not replace a transaction finalizer.  Therefore
"the tool exited 1" is a code/log inference, not a machine-retained status.

Every future collection invocation must be owned by an outer wrapper that
always captures the driver's stdout, stderr, and numeric status.  On success,
ordinary failure, or signal, its unconditional finalizer must run the exact
identity-based endpoint audit, retain that audit's stdout/stderr/status, and
only then publish the wrapper's final status.  The wrapper records must be in
the postcollection checksum and typed-inventory closure.

## Review finding 3: completeness of pre-seal attempt evidence

The phrase "all attempts retained" requires qualification.  Attempt 0 has
the command, narrative, complete involved bodies and hashes, exact repair
diff, and the full preflight stdout/stderr logs and status table.  Attempt 2
has the involved bodies and hashes, repair description, command vector,
collector and endpoint statuses, and the complete smoke transaction's raw
stdout/stderr and final records.

Attempt 1 has its command, narrative, involved bodies and hashes, and exact
repair diff, but it has no retained direct stdout, stderr, or numeric status
artifact.  Its `ModuleNotFoundError` and exit 1 are narrative observations,
not a complete machine-retained transaction.  Accordingly Task 7l retains
the identities and repair histories for all three attempts, but does not
retain complete command/stdout/stderr/status evidence for every attempt.

Every pre-seal attempt in the next fresh package, successful or failed, must
retain the exact command and cwd, stdout, stderr, numeric status, all involved
before/after bodies, their hashes, and the exact diff.  These records must be
created before any retry and included in final closure.

## Review finding 4: attempt-2 repair-path erratum

`pre-seal-attempt-2/repair.patch` names
`../../task7lcalibration.sml`.  From the `pre-seal-attempt-2/` directory, the
correct relative path to the package's top-level source is
`../task7lcalibration.sml`.  The sealed text is preserved; this external
erratum corrects only its path description.  The intended semantic repair is
still the diff between `full-bodies/task7lcalibration.sml` and the package's
top-level `task7lcalibration.sml`.

## Review finding 5: outcome terminology and artifact scope

The authoritative calibration collection did not invoke its collector or
supervisor.  Consequently supervisor classification was **not evaluated**,
no supervisor benchmark-GO commit occurred, and attribution is
**indeterminate** because there is no calibration evidence.  "Mixed" is not
a classification result here.  `GO-SEAL.txt` is an input-integrity seal and
must not be confused with the supervisor benchmark-GO commit.

Statements that no collector or supervisor ran apply only to the
authoritative calibration collection.  The earlier successful load-only
smoke did run the exact collector and supervisor machinery.  Its evidence is
under `smoke-evidence/`; it authorizes load-path integration only and is not a
calibration observation.

The top-level live build paths are clean after cleanup: the executable,
UI/UO, lock, make-dependency, and `.hol` log paths named by the cleanup record
are absent.  Intentional executable/build artifacts nevertheless remain as
evidence at these disclosed locations:

- the frozen build closure under `frozen-inputs/generated/`, including
  `task7lcalibration.exe` and its `.hol/` artifacts;
- attempt-0 bodies under `pre-seal-attempt-0/full-bodies/`;
- collector-validator package copies under
  `pre-seal-attempt-0/logs/selfcheck/collector-v10-test/package-copy/`,
  `preflight-evidence/selfcheck/collector-v10-test/package-copy/`, and
  `preflight-evidence-final/selfcheck/collector-v10-test/package-copy/`,
  including their deliberately retained recursive package-copy descendants.

These are closed evidence artifacts, not top-level live build residue.

## Required next fresh protocol

A new attempt must be wholly fresh and separately sealed.  Before any
authoritative calibration child or supervisor benchmark-GO commit, it must:

1. retain complete evidence for every pre-seal attempt as specified above;
2. finish the load-only smoke and clean or freeze its declared artifacts;
3. generate a provisional artifact reference, input manifest, and scoped
   seal, then make the package recursively read-only;
4. run the exact `collect.sh` in a no-child dry-run first from repository root
   and then from an unrelated cwd; each run must use the real driver path,
   reach a successful scoped seal check, retained recursive read-only audit,
   and retained exact pre-child endpoint, then stop before collector or
   supervisor invocation;
5. retain for both dry-runs the exact command, environment, cwd, driver
   stdout, driver stderr, driver status, and unconditional final exact
   endpoint with its status;
6. after both dry-runs, regenerate the final artifact reference, input
   manifest, and seal, record their exact identities, and recursively restore
   and re-audit the declared read-only state; and
7. immediately before the supervisor benchmark-GO commit, retain a final
   status-bearing package-scoped seal verification, recursive writable-path
   audit, and exact endpoint audit in the postcollection closure.

Only a complete calibration that passes its frozen comparability gates may
support attribution, target profiling, projected speedup, optimization
selection, capability attribution, or an M2 conclusion.
