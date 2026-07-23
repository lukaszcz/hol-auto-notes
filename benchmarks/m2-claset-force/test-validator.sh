#!/bin/sh
set -eu

root=${ROOT:-$(pwd)}
directory=$root/.agent-files/benchmarks/m2-claset-force
validator=$directory/verify-claset-force.awk
fixture_generator=$directory/generate-validator-fixture.awk
generated=$(mktemp)
diagnostic=$(mktemp)
fixture=$(mktemp)
trap 'rm -f "$generated" "$diagnostic" "$fixture"' EXIT HUP INT TERM

awk -f "$validator" "$directory/raw.tsv" > "$generated"
cmp "$generated" "$directory/attempts.tsv"

awk -v scenario=positive_before -f "$fixture_generator" \
  "$directory/raw.tsv" > "$fixture"
awk -f "$validator" "$fixture" > "$generated"

for phase in attempt_selection freshening_setup minor_unification \
             major_unification rule_instantiation \
             child_store_construction direct_result_construction \
             lazy_result_yield direct_child_replacement \
             replay_record_construction record_insertion; do
  for boundary in enter exit; do
    awk -v scenario=positive_phase -v phase="$phase" \
      -v boundary="$boundary" -f "$fixture_generator" \
      "$directory/raw.tsv" > "$fixture"
    awk -f "$validator" "$fixture" > "$generated"
  done
done

for fixture in bad-header unknown-phase reordered-record \
               bad-stdout bad-status bad-counter bad-global-poll \
               bad-prefix bad-entry-balance; do
  if awk -f "$validator" "$directory/fixtures/$fixture.tsv" \
       > "$generated" 2> "$diagnostic"; then
    echo "validator accepted negative fixture: $fixture" >&2
    exit 1
  fi
  if [ ! -s "$diagnostic" ]; then
    echo "validator rejected without a diagnostic: $fixture" >&2
    exit 1
  fi
done

for specification in bad_major_minor:bad-major-minor \
                     bad_safe_duplicate:bad-safe-duplicate \
                     bad_partial_context:bad-partial-context \
                     bad_absent_counts:bad-absent-context-counts \
                     bad_outer_current_count:bad-outer-current-count \
                     bad_stored_current_count:bad-stored-current-count \
                     bad_stdout_before_attempt:bad-stdout-before-attempt \
                     bad_stdout_before_result:bad-stdout-before-result \
                     bad_marker_after_stdout:bad-marker-after-stdout \
                     bad_noncanonical_run:bad-noncanonical-run \
                     bad_noncanonical_attempt:bad-noncanonical-attempt \
                     bad_noncanonical_status:bad-noncanonical-status; do
  fixture_case=${specification%%:*}
  fixture_file=${specification#*:}
  awk -v scenario="$fixture_case" -f "$fixture_generator" \
    "$directory/raw.tsv" > "$fixture"
  cmp "$fixture" "$directory/fixtures/$fixture_file.tsv"
  if awk -f "$validator" "$directory/fixtures/$fixture_file.tsv" \
       > "$generated" 2> "$diagnostic"; then
    echo "validator accepted negative fixture: $fixture_file" >&2
    exit 1
  fi
  if [ ! -s "$diagnostic" ]; then
    echo "validator rejected without a diagnostic: $fixture_file" >&2
    exit 1
  fi
done

echo "authoritative summary reproduced; pre-stored and all 22 classical"
echo "boundary prefixes accepted; 21 negative cases rejected diagnostically"
