BEGIN {
  OFS = (kind == "target" ? "|" : "\t")
  if (kind == "calibration") calibration()
  else if (kind == "active") active()
  else if (kind == "target") target()
  else exit 2
}
function repeat_csv(value,n, out,i) {
  out=value
  for(i=2;i<=n;i++) out=out "," value
  return out
}
function signature(count, out,i) {
  out=repeat_csv("0",37)
  for(i=2;i<=count;i++) out=out ";" repeat_csv("0",37)
  return out
}
function calibration( i,r,p,d,m,a) {
  print "repetition","problem","depth","mode","outcome","elapsed", \
    "attempts","search_counters","reconstruction_signatures"
  row[1]="1,38,4,v1"; row[2]="1,38,4,v2"
  row[3]="1,43,5,v1"; row[4]="1,43,5,v2"
  row[5]="2,43,5,v2"; row[6]="2,43,5,v1"
  row[7]="2,38,4,v2"; row[8]="2,38,4,v1"
  row[9]="3,38,4,v1"; row[10]="3,38,4,v2"
  row[11]="3,43,5,v1"; row[12]="3,43,5,v2"
  for(i=1;i<=12;i++) {
    split(row[i],a,","); r=a[1]; p=a[2]; d=a[3]; m=a[4]
    attempts=(p==38 ? 22 : 2)
    print r,p,d,m,"none","1.000000000",attempts,repeat_csv("0",8), \
      signature(attempts)
  }
}
function active( i,r,m) {
  print "repetition","mode","batch","elapsed","counter_signature"
  row[1]="1,v1"; row[2]="1,v2"; row[3]="2,v2"; row[4]="2,v1"
  row[5]="3,v1"; row[6]="3,v2"; row[7]="4,v2"; row[8]="4,v1"
  row[9]="5,v1"; row[10]="5,v2"
  for(i=1;i<=10;i++) {
    split(row[i],a,","); print a[1],a[2],"1000","1.000000000", \
      repeat_csv("0",9)
  }
}
function stats( a,i,out) {
  for(i=1;i<=37;i++) a[i]=0
  a[1]=11; a[2]=1; a[5]=1
  a[20]=10; a[21]=10
  a[23]=1; a[24]=1; a[25]=1
  for(i=27;i<=33;i++) a[i]=1
  a[34]=1; a[36]=1
  out=a[1]; for(i=2;i<=37;i++) out=out "," a[i]
  return out
}
function attempt(pos,problem,depth,n,completion) {
  print "ATTEMPT",pos,problem,depth,n,completion,"none", \
    "enter,alternative_enumeration", \
    "1,safe_rule,false,enter,minor_unification,1,intro,none",stats(), \
    "1","10","10","0", \
    "0.000000000,0.000000000,1.000000000,0.000000000,0.000000000,0.000000000,0.000000000,0.000000000,0.000000000,0.000000000,0.000000000,1.000000000", \
    "3.000000000","2.000000000","0.000000000","0.000000000", \
    "2.000000000","1","0","0.000000000","1.000000000", \
    "0.000000000","1.000000000","0.000000000","1.000000000", \
    "0.000000000","1.000000000","0.000000000"
}
function summary(pos,problem,depth,n) {
  wall=3*n; klass=1*n; alt=2*n; checkpoints=11*n
  residual=30-wall
  print "SUMMARY",pos,problem,depth,"reconstruction_interrupted", \
    "30.000000000",n,checkpoints,repeat_csv("0",8), \
    sprintf("%.9f,%.9f,%.9f,0.000000000,0.000000000,%.9f,0.000000000,%.9f,0.000000000,%.9f,%.9f", \
      wall,klass,alt,alt,n,n,residual)
}
function target() {
  print "Task7g timed-v2 raw protocol v1"
  attempt(1,34,7,1,"interrupted"); summary(1,34,7,1); print "STATUS",1,34,0
  attempt(2,41,6,1,"completed"); attempt(2,41,6,2,"completed")
  attempt(2,41,6,3,"interrupted"); summary(2,41,6,3); print "STATUS",2,41,0
  attempt(3,45,11,1,"interrupted"); summary(3,45,11,1); print "STATUS",3,45,0
  print "EOF","Task7g timed-v2 raw protocol v1"
}
