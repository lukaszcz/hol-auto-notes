> **HISTORICAL / VOID:** Every later claim of authority in this file is void.
> This package is non-authoritative; use `../m2-timed-v2-final/`.

# Post-collection validator portability repair

The complete 13-line target ledger, ending in its unique EOF record, was
sealed at SHA-256
`1b7b00ead818f2e6a6691f6faaa62dc5d6de402d9675083e39aea6146fceb308`
before this repair.  All three processes had status zero and the exact
predeclared attempt schedule.  The validator then failed during AWK parsing
because this implementation reserves the built-in function name `close`.
No data rejection occurred and no target was rerun.

The sole repair renames the local numeric tolerance helper from `close` to
`near` at its definition and call sites.  Its body, tolerance and every
validation rule remain byte-for-byte otherwise unchanged.  The original raw
ledger is immutable and is checked against `AUTHORITATIVE_RAW.sha256` before
validation or adversarial generation.

The first semantic pass then exposed one predeclared-identity transcription
error: combined `cooperative_checkpoints` counts outer plus stored-rule
checkpoints, while `outer_seen` counts only the former.  The validator now
requires `outer_seen + stored_seen = cooperative_checkpoints`, alongside the
already independent `stored_seen = stored_rule_checkpoints` identity.  This
is the API's defined partition, not a threshold or data-dependent relaxation;
the failed diagnostic is retained in `validator-repair.log`.

The next pass also found that the context checker had incorrectly required
the optional elimination-assumption position to be concrete whenever the
other stored fields were concrete.  The API permits `none` there (notably for
intro rules).  The repaired rule requires all eight fields absent together,
or fields 1--7 concrete with field 8 independently `none` or a natural.  This
matches the predeclared coherent-optional-context rule and does not weaken any
timing or ordering identity.

Finally, fixture generation produced the declared independent corruptions as
24 files, while the test's terminal count literal mistakenly said 23.  All 24
had already been rejected before that count check.  The literal and PASS text
now say 24; fixture contents and rejection logic are unchanged.
