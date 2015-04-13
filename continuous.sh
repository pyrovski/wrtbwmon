#!/bin/sh

echo "main PID: $$"

go=1
collect=0
publish=0

trap 'go=0; echo $PPID' SIGINT

baseDir=/mnt/cifs2
source "$baseDir/common.sh"

#!@todo start a process to read from the request pipe and signal the main loop

updatePID()
{
    f='/tmp/'$1'.pid'
    sh -c 'echo $PPID' > $f
}

listen()
{
    go=1
    listenerReady=0
    continuousPID=''
    while [ $go -eq 1 ]; do
	if [ $listenerReady -eq 0 ]; then
	    updatePID listener
	    read myPID < /tmp/listener.pid
	    echo "listener PID: $myPID"
	    trap 'go=0; echo $PPID' SIGUSR1 SIGINT
	    listenerReady=1
	    echo "listener ready"
	fi
	read clientPID ts 2>/dev/null < /tmp/continuous.pipe
	readStatus=$?
	if [ $readStatus -ne 0 ]; then
	    echo "cont read: $readStatus"
	    if [ $go -ne 1 ]; then
		echo "listener no go"
		break
	    else
		continue
	    fi
	fi
	echo "listener read cont: $clientPID $ts"
	# wait for continuous loop to write its pid to file
	if [ -n "$clientPID" -a -n "$ts" ]; then
	    if [ -n "$continuousPID" ]; then
		echo "$clientPID $ts" > /tmp/listener.pipe &
		kill -SIGUSR1 $continuousPID
		# wait until continuous loop acknowledges
		while [ $go -eq 1 ]; do
		    read < /tmp/cl.pipe # 2>/dev/null
		    readStatus=$?
		    echo "cl read: $readStatus"
		    [ $readStatus -eq 0 ] && break
		done
		[ $go -eq 1 ] || break
		echo "listener read cl"
		# wait for tsdb to read from listener pipe
		wait
		echo "listener done waiting: $?"
	    else
		if [ $clientPID == "continuous" ]; then
		    continuousPID=$ts
		else		    
		    >&2 echo "continuous loop has not started yet?"
		    [ -p /tmp/$clientPID.pipe ] && echo > /tmp/$clientPID.pipe
		fi
	    fi
	fi
    done
    echo "listener exiting; go: $go"
}

wan=$(detectWAN)
[ -z "$wan" ] && echo "Warning: failed to detect WAN interface."

lock
rm -f /tmp/continuous.pid /tmp/continuous.pipe /tmp/cl.pipe /tmp/listener.pipe

continuousReady=0
[ -p /tmp/continuous.pipe ] || mkfifo /tmp/continuous.pipe
[ -p /tmp/listener.pipe ] || mkfifo /tmp/listener.pipe
[ -p /tmp/cl.pipe ] || mkfifo /tmp/cl.pipe

listen &

while [ $go -eq 1 ] ; do
    if [ $continuousReady -eq 0 ]; then
	updatePID continuous
	read myPID < /tmp/continuous.pid
	>&2 echo "continuous PID: $myPID"
	trap "collect=1" SIGUSR1
	trap "publish=1" SIGUSR2
	trap 'go=0; echo $PPID' SIGINT
	continuousReady=1
	>&2 echo "cont writing listener"
	echo "continuous $myPID" > /tmp/continuous.pipe
	>&2 echo "cont wrote listener"
    fi
    date +%s.%N; \
    iptables -nvxL -t mangle -Z | \
	awk -v mode=diff wan="$wan" -f readDB.awk usage.db /proc/net/arp -
    if [ "$collect" -eq 1 ]; then
	collect=0
	if [ -f /tmp/listener.pid -a -d /proc/$(cat /tmp/listener.pid) ]; then
	    echo -e "\ncollect\n"
	    >&2 echo "cont ack"
	    echo > /tmp/cl.pipe
	    >&2 echo "cont ack: $?"	    
	else
	    >&2 echo "listener detection failure?"
	    break
	fi
    elif [ "$publish" -eq 1 ]; then
	publish=0
	cp usage.db usage.db.tmp
	echo > /tmp/wrtbwmon.pipe
    fi
done | awk -f tsdb.awk

rm -f /tmp/continuous.pid /tmp/continuous.pipe /tmp/cl.pipe /tmp/listener.pipe
#!@todo kill listener
echo "killing listener "$(cat /tmp/listener.pid)
kill -SIGUSR1 $(cat /tmp/listener.pid)
echo "waiting for listener"
wait
echo "waited for listener"
unlock

echo main no go
kill $$ -SIGINT
