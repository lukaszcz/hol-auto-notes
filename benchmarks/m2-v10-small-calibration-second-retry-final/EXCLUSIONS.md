# Runtime artifact-audit exclusions

The runtime auditor excludes exactly `ARTIFACT-REFERENCE.tsv` and
`GO-SEAL.txt`, avoiding their necessary self-reference.  The input manifest,
schedule, auditor/verifier/driver/wrapper bodies, protocol, smoke evidence,
dry-run evidence, launcher, UI/UO, locks, dependencies, logs, and all other
package files are included.  Collection output lives only below the mandated
scratch root and is not a package exclusion.
