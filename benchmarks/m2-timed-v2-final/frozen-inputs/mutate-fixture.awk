BEGIN { FS=OFS=(kind=="target" ? "|" : "\t") }
kind=="calibration" && NR==1 && scenario=="header" {$1="bad"; done=1}
kind=="calibration" && NR==2 && !done {
  if(scenario=="schema") {NF=8; done=1}
  else if(scenario=="elapsed") {$6="1e0"; done=1}
  else if(scenario=="problem") {$2="39"; done=1}
  else if(scenario=="depth") {$3="5"; done=1}
  else if(scenario=="mode") {$4="v3"; done=1}
  else if(scenario=="repetition") {$1="01"; done=1}
  else if(scenario=="signature_width") {sub(/,0$/,"",$9); done=1}
  else if(scenario=="signature_token") {sub(/^0/,"x",$9); done=1}
}
kind=="calibration" && scenario=="reorder" && NR==2 {saved=$0; next}
kind=="calibration" && scenario=="reorder" && NR==3 {print; print saved; next}
kind=="target" && NR==2 && !done && scenario!="status" && scenario!="append" {
  if(scenario=="problem") {$3="35"}
  else if(scenario=="problem_noncanonical") {$3="034"}
  else if(scenario=="depth") {$4="8"}
  else if(scenario=="depth_noncanonical") {$4="7.0"}
  else if(scenario=="attempt") {$5="01"}
  else if(scenario=="outer_boundary") {sub(/^enter,/,"bad,",$8)}
  else if(scenario=="outer_phase") {sub(/alternative_enumeration/,"bad",$8)}
  else if(scenario=="step_kind") {sub(/safe_rule/,"bad",$9)}
  else if(scenario=="duplicate_vocab") {sub(/false/,"maybe",$9)}
  else if(scenario=="safe_duplicate") {sub(/false/,"true",$9)}
  else if(scenario=="stored_boundary") {sub(/,enter,minor/,",bad,minor",$9)}
  else if(scenario=="stored_phase") {sub(/minor_unification/,"bad",$9)}
  else if(scenario=="rule_kind") {sub(/,intro,/,",bad,",$9)}
  else if(scenario=="intro_assumption") {sub(/,none$/,",1",$9)}
  else if(scenario=="elim_assumption") {sub(/,intro,none$/,",elim,none",$9)}
  else if(scenario=="major_intro") {sub(/minor_unification/,"major_unification",$9)}
  else if(scenario=="partial_context") {sub(/^1,/,"none,",$9)}
  else if(scenario=="outer_partition") {$20="3.000000000"}
  else if(scenario=="minor_partition") {$26="2.000000000"}
  else if(scenario=="elapsed_grammar") {$16="3"}
  else if(scenario=="stats_width") {sub(/,0$/, "", $10)}
  done=1
}
kind=="target" && $1=="STATUS" && !done && scenario=="status" {$4="1"; done=1}
kind=="target" && $1=="EOF" && scenario=="append" {print; print "STATUS|1|34|0"; next}
{print}
