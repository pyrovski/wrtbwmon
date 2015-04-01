#!/bin/sh

go=1

trap "go=0" SIGINT

while [ $go == 1 ] ; do
    date +%s.%N
    iptables -nvxL RRDIPT_FORWARD -t mangle -Z | \
	awk -v mode=diff -f readDB.awk usage.db /proc/net/arp -
done

echo no go
kill $$ -SIGINT

