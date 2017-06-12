#!/usr/bin/awk

function inInterfaces(host){
    return(interfaces ~ "(^| )"host"($| )")
}

function newRule(arp_ip,
    ipt_cmd){
    # checking for existing rules shouldn't be necessary if newRule is
    # always called after db is read, arp table is read, and existing
    # iptables rules are read.
    ipt_cmd="iptables -t mangle -j RETURN -s " arp_ip
    system(ipt_cmd " -C RRDIPT_FORWARD 2>/dev/null || " ipt_cmd " -A RRDIPT_FORWARD")
    ipt_cmd="iptables -t mangle -j RETURN -d " arp_ip
    system(ipt_cmd " -C RRDIPT_FORWARD 2>/dev/null || " ipt_cmd " -A RRDIPT_FORWARD")
}

function total(i){
    return(bw[i "/in"] + bw[i "/out"])
}

function date(    cmd, d){
    cmd="date +%d-%m-%Y_%H:%M:%S"
    cmd | getline d
    close(cmd)
    #!@todo could start a process with "while true; do date ...; done"
    return(d)
}

BEGIN {
    od=""
    fid=1
    debug=1
    rrd=0
}

/^#/ { # get DB filename
    FS=","
    dbFile=FILENAME
    next
}

# data from database; first file
FNR==NR { #!@todo this doesn't help if the DB file is empty.
#!@todo dynamic IPs are annoying.
# We should track device by MAC, not just IP. However, interfaces can have 
# multiple IPs, so we need to keep rules around for all recent IPs. Because rule
# IPs currently match table IPs, perhaps the UI can add up the values between 
# multiple IPs per MAC address?
    #!@todo could get interface IP here
    m=$1

    # arrays are indexed by MAC/interface, with the exception of 'mac'
    hosts[m] = "" # add this host/interface to hosts
    mac[$2]       =  $1
    ip[m]	 =  $2
    inter[m]      =  $3
    bw[m "/in"]   =  $4
    bw[m "/out"]  =  $5
    firstDate[m]  =  $7
    lastDate[m]   =  $8
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
	if(!(arp_ip in mac)){
	    if(debug)
		print "new IP:", arp_ip, arp_flags > "/dev/stderr"
	    mac[arp_ip] = arp_mac
	}
	if(!(arp_mac in ip)){
	    if(debug)
		print "new MAC:", arp_mac, arp_flags > "/dev/stderr"
	    hosts[arp_mac] = ""
	    mac[arp_ip]   = arp_mac
	    ip[arp_mac]    = arp_ip
	    inter[arp_mac] = arp_dev
	    firstDate[arp_mac] = lastDate[arp_mac] = date()
	    bw[arp_mac "/in"]=bw[arp_mac "/out"]= 0
	}
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
	n=m "/out"
    } else if($7 != "*"){ # interface in
	m=$7
	n=m "/in"
    } else if($8 != "0.0.0.0/0"){ # IP out
	m=mac[$8]
	n=m "/out"
    } else if($9 != "0.0.0.0/0"){ # IP in
	m=mac[$9]
	n=m "/in"
    } else {	
	print "unexpected rule: " $0 > "/dev/stderr"
	next
    }
    if(n == "/in" || n == "/out") {
	print "failed to find MAC/IF for iptables entry: " $0 > "/dev/stderr"
	for (m in ip) {
	    print "ip[" m "]: " ip[m]
	}
	exit # debug
	next
    }

    # remove host from array; any hosts left in array at END get new
    # iptables rules

    #!@todo this deletes a host if any rule exists; if only one
    # directional rule is removed, this will not remedy the situation
    delete hosts[m]

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
#    system("rm -f " dbFile)
    print "#mac,last_ip,iface,in,out,total,first_date,last_date"# > dbFile
    OFS=","
    #!todo use ARP IP (or last seen IP) here.
    for(m in ip)
	print m, ip[m], inter[m], bw[m "/in"], bw[m "/out"], total(m), firstDate[m], lastDate[m]# > dbFile
    close(dbFile)
    # for hosts without rules
    for(host in hosts) if(!inInterfaces(host) && host in ip) newRule(ip[host])
    #!@todo remove rules for stale IPs
}
