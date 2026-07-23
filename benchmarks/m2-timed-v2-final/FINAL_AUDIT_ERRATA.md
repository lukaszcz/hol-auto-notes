# Final post-collection audit errata and integrity repair

This document is the authoritative post-collection correction for the two
initial low-severity final-review findings and the later evidence-tool
findings. It does not amend or replace any frozen input, raw observation,
schedule, runtime artifact manifest, or historical log. No timing was rerun.

## Closure-manifest wording

The phrase "deterministic and sorted by path" in the sealed
`PREDECLARATION.md` is false only as to global sorting. The immutable
413-data-row `ARTIFACTS-FROZEN.tsv` has deterministic sectional order:

1. 398 repository-path records in C-sorted order; then
2. 15 tool records in the deterministic order declared by
   `artifact-manifest.sh`.

This statement overrides only the false phrase "sorted by path" wherever the
frozen predeclaration is cited. It changes no closure membership, file or tool
identity, hash, size, timestamp, pre/post comparison, numeric observation, or
verdict. `final-audit.sh` independently reconstructs the repository-path
membership, checks its C order, checks the declared tool membership and order,
recreates the current closure manifest, and requires the frozen manifest plus
all representative/active/target pre/post endpoints to be byte-identical.

## Package integrity

The old checksum/read-only procedure followed regular files and did not seal
the directory entries for the 12 endpoint-fixture symlinks. The repair adds a
typed deterministic `PACKAGE-INVENTORY.tsv`: ordinary regular files carry
their SHA-256 and every symlink carries its exact, uninterpreted link target.

There is an unavoidable mutual-hash cycle between an inventory and the
checksum file that hashes that inventory. Therefore the inventory omits
itself and `checksums.sha256`; `checksums.sha256` omits only checksum self,
hashes every other regular file, and includes `PACKAGE-INVENTORY.tsv`.
Together these two derived manifests cover all regular files except checksum
self, plus every symlink target. `verify-package-integrity.sh` also proves
that checksum membership is exactly the current regular-file set minus
checksum self and that the regenerated typed inventory is byte-identical.

The current `selfcheck.sh` is an explicit post-collection override of its
frozen body. The frozen original and `INPUTS.sha256` remain byte-identical;
selfcheck verifies every other input-manifest entry and the frozen original.
Its before/after snapshot contains every current regular-file hash and every
exact symlink target. `test-package-integrity.sh` uses a disposable package
copy, proves ordinary selfcheck changes no package entry, retargets only the
copy of `endpoint-preflight/child-task7gactive`, and requires selfcheck to
reject the mutation via the typed inventory. Authoritative fixture symlinks
are never changed.

## Chronology and provenance

The review repair was performed after collection and after the earlier
checksum-generation repair, in this order:

1. capture pre-repair package, protected-evidence, symlink, and affected-file
   hashes under the mandated scratch root;
2. add the erratum, mechanical sectional audit, typed inventory/integrity
   helpers, symlink adversary, and post-collection selfcheck override;
3. update only the current README and plan wording;
4. regenerate only `PACKAGE-INVENTORY.tsv` and `checksums.sha256`;
5. run the complete read-only gates twice and the disposable-copy adversary;
6. compare protected hashes and authoritative symlink targets to the captured
   pre-repair baselines.

The first selfcheck invocation exposed a bug in the new input-manifest path
rebasing: a double-quoted sed expression allowed the selfcheck shell to expand
`$#`, so sed rejected the resulting expression before validation. During that
failed run, the sed diagnostic and an empty checksum-input condition were
observed, but the inner log that displayed them is not retained now. The
surrounding zsh wrapper then attempted to assign its read-only variable
`status`; that outer output and exact status were not retained either. The
faulty intermediate selfcheck body was also not retained. These observations
are not reconstructed as retained evidence, and no complete failed transcript
or body is claimed. No package file was changed by selfcheck, and no timing was
rerun. The repair replaced the expression with an awk field transformation,
regenerated only the two derived integrity manifests, and restarted the
required two clean selfcheck runs from zero.

## Evidence-tool portability repair

A later evidence-tool review found that the current selfcheck and its package
integrity selftest still guarded deletion with a textual, hard-coded scratch
prefix, and that package inventory exclusions depended on the caller's exact
directory spelling. This post-collection repair made these exact changes:

- added `validate-scratch-path.sh`, which accepts an explicit existing scratch
  root and separate scratch directory, rejects `..` and symlink components,
  lexically removes trailing slashes before symlink inspection and
  canonicalization, and returns only a strict canonical descendant for
  deletion;
- changed `selfcheck.sh` and `test-package-integrity.sh` to use that validated
  path, reject overlap with the package, and make no assumption about a
  particular review root;
- canonicalized `PACKAGE_DIR` once in `package-inventory.sh`,
  `verify-package-integrity.sh`, `selfcheck.sh`, `test-package-integrity.sh`,
  and `final-audit.sh` before inventory exclusions or downstream calls;
- added disposable path-safety, outside-marker, repeated-trailing-slash,
  canonical/trailing-slash/safe relative package-path, read-only, and
  symlink-mutation regressions; and
- narrowed the preceding chronology paragraph to the evidence actually
  retained, then updated `README.md` and regenerated only the typed inventory
  and checksum manifests.

No sealed or frozen input, raw observation, runtime artifact, or retained
historical-evidence body was changed; only this current erratum chronology was
narrowed. No tracked source, staging area, commit, or timing run was changed
by this later repair.

Pre-repair SHA-256 values for the affected existing files were:

| File | Pre-repair SHA-256 |
|---|---|
| `README.md` | `94c174f7edeee681b45f505f514c85d25f57311d078cd36260858c871f484146` |
| `selfcheck.sh` | `ff5ef5842c6702e60ddf176a233f5df59efb40630e76a3d4d4717bd3059fb9f4` |
| `checksums.sha256` | `c41f20216aee3aca7a512efa52d554d4b48bb6e4b8ce613dc49b645ed8b26e80` |
| `PLAN_phase_1_2_green.md` | `bfc6eb35392c747607096d1481f502d76d123fdda247939718592ec89c9466e9` |

The final checksums for these files and every new derived package file are
mechanically recorded in `checksums.sha256` (the plan is outside the package
and its final hash is reported in the task handoff). The protected pre-repair
hashes captured for comparison are:

| Evidence | SHA-256 |
|---|---|
| `PREDECLARATION.md` | `f11dccea7e517f765a8252d201d63a175c00f0dfe993eae33898d9212691f990` |
| `ARTIFACTS-FROZEN.tsv` | `fde1f6d4c07229153a8afa5e42334f10741c2693d7b82ac7f64e8d679c242122` |
| `INPUT-MANIFEST.tsv` | `e9a00d95865c45150127fac4db3ae31a1c6a6e7bdaf22d0af81fc2dbaff9bb48` |
| `INPUTS.sha256` | `718225dc6f7ff1fef4e091e4fe063bc1c39d6795b539b9a099f109b26f0ab569` |
| `raw.tsv` | `44fd502b53c5ef6fe7bf28d909eb832ca410c32f61d8aec0eee0716d6e7ca8a3` |
| `calibration-raw.tsv` | `7776e33bc36126dceb34c6b30bee8747f219f210eb5c0438853ac841597fd8d2` |
| `active-calibration-raw.tsv` | `82a80dab756b0053f59b3b6f880c35fef3737e944d8cc2691ccfe40bc7f4dac7` |
