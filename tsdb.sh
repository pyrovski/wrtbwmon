#!/bin/sh

cat realtime.log | awk '\
{
  split($1,a,"/");
  tmin=a[1];
  for(i=s=0;i<=NF;i++){
    split($i,a,"/");
    s+=a[2]
    if(a[1]-tmin >= 10)
      break
  };
  print a[1]-tmin,s
  ORS=" "
  for(i++;i<NF;i++)
    print $i > "realtime.log."
}'
mv realtime.log. realtime.log

exit

cat realtime.log | awk '\
{
  split($1,a,"/");
  tmin=a[1];
  for(i=s=0;i<=NF;i++){
    split($i,a,"/");
    s+=a[2]
  };
  split($NF,a,"/");
  tmax=a[1];
  print tmax-tmin,s
}'
