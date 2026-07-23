# Pre-seal repair ledger

Formal attempt 0 completed both forced builds, both level-2 selftests and all
three harness builds with status zero, then the first endpoint synthetic
returned status 1. It produced no diagnostic line and only created the first
wrapper/child symlink pair; no endpoint log was written. There was no seal,
frozen input manifest, benchmark process, or elapsed row.

The retained `pre-seal-attempt-0/` contains every complete live file body at
the failure, their hashes, the complete preflight status/logs, exact endpoint
directory entries and an attempt-status ledger. A traced diagnostic rerun
under the mandated scratch root showed the sole cause: the wrapper and child
names were correctly `task7h...`, but the three copied non-self-matching
patterns still said `[t]ask7g...`, so the first `pgrep` found no match.

The only repair changes those three endpoint patterns and the identical six
collection endpoint literals plus the environment description from `7g` to
`7h`, and records this ledger. No source, harness semantics, schedule,
validator, threshold, timing, or runtime artifact changed. The complete exact
diff and complete after-bodies are retained beside the failed attempt. The
entire formal preflight is rerun from clean state before seal.
