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
    >&2 echo $f
}

mem(){
    read < /tmp/cl.pipe
    while [ -f /tmp/continuous.pid ]; do
	awk -f mem.awk $(ls *.tsdb)
    done
}

wan=$(detectWAN)
[ -z "$wan" ] && echo "Warning: failed to detect WAN interface."

lock
rm -f /tmp/continuous.pid

continuousReady=0
[ -p /tmp/continuous.pipe ] || mkfifo /tmp/continuous.pipe
[ -p /tmp/cl.pipe ] || mkfifo /tmp/cl.pipe

mem &

while [ $go -eq 1 ] ; do
    if [ $continuousReady -eq 0 ]; then
	updatePID continuous
	read myPID < /tmp/continuous.pid
	trap "publish=1" SIGUSR2
	trap 'go=0; echo $PPID' SIGINT
	continuousReady=1
	echo "continuous $myPID" > /tmp/cl.pipe
    fi
    (date +%s.%N; iptables -nvxL -t mangle -Z | \
	 awk -v mode=diff wan="$wan" -f readDB.awk usage.db /proc/net/arp - ) \
	> /tmp/continuous.pipe
    if [ "$publish" -eq 1 ]; then
	publish=0
	cp usage.db usage.db.tmp
	echo > /tmp/wrtbwmon.pipe
    fi
    sleep 1
done

rm -f /tmp/continuous.pid
#kill -SIGINT $(cat /tmp/mem.pid)
echo exit > /tmp/continuous.pipe
unlock

echo main no go
kill $$ -SIGINT
