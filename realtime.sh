#!/bin/sh

#!@todo this should output multiple streams, tagged by host

period=$1
[ -n "$period" ] || period=10
while true; do
    iptables -nvxL RRDIPT_INPUT -t mangle | grep ' eth0 '
done | awk '
function newFile(n){
  return(sprintf("realtime.%06d.log", n))
}
function date(){
#! this does not work with busybox date
  "date +%s.%N" | getline d
  close("date +%s.%N")
#!@todo could start a process with "while true; do date +%s.%N; done"
  return(d)
}
BEGIN {
  pb=0
  pd=date()
  md=pd
  printf "%1.2f/0 ", pd
}
{
  b=$2
   if(pd-md >= '"$period"'){
    printf "\n%1.2f/0 ", pd
    md=pd
  }
  d=date()
  printf "%1.2f/%d ", d-pd, b-pb
  fflush()
  pb=b
  pd=d
}
'
