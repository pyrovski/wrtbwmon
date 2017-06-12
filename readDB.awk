#!/usr/bin/awk

function dmsg(msg){
    if(debug)
	print msg > "/dev/stderr"
}

function dsys(cmd){
    dmsg(cmd)
    system(cmd)
}

function getMAC(iface, m){
    getline m<("/sys/class/net/"iface"/address")
    return m
}

function getIP(iface, cmd, i, a){
    cmd="/sbin/ifconfig "iface" 2>/dev/null"
    while((cmd|getline i) > 0)
	if(i ~ /^ +inet addr:.+$/){
	    split(i, a, / +/)
	    i="NA"
	    if(a[3] ~ /addr:.+/)
		i=a[3]
	    gsub(/.+:/, "", i)
	    break
	}
    close(cmd)
    return i
}

function inInterfaces(host){
    return(interfaces ~ "(^| )"host"($| )")
}

function newRule(arp_ip){
    # checking for existing rules shouldn't be necessary if newRule is
    # always called after db is read, arp table is read, and existing
    # iptables rules are read.
    dsys(ipt_cmd"-s "arp_ip" -C "f_chain" 2>/dev/null || " ipt_cmd"-s "arp_ip" -A "f_chain)
    dsys(ipt_cmd"-d "arp_ip" -C "f_chain" 2>/dev/null || " ipt_cmd"-d "arp_ip" -A "f_chain)
}

function delRule(target){
    if(inInterfaces(target)) {
	dsys(ipt_cmd"-i "target" -D "i_chain" 2>/dev/null")
	dsys(ipt_cmd"-o "target" -D "o_chain" 2>/dev/null")
    } else {
	dsys(ipt_cmd"-s "target" -D "f_chain" 2>/dev/null")
	dsys(ipt_cmd"-d "target" -D "f_chain" 2>/dev/null")
    }
}

function total(i){
    return(bw[i "/in"] + bw[i "/out"])
}

function date(    cmd, d){
    cmd="date +%d-%m-%Y_%H:%M:%S"
    cmd | getline d
    close(cmd)
    return(d)
}

BEGIN {
    i_chain="RRDIPT_INPUT"
    o_chain="RRDIPT_OUTPUT"
    f_chain="RRDIPT_FORWARD"
    ipt_cmd="iptables -t mangle -j RETURN "
    od=""
    fid=1
    debug=0
    rrd=0
}

/^#/ { # get DB filename
    FS=","
    dbFile=FILENAME
    next
}

# data from database; first file
FNR==NR { #!@todo this doesn't help if the DB file is empty.
    #!@todo could get interface IP here
    m=$1

    if($2 == "NA" && inInterfaces(m)) {
	i=$1
	#!@todo interfaces have MACs; we should track them. Store a map from
	# interface name to MAC, then just put the MAC in the MAC column?
	dmsg("interface " i " MAC: " getMAC(i) ", IP: " getIP(i))
    } else
	i=$2
    # arrays are indexed by MAC/interface, with the exception of 'mac' and 'hosts'
    hosts[i]      = ""
    mac[i]        = m
    ip[m]	  = $2
    inter[m]      = $3
    bw[m "/in"]   +=$4 # accumulate for multiple IPs/MAC
    bw[m "/out"]  +=$5
    firstDate[m]  = $7
    lastDate[m]   = $8
    next
}

# not triggered on the first file
FNR==1 {
    FS=" "
    fid++ #!@todo use fid for all files; may be problematic for empty files
    next
}

# arp: ip hw flags hw_addr mask device
fid==2 {
    #!@todo regex match IPs and MACs for sanity
    arp_ip    = $1
    arp_flags = $3
    arp_mac   = $4
    arp_dev   = $6
    if(arp_flags != "0x0"){
	if(!(arp_mac in ip)){
	    dmsg("new MAC: " arp_mac)
	    hosts[arp_ip]      = ""
	    mac[arp_ip]        = arp_mac
	    ip[arp_mac]        = arp_ip
	    firstDate[arp_mac] = lastDate[arp_mac] = date()
	    bw[arp_mac "/in"]  = bw[arp_mac "/out"] = 0
	} else if(!(arp_ip in mac)){
	    #!@todo we only store one IP per MAC, so the table will thrash 
	    dmsg("new IP: " arp_ip)
	    hosts[arp_ip] = ""
	    mac[arp_ip]   = arp_mac
	    ip[arp_mac]   = arp_ip
	}
	inter[arp_mac]     = arp_dev
    }
    next
}

#!@todo could use mangle chain totals or tailing "unnact" rules to
# account for data for new hosts from their first presence on the
# network to rule creation. The "unnact" rules would have to be
# maintained at the end of the list, and new rules would be inserted
# at the top.

# skip line
# read the chain name and deal with the data accordingly
fid==3 && $1 == "Chain"{
    rrd=$2 ~ /RRDIPT_.*/
    next
}

fid==3 && rrd && (NF < 9 || $1=="pkts"){ next }

fid==3 && rrd { # iptables input
    if($6 != "*"){ # interface out
	m=$6
	i=m
	n=m "/out"
    } else if($7 != "*"){ # interface in
	m=$7
	i=m
	n=m "/in"
    } else if($8 != "0.0.0.0/0"){ # IP out
	i=$8
	m=mac[i]
	n=m "/out"
    } else if($9 != "0.0.0.0/0"){ # IP in
	i=$9
	m=mac[i]
	n=m "/in"
    } else {	
	print "unexpected rule: " $0 > "/dev/stderr"
	next
    }
    if(n == "/in" || n == "/out") {
	dmsg("failed to find MAC/IF for iptables entry: " $0)
	remove[i] = ""
	next
    }

    # remove host from array; any hosts left in array at END get new
    # iptables rules
    #!@todo this deletes a host if any rule exists; if only one
    # directional rule is removed, this will not remedy the situation
    delete hosts[i]

    if($2 > 0){ # counted some bytes
	if(mode == "diff" || mode == "noUpdate")
	    print n, $2
	if(mode!="noUpdate"){
	    if(inInterfaces(m)){ # if label is an interface
		if(!(m in mac)){ # if label was not in db
		    firstDate[m] = date()
		    mac[m] = inter[m] = m
		    ip[m] = "NA"
		    bw[m "/in"]=bw[m "/out"]= 0
		}
	    }
	    bw[n]+=$2
	    lastDate[m] = date()
	}
    }
}

END {
    if(mode=="noUpdate") exit
    close(dbFile)
    dsys("rm -f " dbFile)
    print "#mac,last_ip,iface,in,out,total,first_date,last_date" > dbFile
    OFS=","
    for(m in ip)
	print m, ip[m], inter[m], bw[m "/in"], bw[m "/out"], total(m), firstDate[m], lastDate[m] > dbFile
    close(dbFile)
    # for hosts without rules
    for(host in hosts) if(!inInterfaces(host)) newRule(host)
    # remove broken rules
    #!@todo remove rules for stale IPs
    for(host in remove)
	delRule(host)
}
