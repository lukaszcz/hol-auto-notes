# External review resolution for the failed v10 calibration

## Authority and preservation boundary

This directory is an external erratum for the independently reviewed package
`../m2-v10-small-calibration-final/`.  It is adjacent to, and not inside, that
package.  It was created after collection and after the original package was
sealed.  It is not part of the original precollection seal, does not rewrite
that seal, and grants no retroactive authority to any original claim.

`SEALED-PACKAGE-MANIFEST-BEFORE.tsv` was generated before this resolution
directory existed.  `SEALED-PACKAGE-MANIFEST-AFTER.tsv` was generated after
the documentation changes.  They are byte-identical typed inventories of the
reviewed package: 19 directories, 289 regular files, and no symlinks.  Their
common SHA-256 is recorded in `REVIEWED-PACKAGES.tsv`.  Thus no byte, path, or
symlink target inside the sealed package changed during this resolution.

The exact package-inventory references for both the reviewed package and its
reviewed timed-v4 predecessor are in `REVIEWED-PACKAGES.tsv`.  This erratum
does not make either package more authoritative than its own controlling
review documents.

## Review finding 1: artifact-reference chronology

The original `ARTIFACT-REFERENCE.tsv` is post-seal.  `SEALED.txt` was written
at `2026-07-21 13:13:08.194520287 +0000`; the artifact reference was written
at `2026-07-21 13:13:08.633509963 +0000`.  `PRECOLLECTION.sha256` binds only
`INPUT-MANIFEST.tsv`, not the artifact reference.

The artifact reference has SHA-256
`469a176c9370fe0279e30061d31421f6be098cdde9cd5b9bd07a8a0a36df13ca`.
It is byte-equal to
`collection/child-1/audits/final-artifacts.tsv`, and the postcollection
package checksum and inventory bind it.  Those facts prove postcollection
checksum/equality only.  They do not prove that the reference was
cryptographically immutable from its creation through benchmark GO.  No
retrofit claim is made.

The next fresh protocol must create the artifact reference before benchmark
GO.  One final precollection/GO seal must bind, together and by digest:

- the artifact-reference bytes and exact artifact-auditor identity;
- the frozen schedule; and
- the frozen input manifest.

That seal must be checked before GO and at every post-child/final endpoint.

## Review finding 2: noisy retained preflight endpoint log

`preflight-logs/pre-collection-endpoint.txt` is non-authoritative and noisy.
Its two lines are regex self-matches from the shell command that was running
the audit.  It is not evidence of live benchmark residue and is not a clean
endpoint proof.

The authoritative clean exact `/proc` endpoint artifacts are:

- collector pre-endpoint: `collection/pre-endpoint.txt` (`matches=none`);
- immediate failure endpoint: `collection/failure-endpoint.txt`
  (`matches=none`);
- child final endpoint: `collection/child-1/audits/final-endpoint.txt`
  (`matches=none`, with `endpoint_audit_status=0` in
  `collection/child-1/final-status.txt`); and
- final endpoint: `final-process-audit.txt` (`matches=none`).

The next fresh protocol must use an exact `/proc` identity/endpoint audit,
not regex `pgrep` output, and retain a status for every pre-child,
post-failure/post-child, and final endpoint.

## Review finding 3: elapsed-value terminology

`0.448013836` is only the v10 supervisor runtime interval recorded in
`collection/child-1/raw/supervisor.json`.  The supervisor monotonic timer
begins before launch-vector construction and before wrapper bootstrap, spawn,
and GO.  Elapsed is computed after supervisor cleanup, pidfd closure, and
classification, but before status serialization and durable publication.  It
therefore includes supervisor setup, the failed supervised execution, and
cleanup/classification.  It excludes collector raw sealing, audits, and
publication.  It is not a benchmark time, P38 evidence, external calibration
elapsed, complete collector transaction elapsed, or end-to-end calibration
elapsed.  The harness failed while loading its UI; no calibration row and no
benchmark clock exist.

## Review finding 4: retained live Holmake metadata

The top-level reviewed package retains these live Holmake metadata files:

- `.hol/locks/task7kcalibration.exe.lock`;
- `.hol/locks/task7kcalibration.uo.lock`; and
- `.hol/make-deps/task7kcalibration.sml.d`.

They are inventoried historical package bytes.  They are distinct from the
absent top-level harness executable, UI/UO objects, cache files, live process,
and temporary collection residue.  `frozen-inputs/` intentionally contains
the precollection executable and UI/UO plus its copied metadata as frozen
evidence; those are not live generated residue either.

After freezing inputs, the next fresh protocol must either remove live
Holmake lock/make-dependency metadata before its final seal, or declare the
exact retained metadata and its evidentiary role before that seal.  It may not
claim an artifact-free package while retaining undeclared live metadata.

## Consequence and required fresh retry

Task 7j timed-v4 is a reviewed failed-comparability/protocol chain.  This
Task 7k attempt is a failed pre-clock calibration.  Neither supports timing
attribution, target profiling, projected speedup, optimization selection,
capability attribution, or an M2 conclusion.  Protocol-repair timings are not
benchmark evidence.

A new, separately sealed retry must, before its final seal:

1. use an absolute harness UI path or a frozen, explicitly controlled package
   working directory;
2. run a load-only, no-search, no-timing smoke through the exact collector,
   supervisor, command vector, and working directory intended for collection;
3. freeze or remove the smoke's generated metadata under the declared policy;
4. create the artifact reference and bind its digest, auditor identity,
   schedule, and input manifest in one final seal before benchmark GO; and
5. retain exact `/proc` endpoint audits and statuses throughout collection.

The smoke authorizes only load-path/protocol integration.  It is not a
calibration observation and must not start a benchmark clock or search.
