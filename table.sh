#!/usr/bin/awk
BEGIN {od=""}
NF==2{
    d=$2
    if(od==""){
	od=d
	ld=d
    }
    next
}
$2 > 0{
    if($6 != "*")
	n=$6
    else
	n=$8
    in_[n]+=$2
    if(d-ld > 5){
	ld=d
	print d
	for(i in in_) print i, in_[i]
	#!@todo update table for longer timescale...
    }
}
