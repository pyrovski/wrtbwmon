#!/bin/sh

go=1

trap "go=0" SIGINT

lock()
{
    attempts=0
    while [ $attempts -lt 10 ]; do
	while [ -f /tmp/wrtbwmon.lock -a $attempts -lt 10 ]; do
	    if [ ! -d /proc/$(< /tmp/wrtbwmon.lock) ]; then
		echo "WARNING: Lockfile detected but process $(cat /tmp/wrtbwmon.lock) does not exist !"
		rm -f /tmp/wrtbwmon.lock
	    else
		sleep 1
		attempts=$((attempts+1))
	    fi
	done
	echo $$ > /tmp/wrtbwmon.lock
	read lockPID < /tmp/wrtbwmon.lock
	[[ $$ -eq "$lockPID" ]] && break;
	attempts=$((attempts+1))
    done
    #[[ -n "$DEBUG" ]] && echo $$ "got lock after $attempts attempts"
    trap "go=0" SIGINT
}

unlock()
{
    rm -f /tmp/wrtbwmon.lock
    #[[ -n "$DEBUG" ]] && echo $$ "released lock"
    trap "rm -f /tmp/*$$.tmp; kill -SIGINT $$" SIGINT
}

detectIF()
{
    uci=`which uci 2>/dev/null`
    if [ -n "$uci" -a -x "$uci" ]; then
	IF=`$uci get network.${1}.ifname`
	[ $? -eq 0 ] && echo $IF && return
    fi

    nvram=`which nvram 2>/dev/null`
    if [ -n "$nvram" -a -x "$nvram" ]; then
	IF=`$nvram get ${1}_ifname`
	[ $? -eq 0 ] && echo $IF && return
    fi
}

detectWAN()
{
    [ -n "$WAN_IF" ] && echo $WAN_IF && return
    wan=$(detectIF wan)
    [ -n "$wan" ] && echo $wan && return
}


wan=$(detectWAN)
[ -z "$wan" ] && echo "Warning: failed to detect WAN interface."

lock

while [ $go -eq 1 ] ; do
    (date +%s.%N; \
     iptables -nvxL -t mangle -Z | \
	 awk -v mode=diff wan="$wan" -f readDB.awk usage.db /proc/net/arp - )
done | awk -f tsdb.awk

unlock

echo no go
kill $$ -SIGINT

