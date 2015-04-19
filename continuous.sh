#!/bin/sh

go=1
collect=0
publish=0

trap 'go=0; echo $PPID' SIGINT

baseDir=/mnt/cifs2
source "$baseDir/common.sh"

updatePID()
{
    f='/tmp/'$1'.pid'
    sh -c 'echo $PPID' > $f
}

wan=$(detectWAN)
[ -z "$wan" ] && echo "Warning: failed to detect WAN interface."

lock
rm -f /tmp/continuous.pid

continuousReady=0
[ -p /tmp/continuous.pipe ] || mkfifo /tmp/continuous.pipe

while [ $go -eq 1 ] ; do
    if [ $continuousReady -eq 0 ]; then
	updatePID continuous
#	read myPID < /tmp/continuous.pid
	trap "publish=1" SIGUSR2
	trap 'go=0; echo $PPID' SIGINT
	continuousReady=1
#	echo "continuous $myPID" > /tmp/continuous.pipe
    fi
    date +%s.%N; \
    iptables -nvxL -t mangle -Z | \
	awk -v mode=diff wan="$wan" -f readDB.awk usage.db /proc/net/arp -
    if [ "$publish" -eq 1 ]; then
	publish=0
	cp usage.db usage.db.tmp
	echo > /tmp/wrtbwmon.pipe
    fi
    sleep 1
done > /tmp/continuous.pipe

rm -f /tmp/continuous.pid
unlock

echo main no go
kill $$ -SIGINT
