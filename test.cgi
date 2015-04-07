#!/bin/sh
echo -en "Content-Type: text/plain\nContent-Encoding: gzip\n\n"
#!@todo find a way to only return new data. This could be implemented
#!by having the client request data after a specific timestamp. The
#!filtering could be done in the cgi script or the tsdb awk script,
#!with the latter being faster.
mkfifo /tmp/$$.pipe

#!@todo this script should be modified to implement db backup functionality
t=`echo "$QUERY_STRING" | sed -r 's/(^|.*,)t=([0-9]+([.][0-9]+)*).*/\2/'`

#!@todo this could be done in awk, via the wrtbwmon pipe. However, that method has the chance of hanging the continuous awk script if this script fails.
echo "$$ $t" > /tmp/wrtbwmon.pid

#awk 'BEGIN{f=0;OFS=","}/\{/{f=1;print;next}f&&NF==4{ORS="],["; print $1,$2,$3,$4}/\}/{f=0;;ORS="\n";print "0]]}";exit}' < /tmp/$$.pipe | gzip &
awk 'BEGIN{f=0;OFS=","}/\{/{f=1;print;next}f&&NF==3{ORS="],["; print $1,$2,$3}/\}/{f=0;;ORS="\n";print "0]]}";exit}' < /tmp/$$.pipe | gzip &
#cat < /tmp/$$.pipe &
# awk 'FNR==1{split(FILENAME, a, "_"); print a[1]}NF==3 && $1 >  1428340279.09'  *.tsdb | gzip &
kill -SIGUSR1 `cat /tmp/continuous.pid`
wait
rm -f /tmp/$$.pipe
