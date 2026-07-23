# Task 7n final report

Status: complete target-free standalone microcalibration.

```
mode	median_external	minimum_external	maximum_external
Z	0.511189289	0.509745717	0.511828761
N	6.090917808	6.082526315	6.103101928
metric	value
net_N_minus_Z	5.579728519
task7m_D_minus_C	5.300872114
net_over_task7m	1.052606
consistency_band	[0.80,1.20]
classification	consistent
```

The standalone net is `consistent` with authoritative Task 7m `D-C`, under the
frozen inclusive `[0.80,1.20]` rule.

This descriptive comparison includes fresh-process startup, loop/closure and
counter overhead, Time-value consumption, runtime/GC and v10 wrapping.  Task
7m made the reads inside real reconstruction with different allocation,
cache, locality and control-flow context.  This package therefore identifies
no production source optimization, target profile, capability conclusion or
projected speedup.
