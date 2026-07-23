# Pre-freeze artifact-path repair

The first preparation invocation completed the forced classical and blast
builds, both level-2 selftests, all three harness builds, and the complete
synthetic validator/adversary suite with status zero. Before any timing and
before `SEAL_PLAN.md` existed, artifact freezing exited status 1 with the sole
diagnostic retained in `pre-freeze-attempt-0/failure.log`:

`missing artifact: src/auto/classical/clasetUnify.ui`

The complete then-current bodies are retained under
`pre-freeze-attempt-0/frozen-inputs/`, together with that attempt's input
manifest, hashes, partial artifact manifest, command statuses and logs. The
repair changes only the six source-module UI/UO paths in
`artifact-manifest.sh` from nonexistent source-directory paths to the actual
`src/auto/{classical,blast}/.hol/objs/...` build outputs. It also makes the
artifact-freeze command/status an explicit preflight row. The exact unified
diff is `pre-freeze-attempt-0/artifact-manifest.diff`. No harness, schedule,
workload, clock, deadline, validator rule, summarizer or tracked source was
changed, and no timing had begun.
