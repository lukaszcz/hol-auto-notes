#!/bin/sh
# Future single-segment v4 collector. It performs no benchmark by itself.
set -u

package_input=${PACKAGE_DIR:?validated PACKAGE_DIR required}
root_input=${ROOT:?validated ROOT required}
scratch_root_input=${SCRATCH_ROOT:?validated SCRATCH_ROOT required}
work_input=${SCRATCH_DIR:?validated SCRATCH_DIR required}
endpoint_pattern=${ENDPOINT_PATTERN:?non-self-matching pattern required}
artifact_reference=$(realpath -e -- \
  "${ARTIFACT_REFERENCE:?artifact reference required}") || exit 2

[ "$#" -ge 2 ] && [ "$1" = -- ] || {
  echo 'collect-v4: command must follow --' >&2
  exit 2
}
shift

package=$(realpath -e -- "$package_input") || exit 2
root=$(realpath -e -- "$root_input") || exit 2
scratch_root=$(realpath -e -- "$scratch_root_input") || exit 2
work=$(realpath -m -- "$work_input") || exit 2
tmp=$work/tmp
artifact_output=$work/audits/final-artifacts.tsv

# Shared validation happens before the collector creates or mutates work.
paths=$(python3 -B "$package/future-protocol/validate-paths-v4.py" \
  --root "$root" --package-dir "$package" --scratch-root "$scratch_root" \
  --work "$work" --tmp "$tmp" --output "$artifact_output") || exit 2
[ -n "$paths" ] || exit 2
[ ! -e "$work" ] || { echo 'collect-v4: scratch exists' >&2; exit 2; }
mkdir -p "$work/raw" "$work/audits" "$tmp"

artifact_auditor=${ARTIFACT_AUDITOR:-$package/future-protocol/audit-artifacts-v4.sh}
segment_status=not_started
classification=not_started
supervisor_pid=
supervisor_started=false
requested_signal=none
requested_status=none
requested_count=0
seal_status=not_run
artifact_status=not_run
endpoint_status=not_run
finalizing=0

note_signal() {
  name=$1 number=$2 status=$3
  requested_count=$((requested_count + 1))
  if [ "$requested_signal" = none ]; then
    requested_signal=$name
    requested_status=$status
  fi
  if [ -n "$supervisor_pid" ] && kill -0 "$supervisor_pid" 2>/dev/null; then
    kill -"$number" "$supervisor_pid" 2>/dev/null || :
  fi
}

seal_raw() {
  [ "$seal_status" = not_run ] || return
  seal_status=0
  (cd "$work" && sha256sum raw/stdout raw/stderr raw/supervisor.json) \
    > "$work/raw.seal.sha256.tmp" || seal_status=$?
  if [ "$seal_status" -eq 0 ]; then
    mv "$work/raw.seal.sha256.tmp" "$work/raw.seal.sha256"
  fi
  printf '%s\n' raw_seal >> "$work/finalization-order.txt"
}

finalize() {
  entered_status=$1
  [ "$finalizing" -eq 0 ] || exit "$entered_status"
  finalizing=1
  trap - EXIT HUP INT TERM

  # The foreground wait loop has reaped the supervisor before this sequence.
  seal_raw

  artifact_status=0
  ROOT="$root" PACKAGE_DIR="$package" SCRATCH_ROOT="$scratch_root" \
    SCRATCH_DIR="$tmp" "$artifact_auditor" \
    --root "$root" --package-dir "$package" \
    --scratch-root "$scratch_root" --work "$work" \
    --scratch-dir "$tmp" --output "$artifact_output" || artifact_status=$?
  if [ "$artifact_status" -eq 0 ]; then
    cmp "$artifact_reference" "$artifact_output" >/dev/null 2>&1 || \
      artifact_status=$?
  fi
  printf '%s\n' artifact_audit >> "$work/finalization-order.txt"

  # Match the kernel comm name, not this collector's command arguments.
  matches=$(pgrep -a "$endpoint_pattern" || true)
  if [ -n "$matches" ]; then
    endpoint_status=1
    printf '%s\n' "$matches" > "$work/audits/final-endpoint.txt"
  else
    endpoint_status=0
    printf '%s\n' 'matches=none' > "$work/audits/final-endpoint.txt"
  fi
  printf '%s\n' process_audit >> "$work/finalization-order.txt"

  final_status=$segment_status
  [ "$final_status" != running ] || final_status=125
  [ "$final_status" != not_started ] || final_status=$entered_status
  cleanup_failure=0
  if [ "$seal_status" -ne 0 ] || [ "$artifact_status" -ne 0 ] || \
     [ "$endpoint_status" -ne 0 ] || [ "$segment_status" -eq 125 ]; then
    cleanup_failure=1
    final_status=125
  elif [ "$requested_status" != none ]; then
    final_status=$requested_status
  fi
  temporary=$work/final-status.txt.tmp
  {
    printf 'outer_status_at_finalizer=%s\n' "$entered_status"
    printf 'outer_requested_signal=%s\n' "$requested_signal"
    printf 'outer_requested_status=%s\n' "$requested_status"
    printf 'outer_signal_count=%s\n' "$requested_count"
    printf 'supervisor_started=%s\n' "$supervisor_started"
    printf 'actual_supervisor_status=%s\n' "$segment_status"
    printf 'supervisor_classification=%s\n' "$classification"
    printf 'raw_seal_status=%s\n' "$seal_status"
    printf 'artifact_audit_status=%s\n' "$artifact_status"
    printf 'endpoint_audit_status=%s\n' "$endpoint_status"
    printf 'cleanup_or_audit_failure=%s\n' "$cleanup_failure"
    printf 'final_status=%s\n' "$final_status"
    printf 'work_preserved=%s\n' "$work"
  } > "$temporary" && mv "$temporary" "$work/final-status.txt" || {
    echo 'collect-v4: final status media unwritable' >&2
    final_status=125
  }
  printf '%s\n' final_status >> "$work/finalization-order.txt"
  exit "$final_status"
}

trap 'finalize $?' EXIT
trap 'note_signal HUP HUP 129' HUP
trap 'note_signal INT INT 130' INT
trap 'note_signal TERM TERM 143' TERM

python3 "$package/future-protocol/supervise-v4.py" \
  --timeout "${SEGMENT_TIMEOUT:-5}" \
  --term-grace "${TERM_GRACE:-1}" \
  --post-kill-grace "${POST_KILL_GRACE:-1}" \
  --quiet-interval "${QUIET_INTERVAL:-0.05}" \
  --poll "${POLL_INTERVAL:-0.01}" \
  --status "$work/raw/supervisor.json" \
  --stdout "$work/raw/stdout" --stderr "$work/raw/stderr" \
  --cwd "$root" -- "$@" &
supervisor_pid=$!
supervisor_started=true
segment_status=running
printf '%s\n' supervisor_started > "$work/finalization-order.txt"

# POSIX shells dispatch traps while this background child runs. An interrupted
# wait is retried until the exact supervisor PID has really been reaped.
while :; do
  wait "$supervisor_pid"
  wait_status=$?
  if kill -0 "$supervisor_pid" 2>/dev/null; then
    continue
  fi
  segment_status=$wait_status
  break
done
printf '%s\n' supervisor_wait_complete >> "$work/finalization-order.txt"
classification=$(python3 -c \
  'import json,sys; print(json.load(open(sys.argv[1]))["classification"])' \
  "$work/raw/supervisor.json" 2>/dev/null || printf '%s' unreadable)
exit "$segment_status"
