#!/bin/sh
set -u

usage() {
  printf 'usage: %s FRESH-RESULT-DIRECTORY\n' "$0"
}

die() {
  printf 'adversarial-test: %s\n' "$*" >&2
  exit 1
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

[ "$#" -eq 1 ] || { usage >&2; exit 2; }
case $1 in
  /*) ;;
  *) die "result directory must be an absolute path" ;;
esac
RESULTS=$(realpath -m -- "$1") || die "cannot canonicalize result path"
[ "$RESULTS" = "$1" ] || die "result path must be canonical"
! path_exists "$RESULTS" || die "result path already exists: $RESULTS"
mkdir -- "$RESULTS" || die "cannot create result path"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SCRIPT=$SCRIPT_DIR/reproduce-post-boundary-build.sh
RULES=$SCRIPT_DIR/POST_BOUNDARY_FIX_HOLMAKE_RULES.txt
failures=0
SUMMARY=$RESULTS/summary.log
: > "$SUMMARY"

record_failure() {
  failures=$((failures + 1))
  printf 'FAIL case=%s reason=%s\n' "$1" "$2" | tee -a "$SUMMARY" >&2
}

tree_manifest() {
  root=$1
  output=$2
  (
    cd "$root" || exit 1
    find -P . -mindepth 1 -printf '%P\n' | LC_ALL=C sort |
      while IFS= read -r rel; do
        if [ -L "$rel" ]; then
          stat -c \
            'symlink mode=%a uid=%u gid=%g mtime=%Y ctime=%Z size=%s path=%n' \
            -- "$rel"
          printf 'target=%s path=%s\n' "$(readlink -- "$rel")" "$rel"
        elif [ -f "$rel" ]; then
          hash=$(sha256sum "$rel" | sed 's/ .*//')
          stat -c \
            "file hash=$hash mode=%a uid=%u gid=%g mtime=%Y ctime=%Z" \
            -- "$rel"
          printf 'size=%s path=%s\n' "$(stat -c '%s' -- "$rel")" "$rel"
        elif [ -d "$rel" ]; then
          stat -c \
            'directory mode=%a u=%u g=%g mtime=%Y ctime=%Z size=%s path=%n' \
            -- "$rel"
        else
          stat -c \
            'other mode=%a uid=%u gid=%g mtime=%Y ctime=%Z size=%s path=%n' \
            -- "$rel"
        fi
      done
  ) > "$output"
}

make_template() {
  root=$RESULTS/template
  package=$root/.agent-files/benchmarks/m2-claset-time
  classical=$root/src/auto/classical
  blast=$root/src/auto/blast
  mkdir -p "$package" "$classical/.hol/objs" "$blast/.hol/objs" \
    "$root/bin" "$root/tools" "$root/tools-poly/Holmake" "$root/sigobj"
  printf 'disposable non-HOL fixture\n' > "$root/.task7f-synthetic-fixture"
  cp -- "$SCRIPT" "$package/reproduce-post-boundary-build.sh"
  cp -- "$SCRIPT_DIR/process-group-supervisor.py" \
    "$package/process-group-supervisor.py"
  cp -- "$RULES" "$package/POST_BOUNDARY_FIX_HOLMAKE_RULES.txt"
  for base in m2clasetime workcalibration activecalibration; do
    cp -- "$SCRIPT_DIR/$base.sml" "$package/$base.sml"
  done
  printf 'synthetic Holmakefile\n' > "$classical/Holmakefile"
  printf 'synthetic Holmakefile\n' > "$blast/Holmakefile"
  for rel in \
    clasetStep.sig clasetStep.sml classicalLib.sig classicalLib.sml \
    selftest.sml; do
    printf 'synthetic source %s\n' "$rel" > "$classical/$rel"
  done
  for rel in \
    blastReconstruct.sig blastReconstruct.sml tableauLib.sig tableauLib.sml \
    selftest.sml; do
    printf 'synthetic source %s\n' "$rel" > "$blast/$rel"
  done
  for rel in \
    clasetStep.ui clasetStep.uo classicalLib.ui classicalLib.uo \
    selftest.ui selftest.uo; do
    printf 'synthetic baseline %s\n' "$rel" > "$classical/.hol/objs/$rel"
  done
  for rel in \
    blastReconstruct.ui blastReconstruct.uo tableauLib.ui tableauLib.uo \
    selftest.ui selftest.uo; do
    printf 'synthetic baseline %s\n' "$rel" > "$blast/.hol/objs/$rel"
  done
  printf 'synthetic executable\n' > "$classical/selftest.exe"
  printf 'synthetic executable\n' > "$blast/selftest.exe"
  for rel in Holmake hol; do
    printf '#!/bin/sh\nexit 99\n' > "$root/bin/$rel"
    chmod +x "$root/bin/$rel"
  done
  printf 'synthetic heap\n' > "$root/bin/hol.state0"
  printf 'synthetic default heap\n' > "$root/bin/hol.state"
  printf 'synthetic configure\n' > "$root/tools/smart-configure.sml"
  printf 'synthetic configure implementation\n' \
    > "$root/tools-poly/smart-configure.sml"
  printf 'synthetic generated configure\n' > "$root/tools-poly/configure.sml"
  printf 'synthetic Systeml template\n' \
    > "$root/tools-poly/Holmake/unix-systeml.sml"
}

new_case() {
  name=$1
  CASE=$RESULTS/$name
  SOURCE=$CASE/source
  OUTPUT=$CASE/output
  mkdir -p "$CASE"
  cp -a -- "$RESULTS/template" "$SOURCE"
  tree_manifest "$SOURCE" "$CASE/before.sha256"
}

finish_case() {
  name=$1
  expected=$2
  immutable=$3
  tree_manifest "$SOURCE" "$CASE/after.sha256"
  if [ "$STATUS" -ne "$expected" ]; then
    record_failure "$name" "status=$STATUS expected=$expected"
  elif [ "$immutable" = yes ] &&
      ! cmp -s "$CASE/before.sha256" "$CASE/after.sha256"; then
    diff -u "$CASE/before.sha256" "$CASE/after.sha256" \
      > "$CASE/source-tree.diff" 2>&1 || :
    record_failure "$name" source-tree-changed
  else
    printf 'PASS case=%s status=%s source_immutable=%s\n' \
      "$name" "$STATUS" "$immutable" >> "$SUMMARY"
  fi
}

run_sync() {
  name=$1
  expected=$2
  immutable=$3
  shift 3
  set +e
  (
    cd "$SOURCE" || exit 126
    "$@"
  ) > "$CASE/stdout" 2> "$CASE/stderr"
  STATUS=$?
  set -e
  printf '%s\n' "$STATUS" > "$CASE/status"
  finish_case "$name" "$expected" "$immutable"
}

wait_for_pattern() {
  file=$1
  pattern=$2
  count=0
  while [ "$count" -lt 200 ]; do
    grep "$pattern" "$file" >/dev/null 2>&1 && return 0
    count=$((count + 1))
    sleep 0.05
  done
  return 1
}

run_signal_case() {
  name=$1
  signal=$2
  expected=$3
  repeated=$4
  new_case "$name"
  marker=$CASE/delayed-marker
  parent_pid_file=$CASE/published-outer-pid
  sha256sum "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" \
    "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"process-group-supervisor.py" > "$CASE/script-hashes-before.sha256"
  (
    cd "$SOURCE" || exit 126
    exec env TASK7F_SYNTHETIC=1 \
      TASK7F_TEST_PARENT_PID_FILE="$parent_pid_file" \
      TASK7F_TEST_ACTIVE_DESCENDANT_MARKER="$marker" \
      TASK7F_TEST_DESCENDANT_IGNORE_TERM=1 \
      TASK7F_TEST_DESCENDANT_DELAY=3 \
      python3 -c '
import os
import signal
import sys

signal.signal(signal.SIGINT, signal.SIG_DFL)
script = sys.argv[1]
os.execve(script, [script, sys.argv[2]], os.environ)
' "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$OUTPUT"
  ) > "$CASE/stdout" 2> "$CASE/stderr" &
  launcher_pid=$!
  printf '%s\n' "$launcher_pid" > "$CASE/launcher-pid"
  if wait_for_pattern "$OUTPUT/active-descendant.log.supervisor-events" \
      '^command_group_start ' && [ -s "$parent_pid_file" ]; then
    outer_pid=$(sed -n '1p' "$parent_pid_file")
    printf '%s\n' "$outer_pid" > "$CASE/signaled-outer-pid"
    ps -eo pid=,ppid=,pgid=,sid=,stat=,args= > "$CASE/ps-before-signal.txt"
    if [ "$outer_pid" != "$launcher_pid" ]; then
      record_failure "$name" \
        "published-outer-pid=$outer_pid launcher-pid=$launcher_pid"
    fi
    kill -"$signal" "$outer_pid"
    if [ "$repeated" = yes ]; then
      if wait_for_pattern \
          "$OUTPUT/active-descendant.log.supervisor-events" \
          "received=SIG$signal count=1 forwarded=SIGTERM"; then
        kill -"$signal" "$outer_pid" 2>/dev/null || :
      else
        record_failure "$name" first-supervisor-signal-not-observed
      fi
    fi
    set +e
    wait "$launcher_pid"
    STATUS=$?
    set -e
  else
    kill -TERM "$launcher_pid" 2>/dev/null || :
    wait "$launcher_pid" 2>/dev/null || :
    STATUS=124
  fi
  events=$OUTPUT/active-descendant.log.supervisor-events
  [ -f "$events" ] && cp -- "$events" "$CASE/supervisor-events.txt"
  pgid=$(sed -n \
    's/command_group_start leader=[0-9][0-9]* pgid=\([0-9][0-9]*\)/\1/p' \
    "$events" 2>/dev/null | tail -n 1)
  printf '%s\n' "$pgid" > "$CASE/active-pgid"
  sleep 4
  ps -eo pid=,ppid=,pgid=,sid=,stat=,args= > "$CASE/ps-after-delay.txt"
  if [ -e "$marker" ]; then
    record_failure "$name" delayed-descendant-marker-written
  fi
  if [ -n "$pgid" ] && kill -0 "-$pgid" 2>/dev/null; then
    ps -eo pid=,ppid=,pgid=,sid=,stat=,args= > "$CASE/live-group.txt"
    record_failure "$name" process-group-remains
  fi
  if ! grep "supervisor_signal received=SIG$signal count=1 forwarded=SIGTERM" \
      "$events" >/dev/null 2>&1; then
    record_failure "$name" missing-first-supervisor-event
  fi
  if ! grep '^command_group_escalate .* signal=SIGKILL$' "$events" \
      >/dev/null 2>&1 && [ "$repeated" = no ]; then
    record_failure "$name" missing-term-timeout-escalation
  fi
  if [ "$repeated" = yes ] &&
      ! grep "supervisor_signal received=SIG$signal count=2 forwarded=SIGKILL" \
        "$events" >/dev/null 2>&1; then
    record_failure "$name" missing-second-supervisor-event
  fi
  if ! grep '^command_group_gone .* result=PASS$' "$events" \
      >/dev/null 2>&1; then
    record_failure "$name" missing-command-group-gone-pass
  fi
  if [ ! -d "$OUTPUT" ]; then
    record_failure "$name" output-not-retained
  fi
  sha256sum "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" \
    "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"process-group-supervisor.py" > "$CASE/script-hashes-after.sha256"
  if ! cmp -s "$CASE/script-hashes-before.sha256" \
      "$CASE/script-hashes-after.sha256"; then
    record_failure "$name" script-hashes-changed
  fi
  printf 'marker_absent=%s group_absent=%s\n' \
    "$([ ! -e "$marker" ] && printf PASS || printf FAIL)" \
    "$([ -z "$pgid" ] || ! kill -0 "-$pgid" 2>/dev/null; \
      [ "$?" -eq 0 ] && printf PASS || printf FAIL)" \
    > "$CASE/descendant-audit"
  printf '%s\n' "$STATUS" > "$CASE/status"
  finish_case "$name" "$expected" yes
}

run_supervisor_exit7_case() {
  name=direct_supervisor_exit7
  CASE=$RESULTS/$name
  mkdir -- "$CASE"
  sha256sum "$SCRIPT_DIR/process-group-supervisor.py" \
    > "$CASE/helper-hash.sha256"
  set +e
  python3 "$SCRIPT_DIR/process-group-supervisor.py" --cwd "$CASE" \
    --events "$CASE/events.txt" --pid-file "$CASE/supervisor-pid" \
    -- sh -c 'exit 7' > "$CASE/stdout" 2> "$CASE/stderr"
  status=$?
  set -e
  printf '%s\n' "$status" > "$CASE/status"
  ps -eo pid=,ppid=,pgid=,sid=,stat=,args= > "$CASE/ps-after.txt"
  if [ "$status" -eq 7 ] &&
      grep 'command_exit raw_status=7 normalized_status=7' \
        "$CASE/events.txt" >/dev/null 2>&1 &&
      grep '^command_group_gone .* result=PASS$' "$CASE/events.txt" \
        >/dev/null 2>&1; then
    printf 'PASS case=%s status=7 normalization=ordinary\n' "$name" \
      >> "$SUMMARY"
  else
    record_failure "$name" "status=$status expected=7-or-events-missing"
  fi
}

run_supervisor_independent_term_case() {
  name=direct_supervisor_independent_sigterm
  CASE=$RESULTS/$name
  mkdir -- "$CASE"
  child_pid_file=$CASE/child-pid
  sha256sum "$SCRIPT_DIR/process-group-supervisor.py" \
    > "$CASE/helper-hash.sha256"
  python3 "$SCRIPT_DIR/process-group-supervisor.py" --cwd "$CASE" \
    --events "$CASE/events.txt" --pid-file "$CASE/supervisor-pid" \
    -- sh -c 'printf "%s\n" "$$" > "$1"; exec sleep 30' sh \
    "$child_pid_file" > "$CASE/stdout" 2> "$CASE/stderr" &
  helper_pid=$!
  if wait_for_pattern "$CASE/events.txt" '^command_group_start ' &&
      [ -s "$child_pid_file" ]; then
    child_pid=$(sed -n '1p' "$child_pid_file")
    printf '%s\n' "$child_pid" > "$CASE/signaled-child-pid"
    ps -eo pid=,ppid=,pgid=,sid=,stat=,args= > "$CASE/ps-before.txt"
    kill -TERM "$child_pid"
    set +e
    wait "$helper_pid"
    status=$?
    set -e
  else
    kill -KILL "$helper_pid" 2>/dev/null || :
    wait "$helper_pid" 2>/dev/null || :
    status=124
  fi
  printf '%s\n' "$status" > "$CASE/status"
  ps -eo pid=,ppid=,pgid=,sid=,stat=,args= > "$CASE/ps-after.txt"
  if [ "$status" -eq 143 ] &&
      grep 'command_exit raw_status=-15 normalized_status=143' \
        "$CASE/events.txt" >/dev/null 2>&1 &&
      ! grep '^supervisor_signal ' "$CASE/events.txt" >/dev/null 2>&1 &&
      grep '^command_group_gone .* result=PASS$' "$CASE/events.txt" \
        >/dev/null 2>&1; then
    printf 'PASS case=%s status=143 normalization=negative-child-signal\n' \
      "$name" >> "$SUMMARY"
  else
    record_failure "$name" "status=$status expected=143-or-events-invalid"
  fi
}

make_template

new_case print
run_sync print 0 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" --print

new_case self_check
run_sync self_check 0 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" --self-check

new_case hostile_external_ancestor
run_sync hostile_external_ancestor 1 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" --relocation-check "$OUTPUT"
if ! grep 'ambient external Holmake metadata above future copy: /tmp/Holmakefile' \
    "$CASE/stderr" >/dev/null 2>&1; then
  record_failure hostile_external_ancestor missing-ancestor-diagnostic
fi

new_case synthetic_success
run_sync synthetic_success 0 yes env TASK7F_SYNTHETIC=1 \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$OUTPUT"

new_case relative_alias
run_sync relative_alias 1 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" ../relative-output

new_case dotdot_alias
mkdir -p "$CASE/parent"
run_sync dotdot_alias 1 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$CASE/parent/../alias-output"

new_case symlink_parent
mkdir -p "$CASE/real-parent"
ln -s real-parent "$CASE/link-parent"
run_sync symlink_parent 1 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$CASE/link-parent/output"

new_case existing_output
mkdir "$OUTPUT"
run_sync existing_output 1 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$OUTPUT"

new_case contained_output
run_sync contained_output 1 yes \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$SOURCE/new-output"

new_case harness_conflict
printf 'conflicting harness\n' > "$SOURCE/src/auto/blast/m2clasetime.sml"
tree_manifest "$SOURCE" "$CASE/before.sha256"
run_sync harness_conflict 1 yes env TASK7F_SYNTHETIC=1 \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$OUTPUT"

new_case orphan_conflict
printf 'orphan artifact\n' > "$SOURCE/src/auto/blast/.hol/objs/m2clasetime.uo"
tree_manifest "$SOURCE" "$CASE/before.sha256"
run_sync orphan_conflict 1 yes env TASK7F_SYNTHETIC=1 \
  "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$OUTPUT"

new_case input_mutation
gate=$CASE/continue
(
  cd "$SOURCE" || exit 126
  env TASK7F_SYNTHETIC=1 TASK7F_TEST_AFTER_COPY_GATE="$gate" \
    "$SOURCE/.agent-files/benchmarks/m2-claset-time/"\
"reproduce-post-boundary-build.sh" "$OUTPUT"
) > "$CASE/stdout" 2> "$CASE/stderr" &
pid=$!
if wait_for_pattern "$CASE/stdout" 'test pause after-copy'; then
  printf 'external mutation\n' >> "$SOURCE/src/auto/classical/clasetStep.sml"
  : > "$gate"
  set +e
  wait "$pid"
  STATUS=$?
  set -e
else
  kill -TERM "$pid" 2>/dev/null || :
  wait "$pid" 2>/dev/null || :
  STATUS=124
fi
printf '%s\n' "$STATUS" > "$CASE/status"
finish_case input_mutation 1 intentionally-mutated
if ! grep 'inputs changed' "$CASE/stderr" >/dev/null 2>&1; then
  record_failure input_mutation missing-diagnostic
fi

run_signal_case signal_hup HUP 129 no
run_signal_case signal_int INT 130 no
run_signal_case signal_term TERM 143 no
run_signal_case repeated_term TERM 143 yes
run_supervisor_exit7_case
run_supervisor_independent_term_case

rm -rf -- "$RESULTS/template"
printf 'outer_cases=16 helper_cases=2 failures=%s raw_results=%s\n' \
  "$failures" "$RESULTS" \
  >> "$SUMMARY"
if [ "$failures" -ne 0 ]; then
  printf 'adversarial isolation suite: FAIL (%s failures); raw: %s\n' \
    "$failures" "$RESULTS" >&2
  exit 1
fi
printf 'adversarial isolation suite: PASS; raw retained at %s\n' "$RESULTS"
