#!/bin/sh
echo -en "Content-Type: text/plain\nContent-Encoding: gzip\n\n"
#!@todo find a way to only return new data. This could be implemented
#!by having the client request data after a specific timestamp. The
#!filtering could be done in the cgi script or the tsdb awk script,
#!with the latter being faster.
mkfifo /tmp/$$.pipe
t=`echo "$QUERY_STRING" | sed -r 's/(^|.*,)t=([0-9]+([.][0-9]+)*).*/\2/'`
echo "$$ $t" > /tmp/wrtbwmon.pid
awk 'BEGIN{f=0;OFS=","}/\{/{f=1;print;next}f&&NF==3{ORS="],["; print $1,$2,$3}/\}/{f=0;;ORS="\n";print "0]]}";exit}' < /tmp/$$.pipe | gzip &
kill -SIGUSR1 `cat /tmp/pid`
wait
rm -f /tmp/$$.pipe
