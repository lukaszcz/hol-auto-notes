#!/bin/sh
set -eu

usage() {
  printf '%s\n' \
    "usage: $0 OUTPUT-DIRECTORY" \
    "       $0 --relocation-check OUTPUT-DIRECTORY" \
    "       $0 --print" \
    "       $0 --self-check"
}

die() {
  printf 'reproduction: %s\n' "$*" >&2
  exit 1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

require_tools() {
  cp --version 2>/dev/null | grep 'GNU coreutils' >/dev/null 2>&1 ||
    die "GNU cp with archive mode (-a) is required"
  stat --version 2>/dev/null | grep 'GNU coreutils' >/dev/null 2>&1 ||
    die "GNU stat is required"
  realpath --version 2>/dev/null | grep 'GNU coreutils' >/dev/null 2>&1 ||
    die "GNU realpath is required"
  find --version 2>/dev/null | grep 'GNU findutils' >/dev/null 2>&1 ||
    die "GNU find is required"
  setsid --version 2>/dev/null | grep 'util-linux' >/dev/null 2>&1 ||
    die "util-linux setsid is required"
  if command -v sha256sum >/dev/null 2>&1; then
    DIGEST=sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    DIGEST='shasum -a 256'
  else
    die "sha256sum or shasum is required"
  fi
}

validate_system_tool() {
  name=$1
  found=$(command -v "$name" 2>/dev/null) ||
    die "required system tool is absent from sanitized PATH: $name"
  case $found in
    /*) ;;
    *) die "system tool is not an external absolute command: $name=$found" ;;
  esac
  resolved=$(realpath -e -- "$found") ||
    die "cannot resolve required system tool: $name=$found"
  case $resolved in
    /usr/local/bin/*|/usr/bin/*) ;;
    *) die "system tool resolves outside whitelisted directories: $resolved" ;;
  esac
  printf 'system_tool name=%s command=%s resolved=%s result=PASS\n' \
    "$name" "$found" "$resolved" >> "$SYSTEM_AUDIT"
}

validate_system_tools() {
  : > "$SYSTEM_AUDIT"
  for name in cp stat realpath find sha256sum sed grep dirname cmp rm mkdir \
      date env setsid ps sleep sort readlink chmod ln uname make cc poly polyc \
      strings awk python3 sh cat diff mktemp mv wc; do
    validate_system_tool "$name"
  done
  validate_system_tool strace
  printf 'sanitized_system_path=%s\n' "$SYSTEM_PATH" >> "$SYSTEM_AUDIT"
}

digest() {
  # DIGEST is set only to one of the two declarations above.
  $DIGEST "$1" | sed 's/ .*//'
}

input_paths() {
  cat <<'EOF'
.agent-files/benchmarks/m2-claset-time/POST_BOUNDARY_FIX_HOLMAKE_RULES.txt
.agent-files/benchmarks/m2-claset-time/activecalibration.sml
.agent-files/benchmarks/m2-claset-time/m2clasetime.sml
.agent-files/benchmarks/m2-claset-time/process-group-supervisor.py
.agent-files/benchmarks/m2-claset-time/reproduce-post-boundary-build.sh
.agent-files/benchmarks/m2-claset-time/workcalibration.sml
bin/Holmake
bin/hol
bin/hol.state
bin/hol.state0
src/auto/blast/.hol/objs/blastReconstruct.ui
src/auto/blast/.hol/objs/blastReconstruct.uo
src/auto/blast/.hol/objs/selftest.ui
src/auto/blast/.hol/objs/selftest.uo
src/auto/blast/.hol/objs/tableauLib.ui
src/auto/blast/.hol/objs/tableauLib.uo
src/auto/blast/Holmakefile
src/auto/blast/blastReconstruct.sig
src/auto/blast/blastReconstruct.sml
src/auto/blast/selftest.exe
src/auto/blast/selftest.sml
src/auto/blast/tableauLib.sig
src/auto/blast/tableauLib.sml
src/auto/classical/.hol/objs/clasetStep.ui
src/auto/classical/.hol/objs/clasetStep.uo
src/auto/classical/.hol/objs/classicalLib.ui
src/auto/classical/.hol/objs/classicalLib.uo
src/auto/classical/.hol/objs/selftest.ui
src/auto/classical/.hol/objs/selftest.uo
src/auto/classical/Holmakefile
src/auto/classical/clasetStep.sig
src/auto/classical/clasetStep.sml
src/auto/classical/classicalLib.sig
src/auto/classical/classicalLib.sml
src/auto/classical/selftest.exe
src/auto/classical/selftest.sml
tools/smart-configure.sml
tools-poly/configure.sml
tools-poly/smart-configure.sml
tools-poly/Holmake/unix-systeml.sml
EOF
}

manifest() {
  base=$1
  output=$2
  : > "$output"
  input_paths | while IFS= read -r rel; do
    path=$base/$rel
    [ -f "$path" ] && [ ! -L "$path" ] || {
      printf 'missing-or-nonregular\t%s\n' "$rel" >> "$output"
      continue
    }
    hash=$(digest "$path")
    stat -c \
      "$hash\tmode=%a\tuid=%u\tgid=%g\tsize=%s\tmtime=%Y\t$rel" \
      -- "$path" >> "$output"
  done
  if grep '^missing-or-nonregular' "$output" >/dev/null 2>&1; then
    return 1
  fi
}

tree_manifest() {
  base=$1
  output=$2
  (
    cd "$base" || exit 1
    find -P . -mindepth 1 -printf '%P\n' | LC_ALL=C sort |
      while IFS= read -r rel; do
        if [ -L "$rel" ]; then
          stat -c \
            'symlink mode=%a uid=%u gid=%g mtime=%Y ctime=%Z size=%s path=%n' \
            -- "$rel"
          printf 'target=%s path=%s\n' "$(readlink -- "$rel")" "$rel"
        elif [ -f "$rel" ]; then
          hash=$(digest "$rel")
          stat -c \
            "file hash=$hash mode=%a uid=%u gid=%g mtime=%Y ctime=%Z size=%s path=%n" \
            -- "$rel"
        elif [ -d "$rel" ]; then
          stat -c \
            'directory mode=%a uid=%u gid=%g mtime=%Y ctime=%Z size=%s path=%n' \
            -- "$rel"
        else
          stat -c \
            'other mode=%a uid=%u gid=%g mtime=%Y ctime=%Z size=%s path=%n' \
            -- "$rel"
        fi
      done
  ) > "$output"
}

validate_source_root() {
  PACKAGE=.agent-files/benchmarks/m2-claset-time
  CLASSICAL=src/auto/classical
  BLAST=src/auto/blast
  RULES=$PACKAGE/POST_BOUNDARY_FIX_HOLMAKE_RULES.txt
  manifest "$ROOT" "$1" ||
    die "required source, harness, rule, tool, or baseline artifact is missing"
  [ -x "$ROOT/bin/hol" ] || die "source bin/hol is not executable"
  [ -x "$ROOT/bin/Holmake" ] || die "source bin/Holmake is not executable"
}

validate_output() {
  raw=$1
  case $raw in
    ''|.|..|*/.|*/..|*/) die "output must be a fresh canonical directory" ;;
  esac
  case $raw in
    /*) ;;
    *) die "output path must be absolute and canonical" ;;
  esac

  canonical=$(realpath -m -- "$raw") ||
    die "cannot canonicalize output path: $raw"
  [ "$raw" = "$canonical" ] ||
    die "output path is not canonical (dot or symlink alias): $raw"
  parent=$(dirname -- "$raw")
  physical_parent=$(cd "$parent" 2>/dev/null && pwd -P) ||
    die "output parent must already exist: $parent"
  [ "$parent" = "$physical_parent" ] ||
    die "output parent contains a symlink or noncanonical component: $parent"
  ! path_exists "$canonical" ||
    die "output path already exists: $canonical"

  case $canonical in
    "$ROOT"|"$ROOT"/*)
      die "output must be outside the entire source repository: $ROOT"
      ;;
  esac
  case $ROOT in
    "$canonical"|"$canonical"/*)
      die "output may not contain the source repository: $ROOT"
      ;;
  esac
  OUTPUT=$canonical
}

audit_future_copy_ancestors() {
  future_copy=$OUTPUT/worktree
  audit=$OUTPUT/external-ancestor-metadata.txt
  : > "$audit"
  probe=$future_copy
  while :; do
    for name in Holmakefile .hol_preexec holproject.toml \
        holproject.local.toml; do
      if path_exists "$probe/$name"; then
        printf 'ancestor path=%s metadata=%s scope=external state=present\n' \
          "$probe" "$name" >> "$audit"
        die "ambient external Holmake metadata above future copy: $probe/$name"
      else
        printf 'ancestor path=%s metadata=%s scope=external state=absent\n' \
          "$probe" "$name" >> "$audit"
      fi
    done
    [ "$probe" = / ] && break
    probe=$(dirname -- "$probe")
  done
  printf 'external_ancestor_metadata status=0 audit=%s\n' "${audit##*/}" \
    >> "$TRANSCRIPT"
}

source_unchanged() {
  label=$1
  current=$OUTPUT/source-$label.sha256
  if ! manifest "$ROOT" "$current"; then
    printf 'input_stability label=%s result=FAIL reason=missing\n' "$label" \
      >> "$TRANSCRIPT"
    return 1
  fi
  if ! cmp -s "$OUTPUT/source-before-copy.sha256" "$current"; then
    printf 'input_stability label=%s result=FAIL reason=changed\n' "$label" \
      >> "$TRANSCRIPT"
    diff -u "$OUTPUT/source-before-copy.sha256" "$current" \
      > "$OUTPUT/source-$label.diff" 2>&1 || :
    return 1
  fi
  printf 'input_stability label=%s result=PASS\n' "$label" \
    >> "$TRANSCRIPT"
}

source_tree_unchanged() {
  label=$1
  current=$OUTPUT/source-tree-$label.manifest
  if ! tree_manifest "$ROOT" "$current"; then
    printf 'source_tree_stability label=%s result=FAIL reason=manifest\n' \
      "$label" >> "$TRANSCRIPT"
    return 1
  fi
  if ! cmp -s "$OUTPUT/source-tree-before.manifest" "$current"; then
    printf 'source_tree_stability label=%s result=FAIL reason=changed\n' \
      "$label" >> "$TRANSCRIPT"
    diff -u "$OUTPUT/source-tree-before.manifest" "$current" \
      > "$OUTPUT/source-tree-$label.diff" 2>&1 || :
    return 1
  fi
  printf 'source_tree_stability label=%s result=PASS\n' "$label" \
    >> "$TRANSCRIPT"
}

signal_name=none
signal_count=0
signal_status=0
active_pid=

on_signal() {
  received=$1
  received_status=$2
  signal_count=$((signal_count + 1))
  if [ "$signal_name" = none ]; then
    signal_name=$received
    signal_status=$received_status
  fi
  if [ -n "$active_pid" ]; then
    printf 'outer_signal received=%s count=%s supervisor_pid=%s action=forward\n' \
      "$received" "$signal_count" "$active_pid" >> "$TRANSCRIPT"
    kill -"$received" "$active_pid" 2>/dev/null || :
  else
    printf 'outer_signal received=%s count=%s action=no-active-supervisor\n' \
      "$received" "$signal_count" >> "$TRANSCRIPT"
  fi
  return 0
}

on_exit() {
  status=$?
  trap - EXIT HUP INT TERM
  if [ -n "${active_pid:-}" ]; then
    cleanup_pid=$active_pid
    cleanup_events=${active_events:-}
    kill -TERM "$cleanup_pid" 2>/dev/null || :
    while kill -0 "$cleanup_pid" 2>/dev/null; do
      wait "$cleanup_pid" 2>/dev/null || :
    done
    wait "$cleanup_pid" 2>/dev/null || :
    active_pid=
    if [ -n "$cleanup_events" ] &&
        grep '^command_group_gone .* result=PASS$' "$cleanup_events" \
          >/dev/null 2>&1; then
      printf 'supervisor_cleanup_quiescent pid=%s evidence=%s result=PASS\n' \
        "$cleanup_pid" "${cleanup_events##*/}" >> "$TRANSCRIPT"
    else
      printf 'supervisor_cleanup_quiescent pid=%s result=FAIL\n' \
        "$cleanup_pid" >> "$TRANSCRIPT"
      status=1
    fi
  fi
  if [ "${EXIT_MANIFEST_DONE:-0}" != 1 ] && \
      [ -n "${OUTPUT:-}" ] && [ -f "${OUTPUT:-}/source-tree-before.manifest" ]; then
    source_tree_unchanged at-exit || status=1
  fi
  exit "$status"
}

pause_at_gate() {
  gate=$1
  label=$2
  [ -n "$gate" ] || return 0
  printf 'test_pause=%s gate=%s\n' "$label" "$gate" >> "$TRANSCRIPT"
  printf 'reproduction: test pause %s\n' "$label"
  while [ ! -e "$gate" ]; do sleep 1; done
}

check_isolated_conflicts() {
  grep -E '(^|[^[:alnum:]_])(m2clasetime|workcalibration|activecalibration)' \
    "$COPY/$BLAST/Holmakefile" >/dev/null 2>&1 &&
    die "isolated blast Holmakefile already contains a harness rule"

  for base in m2clasetime workcalibration activecalibration; do
    installed=$COPY/$BLAST/$base.sml
    retained=$COPY/$PACKAGE/$base.sml
    if path_exists "$installed"; then
      [ -f "$installed" ] && [ ! -L "$installed" ] &&
        cmp -s "$retained" "$installed" ||
        die "conflicting harness in isolated copy: $BLAST/$base.sml"
    else
      for rel in \
        "$BLAST/$base.ui" "$BLAST/$base.uo" "$BLAST/$base.exe" \
        "$BLAST/.hol/objs/$base.ui" \
        "$BLAST/.hol/objs/$base.uo" \
        "$BLAST/.hol/make-deps/$base.sig.d" \
        "$BLAST/.hol/make-deps/$base.sml.d"; do
        ! path_exists "$COPY/$rel" ||
          die "orphan harness artifact in isolated copy: $rel"
      done
    fi
  done
}

require_copy_containment() {
  rel=$1
  resolved=$(realpath -e -- "$COPY/$rel") ||
    die "required isolated path cannot be resolved: $rel"
  case $resolved in
    "$COPY"/*) ;;
    *) die "required isolated path escapes through a symlink: $rel" ;;
  esac
}

validate_copy_executable() {
  rel=$1
  require_copy_containment "$rel"
  [ -x "$COPY/$rel" ] || die "isolated executable is not executable: $rel"
  resolved=$(realpath -e -- "$COPY/$rel") ||
    die "cannot resolve isolated executable: $rel"
  case $resolved in
    "$COPY"/*) ;;
    *) die "isolated executable resolves outside copy: $rel=$resolved" ;;
  esac
  printf 'copied_executable path=%s resolved=%s result=PASS\n' \
    "$rel" "$resolved" >> "$SYSTEM_AUDIT"
}

validate_isolated_layout() {
  for rel in bin tools tools-poly sigobj "$PACKAGE" "$CLASSICAL" "$BLAST"; do
    [ -d "$COPY/$rel" ] && [ ! -L "$COPY/$rel" ] ||
      die "required isolated directory is missing or symlinked: $rel"
    require_copy_containment "$rel"
  done
  for rel in bin/hol bin/hol.state bin/hol.state0 bin/Holmake \
      tools/smart-configure.sml tools-poly/smart-configure.sml \
      tools-poly/configure.sml tools-poly/Holmake/unix-systeml.sml; do
    [ -f "$COPY/$rel" ] && [ ! -L "$COPY/$rel" ] ||
      die "required isolated tool/config is missing or symlinked: $rel"
    require_copy_containment "$rel"
  done
  validate_copy_executable bin/hol
  validate_copy_executable bin/Holmake
}

rebase_copied_internal_symlinks() {
  SYMLINK_AUDIT=$OUTPUT/copied-symlink-audit.txt
  : > "$SYMLINK_AUDIT"
  find -P "$COPY" -type l -print | while IFS= read -r link; do
    target=$(readlink -- "$link") || exit 1
    case $target in
      "$ROOT") replacement=$COPY ;;
      "$ROOT"/*) replacement=$COPY/${target#"$ROOT"/} ;;
      *)
        printf 'symlink path=%s target=%s action=preserved-external-or-relative\n' \
          "${link#"$COPY"/}" "$target" >> "$SYMLINK_AUDIT"
        continue
        ;;
    esac
    ln -snf -- "$replacement" "$link" || exit 1
    printf 'symlink path=%s old=%s new=%s action=rebased\n' \
      "${link#"$COPY"/}" "$target" "$replacement" >> "$SYMLINK_AUDIT"
  done || die "failed to audit/rebase copied internal symlinks"
  printf 'copied_symlinks status=0 audit=%s\n' "${SYMLINK_AUDIT##*/}" \
    >> "$TRANSCRIPT"
}

neutralize_external_metadata() {
  METADATA_AUDIT=$OUTPUT/external-metadata-neutralization.txt
  : > "$METADATA_AUDIT"
  for rel in .codex .pi .claude; do
    path=$COPY/$rel
    if path_exists "$path"; then
      links=$(find -P "$path" -type l -print 2>/dev/null | wc -l)
      printf 'metadata path=%s action=remove symlink_count=%s\n' \
        "$rel" "$links" >> "$METADATA_AUDIT"
      find -P "$path" -type l -printf 'removed_link path=%p target=%l\n' \
        2>/dev/null | sed "s|path=$COPY/|path=|" >> "$METADATA_AUDIT"
      rm -rf -- "$path"
    else
      printf 'metadata path=%s action=absent symlink_count=0\n' \
        "$rel" >> "$METADATA_AUDIT"
    fi
    ! path_exists "$path" || die "could not neutralize copied metadata: $rel"
  done
  printf 'external_metadata status=0 audit=%s\n' "${METADATA_AUDIT##*/}" \
    >> "$TRANSCRIPT"
}

audit_absolute_symlinks() {
  ABSOLUTE_LINK_AUDIT=$OUTPUT/remaining-absolute-symlinks.txt
  : > "$ABSOLUTE_LINK_AUDIT"
  total=0
  required=0
  external_other=0
  find -P "$COPY" -type l -print | while IFS= read -r link; do
    target=$(readlink -- "$link") || exit 1
    case $target in
      /*) ;;
      *) continue ;;
    esac
    rel=${link#"$COPY"/}
    case $rel in
      sigobj/*) category=sigobj ;;
      bin/*|tools/*|tools-poly/*|src/*)
        category=build-relevant-or-source-internal
        ;;
      *) category=other ;;
    esac
    resolved=$(realpath -e -- "$link" 2>/dev/null || printf DANGLING)
    containment=external
    case $resolved in
      "$COPY"/*) containment=copy ;;
    esac
    printf 'absolute_link path=%s target=%s resolved=%s category=%s containment=%s\n' \
      "$rel" "$target" "$resolved" "$category" "$containment"
    if [ "$category" != other ] && [ "$containment" != copy ]; then
      exit 1
    fi
  done > "$ABSOLUTE_LINK_AUDIT.raw" ||
    die "build-relevant, source-internal, or sigobj absolute link escapes copy"
  total=$(wc -l < "$ABSOLUTE_LINK_AUDIT.raw")
  required=$(grep -c 'category=\(sigobj\|build-relevant-or-source-internal\)' \
    "$ABSOLUTE_LINK_AUDIT.raw" || :)
  external_other=$(grep -c 'category=other containment=external' \
    "$ABSOLUTE_LINK_AUDIT.raw" || :)
  printf 'absolute_link_counts total=%s required_contained=%s external_other=%s\n' \
    "$total" "$required" "$external_other" >> "$ABSOLUTE_LINK_AUDIT"
  cat "$ABSOLUTE_LINK_AUDIT.raw" >> "$ABSOLUTE_LINK_AUDIT"
  rm -f -- "$ABSOLUTE_LINK_AUDIT.raw"
  printf 'absolute_symlinks status=0 total=%s required_contained=%s ' \
    "$total" "$required" >> "$TRANSCRIPT"
  printf 'external_other=%s audit=%s\n' "$external_other" \
    "${ABSOLUTE_LINK_AUDIT##*/}" >> "$TRANSCRIPT"
}

assert_sigobj_contained() {
  find -P "$COPY/sigobj" -type l -print | while IFS= read -r link; do
    resolved=$(realpath -e -- "$link") || exit 1
    case $resolved in
      "$COPY"/*) ;;
      *) exit 1 ;;
    esac
    printf 'sigobj_link path=%s resolved=%s result=PASS\n' \
      "${link#"$COPY"/}" "$resolved" \
      >> "$OUTPUT/relocation-sigobj-links.txt"
  done || die "a copied sigobj link is dangling or escapes the copy"
  printf 'sigobj_links audit=relocation-sigobj-links.txt result=PASS\n' \
    >> "$OUTPUT/relocation-assertions.txt"
}

reject_original_root() {
  rel=$1
  if strings "$COPY/$rel" | grep -F "$ROOT" >/dev/null 2>&1; then
    strings "$COPY/$rel" | grep -F "$ROOT" \
      > "$OUTPUT/original-root-${rel##*/}.txt" 2>&1 || :
    die "regenerated launcher/config embeds original root: $rel"
  fi
  printf 'embedded_original_root path=%s result=ABSENT\n' "$rel" \
    >> "$OUTPUT/relocation-assertions.txt"
}

assert_line() {
  expected=$1
  file=$2
  grep -F -x "$expected" "$file" >/dev/null 2>&1 ||
    die "missing exact relocation diagnostic: $expected"
  printf 'exact_line=%s result=PASS\n' "$expected" \
    >> "$OUTPUT/relocation-assertions.txt"
}

configure_and_check_relocation() {
  PATH=$COPY/bin:$SYSTEM_PATH
  export PATH
  unset HOLDIR
  printf 'effective_path=%s\nholdir_environment=UNSET\n' "$PATH" \
    >> "$SYSTEM_AUDIT"

  printf 'smart_configure cwd=%s command="poly < tools/smart-configure.sml"\n' \
    "$COPY" >> "$TRANSCRIPT"
  run_logged smart_configure . smart-configure.log \
    sh -c 'exec poly < tools/smart-configure.sml'
  validate_copy_executable bin/hol
  validate_copy_executable bin/Holmake

  run_logged holmake_startup_diagnostic . holmake-startup.log \
    "$COPY/bin/Holmake" --dbg=startup --help \
    --holstate="$COPY/bin/hol.state0"
  run_logged hol_heapname_diagnostic . hol-heapname.log \
    "$COPY/bin/hol" heapname

  diagnostic_dir=$COPY/.task7f-relocation-diagnostic
  diagnostic_holmakefile=$diagnostic_dir/Holmakefile
  diagnostic_target=$diagnostic_dir/relocation-target
  diagnostic_message='relocation diagnostic target created below copied root'
  mkdir -- "$diagnostic_dir"
  printf 'INCLUDES =\nPRE_INCLUDES =\n' > "$diagnostic_holmakefile"
  printf 'relocation-target:\n\tprintf "%%s\\n" "%s" > relocation-target\n' \
    "$diagnostic_message" >> "$diagnostic_holmakefile"
  cp -- "$diagnostic_holmakefile" \
    "$OUTPUT/relocation-diagnostic-Holmakefile.txt"
  ancestor_audit=$OUTPUT/holmake-ancestor-audit.txt
  : > "$ancestor_audit"
  probe=$diagnostic_dir
  while :; do
    case $probe in
      "$COPY"|"$COPY"/*) scope=copy ;;
      *) scope=external ;;
    esac
    for name in Holmakefile .hol_preexec holproject.toml \
        holproject.local.toml; do
      if path_exists "$probe/$name"; then
        printf 'ancestor path=%s metadata=%s scope=%s state=present\n' \
          "$probe" "$name" "$scope" >> "$ancestor_audit"
        [ "$scope" = copy ] ||
          die "ambient external Holmake metadata above diagnostic: $probe/$name"
      else
        printf 'ancestor path=%s metadata=%s scope=%s state=absent\n' \
          "$probe" "$name" "$scope" >> "$ancestor_audit"
      fi
    done
    [ "$probe" = / ] && break
    probe=$(dirname -- "$probe")
  done
  printf 'real_target_controls preexecs=disabled project=disabled ' \
    >> "$TRANSCRIPT"
  printf 'overlay=disabled recursive_prereqs=disabled ' >> "$TRANSCRIPT"
  printf 'includes=empty pre_includes=empty debug=builddepgraph\n' \
    >> "$TRANSCRIPT"
  run_logged holmake_real_target . holmake-real-target.log \
    env -u OLDPWD PWD="$diagnostic_dir" \
    strace -f -e trace=file -o "$OUTPUT/holmake-real-target.strace" \
    "$COPY/bin/Holmake" --dbg=builddepgraph --verbose \
    --no_preexecs --no-project \
    --no_overlay --no_prereqs --holmakefile="$diagnostic_holmakefile" \
    --directory="$diagnostic_dir" --holstate="$COPY/bin/hol.state0" \
    relocation-target
  [ -f "$diagnostic_target" ] && [ ! -L "$diagnostic_target" ] ||
    die "copied Holmake did not create the explicit diagnostic target"
  cp -- "$diagnostic_target" "$OUTPUT/relocation-diagnostic-target.txt"
  grep -F "$ROOT" "$OUTPUT/holmake-real-target.strace" \
    > "$OUTPUT/holmake-real-target.original-accesses.txt" 2>&1 || :
  [ ! -s "$OUTPUT/holmake-real-target.original-accesses.txt" ] ||
    die "copied Holmake accessed the original root; see retained strace"
  printf 'strace_file_access original_root_accesses=0 result=PASS\n' \
    >> "$OUTPUT/relocation-assertions.txt.pending"

  : > "$OUTPUT/relocation-assertions.txt"
  cat "$OUTPUT/relocation-assertions.txt.pending" \
    >> "$OUTPUT/relocation-assertions.txt"
  rm -f -- "$OUTPUT/relocation-assertions.txt.pending"
  assert_line "[startup] HOLDIR = $COPY" \
    "$OUTPUT/holmake-startup.log"
  grep -F "CommandLine.name() = $COPY/bin/Holmake" \
    "$OUTPUT/holmake-startup.log" >/dev/null 2>&1 ||
    die "Holmake did not start from the copied executable"
  grep -F "$COPY/bin/hol.state0" "$OUTPUT/holmake-startup.log" \
    >/dev/null 2>&1 || die "Holmake did not receive the copied state0 path"
  assert_line "$COPY/bin/hol.state" "$OUTPUT/hol-heapname.log"
  if grep -F "$ROOT" "$OUTPUT/holmake-startup.log" >/dev/null 2>&1; then
    die "Holmake startup diagnostic resolved the original source root"
  fi
  printf 'startup_original_root result=ABSENT\n' \
    >> "$OUTPUT/relocation-assertions.txt"

  for spec in \
      "sigobj $COPY/sigobj" \
      "tools $COPY/tools" \
      "state0 $COPY/bin/hol.state0" \
      "default-state $COPY/bin/hol.state"; do
    set -- $spec
    resolved=$(realpath -e -- "$2") ||
      die "relocation path does not exist: $1=$2"
    case $resolved in
      "$COPY"/*) ;;
      *) die "relocation path escapes copy: $1=$resolved" ;;
    esac
    printf 'resolved_path role=%s path=%s result=PASS\n' "$1" "$resolved" \
      >> "$OUTPUT/relocation-assertions.txt"
  done
  generated=$(realpath -e -- "$diagnostic_target") ||
    die "cannot canonicalize existing generated target diagnostic"
  case $generated in
    "$COPY"/*) ;;
    *) die "generated target diagnostic escapes copy: $generated" ;;
  esac
  printf 'resolved_path role=generated-target path=%s result=PASS\n' \
    "$generated" >> "$OUTPUT/relocation-assertions.txt"
  grep -F 'relocation diagnostic target created below copied root' \
    "$OUTPUT/relocation-diagnostic-target.txt" >/dev/null 2>&1 ||
    die "diagnostic target did not contain its harmless recipe marker"
  grep -F 'relocation-target' "$OUTPUT/holmake-real-target.log" \
    >/dev/null 2>&1 || die "Holmake target/recipe output was not retained"
  grep '^\[builddepgraph\]' "$OUTPUT/holmake-real-target.log" \
    >/dev/null 2>&1 || die "Holmake target debug output was not retained"
  if grep -F "$ROOT" "$OUTPUT/holmake-real-target.log" \
      >/dev/null 2>&1; then
    die "Holmake real-target diagnostic resolved the original source root"
  fi
  printf 'real_target_created path=%s no_preexecs=yes result=PASS\n' \
    "$generated" >> "$OUTPUT/relocation-assertions.txt"
  printf 'ancestor_metadata audit=holmake-ancestor-audit.txt result=PASS\n' \
    >> "$OUTPUT/relocation-assertions.txt"

  for rel in \
      tools/Holmake/Systeml.sml \
      bin/Holmake \
      bin/hol \
      tools/editor-modes/emacs/hol-mode.el \
      tools/editor-modes/vim/hol-config.sml \
      tools/editor-modes/vim/filetype.vim; do
    [ -f "$COPY/$rel" ] && [ ! -L "$COPY/$rel" ] ||
      die "regenerated launcher/config missing or symlinked: $rel"
    require_copy_containment "$rel"
    reject_original_root "$rel"
  done
  : > "$OUTPUT/relocation-sigobj-links.txt"
  assert_sigobj_contained
  for rel in bin/hol bin/Holmake bin/hol.state bin/hol.state0 \
      tools/Holmake/Systeml.sml; do
    require_copy_containment "$rel"
    printf 'used_path=%s resolved=%s result=PASS\n' "$rel" \
      "$(realpath -e -- "$COPY/$rel")" \
      >> "$OUTPUT/relocation-assertions.txt"
  done
  printf 'relocation_preflight status=0 configure_log=smart-configure.log ' \
    >> "$TRANSCRIPT"
  printf 'startup_log=holmake-startup.log target_log=holmake-real-target.log ' \
    >> "$TRANSCRIPT"
  printf 'strace=holmake-real-target.strace ' >> "$TRANSCRIPT"
  printf 'assertions=relocation-assertions.txt\n' \
    >> "$TRANSCRIPT"
}

install_harnesses() {
  for base in m2clasetime workcalibration activecalibration; do
    cp -- "$COPY/$PACKAGE/$base.sml" "$COPY/$BLAST/$base.sml"
    cmp -s "$COPY/$PACKAGE/$base.sml" "$COPY/$BLAST/$base.sml"
    printf 'install path=%s/%s.sml status=0\n' "$BLAST" "$base" \
      >> "$TRANSCRIPT"
  done
  printf '\n' >> "$COPY/$BLAST/Holmakefile"
  sed '/^# Recipe indentation below/d' "$COPY/$RULES" \
    >> "$COPY/$BLAST/Holmakefile"
  printf 'append_rules status=0\n' >> "$TRANSCRIPT"
}

record_remove() {
  rel=$1
  path=$COPY/$rel
  if path_exists "$path"; then
    if [ -f "$path" ] && [ ! -L "$path" ]; then
      printf 'remove before=present hash=%s ' "$(digest "$path")" \
        >> "$REMOVALS"
      stat -c 'mtime=%Y size=%s mode=%a path=%n' -- "$path" \
        >> "$REMOVALS"
    else
      printf 'remove before=present-nonregular path=%s\n' "$rel" \
        >> "$REMOVALS"
    fi
    rm -f -- "$path"
  else
    printf 'remove before=absent path=%s\n' "$rel" >> "$REMOVALS"
  fi
  ! path_exists "$path" || die "forced removal failed: $rel"
  printf 'remove after=absent path=%s\n' "$rel" >> "$REMOVALS"
}

remove_chain() {
  dir=$1
  shift
  for base in "$@"; do
    record_remove "$dir/$base.ui"
    record_remove "$dir/$base.uo"
    record_remove "$dir/$base.exe"
    record_remove "$dir/.hol/objs/$base.ui"
    record_remove "$dir/.hol/objs/$base.uo"
    record_remove "$dir/.hol/make-deps/$base.sig.d"
    record_remove "$dir/.hol/make-deps/$base.sml.d"
    record_remove "$dir/.hol/locks/$base.ui.lock"
    record_remove "$dir/.hol/locks/$base.uo.lock"
    record_remove "$dir/.hol/locks/$base.exe.lock"
  done
}

run_logged() {
  label=$1
  dir=$2
  logfile=$3
  shift 3
  set +e
  events=$OUTPUT/$logfile.supervisor-events
  active_events=$events
  supervisor_pid_file=$OUTPUT/$logfile.supervisor-pid
  : > "$events"
  rm -f -- "$supervisor_pid_file"
  python3 "$COPY/$PACKAGE/process-group-supervisor.py" \
    --cwd "$COPY/$dir" --events "$events" \
    --pid-file "$supervisor_pid_file" -- "$@" \
    > "$OUTPUT/$logfile" 2>&1 &
  active_pid=$!
  polls=0
  while [ ! -s "$supervisor_pid_file" ] && \
      kill -0 "$active_pid" 2>/dev/null && [ "$polls" -lt 100 ]; do
    sleep 0.05
    polls=$((polls + 1))
  done
  [ -s "$supervisor_pid_file" ] || {
    wait "$active_pid" 2>/dev/null || :
    active_pid=
    die "process-group supervisor did not publish its pid: $label"
  }
  supervisor_pid=$(sed -n '1p' "$supervisor_pid_file")
  case $supervisor_pid in
    ''|*[!0-9]*)
      wait "$active_pid" 2>/dev/null || :
      active_pid=
      die "process-group supervisor published an invalid pid: $label"
      ;;
  esac
  [ "$supervisor_pid" = "$active_pid" ] ||
    die "process-group supervisor pid does not match waitable child: $label"
  printf 'supervisor_start label=%s cwd=%s pid=%s log=%s events=%s\n' \
    "$label" "$COPY/$dir" "$active_pid" "$logfile" "${events##*/}" \
    >> "$TRANSCRIPT"
  while :; do
    wait "$active_pid"
    status=$?
    if kill -0 "$active_pid" 2>/dev/null; then
      printf 'supervisor_wait interrupted_status=%s pid=%s action=resume\n' \
        "$status" "$active_pid" >> "$TRANSCRIPT"
      continue
    fi
    break
  done
  completed_pid=$active_pid
  active_pid=
  active_events=
  set -e
  sed 's/^/supervisor_event /' "$events" >> "$TRANSCRIPT"
  if ! grep '^command_group_gone .* result=PASS$' "$events" \
      >/dev/null 2>&1; then
    printf 'supervisor_quiescent pid=%s evidence=%s result=FAIL\n' \
      "$completed_pid" "${events##*/}" >> "$TRANSCRIPT"
    exit 1
  fi
  printf 'supervisor_quiescent pid=%s evidence=%s result=PASS\n' \
    "$completed_pid" "${events##*/}" >> "$TRANSCRIPT"
  printf '%s status=%s log=%s\n' "$label" "$status" "$logfile" \
    >> "$TRANSCRIPT"
  if [ "$signal_status" -ne 0 ]; then
    printf 'reproduction: interrupted by %s; retained output: %s\n' \
      "$signal_name" "$OUTPUT" >&2
    exit "$signal_status"
  fi
  [ "$status" -eq 0 ] || exit "$status"
}

emit_artifact() {
  rel=$1
  mkdir -p -- "$(dirname -- "$COPY/$rel")"
  printf 'synthetic rebuilt artifact: %s\n' "$rel" > "$COPY/$rel"
}

synthetic_build_and_test() {
  for rel in \
    "$CLASSICAL/.hol/objs/clasetStep.ui" \
    "$CLASSICAL/.hol/objs/clasetStep.uo" \
    "$CLASSICAL/.hol/objs/classicalLib.ui" \
    "$CLASSICAL/.hol/objs/classicalLib.uo" \
    "$CLASSICAL/.hol/objs/selftest.ui" \
    "$CLASSICAL/.hol/objs/selftest.uo" \
    "$CLASSICAL/selftest.exe" \
    "$BLAST/.hol/objs/blastReconstruct.ui" \
    "$BLAST/.hol/objs/blastReconstruct.uo" \
    "$BLAST/.hol/objs/tableauLib.ui" \
    "$BLAST/.hol/objs/tableauLib.uo" \
    "$BLAST/.hol/objs/selftest.ui" \
    "$BLAST/.hol/objs/selftest.uo" \
    "$BLAST/selftest.exe"; do
    emit_artifact "$rel"
  done
  for base in m2clasetime workcalibration activecalibration; do
    emit_artifact "$BLAST/.hol/objs/$base.ui"
    emit_artifact "$BLAST/.hol/objs/$base.uo"
    emit_artifact "$BLAST/$base.exe"
  done
  printf 'synthetic classical build; HOL not executed\n' \
    > "$OUTPUT/post-boundary-fix-classical-build.log"
  printf 'synthetic blast build; HOL not executed\n' \
    > "$OUTPUT/post-boundary-fix-blast-harness-build.log"
  printf 'synthetic blast rebuild; HOL not executed\n' \
    > "$OUTPUT/post-boundary-fix-blast-harness-rebuild.log"
  printf 'synthetic classical test; HOL not executed\n' \
    > "$OUTPUT/post-boundary-fix-classical-selftest.log"
  printf 'synthetic blast test; HOL not executed\n' \
    > "$OUTPUT/post-boundary-fix-blast-selftest.log"
  printf '%s\n' \
    'classical_build status=0 synthetic=yes' \
    'blast_harness_build status=0 synthetic=yes' \
    'blast_harness_rebuild status=0 synthetic=yes' \
    'classical_level2 status=0 synthetic=yes' \
    'blast_level2 status=0 synthetic=yes' >> "$TRANSCRIPT"
}

hash_stat() {
  chain=$1
  role=$2
  rel=$3
  path=$COPY/$rel
  [ -f "$path" ] && [ ! -L "$path" ] ||
    die "expected isolated build-chain file is missing: $rel"
  printf '%s  %s\n' "$(digest "$path")" "$rel" >> "$HASHES"
  stat -c \
    "chain=$chain role=$role mtime=%Y size=%s mode=%a path=$rel" \
    -- "$path" >> "$FRESH"
}

fresh_edge() {
  chain=$1
  prerequisite=$2
  target=$3
  why=$4
  ptime=$(stat -c '%Y' -- "$COPY/$prerequisite")
  ttime=$(stat -c '%Y' -- "$COPY/$target")
  [ "$ttime" -ge "$ptime" ] ||
    die "stale isolated edge $chain: $target predates $prerequisite"
  printf '%s\n' \
    "edge chain=$chain prerequisite=$prerequisite target=$target" \
    "  prerequisite_mtime=$ptime target_mtime=$ttime ordering=>=" \
    "  result=PASS reason=$why" \
    >> "$FRESH"
}

build_start_edge() {
  rel=$1
  mtime=$(stat -c '%Y' -- "$COPY/$rel")
  [ "$mtime" -ge "$BUILD_START" ] ||
    die "artifact predates forced build start: $rel"
  printf 'build_start_edge artifact=%s artifact_mtime=%s ' \
    "$rel" "$mtime" >> "$FRESH"
  printf 'start=%s result=PASS\n' "$BUILD_START" >> "$FRESH"
}

capture_freshness() {
  : > "$HASHES"
  : > "$FRESH"
  printf 'build_start_epoch=%s build_start_utc=%s\n' \
    "$BUILD_START" "$BUILD_START_UTC" >> "$FRESH"
  printf 'removal_evidence=%s\n' "${REMOVALS##*/}" >> "$FRESH"

  for spec in \
    "classical clasetStep-sig $CLASSICAL/clasetStep.sig" \
    "classical clasetStep-sml $CLASSICAL/clasetStep.sml" \
    "classical clasetStep-ui $CLASSICAL/.hol/objs/clasetStep.ui" \
    "classical clasetStep-uo $CLASSICAL/.hol/objs/clasetStep.uo" \
    "classical classicalLib-sig $CLASSICAL/classicalLib.sig" \
    "classical classicalLib-sml $CLASSICAL/classicalLib.sml" \
    "classical classicalLib-ui $CLASSICAL/.hol/objs/classicalLib.ui" \
    "classical classicalLib-uo $CLASSICAL/.hol/objs/classicalLib.uo" \
    "classical selftest-sml $CLASSICAL/selftest.sml" \
    "classical selftest-ui $CLASSICAL/.hol/objs/selftest.ui" \
    "classical selftest-uo $CLASSICAL/.hol/objs/selftest.uo" \
    "classical selftest-exe $CLASSICAL/selftest.exe" \
    "blast blastReconstruct-sig $BLAST/blastReconstruct.sig" \
    "blast blastReconstruct-sml $BLAST/blastReconstruct.sml" \
    "blast blastReconstruct-ui $BLAST/.hol/objs/blastReconstruct.ui" \
    "blast blastReconstruct-uo $BLAST/.hol/objs/blastReconstruct.uo" \
    "blast tableauLib-sig $BLAST/tableauLib.sig" \
    "blast tableauLib-sml $BLAST/tableauLib.sml" \
    "blast tableauLib-ui $BLAST/.hol/objs/tableauLib.ui" \
    "blast tableauLib-uo $BLAST/.hol/objs/tableauLib.uo" \
    "blast selftest-sml $BLAST/selftest.sml" \
    "blast selftest-ui $BLAST/.hol/objs/selftest.ui" \
    "blast selftest-uo $BLAST/.hol/objs/selftest.uo" \
    "blast selftest-exe $BLAST/selftest.exe"; do
    set -- $spec
    hash_stat "$1" "$2" "$3"
  done
  for base in m2clasetime workcalibration activecalibration; do
    hash_stat "$base" source "$BLAST/$base.sml"
    hash_stat "$base" ui "$BLAST/.hol/objs/$base.ui"
    hash_stat "$base" uo "$BLAST/.hol/objs/$base.uo"
    hash_stat "$base" exe "$BLAST/$base.exe"
  done

  fresh_edge classical "$CLASSICAL/clasetStep.sig" \
    "$CLASSICAL/.hol/objs/clasetStep.ui" signature-to-ui
  fresh_edge classical "$CLASSICAL/clasetStep.sml" \
    "$CLASSICAL/.hol/objs/clasetStep.uo" source-to-uo
  fresh_edge classical "$CLASSICAL/.hol/objs/clasetStep.ui" \
    "$CLASSICAL/.hol/objs/clasetStep.uo" ui-to-uo
  fresh_edge classical "$CLASSICAL/classicalLib.sig" \
    "$CLASSICAL/.hol/objs/classicalLib.ui" signature-to-ui
  fresh_edge classical "$CLASSICAL/classicalLib.sml" \
    "$CLASSICAL/.hol/objs/classicalLib.uo" source-to-uo
  fresh_edge classical "$CLASSICAL/.hol/objs/classicalLib.ui" \
    "$CLASSICAL/.hol/objs/classicalLib.uo" ui-to-uo
  fresh_edge classical "$CLASSICAL/.hol/objs/clasetStep.uo" \
    "$CLASSICAL/.hol/objs/classicalLib.uo" direct-Holmake-prerequisite
  fresh_edge classical "$CLASSICAL/selftest.sml" \
    "$CLASSICAL/.hol/objs/selftest.ui" source-to-ui
  fresh_edge classical "$CLASSICAL/selftest.sml" \
    "$CLASSICAL/.hol/objs/selftest.uo" source-to-uo
  fresh_edge classical "$CLASSICAL/.hol/objs/selftest.ui" \
    "$CLASSICAL/.hol/objs/selftest.uo" ui-to-uo
  fresh_edge classical "$CLASSICAL/.hol/objs/classicalLib.uo" \
    "$CLASSICAL/.hol/objs/selftest.uo" direct-Holmake-prerequisite
  fresh_edge classical "$CLASSICAL/.hol/objs/selftest.uo" \
    "$CLASSICAL/selftest.exe" direct-Holmake-prerequisite

  fresh_edge blast "$BLAST/blastReconstruct.sig" \
    "$BLAST/.hol/objs/blastReconstruct.ui" signature-to-ui
  fresh_edge blast "$BLAST/blastReconstruct.sml" \
    "$BLAST/.hol/objs/blastReconstruct.uo" source-to-uo
  fresh_edge blast "$BLAST/.hol/objs/blastReconstruct.ui" \
    "$BLAST/.hol/objs/blastReconstruct.uo" ui-to-uo
  fresh_edge blast "$BLAST/tableauLib.sig" \
    "$BLAST/.hol/objs/tableauLib.ui" signature-to-ui
  fresh_edge blast "$BLAST/tableauLib.sml" \
    "$BLAST/.hol/objs/tableauLib.uo" source-to-uo
  fresh_edge blast "$BLAST/.hol/objs/tableauLib.ui" \
    "$BLAST/.hol/objs/tableauLib.uo" ui-to-uo
  fresh_edge blast "$BLAST/.hol/objs/blastReconstruct.uo" \
    "$BLAST/.hol/objs/tableauLib.uo" direct-Holmake-prerequisite
  fresh_edge blast "$BLAST/selftest.sml" \
    "$BLAST/.hol/objs/selftest.ui" source-to-ui
  fresh_edge blast "$BLAST/selftest.sml" \
    "$BLAST/.hol/objs/selftest.uo" source-to-uo
  fresh_edge blast "$BLAST/.hol/objs/selftest.ui" \
    "$BLAST/.hol/objs/selftest.uo" ui-to-uo
  fresh_edge blast "$BLAST/.hol/objs/tableauLib.uo" \
    "$BLAST/.hol/objs/selftest.uo" direct-Holmake-prerequisite
  fresh_edge blast "$BLAST/.hol/objs/selftest.uo" \
    "$BLAST/selftest.exe" direct-Holmake-prerequisite

  for base in m2clasetime workcalibration activecalibration; do
    fresh_edge "$base" "$BLAST/$base.sml" \
      "$BLAST/.hol/objs/$base.ui" source-to-ui
    fresh_edge "$base" "$BLAST/$base.sml" \
      "$BLAST/.hol/objs/$base.uo" source-to-uo
    fresh_edge "$base" "$BLAST/.hol/objs/$base.ui" \
      "$BLAST/.hol/objs/$base.uo" ui-to-uo
    fresh_edge "$base" "$BLAST/.hol/objs/tableauLib.uo" \
      "$BLAST/.hol/objs/$base.uo" direct-rule-prerequisite
    fresh_edge "$base" "$BLAST/.hol/objs/$base.uo" \
      "$BLAST/$base.exe" direct-rule-prerequisite
    fresh_edge "$base" "$BLAST/.hol/objs/tableauLib.uo" \
      "$BLAST/$base.exe" direct-rule-prerequisite
  done

  for rel in \
    "$CLASSICAL/.hol/objs/clasetStep.ui" \
    "$CLASSICAL/.hol/objs/clasetStep.uo" \
    "$CLASSICAL/.hol/objs/classicalLib.ui" \
    "$CLASSICAL/.hol/objs/classicalLib.uo" \
    "$CLASSICAL/.hol/objs/selftest.ui" \
    "$CLASSICAL/.hol/objs/selftest.uo" \
    "$CLASSICAL/selftest.exe" \
    "$BLAST/.hol/objs/blastReconstruct.ui" \
    "$BLAST/.hol/objs/blastReconstruct.uo" \
    "$BLAST/.hol/objs/tableauLib.ui" \
    "$BLAST/.hol/objs/tableauLib.uo" \
    "$BLAST/.hol/objs/selftest.ui" \
    "$BLAST/.hol/objs/selftest.uo" \
    "$BLAST/selftest.exe"; do
    build_start_edge "$rel"
  done
  for base in m2clasetime workcalibration activecalibration; do
    build_start_edge "$BLAST/.hol/objs/$base.ui"
    build_start_edge "$BLAST/.hol/objs/$base.uo"
    build_start_edge "$BLAST/$base.exe"
  done
}

self_check() {
  fixture=$(mktemp -d "${TMPDIR:-/tmp}/task7f-isolation-check.XXXXXX") ||
    die "could not create self-check fixture"
  source=$fixture/source
  isolated=$fixture/output/worktree
  mkdir -p "$source/tree" "$isolated"
  printf 'source value\n' > "$source/tree/value"
  ln -s value "$source/tree/link"
  before=$(digest "$source/tree/value")
  cp -a -- "$source/." "$isolated/"
  [ -L "$isolated/tree/link" ]
  printf 'isolated mutation\n' > "$isolated/tree/value"
  after=$(digest "$source/tree/value")
  [ "$before" = "$after" ]
  [ "$(cat "$source/tree/value")" = 'source value' ]
  rm -rf -- "$fixture"
  printf '%s\n' \
    'type_preserving_copy=PASS' \
    'isolated_mutation=PASS' \
    'source_content_unchanged=PASS' \
    'isolated_copy_self_check=PASS'
}

[ "$#" -ge 1 ] || { usage >&2; exit 2; }
MODE=run
case $#:$1 in
  1:--print) MODE=print ;;
  1:--self-check) MODE=self-check ;;
  2:--relocation-check) MODE=relocation; shift ;;
  1:--*) usage >&2; exit 2 ;;
  1:*) ;;
  *) usage >&2; exit 2 ;;
esac

SYSTEM_PATH=/usr/local/bin:/usr/bin:/bin
PATH=$SYSTEM_PATH
export PATH
require_tools
if [ "$MODE" = self-check ]; then
  self_check
  exit 0
fi

ROOT=$(pwd -P)
if [ "$MODE" = print ]; then
  printf '%s\n' \
    "source: $ROOT (read-only to this procedure)" \
    '1. require a fresh absolute canonical output outside the entire source' \
    '   repository; reject dot, dotdot, symlink-parent, existing, and either' \
    '   direction of source/output containment' \
    '2. hash/stat all authoritative inputs and required baseline artifacts' \
    '3. copy the complete source tree with GNU cp -a to output/worktree' \
    '4. remove copied .git and external .codex/.pi/.claude metadata;' \
    '   rebase and categorize every remaining absolute copied symlink' \
    '5. sanitize PATH, leave HOLDIR unset, and smart-configure in the copy' \
    '6. use copied Holmake to create one explicit harmless diagnostic target' \
    '   with ancestor preexecs disabled; reject original-root resolution' \
    '7. re-hash the comprehensive source tree and retain drift diagnostics' \
    '8. install rules/harnesses only in the conflict-free isolated copy' \
    '9. record removals/build start; rebuild and run level-2 tests there' \
    '10. hash/stat chains; check all direct edges with >= timestamp order' \
    '11. re-hash source; retain output on success or failure,' \
    '   including HUP, INT, TERM, and repeated-signal interruption' \
    '12. the outer shell only forwards signals and reaps; the Python' \
    '   supervisor alone owns TERM/KILL and verified group disappearance' \
    '13. --relocation-check stops before harness/build/test work and removes' \
    '   its disposable copy after retaining raw configuration/diagnostics' \
    '14. never modify, lock, back up, restore, or delete source-tree paths'
  exit 0
fi

if [ "${TASK7F_SYNTHETIC:-0}" = 1 ]; then
  [ -f "$ROOT/.task7f-synthetic-fixture" ] ||
    die "synthetic mode is restricted to a marked disposable test fixture"
elif [ -n "${TASK7F_TEST_AFTER_COPY_GATE:-}" ] ||
    [ -n "${TASK7F_TEST_BEFORE_BUILD_GATE:-}" ] ||
    [ "${TASK7F_TEST_HANDLER_PAUSE:-0}" = 1 ] ||
    [ -n "${TASK7F_TEST_ACTIVE_DESCENDANT_MARKER:-}" ] ||
    [ -n "${TASK7F_TEST_DESCENDANT_DELAY:-}" ] ||
    [ "${TASK7F_TEST_DESCENDANT_IGNORE_TERM:-0}" = 1 ] ||
    [ -n "${TASK7F_TEST_PARENT_PID_FILE:-}" ]; then
  die "test hooks require marked synthetic mode"
fi

[ "$MODE" != relocation ] || [ "${TASK7F_SYNTHETIC:-0}" != 1 ] ||
  die "relocation-check requires the real copied HOL4 tools"

validate_output "$1"
mkdir -- "$OUTPUT"
TRANSCRIPT=$OUTPUT/command-status-transcript.txt
: > "$TRANSCRIPT"
printf 'source_root=%s\noutput=%s\ncopy_method=GNU-cp--archive\n' \
  "$ROOT" "$OUTPUT" >> "$TRANSCRIPT"
SYSTEM_AUDIT=$OUTPUT/path-tool-audit.txt
validate_system_tools
printf 'system_path_audit status=0 file=%s\n' "${SYSTEM_AUDIT##*/}" \
  >> "$TRANSCRIPT"
if [ "${TASK7F_SYNTHETIC:-0}" != 1 ]; then
  audit_future_copy_ancestors
else
  printf 'external_ancestor_metadata status=SKIPPED reason=synthetic-no-Holmake\n' \
    >> "$TRANSCRIPT"
fi

tree_manifest "$ROOT" "$OUTPUT/source-tree-before.manifest" ||
  die "could not capture comprehensive source-tree manifest"
printf 'source_tree_manifest_before status=0 hash_metadata=mode,mtime,ctime,uid,gid\n' \
  >> "$TRANSCRIPT"
EXIT_MANIFEST_DONE=0

trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
trap 'on_exit' EXIT
if [ -n "${TASK7F_TEST_PARENT_PID_FILE:-}" ]; then
  printf '%s\n' "$$" > "$TASK7F_TEST_PARENT_PID_FILE"
fi

if ! validate_source_root "$OUTPUT/source-before-copy.sha256"; then
  exit 1
fi
printf 'input_manifest_before status=0\n' >> "$TRANSCRIPT"
script_path=$ROOT/$PACKAGE/reproduce-post-boundary-build.sh
printf 'hash=%s size=%s path=%s\n' "$(digest "$script_path")" \
  "$(stat -c '%s' -- "$script_path")" \
  "$PACKAGE/reproduce-post-boundary-build.sh" \
  > "$OUTPUT/invoked-script-manifest.txt"
printf 'invoked_script_manifest status=0 file=invoked-script-manifest.txt\n' \
  >> "$TRANSCRIPT"

COPY=$OUTPUT/worktree
mkdir -- "$COPY"
cp -a -- "$ROOT/." "$COPY/"
printf 'copy status=0 destination=%s\n' "$COPY" >> "$TRANSCRIPT"

# A linked worktree's .git file points back into the source repository.
# It has no role in this procedure and must not be usable from the copy.
if path_exists "$COPY/.git"; then
  rm -rf -- "$COPY/.git"
fi
! path_exists "$COPY/.git" || die "could not neutralize copied .git metadata"
printf 'copied_git_metadata action=removed status=0\n' >> "$TRANSCRIPT"

neutralize_external_metadata
rebase_copied_internal_symlinks
audit_absolute_symlinks
validate_isolated_layout
printf 'isolated_tools status=0\n' >> "$TRANSCRIPT"
PATH=$COPY/bin:$SYSTEM_PATH
export PATH
unset HOLDIR

pause_at_gate "${TASK7F_TEST_AFTER_COPY_GATE:-}" after-copy
if ! source_unchanged after-copy; then
  die "relevant inputs changed while snapshot was taken; output retained"
fi
if ! manifest "$COPY" "$OUTPUT/copy-after-copy.sha256"; then
  die "isolated copy is missing a required input; output retained"
fi
if ! cmp -s "$OUTPUT/source-before-copy.sha256" \
    "$OUTPUT/copy-after-copy.sha256"; then
  diff -u "$OUTPUT/source-before-copy.sha256" \
    "$OUTPUT/copy-after-copy.sha256" \
    > "$OUTPUT/source-copy.diff" 2>&1 || :
  die "isolated copy does not match input snapshot; output retained"
fi
printf 'copy_manifest_match status=0\n' >> "$TRANSCRIPT"

if [ "${TASK7F_SYNTHETIC:-0}" != 1 ]; then
  configure_and_check_relocation
  if ! source_tree_unchanged after-relocation-preflight; then
    die "source tree changed during real relocation preflight"
  fi
  if [ "$MODE" = relocation ]; then
    rm -rf -- "$COPY"
    ! path_exists "$COPY" || die "could not remove disposable relocated copy"
    printf 'disposable_copy action=removed status=0\n' >> "$TRANSCRIPT"
    if ! source_tree_unchanged after-relocation-cleanup; then
      die "source tree changed during relocation preflight cleanup"
    fi
    EXIT_MANIFEST_DONE=1
    printf 'relocation_check_complete status=0 raw_output=%s\n' "$OUTPUT" \
      >> "$TRANSCRIPT"
    printf 'relocation check complete; raw evidence retained at %s\n' "$OUTPUT"
    exit 0
  fi
else
  printf 'relocation_preflight status=SKIPPED reason=synthetic-filesystem-only\n' \
    >> "$TRANSCRIPT"
fi

check_isolated_conflicts
install_harnesses
REMOVALS=$OUTPUT/forced-removals.txt
: > "$REMOVALS"
remove_chain "$CLASSICAL" clasetStep classicalLib selftest
remove_chain "$BLAST" blastReconstruct tableauLib selftest \
  m2clasetime workcalibration activecalibration
BUILD_START=$(date +%s)
BUILD_START_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
printf 'forced_removal status=0 log=%s\n' "${REMOVALS##*/}" \
  >> "$TRANSCRIPT"
printf 'build_start epoch=%s utc=%s\n' "$BUILD_START" "$BUILD_START_UTC" \
  >> "$TRANSCRIPT"

pause_at_gate "${TASK7F_TEST_BEFORE_BUILD_GATE:-}" before-build
if [ "${TASK7F_SYNTHETIC:-0}" = 1 ]; then
  if [ -n "${TASK7F_TEST_ACTIVE_DESCENDANT_MARKER:-}" ]; then
    marker=$TASK7F_TEST_ACTIVE_DESCENDANT_MARKER
    run_logged active_descendant . active-descendant.log sh -c '
      marker=$1
      delay=$2
      if [ "$3" = 1 ]; then trap "" TERM; fi
      (sleep "$delay"; printf "descendant escaped\n" > "$marker") &
      child=$!
      printf "active_descendant_pid=%s marker=%s\n" "$child" "$marker"
      wait "$child"
    ' sh "$marker" "${TASK7F_TEST_DESCENDANT_DELAY:-3}" \
      "${TASK7F_TEST_DESCENDANT_IGNORE_TERM:-0}"
  fi
  synthetic_build_and_test
else
  HOLMAKE=$COPY/bin/Holmake
  run_logged classical_build "$CLASSICAL" \
    post-boundary-fix-classical-build.log "$HOLMAKE" selftest.exe
  run_logged blast_harness_build "$BLAST" \
    post-boundary-fix-blast-harness-build.log "$HOLMAKE" \
    m2clasetime.exe workcalibration.exe activecalibration.exe
  remove_chain "$BLAST" blastReconstruct tableauLib selftest \
    m2clasetime workcalibration activecalibration
  run_logged blast_harness_rebuild "$BLAST" \
    post-boundary-fix-blast-harness-rebuild.log "$HOLMAKE" selftest.exe \
    m2clasetime.exe workcalibration.exe activecalibration.exe
  validate_copy_executable "$CLASSICAL/selftest.exe"
  validate_copy_executable "$BLAST/selftest.exe"
  run_logged classical_level2 "$CLASSICAL" \
    post-boundary-fix-classical-selftest.log env HOLSELFTESTLEVEL=2 \
    ./selftest.exe
  run_logged blast_level2 "$BLAST" \
    post-boundary-fix-blast-selftest.log env HOLSELFTESTLEVEL=2 ./selftest.exe
fi

HASHES=$OUTPUT/post-boundary-fix-reproduction-hashes.sha256
FRESH=$OUTPUT/post-boundary-fix-reproduction-freshness.txt
capture_freshness
printf 'hash_capture status=0 file=%s\n' "${HASHES##*/}" \
  >> "$TRANSCRIPT"
printf 'freshness_capture status=0 file=%s\n' "${FRESH##*/}" \
  >> "$TRANSCRIPT"

if ! source_unchanged after-run; then
  die "relevant source inputs changed during isolated run; output retained"
fi
if ! source_tree_unchanged after-run; then
  die "source tree changed during isolated run; output retained"
fi
EXIT_MANIFEST_DONE=1
printf 'reproduction_complete status=0 retained_copy=%s\n' "$COPY" \
  >> "$TRANSCRIPT"
printf 'reproduction complete; retained isolated output: %s\n' "$OUTPUT"
