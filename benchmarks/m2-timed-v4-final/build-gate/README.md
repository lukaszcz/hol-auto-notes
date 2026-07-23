# Required development build gate

At HEAD `244b01d7189ac803df48e246a483c33b553e3daa`, the exact command

```text
bin/build -t --seq=tools/sequences/upto-auto
```

ran from 2026-07-21 06:18:06 UTC through 06:23:09 UTC and returned status 0.
The complete combined stdout/stderr is `upto-auto.log`; its SHA-256 and the
before/after HEAD identities are in `provenance.tsv`.

This is the routine `src/auto` development gate required by
`src/auto/CLAUDE.md`. It is not `bin/build -F -t`, does not exercise the full
distribution, and is not claimed as the full M5 phase-boundary gate.
