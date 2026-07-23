BEGIN { FS="\t"; OFS="\t" }
FNR == 1 { next }
FILENAME == ARGV[1] { key="P" $2 "@" $3; n[key,$4]++; v[key,$4,n[key,$4]]=$6; next }
FILENAME == ARGV[2] { key="active-1000"; n[key,$2]++; v[key,$2,n[key,$2]]=$4; next }
function sort_values(key,mode,  i,j,t) {
  for (i=1;i<=n[key,mode];i++) a[i]=v[key,mode,i]+0
  for (i=1;i<=n[key,mode];i++) for (j=i+1;j<=n[key,mode];j++)
    if (a[j]<a[i]) {t=a[i];a[i]=a[j];a[j]=t}
}
END {
  print "workload","v1_median","v1_min","v1_max","v2_median","v2_min","v2_max","v2_over_v1","percent_change"
  keys[1]="P38@4"; keys[2]="P43@5"; keys[3]="active-1000"
  for (k=1;k<=3;k++) {
    key=keys[k]; sort_values(key,"v1"); lo1=a[1]; hi1=a[n[key,"v1"]]; med1=a[int((n[key,"v1"]+1)/2)]
    delete a; sort_values(key,"v2"); lo2=a[1]; hi2=a[n[key,"v2"]]; med2=a[int((n[key,"v2"]+1)/2)]
    print key,sprintf("%.9f",med1),sprintf("%.9f",lo1),sprintf("%.9f",hi1),sprintf("%.9f",med2),sprintf("%.9f",lo2),sprintf("%.9f",hi2),sprintf("%.6f",med2/med1),sprintf("%.2f",100*(med2/med1-1))
    delete a
  }
}
