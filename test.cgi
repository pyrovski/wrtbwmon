#!/bin/sh

go=1
trap "go=0; kill -SIGQUIT $pipesPID $timerPID; rm -f /tmp/$$.*; exit 1" SIGINT

echo -en "Content-Type: text/plain\nContent-Encoding: gzip\n\n"
mkfifo /tmp/$$.pipe

#!@todo start continuous if not running

continuousPID=`cat /tmp/continuous.pid`
[ -n "$continuousPID" ] || exit 1

#!@todo this script should be modified to implement db backup functionality
t=`echo "$QUERY_STRING" | sed -r 's/(^|.*,)t=([0-9]+([.][0-9]+)*).*/\2/'`

[ -p /tmp/continuous.pipe ] || exit 1
(echo "$$ $t"; read < /tmp/$$.pipe) > /tmp/continuous.pipe &
pipesPID=$!

elapsed=0
(while [ $go -eq 1 -a $elapsed -lt 10 ]; do
     sleep 1;
     elapsed=$((elapsed+1))
 done
 kill $pipesPID) &
timerPID=$!
wait $pipesPID
#>&2 echo "wait: $?"
[ -f /tmp/$$.dump ] || exit 1
gzip -c /tmp/$$.dump
kill $timerPID
wait
rm -f /tmp/$$.*
