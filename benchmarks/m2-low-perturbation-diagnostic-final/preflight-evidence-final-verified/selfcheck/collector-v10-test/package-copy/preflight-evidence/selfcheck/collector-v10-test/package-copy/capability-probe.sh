#!/bin/sh
# No-benchmark sampler capability probe.  It must run before path selection.
set -u
out=${1:?output directory required}
mkdir -p "$out"
status=0

record() {
  label=$1
  shift
  rc=0
  "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || rc=$?
  printf '%s\n' "$rc" >"$out/$label.status"
  [ "$rc" -eq 0 ] || status=1
}

perf_path=$(command -v perf 2>/dev/null || true)
printf '%s\n' "$perf_path" >"$out/perf.path"
[ -n "$perf_path" ] || status=1
if [ -n "$perf_path" ]; then
  record version "$perf_path" --version
fi
record paranoid /bin/sh -c 'cat /proc/sys/kernel/perf_event_paranoid'
record kptr_restrict /bin/sh -c 'cat /proc/sys/kernel/kptr_restrict'
printf '%s\n' \
  'frequency_hz=9' \
  'call_graph=dwarf' \
  'probe_child=/bin/sleep 2' \
  'minimum_samples=10' \
  'minimum_symbol_and_dso_fraction=0.90' \
  >"$out/config.txt"

if [ -n "$perf_path" ]; then
  record recording "$perf_path" record -F 9 -g --call-graph dwarf \
    -o "$out/perf.data" -- /bin/sleep 2
  if [ "$(cat "$out/recording.status")" -eq 0 ]; then
    record report "$perf_path" report --stdio --no-children \
      -i "$out/perf.data"
  else
    printf '%s\n' 125 >"$out/report.status"
    : >"$out/report.stdout"
    : >"$out/report.stderr"
    status=1
  fi
else
  printf '%s\n' 127 >"$out/recording.status"
  printf '%s\n' 127 >"$out/report.status"
  : >"$out/recording.stdout"
  : >"$out/recording.stderr"
  : >"$out/report.stdout"
  : >"$out/report.stderr"
fi

printf '%s\n' \
  'wrapper_assessment=requires_successful_recording_before_v10_probe' \
  'containment_model=perf_must_be_supervised_launch-vector program' \
  'decision_rule=any_failed_criterion_selects_fallback' \
  >"$out/wrapper-assessment.txt"
printf '%s\n' "$status" >"$out/probe.status"
exit "$status"
