#!/usr/bin/awk

BEGIN{
    t=0
    intervals="0 10  60 3600 86400 2628000 31536000"
    labels   ="r 10s m  h    d     M       y"
    split(intervals, s_intervals)
    numLabels=split(labels, s_labels)

    for(i=1; i <= numLabels; i++)
	intervalMap[s_intervals[i]] = s_labels[i]
    pipe="/tmp/wrtbwmon.pipe"
    numHosts=0
}

function addEntry(t, _in, _out, entryFile){
    print t, _in, _out >> entryFile
}

function _compact(host, interval, interval2,  i,n,l,a,f){
    key=host "." interval2
    tDiff = t-lastCompact[key]
    if(key in lastCompact && tDiff < interval2){
#	print "compacting", host, interval, interval2 ": not enough time elapsed:", tDiff
	return(1)
    }
#    print "compacting", host, interval, interval2
    lastCompact[key] = t
    f="./" host "." intervalMap[interval] ".tsdb"
#    print f
    close(f)
    line=0
    processed=0
    while(1==(r=getline < f)){
	line++
	if(NF == 3){
	    processed++
	    if(line==1){
#!@todo technically, this should be the time of the last entry in the
#!interval2 file
		lastTS=$1
		lastLine=line
		s_in=s_out=0
	    }
	    s_in  += $2
	    s_out += $3
	    if($1 - lastTS >= interval2 - interval){
		nextF = "./" host "." intervalMap[interval2] ".tsdb"
		addEntry($1, s_in, s_out, nextF)
		    print $1, s_in, s_out, nextF
		    lastTS=$1
		    s_in=s_out=0
		    lastLine = line
	    }
	}
    }
    close(f)
    if(processed > 0){
	# retain entries not compacted
	if(lastLine != line){
#	    print line-lastLine " leftover of " line " entries"
	    tmpF = "/tmp/"host"."intervalMap[interval]".tsdb"
	    cmd = "tail -n +" lastLine+1" "f " > " tmpF " && mv " tmpF " " f" 2>/dev/null"
	    system(cmd)
	} else
	    system("rm -f " f)
	return(0)
    } else
	# no lines processed, so next compaction doesn't need to run
	return(1)
}

function compact(host,  i){
    if(lastCompact[host]){
	print "compacting " host " at time " t ": " t-lastCompact[host] "s"
    } else {
	print "first compaction for " host
    }
    r=0
    for(i=1; i < numLabels; i++)
	if(!r){
	    r=_compact(host, s_intervals[i], s_intervals[i+1])
	    #if(s_intervals[i+1] ...)
	}
    lastCompact[host] = t
}

function dump(){
    for(host in db_in){
	if(t-lastCompact[host] >= 10)
	    compact(host)
	addEntry(t, db_in[host], db_out[host], "./" host "." intervalMap[0] ".tsdb")
	delete db_in[host]
	delete db_out[host]
	if(!(host in hosts)){
	    numHosts++
	    hosts[host] = ""
	}
    }
}

NF==1 && $1 ~ /[0-9]+[.][0-9]+/{
    t=$1
    printf "%s\r", t
    dump()
    next
}

NF==1 && $1 == "collect"{
    print "collect!\n"
    getline pid < "/tmp/wrtbwmon.pid"
#    print pid
    split(pid, a, " ")
    pid=a[1]
    reqTime=a[2]
    close("/tmp/wrtbwmon.pid")
    system("rm -f /tmp/wrtbwmon.pid")
    pidPipe = "/tmp/"pid".pipe"
    print "{" > pidPipe
    #!@todo this only prints hosts that have generated traffic since script start
    hostCount = 1
    for(host in hosts){
#	print host
	printf "\"" host "\":[[" > pidPipe
	system("cat "host".*.tsdb | awk -v t="reqTime" 'NF==3 && $1>t' | sort -n > "pidPipe)
	printf "0]]" > pidPipe
	if(hostCount != numHosts)
	    printf "," > pidPipe
	hostCount++
    }
    print "}" > pidPipe
    close(pidPipe)
    next
}

{
    split($1, a, "/")
    host = a[1]
    dir  = a[2]
    if(dir == "in")
	db_in[host] += $2
    else
	db_out[host] += $2
}

END{
    dump()
}
