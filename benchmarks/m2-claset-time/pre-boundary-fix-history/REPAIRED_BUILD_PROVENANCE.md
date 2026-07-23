# Historical pre-boundary repaired-final build provenance

Historical/non-authoritative notice: these hashes and builds precede the
terminal-clock boundary fix.  Current hashes and build provenance are in
`../POST_BOUNDARY_FIX_BUILD_PROVENANCE.md`.

Build command from `src/auto/blast`, status 0:

    Holmake m2clasetime.exe workcalibration.exe activecalibration.exe > ../../..//.agent-files/benchmarks/m2-claset-time/repaired-final-build.log 2>&1

The exact temporary rules are in `TEMPORARY_HOLMAKE_RULES.txt`.  The build
log is `repaired-final-build.log`.  Retained/installed harness source hashes
matched byte-for-byte:

    ef2e6077e641153ccc5731371c905f290830ab9b19d5512baac27c67dd4811af  m2clasetime.sml
    6e5a57c241d622fc635f1816c42fc94c541653d74a1b8499d0a106c5fc7343e3  workcalibration.sml
    92c8a1ae41eabf7fe163a69693d1c1003f31c44bab1b19ba42c6a544a43f6dd6  activecalibration.sml

Final measured implementation source/object hashes:

    932f33bc66da0a4a91015db69d705d51ea1b4fa5783e3df6c1617e0ed2ed08c7  clasetStep.sig
    5001c9696b936b3df92c2dcf4b9d0a4a837909ef5eefac849068eded77751f8c  clasetStep.sml
    99a90ba3b76a69581b7119466a4eacdd436c2a5ddb9fb4f598598c994fc1a904  clasetStep.ui
    26ccc6eb57f4344aff96d27a6bdc136f6dc7108bf973680264d98401597826c5  clasetStep.uo
    68876bf67fb491eaa39b63fd092065a3bbf1068729d61799510a85c5152f41fa  blastReconstruct.sig
    9f930a241465486c4cd69c48559c268c8da3508a7a6fe5c6e7d8a62f223f992d  blastReconstruct.sml
    7bc48d7b9e0428b855cc3882d0849fc5ff218fcaa3ebde714e0c970b34ea89b4  blastReconstruct.ui
    0f8173d32e0ca18c9fb00ef66ab9f834f6b18571eaa3a30f2246f61189bb493b  blastReconstruct.uo

Harness object/executable hashes:

    1faf718ccd3849d5dcaeea2a576398bfd1abfdb1d2146c67c5855d1345242205  m2clasetime.uo
    17ecc78c97f84e0feed59bd70a028da39c4e8a680ce60db286215057873a2de0  m2clasetime.exe
    d9368156737b879b70a83827daab2d0d3d5db36807ba9fcc6c62b51adda6b0bc  workcalibration.uo
    3f474924c658d28680881a9541864c16f2a74d6f56f53b658120eccedbd1a71f  workcalibration.exe
    4608cb802b3f275d78f0a94861fb5ca9afcd5217b4c969133b2f5c80939a8d08  activecalibration.uo
    20d9904a6d01f58c498aeaf20c117ca0ead52b32a1c3ea030fbfd230cbeff8e9  activecalibration.exe

After explicitly deleting and regenerating the affected relocated UI/UO
manifests, freshness was rechecked with integer-second mtimes.
`clasetStep.ui/.uo` (1784542408) are newer than its newest source
(1784542336); `blastReconstruct.ui/.uo` and every harness UI/UO/executable
(1784542428) are newer than the reconstruction source (1784540693) and
harness sources (1784541395).  `repaired-final-classical-build.log` and
`repaired-final-rebuild.log` retain those forced rebuilds.  Full regenerated
classical and blast selftests then returned status 0 in their retained logs.
Thus the regenerated-final measured executables correspond to the repaired
sources, not stale objects.
