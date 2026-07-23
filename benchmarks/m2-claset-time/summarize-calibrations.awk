BEGIN {
  FS = "\t"
  OFS = "\t"
  print "dataset", "workload", "samples", "untimed_median", \
    "untimed_min", "untimed_max", "timed_median", "timed_min", \
    "timed_max", "timed_over_untimed_ratio", "percent_change"
}

FNR == 1 {
  if ($0 == "repetition\tproblem\tdepth\tmode\toutcome\telapsed\t" \
      "attempts\tcheckpoints\tinferences\tbranches_created\t" \
      "branches_closed\tchoices_pruned\tmax_cost\tcache_hits\t" \
      "conversions\treconstruction_signatures") {
    dataset = "representative"
  } else if ($0 == "repetition\tmode\tbatch\telapsed\tcheckpoints\t" \
             "entries\texits\tstored_checkpoints\tstored_entries\t" \
             "stored_exits\tattempts\tmajor\trecords") {
    dataset = "active"
  } else {
    bad = 1
  }
  next
}

dataset == "representative" {
  workload = "P" $2 "@" $3
  mode = $4
  elapsed = $6 + 0
  key = dataset SUBSEP workload
  if (!(key in seen)) {
    seen[key] = 1
    order[++order_count] = key
    workload_name[key] = workload
  }
  count[key, mode]++
  value[key, mode, count[key, mode]] = elapsed
  next
}

dataset == "active" {
  workload = "stored_elim_success@" $3
  mode = $2
  elapsed = $4 + 0
  key = dataset SUBSEP workload
  if (!(key in seen)) {
    seen[key] = 1
    order[++order_count] = key
    workload_name[key] = workload
  }
  count[key, mode]++
  value[key, mode, count[key, mode]] = elapsed
  next
}

function summarize(key, mode, n, result, i, j, item) {
  for (i = 1; i <= n; i++) sorted[i] = value[key, mode, i]
  for (i = 2; i <= n; i++) {
    item = sorted[i]
    j = i - 1
    while (j >= 1 && sorted[j] > item) {
      sorted[j + 1] = sorted[j]
      j--
    }
    sorted[j + 1] = item
  }
  result = sprintf("%.9f\t%.9f\t%.9f", \
    sorted[(n + 1) / 2], sorted[1], sorted[n])
  for (i = 1; i <= n; i++) delete sorted[i]
  return result
}

function median(key, mode, n, i, j, item, result) {
  for (i = 1; i <= n; i++) sorted[i] = value[key, mode, i]
  for (i = 2; i <= n; i++) {
    item = sorted[i]
    j = i - 1
    while (j >= 1 && sorted[j] > item) {
      sorted[j + 1] = sorted[j]
      j--
    }
    sorted[j + 1] = item
  }
  result = sorted[(n + 1) / 2]
  for (i = 1; i <= n; i++) delete sorted[i]
  return result
}

END {
  if (bad) exit 1
  for (position = 1; position <= order_count; position++) {
    key = order[position]
    untimed_count = count[key, "untimed"]
    timed_count = count[key, "timed"]
    if (untimed_count < 1 || untimed_count != timed_count) exit 1
    untimed_median = median(key, "untimed", untimed_count)
    timed_median = median(key, "timed", timed_count)
    if (untimed_median == 0) exit 1
    ratio = timed_median / untimed_median
    split(key, parts, SUBSEP)
    printf "%s\t%s\t%d\t%s\t%s\t%.9f\t%.9f\n", \
      parts[1], workload_name[key], untimed_count, \
      summarize(key, "untimed", untimed_count), \
      summarize(key, "timed", timed_count), ratio, (ratio - 1) * 100
  }
}
