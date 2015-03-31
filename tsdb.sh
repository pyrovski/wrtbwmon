#!/usr/bin/awk

#!@todo this should keep an array of data per host
{
  split($1,a,"/");
  tmin=a[1];
  t=tmin
  s=0
  for(i=2;i<=NF;i++){
    split($i,a,"/");
    t+=a[1]
    s+=a[2]
  };
  printf "%10.2f %d\n", t, s
  fflush()
}
