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

trap "unlock; exit 1" SIGINT

chains='INPUT OUTPUT FORWARD'
DEBUG=1
tun=tun0
DB=$2

header="#mac,ip,iface,peak_in,peak_out,offpeak_in,offpeak_out,total,first_date,last_date"

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
    wan=$(detectIF wan)
    [ -n "$wan" ] && echo $wan && return
    [ -n "$WAN_IF" ] && echo $WAN_IF && return
}

dateFormat()
{
    date "+%d-%m-%Y_%H:%M:%S"
}

lock()
{
    while [ -f /tmp/wrtbwmon.lock ]; do
	if [ ! -d /proc/$(cat /tmp/wrtbwmon.lock) ]; then
	    echo "WARNING: Lockfile detected but process $(cat /tmp/wrtbwmon.lock) does not exist !"
	    rm -f /tmp/wrtbwmon.lock
	fi
	sleep 1
    done
    echo $$ > /tmp/wrtbwmon.lock
}

unlock()
{
    rm -f /tmp/wrtbwmon.lock
}

# chain
newChain()
{
    chain=$1
    table=$(getTable $chain)

    #Create the RRDIPT_$chain chain (it doesn't matter if it already exists).
    iptables -t $table -N RRDIPT_$chain 2> /dev/null
    
    #Add the RRDIPT_$chain CHAIN to the $chain chain (if non existing).
    iptables -t $table -L $chain --line-numbers -n | grep "RRDIPT_$chain" > /dev/null
    if [ $? -ne 0 ]; then
	iptables -t $table -L $chain -n | grep "RRDIPT_$chain" > /dev/null
	if [ $? -eq 0 ]; then
	    [ -n "$DEBUG" ] && echo "DEBUG: iptables chain misplaced, recreating it..."
	    iptables -t $table -D $chain -j RRDIPT_$chain
	fi
	iptables -t $table -I $chain -j RRDIPT_$chain
    fi
}

# chain
getTable()
{
    #grep "^$1 " /tmp/tables | cut -d' ' -f2
    echo mangle
}

# chain tun
newRuleIF()
{
    chain=$1
    IF=$2
    table=$(getTable $chain)
    
    iptables -t $table -nvL RRDIPT_$chain | grep " $IF " > /dev/null
    if [ "$?" -ne 0 ]; then
	if [ "$chain" = "OUTPUT" ]; then
	    iptables -t $table -A RRDIPT_$chain -o $IF -j RETURN
	elif [ "$chain" = "INPUT" ]; then
	    iptables -t $table -A RRDIPT_$chain -i $IF -j RETURN
	fi
    elif [ -n "$DEBUG" ]; then
	echo "DEBUG: table $table chain $chain rule $IF already exists?"
    fi
}

# chain IP
newRule()
{
    chain=$1
    IP=$2
    table=$(getTable $chain)

    #Add iptable rules (if non existing).
    iptables -t $table -nL RRDIPT_$chain | grep "$IP " > /dev/null
    if [ $? -ne 0 ]; then
	if [ "$chain" = "OUTPUT" -o "$chain" = "FORWARD" ]; then
	    iptables -t $table -I RRDIPT_$chain -d $IP -j RETURN
	fi
	if [ "$chain" = "INPUT" -o "$chain" = "FORWARD" ]; then
	    iptables -t $table -I RRDIPT_$chain -s $IP -j RETURN
	fi
    fi
}

# interface
readIF()
{
    IF=$1
    for chain in INPUT OUTPUT; do
	grep " $IF " /tmp/traffic_${chain}_$$.tmp > \
	     /tmp/${IF}_${chain}_$$.tmp
	read PKTS BYTES TARGET PROT OPT IFIN IFOUT SRC DST < \
	     /tmp/${IF}_${chain}_$$.tmp
	[ "$chain" = "OUTPUT" ] && [ "$IFOUT" = "$IF" ] && \
	    OUT=$((OUT + BYTES))
	[ "$chain" = "INPUT" ] && [ "$IFIN" = "$IF" ] && \
	    IN=$((IN + BYTES))
	rm -f /tmp/${IF}_${chain}_$$.tmp
    done
    echo "$IN $OUT"
}

# MAC IP IFACE IN OUT DB
updatedb()
{
    MAC=$1
    IP=$2
    IFACE=$3
    IN=$4
    OUT=$5
    DB=$6
    
    [ -n "$DEBUG" ] && echo "DEBUG: New traffic for $MAC/$IP since last update: $IN:$OUT"
    
    LINE=$(grep ${MAC} $DB)
    if [ -z "$LINE" ]; then
	[ -n "$DEBUG" ] && echo "DEBUG: $MAC/$IP is a new host !"

	# add rules for new host
	if [ -n "$tun" -a "$IP" = "NA" ]; then
	    for chain in INPUT OUTPUT; do
		newRuleIF $chain $tun
	    done
	fi
	newRule FORWARD $IP
	
	PEAKUSAGE_IN=0
	PEAKUSAGE_OUT=0
	OFFPEAKUSAGE_IN=0
	OFFPEAKUSAGE_OUT=0

	firstDate=$(dateFormat)
	
	#!@todo get hostname with: nslookup $IP | grep "$IP " | cut -d' ' -f4
    else
	echo $LINE | cut -s -d, -f4-9 > "/tmp/${MAC}_$$.tmp"
	IFS=, read PEAKUSAGE_IN PEAKUSAGE_OUT OFFPEAKUSAGE_IN OFFPEAKUSAGE_OUT TOTAL firstDate < "/tmp/${MAC}_$$.tmp"
    fi
    
    if [ "${3}" = "offpeak" ]; then
	echo $LINE | cut -f6,7 -s -d, > "/tmp/${MAC}_$$.tmp"
	IFS=, read OFFPEAKUSAGE_IN OFFPEAKUSAGE_OUT < "/tmp/${MAC}_$$.tmp"
	OFFPEAKUSAGE_IN=$((OFFPEAKUSAGE_IN + IN))
	OFFPEAKUSAGE_OUT=$((OFFPEAKUSAGE_OUT + OUT))
    else
	echo $LINE | cut -f4,5 -s -d, > "/tmp/${MAC}_$$.tmp"
	IFS=, read PEAKUSAGE_IN PEAKUSAGE_OUT < "/tmp/${MAC}_$$.tmp"
	PEAKUSAGE_IN=$((PEAKUSAGE_IN + IN))
	PEAKUSAGE_OUT=$((PEAKUSAGE_OUT + OUT))
    fi
    TOTAL=$((OFFPEAKUSAGE_OUT + OFFPEAKUSAGE_IN + PEAKUSAGE_OUT + PEAKUSAGE_IN))

    rm -f "/tmp/${MAC}_$$.tmp"
    
    #!@todo combine updates
    grep -v "^$MAC" $DB > /tmp/db_$$.tmp

    trap "" SIGINT
    mv /tmp/db_$$.tmp $DB

    echo $MAC,$IP,$IFACE,$PEAKUSAGE_IN,$PEAKUSAGE_OUT,$OFFPEAKUSAGE_IN,$OFFPEAKUSAGE_OUT,$TOTAL,$firstDate,$(dateFormat) >> $DB
    trap "unlock; exit 1" SIGINT
}

############################################################

case $1 in
    "setup" )
	for chain in $chains; do
	    newChain $chain
	done

	chain=FORWARD

	#For each host in the ARP table
        grep -vi 0x0 /proc/net/arp | tail -n +2 | \
	    while read IP TYPE FLAGS MAC MASK IFACE
	    do
		newRule $chain $IP
	    done	

	lan=$(detectLAN)
	wan=$(detectWAN)
	if [ -n "$wan" ]; then
	    wanIP=`ifconfig $wan | grep -o 'inet addr:[0-9.]\+' | cut -d':' -f2`
	else
	    echo "Warning: failed to detect WAN interface."
	fi
	
	# track local data
	for chain in INPUT OUTPUT; do
	    [ -n "$wan" ] && newRuleIF $chain $wan
	    #!@todo automate this;
	    # can detect gateway IPs: route -n | grep '^[0-9]' | awk '{print $2}' | sort | uniq | grep -v 0.0.0.0
	    [ -n "$tun" ] && newRuleIF $chain $tun
	done
	
	;;
    
    "update" )
	[ -z "$DB" ] && echo "ERROR: Missing argument 2" && exit 1	
	[ ! -f "$DB" ] && echo $header > "$DB"
	[ ! -w "$DB" ] && echo "ERROR: $DB not writable" && exit 1

	lock

	#Read and reset counters
	for chain in $chains; do
	    table=$(getTable $chain)
	    iptables -t $table -L RRDIPT_$chain -vnxZ > /tmp/traffic_${chain}_$$.tmp
	done

	# read tun data
	if [ -n "$tun" ]; then
	    IN_OUT=`readIF $tun`
	    IN=`echo $IN_OUT | cut -d' ' -f1`
	    OUT=`echo $IN_OUT | cut -d' ' -f2`
	    [ "$IN" -gt 0 -o "$OUT" -gt 0 ] && \
		updatedb "($tun)" NA $tun $IN $OUT $DB
	fi

	wan=$(detectWAN)
	if [ -n "$wan" ]; then
	    # read WAN data
	    IN_OUT=$(readIF $wan)
	    IN=`echo $IN_OUT | cut -d' ' -f1`
	    OUT=`echo $IN_OUT | cut -d' ' -f2`
	    
	    [ "${IN}" -gt 0 -o "${OUT}" -gt 0 ] && \
		updatedb "(WAN)" NA $wan $IN $OUT $DB
	fi
	
        grep -vi 0x0 /proc/net/arp | tail -n +2 | \
	    while read IP TYPE FLAGS MAC MASK IFACE
	    do
		IN=0
		OUT=0
		#Add new data to the graph.
		chain=FORWARD
		grep $IP /tmp/traffic_${chain}_$$.tmp > /tmp/${IP}_${chain}_$$.tmp
		while read PKTS BYTES TARGET PROT OPT IFIN IFOUT SRC DST
		do
		    #!@todo OUT and IN used here refer to the IP's perspective, not ours
		    [ "$DST" = "$IP" ] && IN=$((IN + BYTES))
		    [ "$SRC" = "$IP" ] && OUT=$((OUT + BYTES))
		done < /tmp/${IP}_${chain}_$$.tmp
		rm -f /tmp/${IP}_${chain}_$$.tmp
		
		if [ "${IN}" -gt 0 -o "${OUT}" -gt 0 ]; then
		    updatedb $MAC $IP $IFACE $IN $OUT $DB
		fi
	    done

	#Free some memory
	rm -f /tmp/*_$$.tmp
	unlock
	;;
    
    "publish" )

	[ -z "$DB" ] && echo "ERROR: Missing database argument" && exit 1
	[ -z "$3" ] && echo "ERROR: Missing argument 3" && exit 1
	
	USERSFILE=/tmp/dhcp.leases
	#/etc/dnsmasq.conf
	[ -f "$USERSFILE" ] || USERSFILE=/tmp/dnsmasq.conf
	[ -z "$4" ] || USERSFILE=$4
	[ -f "$USERSFILE" ] || USERSFILE=/dev/null

	# first do some number crunching - rewrite the database so that it is sorted
	lock
	grep -v '^#' $DB | awk -F, '{OFS=","; a=$4; $4=""; print a OFS $0}' | tr -s ',' | sort -rn > /tmp/sorted_$$.tmp
	unlock

        # create HTML page
	awk '/^#cut here 1/{flag=1;next}/^#cut here 2/{flag=0}flag'< $0 > ${3}
	while IFS=, read PEAKUSAGE_IN MAC IP IFACE PEAKUSAGE_OUT OFFPEAKUSAGE_IN OFFPEAKUSAGE_OUT TOTAL FIRSTSEEN LASTSEEN
	do
	    echo "new Array(" >> ${3}
	    case $USERSFILE in
		"/tmp/dhcp.leases" )
		    USER=$(grep "$MAC" "$USERSFILE" | cut -f4 -s -d' ' )
		    ;;
		* )
		    USER=$(grep "$MAC" "$USERSFILE" | cut -f2 -s -d, )
		    ;;
	    esac
	    [ -z "$USER" ] && USER=${MAC}
	    echo "\"$USER\",$PEAKUSAGE_IN,$PEAKUSAGE_OUT,$OFFPEAKUSAGE_IN,$OFFPEAKUSAGE_OUT,$TOTAL,\"$FIRSTSEEN\",\"$LASTSEEN\")," >> ${3}
	done < /tmp/sorted_$$.tmp
	echo "0);" >> ${3}
	
	awk 'f;/^#cut here 2/{f=1}' < $0 | sed "s/(date)/`date`/" >> $3
	
	#Free some memory
	rm -f /tmp/*_$$.tmp
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

exit

#cut here 1#
<html><head><title>Traffic</title>
<script type="text/javascript">
function getSize(size) {
    var prefix=new Array("","k","M","G","T","P","E","Z"); var base=1000;
    var pos=0;
    while (size>base) {
        size/=base; pos++;
    }
    if (pos > 2) precision=1000; else precision = 1;
    return (Math.round(size*precision)/precision)+' '+prefix[pos];}
</script></head>
<body><h1>Total Usage:</h1>
<table border="1">
<tr bgcolor=silver>
<th>User</th>
<th>Peak download</th>
<th>Peak upload</th>
<th>Offpeak download</th>
<th>Offpeak upload</th>
<th>Total</th>
<th>First seen</th>
<th>Last seen</th>
</tr>
<script type="text/javascript">
var values = new Array(

#cut here 2#    
for (i=0; i < values.length-1; i++) {
    document.write("<tr><td>");
    document.write(values[i][0]);
    document.write("</td>");
    for (j=1; j < 6; j++) {
        document.write("<td>");
        document.write(getSize(values[i][j]));
        document.write("</td>");
    }
    document.write("<td>");
    document.write(values[i][6]);
    document.write("</td>");
    document.write("<td>");
    document.write(values[i][7]);
    document.write("</td>");
    document.write("</tr>");
}
</script></table>
<br /><small>This page was generated on (date)</small>
</body></html>

