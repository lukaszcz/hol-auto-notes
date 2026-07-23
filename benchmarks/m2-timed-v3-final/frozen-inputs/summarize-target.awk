BEGIN {FS="|";OFS="\t"}
$1=="ATTEMPT" {
  p=$3;depth[p]=$4;attempts[p]++;split($15,c,",")
  wall[p]+=$16;classical[p]+=c[12];alt[p]+=$17;replay[p]+=$18
  other[p]+=$19;outer[p]+=$20
  for(i=21;i<=29;i++)counts[p,i]+=$i
  for(i=30;i<=38;i++)times[p,i]+=$i
  for(i=39;i<=47;i++)if($i+0>maxima[p,i])maxima[p,i]=$i
  for(i=48;i<=52;i++)pull_counts[p,i]+=$i
  for(i=53;i<=57;i++)pull_times[p,i]+=$i
  for(i=58;i<=61;i++)if($i+0>pull_maxima[p,i])pull_maxima[p,i]=$i
}
$1=="SUMMARY"{p=$3;elapsed[p]=$6;split($10,t,",");residual[p]=t[48]}
END {
  print "problem","depth","attempts","process_s","attempt_s", \
    "process_residual_s","classical_s","alternative_s","replay_s", \
    "other_outer_s","outer_s","minor_calls","minor_failures", \
    "normalization_events","lookup_walk_events","structural_events", \
    "decision_events","binding_events","binding_failures","other_events", \
    "normalization_s","lookup_walk_s","structural_s","decision_s", \
    "binding_s","traversal_other_s","coarse_traversal_s","cleanup_s", \
    "minor_s","max_normalization_s","max_lookup_walk_s", \
    "max_structural_s","max_decision_s","max_binding_s", \
    "max_traversal_other_s","max_coarse_traversal_s","max_cleanup_s", \
    "max_minor_s","completed_pulls","failed_pulls","interrupted_pulls", \
    "classical_snapshots","terminal_statistics_reads","completed_pull_s", \
    "failed_pull_s","interrupted_pull_s","pull_total_s","pull_residual_s", \
    "max_completed_pull_s","max_failed_pull_s","max_interrupted_pull_s", \
    "max_pull_s","alternative_attempt_pct","classical_attempt_pct", \
    "lookup_traversal_pct","structural_traversal_pct", \
    "decision_traversal_pct","binding_traversal_pct","other_traversal_pct", \
    "lookup_attempt_pct","structural_attempt_pct","decision_attempt_pct", \
    "binding_attempt_pct","other_attempt_pct","max_lookup_category_pct", \
    "max_structural_category_pct","max_decision_category_pct", \
    "max_binding_category_pct","max_other_category_pct", \
    "pull_total_alternative_pct","pull_residual_alternative_pct", \
    "max_pull_total_pct"
  order[1]=34;order[2]=41;order[3]=45
  for(k=1;k<=3;k++){
    p=order[k]
    printf "%s\t%s\t%s\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f\t%.9f", \
      p,depth[p],attempts[p],elapsed[p],wall[p],residual[p],classical[p], \
      alt[p],replay[p],other[p],outer[p]
    for(i=21;i<=29;i++)printf "\t%d",counts[p,i]
    for(i=30;i<=38;i++)printf "\t%.9f",times[p,i]
    for(i=39;i<=47;i++)printf "\t%.9f",maxima[p,i]
    for(i=48;i<=52;i++)printf "\t%d",pull_counts[p,i]
    for(i=53;i<=57;i++)printf "\t%.9f",pull_times[p,i]
    for(i=58;i<=61;i++)printf "\t%.9f",pull_maxima[p,i]
    printf "\t%.2f\t%.2f",100*alt[p]/wall[p],100*classical[p]/wall[p]
    for(i=31;i<=35;i++)printf "\t%.2f",100*times[p,i]/times[p,36]
    for(i=31;i<=35;i++)printf "\t%.2f",100*times[p,i]/wall[p]
    for(i=40;i<=44;i++)printf "\t%.3f", \
      (times[p,i-9]?100*maxima[p,i]/times[p,i-9]:0)
    printf "\t%.2f\t%.2f\t%.3f\n",100*pull_times[p,56]/alt[p], \
      100*pull_times[p,57]/alt[p], \
      (pull_times[p,56]?100*pull_maxima[p,61]/pull_times[p,56]:0)
  }
}
