#!/bin/sh
echo -en "Content-Type: text/plain\nContent-Encoding: gzip\n\n"
mkfifo /tmp/$$.pipe

#!@todo start continuous if not running

#!@todo this script should be modified to implement db backup functionality
t=`echo "$QUERY_STRING" | sed -r 's/(^|.*,)t=([0-9]+([.][0-9]+)*).*/\2/'`

echo "$$ $t" > /tmp/wrtbwmon.pipe &
gzip -c `cat /tmp/$$.pipe` &
kill -SIGUSR1 `cat /tmp/continuous.pid`
wait
rm -f /tmp/$$.*
