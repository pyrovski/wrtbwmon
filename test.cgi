#!/bin/sh

go=1
trap "go=0; kill -SIGQUIT $pipesPID $timerPID; rm -f /tmp/$$.*; exit 1" SIGINT

echo -en "Content-Type: text/plain\nContent-Encoding: gzip\n\n"
cd /tmp || exit 1

#!@todo start continuous if not running

t=`echo "$QUERY_STRING" | sed -r 's/(^|.*,)t=([0-9]+([.][0-9]+)*).*/\2/'`
continuousPID=`cat /tmp/continuous.pid 2>/dev/null`
if [ $? -ne 0 -o -z "$continuousPID" ]; then
    if [ "$t" -ne 0 ]; then
	mode=diff ./wrtbwmon update ./usage.db | awk -v noCollect=1 -f ./tsdb.awk
    fi
    awk -v ts=$t -f ./dump.awk *.tsdb | gzip -c -
    exit
fi

#!@todo this script should be modified to implement db backup functionality

[ -p /tmp/continuous.pipe ] || exit 1
mkfifo /tmp/$$.pipe || exit 1
echo "$$ $t" > /tmp/continuous.pipe &
pipesPID=$!

#elapsed=0
#(
#    while [ $go -eq 1 -a $elapsed -lt 10 ]; do
#	trap 'go=0' SIGTERM
#	sleep 1;
#	elapsed=$((elapsed+1))
#    done
#    if [ $go -eq 0 ]; then
#	exit
#    fi
#    kill $pipesPID) &
#timerPID=$!
wait $pipesPID
#if [ ! -f /tmp/$$.dump ]; then
#    >&2 echo "$$ no dump"
#    kill $timerPID; wait
#    exit 1
#else
    gzip -c /tmp/$$.pipe
#fi
#kill $timerPID; wait
rm -f /tmp/$$.pipe
