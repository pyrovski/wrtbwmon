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
    oldTrap=$(trap | grep SIGINT | sed 's/.* -- //')
    trap "go=0" SIGINT
}

unlock()
{
    rm -f /tmp/wrtbwmon.lock
    #[[ -n "$DEBUG" ]] && echo $$ "released lock"
    trap "$oldTrap"
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
