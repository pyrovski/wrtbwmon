#!/bin/sh
#
# Traffic logging tool for OpenWRT-based routers
#
# Created by Emmanuel Brucy (e.brucy AT qut.edu.au)
# Updated by Peter Bailey (peter.eldridge.bailey@gmail.com)
#
# Based on work from Fredrik Erlandsson (erlis AT linux.nu)
# Based on traff_graph script by twist - http://wiki.openwrt.org/RrdTrafficWatch
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#!@todo add logger
#!@todo reference awk scripts and html templates in predictable location

[ -p /tmp/wrtbwmon.pipe ] || mkfifo /tmp/wrtbwmon.pipe

trap "rm -f /tmp/*$$.tmp; kill -SIGINT $$" SIGINT
baseDir=/mnt/cifs2

chains='INPUT OUTPUT FORWARD'
DEBUG=
tun=
DB=$2

header="#mac,ip,iface,peak_in,peak_out,offpeak_in,offpeak_out,total,first_date,last_date"

source "$baseDir/common.sh"

############################################################

case $1 in
    "update" )
	[ -z "$DB" ] && echo "ERROR: Missing argument 2" && exit 1	
	[ ! -f "$DB" ] && echo $header > "$DB"
	[ ! -w "$DB" ] && echo "ERROR: $DB not writable" && exit 1

	wan=$(detectWAN)
	if [ -z "$wan" ]; then
	    echo "Warning: failed to detect WAN interface."
	fi

	if [ -f /tmp/continuous.pid ]; then
	    if [ -d /proc/$(cat /tmp/continuous.pid) ]; then
		echo "continuous running; abort"
		exit
	    else
		echo "Warning: removing /tmp/continuous.pid"
		rm -f /tmp/continuous.pid
	    fi
	fi
	
	lock

	curDate=$(date +%s.%N)
	[ "$mode" = "diff" ] && echo $curDate
	iptables -nvxL -t mangle -Z | awk -v mode="$mode" wan="$wan" -f $baseDir/readDB.awk $DB /proc/net/arp -
	
	unlock

	[ "$mode" != "noUpdate" ] && echo $curDate > /tmp/wrtbwmon.lastUpdate

        #Free some memory
	rm -f /tmp/*_$$.tmp
	exit
	;;
    
    "publish" )

	[ -z "$DB" ] && echo "ERROR: Missing database argument" && exit 1
	[ -z "$3" ] && echo "ERROR: Missing argument 3" && exit 1
	
	# first do some number crunching - rewrite the database so that it is sorted

	# publishing doesn't need a lock, it needs a stable copy of
	# the db. If continuous is running, send a signal to make a
	# copy.
	read pid 2>/dev/null < /tmp/continuous.pid
	if [ $? -eq 0 -a -n "$pid" -a -d "/proc/$pid" ]; then
	    echo "got $pid for continuous"
	    DB=$DB.tmp
	    kill -SIGUSR2 $pid
	    read < /tmp/wrtbwmon.pipe
	else
	    pid=''
	    lock
	fi

	# busybox sort truncates numbers to 32 bits
	grep -v '^#' $DB | awk -F, '{OFS=","; a=sprintf("%f",$4/1e6); $4=""; print a,$0}' | tr -s ',' | sort -rn | awk -F, '{OFS=",";$1=sprintf("%f",$1*1e6);print}' > /tmp/sorted_$$.tmp

	if [ -n "$pid" ]; then
	    rm -f $DB
	else
	    unlock
	fi

        # create HTML page
	cp $baseDir/usage.htm1 $3
	while IFS=, read PEAKUSAGE_IN MAC IP IFACE PEAKUSAGE_OUT OFFPEAKUSAGE_IN OFFPEAKUSAGE_OUT TOTAL FIRSTSEEN LASTSEEN
	do
	    echo "
new Array(\"$(lookup $MAC $IP $4)\",
$PEAKUSAGE_IN,$PEAKUSAGE_OUT,$OFFPEAKUSAGE_IN,$OFFPEAKUSAGE_OUT,$TOTAL,\"$FIRSTSEEN\",\"$LASTSEEN\")," >> ${3}
	done < /tmp/sorted_$$.tmp
	echo "0);" >> ${3}
	
	sed "s/(date)/`date`/" < $baseDir/usage.htm2 >> $3
	
	#Free some memory
	rm -f /tmp/*_$$.tmp
	;;
    
    "setup" )
	for chain in $chains; do
	    newChain $chain
	done

	#For each host in the ARP table
        grep -vi '^IP\|0x0' /proc/net/arp > /tmp/arp_$$.tmp
	while read IP TYPE FLAGS MAC MASK IFACE
	do
	    newRule FORWARD $IP
	done < /tmp/arp_$$.tmp
	
	#lan=$(detectLAN)
	wan=$(detectWAN)
	if [ -z "$wan" ]; then
	    echo "Warning: failed to detect WAN interface."
	    #else wanIP=`ifconfig $wan | grep -o 'inet addr:[0-9.]\+' | cut -d':' -f2`
	fi
	
	# track local data
	for chain in INPUT OUTPUT; do
	    [ -n "$wan" ] && newRuleIF $chain $wan
	    #!@todo automate this;
	    # can detect gateway IPs: route -n | grep '^[0-9]' | awk '{print $2}' | sort | uniq | grep -v 0.0.0.0
	    [ -n "$tun" ] && newRuleIF $chain $tun
	done
	
	;;

    "remove" )
	iptables-save | grep -v RRDIPT | iptables-restore
	;;
    
    *)
	echo "Usage: $0 {setup|update|publish|remove} [options...]"
	echo "Options: "
	echo "   $0 setup"
	echo "   $0 update database_file [offpeak]"
	echo "   $0 publish database_file path_of_html_report [user_file]"
	echo "Examples: "
	echo "   $0 setup"
	echo "   $0 update /tmp/usage.db offpeak"
	echo "   $0 publish /tmp/usage.db /www/user/usage.htm /jffs/users.txt"
	echo "   $0 remove"
	echo "Note: [user_file] is an optional file to match users with their MAC address"
	echo "       Its format is: 00:MA:CA:DD:RE:SS,username , with one entry per line"
	;;
esac
