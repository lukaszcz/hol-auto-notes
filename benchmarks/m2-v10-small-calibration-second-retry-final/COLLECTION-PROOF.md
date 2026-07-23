# Collection proof

The final `collect.sh` ran from repository-root cwd through `run-driver.sh`
with `DRY_RUN=0`.  Its first operations repeated the final scoped seal,
recursive read-only, and exact pre-child endpoint gates.  It then ran exactly
the 20 frozen schedule rows.  `driver-status.tsv` contains 20 ordered zero
statuses; every child has a v10 supervisor record, raw durability seal,
artifact identity equal to the final reference, exact final endpoint, and
zero final status.  No `STOPPED.tsv` exists.

After child 20, the frozen materializer created the 22-line closed raw ledger,
the frozen validator printed `validate-results: PASS`, raw bytes were
immediately SHA-256 sealed, and the frozen summarizer wrote the result.  The
outer wrapper retained driver stdout/stderr/status and an unconditional final
exact endpoint with status zero.  No row was imported, replaced, or rerun.
