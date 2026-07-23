# Authoritative collection result: calibration failed; targets forbidden

The final sealed chain ran once. P38 repetition 1 completed with exact paired
work/signature parity: v2 `1.652517000` seconds and v4 `8.652819000` seconds
(observed ratio `5.235` approximately). P43 v2 completed at `12.645914000`
seconds. P43 v4 emitted no elapsed row before its 45-second watchdog.

The P43 v4 leader was observed reaped after TERM with wait return code `-15`
and signal 15; this is a right-censored `>=45 s` observation, not a completion
time. Its supervisor JSON recorded `group_gone=false` at the immediate check
and therefore returned 125. A later retained process-group and endpoint audit
found the group gone and no matching task process, but that does not rewrite
the failed immediate process-control result.

Consequently the fixed representative schedule is incomplete and cannot
produce its predeclared medians. The v4 comparability gate did not pass, the
active schedule never began, and P34/P41/P45 correctly never began. No v4
target category/pull distribution, causal attribution, projected speedup,
optimization, or capability conclusion is permitted.

The minimally perturbing next diagnostic is twofold: first apply the retained
group-lifecycle patch so grace/escalation follows the whole group after leader
reap; then use the already-bounded v4 summary on a smaller fixed-work fixture
or profiler to separate clock-call/operation-count overhead from summary
aggregation. Do not repeat P43@5 until that bounded calibration predicts it
will remain inside a short watchdog. P38 already establishes material v4
observer cost on completed equal work.
