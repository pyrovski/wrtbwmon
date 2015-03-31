#!/bin/sh

rm -f realtime.*.log

while true; do
    sudo iptables -nvxL RRDIPT_INPUT -t mangle | grep ' eth0 '
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
  i=j=pb=0
  f=newFile(i)
  pd=date()
}
{
  b=$2
  if(++j >= 1000){
    j=0
    close(f)
    f=newFile(++i)
    printf "%f ", pd > f
  }
  d=date()
  printf "%1.2f/%d ", d-pd, b-pb > f
  fflush(f)
  pb=b
  pd=d
}
'
