#mac,ip,iface,peak_in,peak_out,offpeak_in,offpeak_out,total,first_date,last_date
BEGIN {od=""}

/^#/{FS=","; next }

# data from database; first file
FNR==NR{
    #!@todo could also build mac->ip table
    if($2 == "NA")
	n=$1
    else
	n=$2
    bw[n "/in"]   =  $4
    bw[n "/out"]  =  $5
    bw[n "/in"]  +=  $6
    bw[n "/out"] +=  $7
    firstDate[n]  =  $9
    lastDate[n]   = $10
    next
}

# change FS on 2nd file
FNR==1{FS=" "; next}

# skip line
$1 == "pkts" { next }

# date line
NF==2{
    d=$2
    if(od==""){
	od=d
	md=d
	ld=d
    } else if(d-md > 5){
	md=d
    	print d
    	for(i in _) print i, _[i]
    	#!@todo update table for longer timescale...
    }
    print d-ld
    ld=d
    next
}

# iptables input
$2 > 0{
    if($6 != "*")
	n=$6 "/in"
    else if($7 != "*")
	n=$7 "/out"
    else if($8 != "0.0.0.0/0")
	n=$8 "/in"
    else
	n=$9 "/out"
    bw[n]+=$2
}

END {
    for(i in bw) print i, bw[i]
}
