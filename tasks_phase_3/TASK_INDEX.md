# Phase 3 task index

Tasks implementing `.agent-files/PLAN_phase_3.md` (clasimp layer,
`src/auto/clasimp/`).  Mapping to the plan's §12 table: plan tasks
01–02 are TASK_01–02; plan task 03's Docfile half moves into TASK_13
(the Docfiles task), the rest is TASK_03; plan tasks 04–09 are
TASK_04–09; plan task 10 is split into TASK_10 (decision tree +
`Iff` marker) and TASK_11 (persistence); plan tasks 11–13 are
TASK_12–14.  Each task is sized for one agent in a 200k-token
context window.

Per-task gate (plan §12 preamble): `bin/build -t
--seq=tools/sequences/upto-auto`, `Holmake` + `./selftest.exe` in
each touched directory, `tools/h4pedant/h4pedant` on touched
directories.

## Cross-module amendments

- [TASK_01](TASK_01.md): `simpLib` mode-parameterized
  `GEN_GLOBAL_SIMP_TAC` (D31); §3.1; no dependency.
- [TASK_02](TASK_02.md): `classicalLib.CS_DEPTH_SOLVE_TAC` (D32/D36);
  §3.2; no dependency.
- [TASK_03](TASK_03.md): layer-wide insertion refactor (D30); §3.4;
  depends on 02 (shared files).
- [TASK_04](TASK_04.md): `tableauLib.CS_BLAST_DEPTH_TAC` (D33/D36);
  §3.3; depends on 03 (shared files).
- [TASK_05](TASK_05.md): `Simp`/`Iff` marker constructors; §3.5;
  depends on 03.

## The clasimp layer

- [TASK_06](TASK_06.md): `src/auto/clasimp/` scaffold, clasimpset,
  safe-solver stack, `asm_full_simp`/`safe_asm_full_simp`; §4;
  depends on 01.
- [TASK_07](TASK_07.md): `add_simp_wrapper`/`add_safe_simp_wrapper`
  (D37) + argument processor; §5–§6; depends on 05 and 06.
- [TASK_08](TASK_08.md): `FASTFORCE_TAC`/`SLOWSIMP_TAC`/
  `BESTSIMP_TAC`/`CLARSIMP_TAC` + `CS_*` forms; §7.3–§7.4; depends
  on 07.
- [TASK_09](TASK_09.md): `AUTO_TAC`/`AUTO_DEPTH_TAC`/`FORCE_TAC` +
  `CS_*` forms; §7.1–§7.2; depends on 04 and 07.

## `[iff]`, TypeBase, docs, gate

- [TASK_10](TASK_10.md): `[iff]` decision tree + `Iff` marker wiring;
  §8.1; depends on 07.
- [TASK_11](TASK_11.md): `[iff]` persistence — settype, attribute,
  `remove_iff`, theory_tests; §8.2; depends on 06 and 10.
- [TASK_12](TASK_12.md): TypeBase constructor intros; §9; depends
  on 10.
- [TASK_13](TASK_13.md): Docfiles, incl. Phase-1/2 insertion updates
  deferred from TASK_03; §11; depends on 08, 09, 11, 12.
- [TASK_14](TASK_14.md): Phase-3 `bin/build -F -t` gate, expected
  fully green; §12 row 13; depends on all preceding tasks.

Parallelism notes: TASK_01 and TASK_02 are independent.  The
cross-module chain 02→03→04→05 is serial (shared files).  TASK_06
needs only TASK_01 and can run alongside the 02→…→05 chain.  After
TASK_07, TASK_08/TASK_09/TASK_10 all unblock (09 also needs 04);
they share `src/auto/clasimp/` sources and selftest.sml, so should
not run concurrently with each other.  TASK_11 and TASK_12 follow
TASK_10 under the same no-concurrency caveat.  TASK_13 touches only
`help/Docfiles` and can run alongside nothing-else-pending or late
clasimp tasks whose surface is final.
