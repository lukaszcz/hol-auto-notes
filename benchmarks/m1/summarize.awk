BEGIN {
  FS = OFS = "\t"
  print "problem", "depth", "batch", "baseline_samples_s", \
        "baseline_median_s", "baseline_range_s", "current_samples_s", \
        "current_median_s", "current_range_s", "baseline_over_current", \
        "time_reduction_percent"
}

NR == 1 { next }

{
  revision[$4, $1, $2] = $8 + 0
  depth[$4] = $5
  batch[$4] = $6
  seen[$4] = 1
}

function sorted_samples(values, count, i, j, temporary, result) {
  for (i = 2; i <= count; i++) {
    temporary = values[i]
    j = i - 1
    while (j >= 1 && values[j] > temporary) {
      values[j + 1] = values[j]
      j--
    }
    values[j + 1] = temporary
  }
  result = sprintf("%.6f", values[1])
  for (i = 2; i <= count; i++)
    result = result "," sprintf("%.6f", values[i])
  return result
}

END {
  split("34 38 41 42 43 45", problems, " ")
  for (i = 1; i <= 6; i++) {
    problem = problems[i]
    for (repetition = 1; repetition <= 9; repetition++) {
      b[repetition] = revision[problem, "be308c56d", repetition]
      c[repetition] = revision[problem, "c7f72c445", repetition]
    }
    baseline = sorted_samples(b, 9)
    current = sorted_samples(c, 9)
    baseline_median = b[5]
    current_median = c[5]
    ratio = baseline_median / current_median
    reduction = 100 * (baseline_median - current_median) / baseline_median
    print problem, depth[problem], batch[problem], baseline,
          sprintf("%.6f", baseline_median),
          sprintf("%.6f--%.6f", b[1], b[9]), current,
          sprintf("%.6f", current_median),
          sprintf("%.6f--%.6f", c[1], c[9]),
          sprintf("%.3f", ratio), sprintf("%.1f", reduction)
  }
}
