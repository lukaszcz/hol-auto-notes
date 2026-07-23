# Post-boundary-fix build provenance

The classical source/test chain was touched and rebuilt with
`Holmake selftest.exe`; that dependency traversal also rebuilt the downstream
`classicalLib` object.  The blast reconstruction UI/UO, selftest UI/UO/exe,
and all three harness UI/UO/executables were then explicitly removed and
regenerated with the temporary rules in `POST_BOUNDARY_FIX_HOLMAKE_RULES.txt`;
the traversal also rebuilt the downstream `tableauLib` object.
`post-boundary-fix-*-build.log` retains the builds' output.

The full `HOLSELFTESTLEVEL=2` classical and blast executables both completed
successfully.  Their complete logs are
`post-boundary-fix-classical-selftest.log` and
`post-boundary-fix-blast-selftest.log`; the latter contains the new green
terminal-clock boundary test and the unchanged corpus outcomes.

`POST_BOUNDARY_FIX_COMMAND_STATUS_TRANSCRIPT.txt` gives reconstructed
descriptions of the retained copy/install, temporary-rule, build,
forced-removal/rebuild, level-2 test, hash/freshness, and cleanup operations
and their supported status-0 results.  The original shell history was not
retained.  Consequently that document is not runnable and does not invent
normalized command history; the reproduction script below is the only
supported runnable procedure.

Source/object hashes:

    932f33bc66da0a4a91015db69d705d51ea1b4fa5783e3df6c1617e0ed2ed08c7  clasetStep.sig
    5001c9696b936b3df92c2dcf4b9d0a4a837909ef5eefac849068eded77751f8c  clasetStep.sml
    99a90ba3b76a69581b7119466a4eacdd436c2a5ddb9fb4f598598c994fc1a904  clasetStep.ui
    26ccc6eb57f4344aff96d27a6bdc136f6dc7108bf973680264d98401597826c5  clasetStep.uo
    8eba44194bc93b27f6ac157f0a8acffcd83a69a0b01bdfdfed110b4e7c94e113  blastReconstruct.sig
    6c2dda62a4ccbe3390cd8d17e06ca613f284f5e3ccfa5023a9e31643082faa6d  blastReconstruct.sml
    7bc48d7b9e0428b855cc3882d0849fc5ff218fcaa3ebde714e0c970b34ea89b4  blastReconstruct.ui
    0f8173d32e0ca18c9fb00ef66ab9f834f6b18571eaa3a30f2246f61189bb493b  blastReconstruct.uo

Test source/object/executable hashes:

    431edd6370ab2abc1ddfbe8986c1bcfbdfa5c3b0caa2dfd18cabf54759be66ba  classical/selftest.sml
    fac893e68ea4900467287ae5ddedbcf83590a3fdec0b9b0707ba00f48e763f44  classical/selftest.uo
    74d761d5517d8e1897f4a899954bd8faa124adc9a83ed9be280dac97837a94cf  blast/selftest.sml
    2ccac0e1ac743e44460c098cc45fe827c7a81dc29cc3379d3eccc87765280581  blast/selftest.uo
    466c2ec01a4f4542d48922c81205ae610ab68cbd11cfefada61a85984041882f  selftest.exe

Harness object/executable hashes:

    1faf718ccd3849d5dcaeea2a576398bfd1abfdb1d2146c67c5855d1345242205  m2clasetime.uo
    17ecc78c97f84e0feed59bd70a028da39c4e8a680ce60db286215057873a2de0  m2clasetime.exe
    d9368156737b879b70a83827daab2d0d3d5db36807ba9fcc6c62b51adda6b0bc  workcalibration.uo
    3f474924c658d28680881a9541864c16f2a74d6f56f53b658120eccedbd1a71f  workcalibration.exe
    4608cb802b3f275d78f0a94861fb5ca9afcd5217b4c969133b2f5c80939a8d08  activecalibration.uo
    20d9904a6d01f58c498aeaf20c117ca0ead52b32a1c3ea030fbfd230cbeff8e9  activecalibration.exe

Classical sources have integer mtime 1784545154 and their UI/UO/selftest
artifacts are later within that second.  Blast reconstruction/test/harness
sources have mtime 1784545189; reconstruction UI/UO are 1784545241 and every
final test/harness artifact is 1784545317.  The measured executables are thus
fresh relative to every changed or installed source.  The tables above are
the hashes retained for the completed authoritative run; they do not pretend
to retrofit unrecorded historical hashes for `classicalLib`, `tableauLib`, or
harness UI files.  The current reproducer closes that capture gap explicitly.

## Direct build/selftest reproduction

From the configured repository root, choose a new output directory and run:

    output=/tmp/isabelle-tactics-task7f-20260720-root/reproductions/fresh
    .agent-files/benchmarks/m2-claset-time/reproduce-post-boundary-build.sh \
      "$output"

The executable requires a fresh absolute canonical output outside the entire
physical source repository.  It rejects relative, dot/dotdot,
symlinked-parent and existing paths, plus source/output containment in either
direction.  Before copying, it hashes and stats the authoritative
implementation and test sources, all three harnesses, both Holmakefiles, the
rule fragment, required tools/configuration, and baseline chain artifacts.

Declared GNU `cp -a` copies the complete repository to `OUTPUT/worktree`.
Copied top-level linked-worktree `.git` metadata is removed without running a
git command there.  External copied `.codex`, `.pi`, and `.claude` metadata is
also removed before configuration.  Absolute copied links back into the
source are rebased to the copy.  Every remaining absolute link is path-listed
and categorized; build-relevant/source-internal and sigobj links must resolve
inside the copy, while other external links are explicitly counted rather
than covered by a false global claim.  From the copy root, with `HOLDIR` unset,
the supported `poly < tools/smart-configure.sml` regenerates launch tools and
configuration.  Copied Holmake startup/help and hol heapname diagnostics then
check HOLDIR, state0/default-state, sigobj and tools.  Copied Holmake also runs
one explicit harmless recipe from a tiny diagnostic Holmakefile, with ancestor
preexecs and ambient project/overlay/prerequisite discovery disabled.  Its
debug/recipe output and created existing target are retained, canonicalized
below the copy, and checked for original-root resolution.  A post-copy source
manifest equals the pre-copy manifest, and the isolated required-input
manifest must equal both.  Any mismatch retains output and a diagnostic diff.
Before copying, every external ancestor of the future copy must be free of
Holmake/preexec/project metadata.  The copied real target is additionally
wrapped in Linux `strace -f -e trace=file`; every syscall path is retained and
even one reference to the original root rejects the run.  This requires GNU
userland, `/usr/bin/strace`, and ptrace permission.

The output directory receives five retained-style build/test logs, a
command/status transcript, a SHA-256 capture, and a stat/freshness capture.
Those captures enumerate `clasetStep` through `classicalLib` and classical
selftest, `blastReconstruct` through `tableauLib` and blast selftest, and each
of the three harness source/UI/UO/executable chains.  Every path is hashed and
statted.  Every direct prerequisite edge uses non-strict integer-second
ordering, appropriate to same-second UI/UO writes, together with explicit
forced-removal and build-start evidence.

Harnesses, rules, removals, builds, and tests occur only after that preflight,
with PATH restricted to copied bin and validated system directories; HOLDIR
is never exported.  A Python 3 supervisor solely owns each spawning command's
new session/process group, forwards TERM then escalates to KILL, verifies group
absence and reaps.  Outer signal traps only forward every HUP/INT/TERM to the
active supervisor and return, including repeated signals; they never infer or
signal a PGID.  The shell reaps the supervisor and records quiescence only
after parsing its retained group-gone PASS event.  Negative child signal
returns are normalized to `128+N` when the supervisor itself was unsignaled.
The output is retained on success, failure or signal.  There is no
backup, restore, recovery lock, or cleanup: the procedure never writes a
source path.  `--print` reports the plan without modification; `--self-check`
exercises a type-preserving isolated copy without running HOL.  The executable
`--relocation-check` stops before HOL build/test and removes its disposable
copy after retaining real diagnostics.  `test-reproduction-isolation.sh`
supplies synthetic filesystem and active-descendant adversaries only; it is
not relocation evidence.  Superseded logs are under `pre-relocation-history/`.
The later pre-final summaries are under `pre-final-relocation-history/`.

The final real relocation proof is the status-0 private-namespace run at the
exact host path recorded in `NAMESPACE_RELOCATION_INVOCATION.md`.  Its input
manifest matches all 40 current authoritative inputs byte-for-byte, including
the current reproducer and process-group supervisor.  The compact retained raw
subset is `authoritative-relocation-evidence/`; hashes for omitted bulky raw
manifests and link audits are pinned there.  This relocation check performs no
HOL build, selftest, calibration, or target timing.

This reproduction does not rerun either timing driver and cannot make its
outputs authoritative measurement evidence.
