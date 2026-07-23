#!/usr/bin/awk -f
BEGIN {
  FS = "|"
  tolerance = 0.00000001
  ep[1] = "34"; ed[1] = "7"; ea[1] = "1"
  ep[2] = "41"; ed[2] = "6"; ea[2] = "3"
  ep[3] = "45"; ed[3] = "11"; ea[3] = "1"
  ec[1,1] = "interrupted"
  ec[2,1] = "completed"; ec[2,2] = "completed"
  ec[2,3] = "interrupted"; ec[3,1] = "interrupted"
  outer_phase["replay_recursion"] = 4
  outer_phase["alternative_enumeration"] = 5
  outer_phase["typed_hyp_subst"] = 7
  outer_phase["typed_close_assume"] = 8
  outer_phase["typed_close_contradiction"] = 9
  outer_phase["typed_safe_rule"] = 10
  outer_phase["typed_defer_goal"] = 11
  outer_phase["typed_unsafe_rule"] = 12
  outer_phase["stored_rule_setup"] = 13
  outer_phase["stored_rule_transition"] = 14
  outer_phase["duplicate_child_move"] = 15
  outer_phase["finish_open_goals"] = 16
  outer_phase["ground_replay"] = 17
  outer_phase["kernel_replay"] = 18
  outer_phase["finish_residual_goals"] = 19
  rule_phase["attempt_selection"] = 23
  rule_phase["freshening_setup"] = 24
  rule_phase["minor_unification"] = 25
  rule_phase["major_unification"] = 26
  rule_phase["rule_instantiation"] = 27
  rule_phase["child_store_construction"] = 28
  rule_phase["direct_result_construction"] = 29
  rule_phase["lazy_result_yield"] = 30
  rule_phase["direct_child_replacement"] = 31
  rule_phase["replay_record_construction"] = 32
  rule_phase["record_insertion"] = 33
}
function fail(message) {
  if (!failed) print "verify-target: " message > "/dev/stderr"
  failed = 1
  exit 1
}
function natural(x) { return x ~ /^(0|[1-9][0-9]*)$/ }
function positive(x) { return x ~ /^[1-9][0-9]*$/ }
function decimal(x) {
  return x ~ /^(0|[1-9][0-9]*)[.][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/
}
function near(a,b, d) { d=(a+0)-(b+0); if(d<0)d=-d; return d<=tolerance }
function csv(field,array,width,kind, n,i) {
  n=split(field,array,",")
  if(n!=width) fail(kind " width")
  for(i=1;i<=n;i++) {
    if(kind=="natural CSV" && !natural(array[i])) fail(kind " token")
    if(kind=="decimal CSV" && !decimal(array[i])) fail(kind " token")
  }
}
function scheduled(pos,problem,depth) {
  return positive(pos) && pos<=3 &&
    problem ~ ("^" ep[pos] "$") && depth ~ ("^" ed[pos] "$")
}
NR==1 {
  if ($0 != "Task7g timed-v2 raw protocol v1") fail("exact header/schema")
  next
}
eof_seen { fail("record after EOF") }
$1=="ATTEMPT" {
  if(NF!=31) fail("attempt schema")
  if(!scheduled($2,$3,$4)) fail("canonical target schedule literal")
  pos=$2+0; attempt=$5+0
  if(current_pos==0) current_pos=1
  if(pos!=current_pos) fail("target block order")
  if(stage[pos]!="" && stage[pos]!="attempt") fail("attempt order")
  if(!positive($5) || attempt!=attempt_count[pos]+1 || attempt>ea[pos])
    fail("canonical attempt literal")
  attempt_count[pos]=attempt; stage[pos]="attempt"
  if($6!=ec[pos,attempt] || $7!="none")
    fail("attempt completion/result vocabulary")
  if(split($8,oc,",")!=2) fail("outer context width")
  if(oc[1]=="none" || oc[2]=="none") {
    if(oc[1]!="none" || oc[2]!="none") fail("partial outer context")
  } else {
    if(oc[1]!="enter" && oc[1]!="exit") fail("outer boundary vocabulary")
    if(!(oc[2] in outer_phase)) fail("outer phase vocabulary")
  }
  if(split($9,sc,",")!=8) fail("stored context width")
  absent=(sc[1]=="none")
  if(absent) {
    for(i=2;i<=8;i++) if(sc[i]!="none") fail("partial stored context")
  } else {
    for(i=1;i<=7;i++) if(sc[i]=="none") fail("partial stored context")
    if(!positive(sc[1]) || !positive(sc[6])) fail("stored position literal")
    if(sc[2]!="safe_rule" && sc[2]!="unsafe_rule")
      fail("stored step vocabulary")
    if(sc[3]!="true" && sc[3]!="false") fail("duplicate vocabulary")
    if(sc[2]=="safe_rule" && sc[3]!="false") fail("safe duplicate relationship")
    if(sc[4]!="enter" && sc[4]!="exit") fail("stored boundary vocabulary")
    if(!(sc[5] in rule_phase)) fail("stored phase vocabulary")
    if(sc[7]!="intro" && sc[7]!="elim") fail("rule kind vocabulary")
    if(sc[7]=="intro" && sc[8]!="none") fail("intro assumption relationship")
    if(sc[7]=="elim" && !positive(sc[8])) fail("elim assumption relationship")
    if(sc[5]=="major_unification" && sc[7]!="elim")
      fail("major-unification rule relationship")
  }
  csv($10,stats,37,"natural CSV")
  for(i=11;i<=14;i++) if(!natural($i)) fail("observer natural")
  if($11!=stats[2]+stats[3]) fail("outer observer identity")
  if($12!=stats[20] || $13!=stats[21] || $14!=stats[22])
    fail("stored observer identity")
  if(stats[1]!=$11+$12) fail("combined checkpoint identity")
  if(stats[3]>stats[2] || stats[22]>stats[21] || $14>$13)
    fail("entry/exit prefix")
  if(stats[6]!=stats[7]+stats[8]+stats[9]+stats[10]+stats[11]+stats[12])
    fail("typed-step subtotal")
  outer_entries=stats[4]+stats[5]+stats[6]
  for(i=13;i<=19;i++) outer_entries+=stats[i]
  if(stats[2]!=outer_entries) fail("outer phase-entry subtotal")
  stored_entries=0; for(i=23;i<=33;i++) stored_entries+=stats[i]
  if(stats[21]!=stored_entries) fail("stored phase-entry subtotal")
  if(stats[23]!=stats[34]+stats[35] || stats[23]!=stats[36]+stats[37])
    fail("stored attempt-kind subtotal")
  if(stats[24]>stats[23] || stats[25]>stats[24])
    fail("attempt/fresh/minor relationship")
  if(stats[26]>stats[25] || stats[26]>stats[35])
    fail("major-unification count relationship")
  if(stats[27]>stats[25] || stats[27]>stats[26]+stats[34])
    fail("instantiation relationship")
  if(stats[28]>stats[27] || stats[29]>stats[28] || stats[30]>stats[29] ||
     stats[31]>stats[30] || stats[32]>stats[31] || stats[33]>stats[32])
    fail("yield/record relationship")
  if(oc[1]!="none") {
    if(stats[outer_phase[oc[2]]]<1) fail("current outer phase relationship")
    if(oc[1]=="exit" && stats[3]<1) fail("current outer exit relationship")
  }
  if(absent) {
    if($12+$13+$14!=0) fail("absent stored context relationship")
    for(i=20;i<=37;i++) if(stats[i]!=0) fail("absent stored context relationship")
  } else {
    if($12<1 || stats[rule_phase[sc[5]]]<1)
      fail("current stored phase relationship")
    if(sc[4]=="exit" && stats[22]<1) fail("current stored exit relationship")
    if(sc[7]=="intro" && stats[34]<1 || sc[7]=="elim" && stats[35]<1)
      fail("current rule-kind count relationship")
    if(sc[2]=="safe_rule" && stats[36]<1 ||
       sc[2]=="unsafe_rule" && stats[37]<1)
      fail("current step-kind count relationship")
  }
  csv($15,klass,12,"decimal CSV")
  subtotal=0; for(i=1;i<=11;i++) subtotal+=klass[i]
  if(!near(subtotal,klass[12])) fail("classical subtotal")
  for(i=16;i<=20;i++) if(!decimal($i)) fail("outer/attempt decimal grammar")
  for(i=21;i<=22;i++) if(!natural($i)) fail("minor count grammar")
  for(i=23;i<=31;i++) if(!decimal($i)) fail("minor/residual decimal grammar")
  if($22>$21) fail("failures/calls relationship")
  if(stats[25]!=$21) fail("minor calls/counter identity")
  if(!near($17+$18+$19,$20)) fail("outer partition")
  if(!near($20+klass[12],$16)) fail("attempt partition")
  if(!near($23+$24+$25,$26)) fail("minor partition")
  if(!near(klass[3],$26)) fail("minor/classical identity")
  if($25+0!=0 || $29+0!=0) fail("cleanup zero relationship")
  if($27>$23+tolerance || $28>$24+tolerance || $29>$25+tolerance ||
     $30>$26+tolerance) fail("maximum/category relationship")
  if($30+tolerance<$27 || $30+tolerance<$28 || $30+tolerance<$29)
    fail("overall/component maximum relationship")
  if(!near($31,0)) fail("attempt residual")
  sumwall[pos]+=$16; sumclass[pos]+=klass[12]
  sumalt[pos]+=$17; sumreplay[pos]+=$18; sumother[pos]+=$19
  sumouter[pos]+=$20; sumnorm[pos]+=$23; sumtrav[pos]+=$24
  sumcleanup[pos]+=$25; summinor[pos]+=$26
  sumcheckpoints[pos]+=stats[1]
  next
}
$1=="SUMMARY" {
  if(NF!=10) fail("summary schema")
  if(!scheduled($2,$3,$4)) fail("canonical summary schedule literal")
  pos=$2+0
  if(pos!=current_pos || stage[pos]!="attempt" || attempt_count[pos]!=ea[pos])
    fail("summary order/exact attempts")
  if($5!="reconstruction_interrupted") fail("summary outcome vocabulary")
  if(!decimal($6) || $6+0<30 || $6+0>=60) fail("process elapsed grammar/range")
  if(!positive($7) || $7!=ea[pos] || !natural($8))
    fail("summary attempt/poll literal")
  csv($9,search,8,"natural CSV")
  csv($10,total,11,"decimal CSV")
  if(!near(total[1],sumwall[pos]) || !near(total[2],sumclass[pos]) ||
     !near(total[3],sumalt[pos]) || !near(total[4],sumreplay[pos]) ||
     !near(total[5],sumother[pos]) || !near(total[6],sumouter[pos]) ||
     !near(total[7],sumnorm[pos]) || !near(total[8],sumtrav[pos]) ||
     !near(total[9],sumcleanup[pos]) || !near(total[10],summinor[pos]))
    fail("summary/attempt mechanical sums")
  if(!near(total[11],$6-total[1])) fail("process residual")
  if($8!=search[1]+sumcheckpoints[pos]) fail("global stop/checkpoint identity")
  stage[pos]="summary"; next
}
$1=="STATUS" {
  if(NF!=4) fail("status schema")
  if(!positive($2) || $2!=current_pos ||
     $3 !~ ("^" ep[current_pos] "$") || $4!="0" ||
     stage[current_pos]!="summary") fail("status/order/value")
  stage[current_pos]="status"
  if(current_pos<3) current_pos++
  next
}
$1=="EOF" {
  if(NF!=2 || $2!="Task7g timed-v2 raw protocol v1") fail("exact EOF")
  for(i=1;i<=3;i++) if(stage[i]!="status") fail("incomplete schedule")
  eof_seen=1; next
}
{ fail("unknown record") }
END {
  if(failed) exit 1
  if(!eof_seen) {
    print "verify-target: missing EOF" > "/dev/stderr"
    exit 1
  }
  print "target schema/order/vocabulary/relationships/status: PASS"
}
