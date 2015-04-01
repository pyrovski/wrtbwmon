#!@todo locks, offpeak, interfaces

function total(i){
    return(bwp[i "/in"] + bwp[i "/out"] + bwo[i "/in"] + bwo[i "/out"])
}

function date(){
    cmd="date +%d-%m-%Y_%H:%M:%S"
    cmd | getline d
    close(cmd)
#!@todo could start a process with "while true; do date ...; done"
    return(d)
}

BEGIN {
    od=""
    fid=1
    debug=0
    rrd=0
}

/^#/ {
    FS=","
    dbFile=FILENAME
    next
}

# data from database; first file
FNR==NR {
    if($2 == "NA")
	n=$1
    else
	n=$2
    mac[n]        =  $1
    ip[n]         =  $2
    inter[n]      =  $3
    bwp[n "/in"]  =  $4
    bwp[n "/out"] =  $5
    bwo[n "/in"]  =  $6
    bwo[n "/out"] =  $7
    firstDate[n]  =  $9
    lastDate[n]   = $10
    next
}

# not triggered on the first file
FNR==1 {
    FS=" "
    fid++
    next
}

# arp: ip hw flags hw_addr mask device
fid==2 {
    arp_ip    = $1
    arp_flags = $3
    arp_mac   = $4
    arp_dev   = $6
    if(arp_flags != "0x0" && !(arp_ip in ip)){
	if(debug)
	    print "new host:", arp_ip, arp_flags > "/dev/stderr"
	# new host; add rule
	"iptables -t mangle -I RRDIPT_FORWARD -d arp_ip -j RETURN"
	"iptables -t mangle -I RRDIPT_FORWARD -s arp_ip -j RETURN"
	mac[arp_ip]   = arp_mac
	ip[arp_ip]    = arp_ip
	inter[arp_ip] = arp_dev
	bwp[arp_ip "/in"]=bwp[arp_ip "/out"]=bwo[arp_ip "/in"]=bwo[arp_ip "/out"] = 0
	firstDate[arp_ip]=lastDate[arp_ip] = date()
    }
}

# skip line
# read the chain name and deal with the data accordingly
fid==3 && $1 == "Chain"{
    rrd=$2 ~ /RRDIPT_.*/
    next
}

fid==3 && rrd && (NF < 9 || $1=="pkts"){ next }

# iptables input
fid==3 && rrd && $2 > 0{
    if($6 != "*")
	n=$6 "/in"
    else if($7 != "*")
	n=$7 "/out"
    else if($8 != "0.0.0.0/0")
	n=$8 "/in"
    else
	n=$9 "/out"
    #!@todo offpeak
    if(mode == "diff" || mode == "noUpdate")
	print n, $2
    if(mode!="noUpdate")
	bwp[n]+=$2
}

END {
    if(mode=="noUpdate")
	exit
    close(dbFile)
    print "#mac,ip,iface,peak_in,peak_out,offpeak_in,offpeak_out,total,first_date,last_date" > dbFile
    OFS=","
    for(i in mac)
	print mac[i], ip[i], inter[i], bwp[i "/in"], bwp[i "/out"], bwo[i "/in"], bwo[i "/out"], total(i), firstDate[i], lastDate[i] > dbFile
}
