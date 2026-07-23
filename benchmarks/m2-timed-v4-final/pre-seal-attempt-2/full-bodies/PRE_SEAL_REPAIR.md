# Pre-seal attempt 0 and repair

No benchmark clock or input seal existed. The first seal orchestration was
invoked from zsh without `SH_WORD_SPLIT`, so its scalar list was treated as
one filename; it also omitted the `ROOT` required by `artifact-manifest.sh`.
The command continued because its outer interactive shell lacked `set -e`
and therefore wrote visibly invalid empty/partial generated seal files.

`pre-seal-attempt-0/` retains those exact generated bodies plus the complete
protocol bodies present at the attempt. `failure.log` retains the diagnostics.
The only repair is to rerun the generation under `bash -c 'set -eu; ...'`,
set `ROOT` explicitly, and include this ledger in the frozen input list. No
predeclaration, schedule, harness, validator, threshold or process-control
semantics changed, and no timing retry is involved.

The first bash repair invocation became pre-seal attempt 1: nested quoting
expanded the inner AWK `$1` under `set -u`. It stopped immediately after the
closure manifest and before any clock. `pre-seal-attempt-1/` retains its full
bodies, generated files and sole diagnostic. The second mechanical repair
removes AWK from hash extraction (`read -r hash ignored` consumes
`sha256sum` output). Again, no protocol semantic changed.
