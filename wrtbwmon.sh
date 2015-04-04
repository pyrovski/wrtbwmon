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
#!@todo store time series data
#!@todo reference awk scripts and html templates in predictable location

trap "rm -f /tmp/*$$.tmp; kill -SIGINT $$" SIGINT
baseDir=/mnt/cifs2

chains='INPUT OUTPUT FORWARD'
DEBUG=
tun=
DB=$2

header="#mac,ip,iface,peak_in,peak_out,offpeak_in,offpeak_out,total,first_date,last_date"

lookup()
{
    MAC=$1
    IP=$2
    userDB=$3
    for USERSFILE in $userDB /tmp/dhcp.leases /tmp/dnsmasq.conf /etc/dnsmasq.conf /etc/hosts; do
	[ ! -e "$USERSFILE" ] && continue
	case $USERSFILE in
	    /tmp/dhcp.leases )
		USER=$(grep "$MAC" $USERSFILE | cut -f4 -s -d' ')
		;;
	    /etc/hosts )
		USER=$(grep "^$IP " $USERSFILE | cut -f2 -s -d' ')
		;;
	    * )
		USER=$(grep "$MAC" "$USERSFILE" | cut -f2 -s -d,)
		;;
	esac
	[ -n "$USER" ] && break
    done
    #!@todo get hostname with: nslookup $IP | grep "$IP " | cut -d' ' -f4
    [ -z "$USER" ] && USER=${MAC}
    echo $USER
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

detectLAN()
{
    [ -e /sys/class/net/br-lan ] && echo br-lan && return
    lan=$(detectIF lan)
    [ -n "$lan" ] && echo $lan && return
}

detectWAN()
{
    [ -n "$WAN_IF" ] && echo $WAN_IF && return
    wan=$(detectIF wan)
    [ -n "$wan" ] && echo $wan && return
}

dateFormat()
{
    date "+%d-%m-%Y_%H:%M:%S"
}

lock()
{
    attempts=0
    while [ $attempts -lt 10 ]; do
	while [ -f /tmp/wrtbwmon.lock ]; do
	    if [ ! -d /proc/$(< /tmp/wrtbwmon.lock) ]; then
		echo "WARNING: Lockfile detected but process $(cat /tmp/wrtbwmon.lock) does not exist !"
		rm -f /tmp/wrtbwmon.lock
	    else
		sleep 1
	    fi
	done
	echo $$ > /tmp/wrtbwmon.lock
	read lockPID < /tmp/wrtbwmon.lock
	[[ $$ -eq "$lockPID" ]] && break;
	attempts=$((attempts+1))
    done
    #[[ -n "$DEBUG" ]] && echo $$ "got lock after $attempts attempts"
    trap "" SIGINT
}

unlock()
{
    rm -f /tmp/wrtbwmon.lock
    #[[ -n "$DEBUG" ]] && echo $$ "released lock"
    trap "rm -f /tmp/*$$.tmp; kill -SIGINT $$" SIGINT
}

# chain
newChain()
{
    chain=$1

    #Create the RRDIPT_$chain chain (it doesn't matter if it already exists).
    iptables -t mangle -N RRDIPT_$chain 2> /dev/null
    
    #Add the RRDIPT_$chain CHAIN to the $chain chain (if non existing).
    iptables -t mangle -L $chain --line-numbers -n | grep "RRDIPT_$chain" > /dev/null
    if [ $? -ne 0 ]; then
	iptables -t mangle -L $chain -n | grep "RRDIPT_$chain" > /dev/null
	if [ $? -eq 0 ]; then
	    [ -n "$DEBUG" ] && echo "DEBUG: iptables chain misplaced, recreating it..."
	    iptables -t mangle -D $chain -j RRDIPT_$chain
	fi
	iptables -t mangle -I $chain -j RRDIPT_$chain
    fi
}

# chain tun
newRuleIF()
{
    chain=$1
    IF=$2
    
    iptables -t mangle -nvL RRDIPT_$chain | grep " $IF " > /dev/null
    if [ "$?" -ne 0 ]; then
	if [ "$chain" = "OUTPUT" ]; then
	    iptables -t mangle -A RRDIPT_$chain -o $IF -j RETURN
	elif [ "$chain" = "INPUT" ]; then
	    iptables -t mangle -A RRDIPT_$chain -i $IF -j RETURN
	fi
    elif [ -n "$DEBUG" ]; then
	echo "DEBUG: table mangle chain $chain rule $IF already exists?"
    fi
}

# chain IP
newRule()
{
    chain=$1
    IP=$2
    
    #Add iptable rules (if non existing).
    iptables -t mangle -nL RRDIPT_$chain | grep "$IP " > /dev/null
    if [ $? -ne 0 ]; then
        if [ "$chain" = "OUTPUT" -o "$chain" = "FORWARD" ]; then
            iptables -t mangle -I RRDIPT_$chain -d $IP -j RETURN
        fi
        if [ "$chain" = "INPUT" -o "$chain" = "FORWARD" ]; then
            iptables -t mangle -I RRDIPT_$chain -s $IP -j RETURN
        fi
    fi
}

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

	lock

	iptables -nvxL -t mangle -Z | awk -v wan="$wan" -f $baseDir/readDB.awk $DB /proc/net/arp -

	unlock

        #Free some memory
	rm -f /tmp/*_$$.tmp
	exit
	;;
    
    "publish" )

	[ -z "$DB" ] && echo "ERROR: Missing database argument" && exit 1
	[ -z "$3" ] && echo "ERROR: Missing argument 3" && exit 1
	
	# first do some number crunching - rewrite the database so that it is sorted
	lock
	grep -v '^#' $DB | awk -F, '{OFS=","; a=$4; $4=""; print a OFS $0}' | tr -s ',' | sort -rn > /tmp/sorted_$$.tmp
	unlock

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
