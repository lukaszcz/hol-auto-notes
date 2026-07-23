#!/bin/sh
# Future single-segment collector skeleton. It performs no benchmark by itself.
set -u

root=$(realpath -e -- "${ROOT:?validated ROOT required}") || exit 2
package=$(realpath -e -- "${PACKAGE_DIR:?validated PACKAGE_DIR required}") || exit 2
scratch_root=${SCRATCH_ROOT:?validated SCRATCH_ROOT required}
scratch_input=${SCRATCH_DIR:?validated SCRATCH_DIR required}
work=$($package/validate-scratch-path.sh "$scratch_root" "$scratch_input") || exit 2
endpoint_pattern=${ENDPOINT_PATTERN:?non-self-matching endpoint pattern required}
artifact_reference=$(realpath -e -- \
  "${ARTIFACT_REFERENCE:?artifact reference required}") || exit 2
artifact_auditor=${ARTIFACT_AUDITOR:-$package/artifact-manifest.sh}

[ "$#" -ge 2 ] && [ "$1" = -- ] || {
  echo 'collect-v2: command must follow --' >&2
  exit 2
}
shift
[ ! -e "$work" ] || { echo 'collect-v2: scratch exists' >&2; exit 2; }
mkdir -p "$work/raw" "$work/audits"

segment_status=not_run
classification=not_run
seal_status=not_run
endpoint_status=not_run
artifact_status=not_run
finalizing=0

seal_raw() {
  if [ "$seal_status" != not_run ]; then return; fi
  seal_status=0
  (cd "$work" && sha256sum raw/stdout raw/stderr raw/supervisor.json) \
    > "$work/raw.seal.sha256.tmp" || seal_status=$?
  if [ "$seal_status" -eq 0 ]; then
    mv "$work/raw.seal.sha256.tmp" "$work/raw.seal.sha256"
  fi
}

finalize() {
  entered_status=$1
  [ "$finalizing" -eq 0 ] || exit "$entered_status"
  finalizing=1
  trap - EXIT HUP INT TERM

  # Seal first. Audits and report materialization occur only after this point.
  seal_raw

  matches=$(pgrep -af "$endpoint_pattern" || true)
  if [ -n "$matches" ]; then
    endpoint_status=1
    printf '%s\n' "$matches" > "$work/audits/final-endpoint.txt"
  else
    endpoint_status=0
    printf '%s\n' 'matches=none' > "$work/audits/final-endpoint.txt"
  fi

  artifact_status=0
  ROOT="$root" PACKAGE_DIR="$package" "$artifact_auditor" \
    "$work/audits/final-artifacts.tsv" || artifact_status=$?
  if [ "$artifact_status" -eq 0 ]; then
    cmp "$artifact_reference" "$work/audits/final-artifacts.tsv" \
      >/dev/null 2>&1 || artifact_status=$?
  fi

  final_status=$entered_status
  if [ "$segment_status" != not_run ]; then final_status=$segment_status; fi
  if [ "$seal_status" -ne 0 ] || [ "$endpoint_status" -ne 0 ] || \
     [ "$artifact_status" -ne 0 ]; then
    [ "$final_status" -ne 0 ] || final_status=125
  fi
  {
    printf 'outer_status_at_finalizer=%s\n' "$entered_status"
    printf 'segment_status=%s\n' "$segment_status"
    printf 'supervisor_classification=%s\n' "$classification"
    printf 'raw_seal_status=%s\n' "$seal_status"
    printf 'endpoint_audit_status=%s\n' "$endpoint_status"
    printf 'artifact_audit_status=%s\n' "$artifact_status"
    printf 'final_status=%s\n' "$final_status"
    printf 'work_preserved=%s\n' "$work"
  } > "$work/final-status.txt"
  exit "$final_status"
}

trap 'finalize $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if python3 "$package/future-protocol/supervise-v2.py" \
    --timeout "${SEGMENT_TIMEOUT:-5}" \
    --term-grace "${TERM_GRACE:-1}" \
    --post-kill-grace "${POST_KILL_GRACE:-1}" \
    --status "$work/raw/supervisor.json" \
    --stdout "$work/raw/stdout" --stderr "$work/raw/stderr" \
    --cwd "$root" -- "$@"; then
  segment_status=0
else
  segment_status=$?
fi

# This is deliberately the first post-supervisor materialization.
seal_raw
classification=$(python3 -c \
  'import json,sys; print(json.load(open(sys.argv[1]))["classification"])' \
  "$work/raw/supervisor.json" 2>/dev/null || printf '%s' unreadable)
exit "$segment_status"
