#!/bin/sh

go=1
collect=0
publish=0

trap "go=0" SIGINT

baseDir=/mnt/cifs2
source "$baseDir/common.sh"

updatePID()
{
    t='/tmp/$$.sh'
    echo 'echo $PPID > /tmp/continuous.pid' > $t
    sh $t
    rm -f $t
    trap "collect=1" SIGUSR1
    trap "publish=1" SIGUSR2
    childReady=1
}

wan=$(detectWAN)
[ -z "$wan" ] && echo "Warning: failed to detect WAN interface."

lock

childReady=0
[ -p /tmp/continuous.pipe ] || mkfifo /tmp/continuous.pipe

while [ $go -eq 1 ] ; do
    if [ $childReady -eq 0 ]; then
	updatePID
    fi
    date +%s.%N; \
    iptables -nvxL -t mangle -Z | \
	awk -v mode=diff wan="$wan" -f readDB.awk usage.db /proc/net/arp -
    if [ "$collect" -eq 1 ]; then
	echo -e "\ncollect\n"
	collect=0
    elif [ "$publish" -eq 1 ]; then
	cp usage.db usage.db.tmp
	echo > /tmp/wrtbwmon.pipe
	publish=0
    fi
done | awk -f tsdb.awk

rm -f /tmp/continuous.pid /tmp/continuous.pipe
unlock

echo no go
kill $$ -SIGINT
