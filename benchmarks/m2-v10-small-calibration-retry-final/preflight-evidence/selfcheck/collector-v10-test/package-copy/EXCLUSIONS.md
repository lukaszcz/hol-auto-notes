# Runtime artifact-audit exclusions

The exact runtime artifact auditor excludes only these package-relative
regular files:

1. `ARTIFACT-REFERENCE.tsv` — the auditor's own frozen expected output;
2. `GO-SEAL.txt` — the final seal that hashes that reference.

No directory, symlink, generated executable/object/metadata file, smoke
evidence, schedule, manifest, source, validator, or protocol file is excluded.
Collection is outside the package during all children and is therefore not an
auditor exclusion.
