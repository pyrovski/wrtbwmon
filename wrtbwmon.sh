#!/bin/sh
#
# wrtbwmon: traffic logging tool for routers
#
# Peter Bailey (peter.eldridge.bailey+wrtbwmon AT gmail.com)
#
# Based on work by:
# Emmanuel Brucy (e.brucy AT qut.edu.au)
# Fredrik Erlandsson (erlis AT linux.nu)
# twist - http://wiki.openwrt.org/RrdTrafficWatch

#!@todo add logger
#!@todo cache DNS results
#!@todo use a config file

trap "rm -f /tmp/*_$$.tmp; kill $$" INT
binDir=/usr/sbin
dataDir=/usr/share/wrtbwmon
lockDir=/tmp/wrtbwmon.lock
pidFile=$lockDir/pid

chains='INPUT OUTPUT FORWARD'
DEBUG=
interfaces='eth0 tun0' # in addition to detected WAN
DB=$2
mode=

# don't perform reverse DNS lookups by default
DO_RDNS=
# DNS server for reverse lookups
DNS=

header="#mac,ip,iface,in,out,total,first_date,last_date"

createDbIfMissing()
{
    [ ! -f "$DB" ] && echo $header > "$DB"
}

checkDbArg()
{
    [ -z "$DB" ] && echo "ERROR: Missing argument 2 (database file)" && exit 1
}

checkDB()
{
    [ ! -f "$DB" ] && echo "ERROR: $DB does not exist" && exit 1
    [ ! -w "$DB" ] && echo "ERROR: $DB is not writable" && exit 1   
}

checkWAN()
{
    [ -z "$wan" ] && echo "Warning: failed to detect WAN interface."
}

lookup()
{
    MAC=$1
    IP=$2
    userDB=$3
    for USERSFILE in $userDB /tmp/dhcp.leases /tmp/dnsmasq.conf /etc/dnsmasq.conf /etc/hosts; do
	[ -e "$USERSFILE" ] || continue
	case $USERSFILE in
	    /tmp/dhcp.leases )
		USER=$(grep -i "$MAC" $USERSFILE | cut -f4 -s -d' ')
		;;
	    /etc/hosts )
		USER=$(grep "^$IP " $USERSFILE | cut -f2 -s -d' ')
		;;
	    * )
		USER=$(grep -i "$MAC" "$USERSFILE" | cut -f2 -s -d,)
		;;
	esac
	[ "$USER" = "*" ] && USER=
	[ -n "$USER" ] && break
    done
    nslookup=`which nslookup`
    if [ -n "$DO_RDNS" -a -z "$USER" -a "$IP" != "NA" -a -n "$nslookup" ]; then
	USER=`$nslookup $IP $DNS | awk '!/server can/{if($4){print $4; exit}}' | sed -re 's/[.]$//'`
    fi
    [ -z "$USER" ] && USER=${MAC}
    echo $USER
}

detectIF()
{
    uci=`which uci 2>/dev/null`
    if [ -n "$uci" -a -x "$uci" ]; then
	IF=`$uci get network.${1}.ifname 2>/dev/null`
	[ $? -eq 0 ] && echo $IF && return
    fi

    nvram=`which nvram 2>/dev/null`
    if [ -n "$nvram" -a -x "$nvram" ]; then
	IF=`$nvram get ${1}_ifname 2>/dev/null`
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
    wan=$(ip route show 2>/dev/null | grep default | sed -re '/^default/ s/default.*dev +([^ ]+).*/\1/')
    [ -n "$wan" ] && echo $wan && return
}

lock()
{
    attempts=0
    while [ $attempts -lt 10 ]; do
	mkdir $lockDir 2>/dev/null && break
	attempts=$((attempts+1))
	pid=`cat $pidFile 2>/dev/null`
	if [ -n "$pid" ]; then
	    if [ -d "/proc/$pid" ]; then
		[ -n "$DEBUG" ] && echo "WARNING: Lockfile detected but process $(cat $pidFile) does not exist !"
		rm -rf $lockDir
	    else
		sleep 1
	    fi
	fi
    done
    mkdir $lockDir 2>/dev/null
    echo $$ > $pidFile
    [ -n "$DEBUG" ] && echo $$ "got lock after $attempts attempts"
    trap '' INT
}

unlock()
{
    rm -rf $lockDir
    [ -n "$DEBUG" ] && echo $$ "released lock"
    trap "rm -f /tmp/*_$$.tmp; kill $$" INT
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

update()
{
    #!@todo could let readDB.awk handle this; that would place header
    #!info in fewer places
    createDbIfMissing
    
    checkDB
    checkWAN

    lock
    #!@todo only zero our own chains
    iptables -nvxL -t mangle -Z > /tmp/iptables_$$.tmp
    # echo awk -v mode="$mode" -v interfaces=\""$interfaces"\" -f $binDir/readDB.awk \
    # 	$DB \
    # 	/proc/net/arp \
    # 	/tmp/iptables_$$.tmp

    # exit 1
    awk -v mode="$mode" -v interfaces=\""$interfaces"\" -f $binDir/readDB.awk \
	$DB \
	/proc/net/arp \
	/tmp/iptables_$$.tmp
    unlock
}

############################################################

case $1 in
    "dump" )
	checkDbArg
	lock
	tr ',' '\t' < "$DB"
	unlock
    ;;

    "update" )
	checkDbArg
	wan=$(detectWAN)
	interfaces="$interfaces $wan"
	update
	rm -f /tmp/*_$$.tmp
	exit
	;;

    "publish" )
	checkDbArg
	[ -z "$3" ] && echo "ERROR: Missing argument 3" && exit 1
	
	# sort DB
	lock

	# busybox sort truncates numbers to 32 bits
	grep -v '^#' $DB | awk -F, '{OFS=","; a=sprintf("%f",$4/1e6); $4=""; print a,$0}' | tr -s ',' | sort -rn | awk -F, '{OFS=",";$1=sprintf("%f",$1*1e6);print}' > /tmp/sorted_$$.tmp

        # create HTML page
	rm -f $3.tmp
	cp $dataDir/usage.htm1 $3.tmp
	
	while IFS=, read PEAKUSAGE_IN MAC IP IFACE PEAKUSAGE_OUT TOTAL FIRSTSEEN LASTSEEN
	do
	    echo "
new Array(\"$(lookup $MAC $IP $4)\",
$PEAKUSAGE_IN,$PEAKUSAGE_OUT,$TOTAL,\"$FIRSTSEEN\",\"$LASTSEEN\")," >> $3.tmp
	done < /tmp/sorted_$$.tmp
	echo "0);" >> $3.tmp
	
	sed "s/(date)/`date`/" < $dataDir/usage.htm2 >> $3.tmp
	mv $3.tmp $3

	unlock
	
	#Free some memory
	rm -f /tmp/*_$$.tmp
	;;
    
    "setup" )
	checkDbArg
	if [ -w "$DB" ]; then
	    echo "Warning: using existing $DB"
	else
	    createDbIfMissing
	fi
	
	for chain in $chains; do
	    newChain $chain
	done

	#lan=$(detectLAN)
	wan=$(detectWAN)
	checkWAN
	interfaces="$interfaces $wan"

	# track local data
	for chain in INPUT OUTPUT; do
	    for interface in $interfaces; do
		[ -n "$interface" ] && [ -e "/sys/class/net/$interface" ] && newRuleIF $chain $interface
	    done
	done

	# this will add rules for hosts in arp table
	update

	rm -f /tmp/*_$$.tmp
	;;

    "remove" )
	iptables-save | grep -v RRDIPT | iptables-restore
	;;

    *)
	echo \
"Usage: $0 {setup|update|publish|remove} [options...]
Options:
   $0 setup database_file
   $0 update database_file
   $0 publish database_file path_of_html_report [user_file]
Examples:
   $0 setup /tmp/usage.db
   $0 update /tmp/usage.db
   $0 publish /tmp/usage.db /www/user/usage.htm /jffs/users.txt
   $0 remove
Note: [user_file] is an optional file to match users with MAC addresses.
       Its format is \"00:MA:CA:DD:RE:SS,username\", with one entry per line."
	;;
esac
