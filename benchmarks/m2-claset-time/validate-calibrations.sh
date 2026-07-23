#!/bin/sh
set -eu

dir=${1:-.agent-files/benchmarks/m2-claset-time}
representative=${2:-$dir/regenerated-final-calibration-raw.tsv}
active=${3:-$dir/regenerated-final-active-calibration-raw.tsv}
representative_schedule=${4:-$dir/calibration-schedule.tsv}
active_schedule=${5:-$dir/active-calibration-schedule.tsv}
locked_summary=${6:-$dir/regenerated-final-calibration-summary.tsv}

awk -F '\t' '
  BEGIN {
    expected_rows = 18
    expected = "1:1:1:38:4:untimed,2:1:1:38:4:timed," \
      "3:1:2:43:5:untimed,4:1:2:43:5:timed," \
      "5:1:3:34:6:untimed,6:1:3:34:6:timed," \
      "7:2:3:34:6:timed,8:2:3:34:6:untimed," \
      "9:2:2:43:5:timed,10:2:2:43:5:untimed," \
      "11:2:1:38:4:timed,12:2:1:38:4:untimed," \
      "13:3:1:38:4:untimed,14:3:1:38:4:timed," \
      "15:3:2:43:5:untimed,16:3:2:43:5:timed," \
      "17:3:3:34:6:untimed,18:3:3:34:6:timed"
  }
  NR == FNR {
    if (FNR == 1) {
      if ($0 != "sequence\trepetition\tposition\tproblem\tdepth\tmode")
        bad = 1
      next
    }
    sequence = FNR - 1
    if (NF != 6 || $1 != sequence ||
        ($3 == 1 && $4 != 38) || ($3 == 2 && $4 != 43) ||
        ($3 == 3 && $4 != 34) ||
        ($6 != "timed" && $6 != "untimed")) bad = 1
    for (i = 1; i <= 6; i++) schedule[sequence, i] = $i
    protocol = protocol (protocol == "" ? "" : ",") \
      $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6
    schedule_rows++
    next
  }
  FNR == 1 {
    if ($0 != "repetition\tproblem\tdepth\tmode\toutcome\telapsed\t" \
        "attempts\tcheckpoints\tinferences\tbranches_created\t" \
        "branches_closed\tchoices_pruned\tmax_cost\tcache_hits\t" \
        "conversions\treconstruction_signatures") bad = 1
    next
  }
  {
    row = FNR - 1
    if (NF != 16 || row > schedule_rows ||
        $1 != schedule[row, 2] || $2 != schedule[row, 4] ||
        $3 != schedule[row, 5] || $4 != schedule[row, 6]) bad = 1
    if ($5 != "none" || $6 !~ /^[0-9]+([.][0-9]+)?$/) bad = 1
    pair = $1 FS $2
    if (pair in seen) {
      if (seen_mode[pair] == $4) bad = 1
      for (i = 5; i <= 16; i++)
        if (i != 6 && $i != value[pair, i]) bad = 1
    } else {
      seen[pair] = 1
      seen_mode[pair] = $4
      for (i = 5; i <= 16; i++) value[pair, i] = $i
    }
    raw_rows++
  }
  END {
    if (protocol != expected || schedule_rows != expected_rows ||
        raw_rows != expected_rows ||
        length(seen) != 9) bad = 1
    exit bad
  }
' "$representative_schedule" "$representative"

awk -F '\t' '
  BEGIN {
    expected_rows = 10
    expected = "1:1:stored_elim_success:1000:untimed," \
      "2:1:stored_elim_success:1000:timed," \
      "3:2:stored_elim_success:1000:timed," \
      "4:2:stored_elim_success:1000:untimed," \
      "5:3:stored_elim_success:1000:untimed," \
      "6:3:stored_elim_success:1000:timed," \
      "7:4:stored_elim_success:1000:timed," \
      "8:4:stored_elim_success:1000:untimed," \
      "9:5:stored_elim_success:1000:untimed," \
      "10:5:stored_elim_success:1000:timed"
  }
  NR == FNR {
    if (FNR == 1) {
      if ($0 != "sequence\trepetition\tfixture\tbatch\tmode") bad = 1
      next
    }
    sequence = FNR - 1
    if (NF != 5 || $1 != sequence ||
        $3 != "stored_elim_success" || $4 != 1000 ||
        ($5 != "timed" && $5 != "untimed")) bad = 1
    for (i = 1; i <= 5; i++) schedule[sequence, i] = $i
    protocol = protocol (protocol == "" ? "" : ",") \
      $1 ":" $2 ":" $3 ":" $4 ":" $5
    schedule_rows++
    next
  }
  FNR == 1 {
    if ($0 != "repetition\tmode\tbatch\telapsed\tcheckpoints\t" \
        "entries\texits\tstored_checkpoints\tstored_entries\t" \
        "stored_exits\tattempts\tmajor\trecords") bad = 1
    next
  }
  {
    row = FNR - 1
    if (NF != 13 || row > schedule_rows ||
        $1 != schedule[row, 2] || $2 != schedule[row, 5] ||
        $3 != schedule[row, 4]) bad = 1
    if ($4 !~ /^[0-9]+([.][0-9]+)?$/) bad = 1
    pair = $1
    if (pair in seen) {
      if (seen_mode[pair] == $2) bad = 1
      for (i = 3; i <= 13; i++)
        if (i != 4 && $i != value[pair, i]) bad = 1
    } else {
      seen[pair] = 1
      seen_mode[pair] = $2
      for (i = 3; i <= 13; i++) value[pair, i] = $i
    }
    raw_rows++
  }
  END {
    if (protocol != expected || schedule_rows != expected_rows ||
        raw_rows != expected_rows ||
        length(seen) != 5) bad = 1
    exit bad
  }
' "$active_schedule" "$active"

temporary=$(mktemp "${TMPDIR:-/tmp}/m2-claset-time-summary.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
awk -f "$dir/summarize-calibrations.awk" "$representative" "$active" \
  > "$temporary"
cmp -s "$locked_summary" "$temporary" || {
  echo 'calibration summary differs from locked summary' >&2
  exit 1
}

echo 'calibrations exactly match schedules, pairs, work, results, and summary'
