#!/usr/bin/awk -f
BEGIN {
  FS="|"; tolerance=0.00000001
  expected_problem[1]=34; expected_depth[1]=7; expected_attempts[1]=1
  expected_problem[2]=41; expected_depth[2]=6; expected_attempts[2]=3
  expected_problem[3]=45; expected_depth[3]=11; expected_attempts[3]=1
  expected_completion[1,1]="interrupted"
  expected_completion[2,1]="completed"
  expected_completion[2,2]="completed"
  expected_completion[2,3]="interrupted"
  expected_completion[3,1]="interrupted"
}
function fail(message) { print "verify-target: " message > "/dev/stderr"; exit 1 }
function natural(x) { return x ~ /^[0-9]+$/ }
function decimal(x) { return x ~ /^[0-9]+([.][0-9]+)?$/ }
function near(a,b) { d=(a+0)-(b+0); if(d<0)d=-d; return d<=tolerance }
function csv(field,array,n, kind, i) {
  n=split(field,array,",")
  for(i=1;i<=n;i++) {
    if(kind=="natural" && !natural(array[i])) fail("bad natural CSV")
    if(kind=="decimal" && !decimal(array[i])) fail("bad decimal CSV")
  }
  return n
}
function scheduled(pos,problem,depth) {
  return natural(pos) && pos>=1 && pos<=3 &&
         problem==expected_problem[pos] && depth==expected_depth[pos]
}
NR==1 {
  if ($0 != "Task7g timed-v2 raw protocol v1") fail("bad header")
  next
}
eof_seen { fail("record after EOF") }
$1=="ATTEMPT" {
  if(NF!=31) fail("attempt schema")
  pos=$2+0; problem=$3+0; depth=$4+0; attempt=$5+0
  if(!scheduled($2,$3,$4)) fail("attempt schedule literal")
  if(stage[pos]!="" && stage[pos]!="attempt") fail("attempt order")
  if(pos!=current_position && !(current_position==0 || pos==current_position+1))
    fail("position order")
  current_position=pos; stage[pos]="attempt"
  if(attempt != attempt_count[pos]+1 || attempt>expected_attempts[pos])
    fail("attempt number")
  attempt_count[pos]=attempt
  if($6!=expected_completion[pos,attempt] || $7!="none")
    fail("attempt completion/result")
  if(split($8,context,",")!=2) fail("outer context width")
  if(context[1]!="enter" && context[1]!="exit" && context[1]!="none")
    fail("outer context boundary")
  if((context[1]=="none") != (context[2]=="none")) fail("partial outer context")
  if(split($9,stored,",")!=8) fail("stored context width")
  if(stored[1]=="none") {
    for(i=2;i<=8;i++) if(stored[i]!="none") fail("partial stored context")
  } else {
    for(i=1;i<=7;i++) if(stored[i]=="none") fail("partial stored context")
    if(!natural(stored[1]) || !natural(stored[6]) ||
       (stored[8]!="none" && !natural(stored[8])))
      fail("bad concrete stored context")
  }
  if(csv($10,stats,0,"natural")!=37) fail("statistics width")
  for(i=11;i<=14;i++) if(!natural($i)) fail("observer natural")
  if(($11+0)+($12+0)!=stats[1] || $12!=stats[20] ||
     $13!=stats[21] || $14!=stats[22])
    fail("observer/statistics identity")
  if(stats[3]>stats[2] || stats[22]>stats[21] || $14>$13)
    fail("entry/exit prefix")
  if(csv($15,klass,0,"decimal")!=12) fail("classical time width")
  subtotal=0; for(i=1;i<=11;i++) subtotal+=klass[i]
  if(!near(subtotal,klass[12])) fail("classical subtotal")
  for(i=16;i<=20;i++) if(!decimal($i)) fail("outer/attempt decimal")
  for(i=21;i<=22;i++) if(!natural($i)) fail("minor count natural")
  for(i=23;i<=31;i++) if(!decimal($i)) fail("minor/residual decimal")
  if($22>$21) fail("failures exceed calls")
  if(stats[25]!=$21) fail("minor calls/counter identity")
  if(!near(($17+0)+($18+0)+($19+0),$20)) fail("outer partition")
  if(!near(($20+0)+(klass[12]+0),$16)) fail("attempt partition")
  if(!near(($23+0)+($24+0)+($25+0),$26)) fail("minor partition")
  if(!near(klass[3],$26)) fail("minor/classical identity")
  if(($25+0)!=0 || ($29+0)!=0) fail("cleanup must be zero")
  if(($27+0)>($23+0)+tolerance || ($28+0)>($24+0)+tolerance ||
     ($29+0)>($25+0)+tolerance || ($30+0)>($26+0)+tolerance)
    fail("maximum exceeds category")
  if(($30+0)+tolerance<($27+0) || ($30+0)+tolerance<($28+0) ||
     ($30+0)+tolerance<($29+0)) fail("overall maximum below component")
  if(!near($31,0)) fail("attempt residual")
  sumwall[pos]+=$16; sumclass[pos]+=klass[12]
  sumalt[pos]+=$17; sumreplay[pos]+=$18; sumother[pos]+=$19
  sumouter[pos]+=$20; sumnorm[pos]+=$23; sumtrav[pos]+=$24
  sumcleanup[pos]+=$25; summinor[pos]+=$26
  next
}
$1=="SUMMARY" {
  if(NF!=10) fail("summary schema")
  pos=$2+0
  if(!scheduled($2,$3,$4) || pos!=current_position) fail("summary schedule")
  if(stage[pos]!="attempt" || attempt_count[pos]!=expected_attempts[pos])
    fail("summary before exact attempts")
  if($5!="reconstruction_interrupted" || !decimal($6) ||
     !natural($7) || $7!=expected_attempts[pos] || !natural($8))
    fail("summary outcome/count")
  if(csv($9,search,0,"natural")!=8) fail("search statistics width")
  if(csv($10,total,0,"decimal")!=11) fail("summary time width")
  if(!near(total[1],sumwall[pos]) || !near(total[2],sumclass[pos]) ||
     !near(total[3],sumalt[pos]) || !near(total[4],sumreplay[pos]) ||
     !near(total[5],sumother[pos]) || !near(total[6],sumouter[pos]) ||
     !near(total[7],sumnorm[pos]) || !near(total[8],sumtrav[pos]) ||
     !near(total[9],sumcleanup[pos]) || !near(total[10],summinor[pos]))
    fail("summary/attempt sums")
  if(!near(total[11],($6+0)-total[1])) fail("process residual")
  elapsed[pos]=$6; process_residual[pos]=total[11]
  stage[pos]="summary"
  next
}
$1=="STATUS" {
  if(NF!=4) fail("status schema")
  pos=$2+0
  if(pos!=current_position || $3!=expected_problem[pos] || $4!="0" ||
     stage[pos]!="summary") fail("status/order/value")
  stage[pos]="status"; next
}
$1=="EOF" {
  if(NF!=2 || $2!="Task7g timed-v2 raw protocol v1") fail("bad EOF")
  for(i=1;i<=3;i++) if(stage[i]!="status") fail("incomplete schedule")
  eof_seen=1; next
}
{ fail("unknown record") }
END {
  if(!eof_seen) fail("missing EOF")
  print "target schema/order/status/partition/context validation: PASS"
}
