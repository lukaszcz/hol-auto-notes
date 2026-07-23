BEGIN { FS="|"; OFS="\t" }
$1=="ATTEMPT" {
  p=$3; depth[p]=$4; attempts[p]++
  split($15,c,",")
  wall[p]+=$16; classical[p]+=c[12]
  alt[p]+=$17; replay[p]+=$18; other[p]+=$19; outer[p]+=$20
  calls[p]+=$21; failures[p]+=$22
  norm[p]+=$23; traversal[p]+=$24; cleanup[p]+=$25; minor[p]+=$26
  if($27+0>maxnorm[p])maxnorm[p]=$27
  if($28+0>maxtrav[p])maxtrav[p]=$28
  if($29+0>maxcleanup[p])maxcleanup[p]=$29
  if($30+0>maxminor[p])maxminor[p]=$30
  split($10,s,","); pulls[p]+=s[5]
}
$1=="SUMMARY" {
  p=$3; elapsed[p]=$6; split($10,t,","); residual[p]=t[11]
}
END {
  print "problem","depth","attempts","process_s","attempt_s","process_residual_s","classical_s","alternative_s","replay_s","other_outer_s","outer_s","minor_calls","minor_failures","normalization_s","traversal_s","cleanup_s","minor_s","max_normalization_s","max_traversal_s","max_cleanup_s","max_minor_s","alternative_pulls","alternative_attempt_pct","replay_attempt_pct","other_attempt_pct","classical_attempt_pct","traversal_minor_pct","traversal_attempt_pct","max_traversal_category_pct","max_minor_category_pct"
  order[1]=34; order[2]=41; order[3]=45
  for(i=1;i<=3;i++) {
    p=order[i]
    print p,depth[p],attempts[p],sprintf("%.9f",elapsed[p]),sprintf("%.9f",wall[p]),sprintf("%.9f",residual[p]),sprintf("%.9f",classical[p]),sprintf("%.9f",alt[p]),sprintf("%.9f",replay[p]),sprintf("%.9f",other[p]),sprintf("%.9f",outer[p]),calls[p],failures[p],sprintf("%.9f",norm[p]),sprintf("%.9f",traversal[p]),sprintf("%.9f",cleanup[p]),sprintf("%.9f",minor[p]),sprintf("%.9f",maxnorm[p]),sprintf("%.9f",maxtrav[p]),sprintf("%.9f",maxcleanup[p]),sprintf("%.9f",maxminor[p]),pulls[p],sprintf("%.2f",100*alt[p]/wall[p]),sprintf("%.2f",100*replay[p]/wall[p]),sprintf("%.2f",100*other[p]/wall[p]),sprintf("%.2f",100*classical[p]/wall[p]),sprintf("%.2f",100*traversal[p]/minor[p]),sprintf("%.2f",100*traversal[p]/wall[p]),sprintf("%.3f",100*maxtrav[p]/traversal[p]),sprintf("%.3f",100*maxminor[p]/minor[p])
  }
}
