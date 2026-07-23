# Post-collection checksum-generation repair

After all timing, validation, reporting, plan bookkeeping, and the successful
pre-checksum read-only selfcheck, the first checksum-generation shell command
failed. Its zsh loop used the variable name `path`, which is tied to zsh's
`PATH` array. After the first assignment, each `sha256sum` lookup emitted
`zsh:1: command not found: sha256sum`. The failed scratch manifest is exactly
zero bytes and no package `checksums.sha256` was created. The orchestration
result was nonzero, but its exact numeric status was not retained, so none is
claimed.

This occurred after clocks but did not run a harness, touch raw data, change a
sealed input or runtime artifact, or meet a target retry condition. No timing
was rerun. The corrected mechanical command changes only the local loop
variable to `file_path`, writes under the mandated scratch root, and copies a
complete checksum manifest into the package. The final read-only selfcheck
then verifies it and compares full package manifests before and after.
