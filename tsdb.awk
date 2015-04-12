#!/usr/bin/awk

BEGIN{
    fLastUpdate = "/tmp/wrtbwmon.lastUpdate"
    r=getline t < fLastUpdate
    close(fLastUpdate)
    if(r != 1)
	t=0
    else
	firstTS = t
    
    intervals="0 10  60 3600 86400 2628000 31536000"
    labels   ="r 10s m  h    d     M       y"
    split(intervals, s_intervals)
    numLabels=split(labels, s_labels)

    for(i=1; i <= numLabels; i++)
	intervalMap[s_intervals[i]] = s_labels[i]
    pipe="/tmp/continuous.pipe"
    numHosts=0
    samples=0
    zeros=""
}

function addEntry(t, _in, _out, entryFile){
    print t, _in, _out >> entryFile
}

function _compact(host, interval, interval2,
		  n,l,f,fTmp,nextF,nextFirstTS,lastTS)
{
    key=host "." interval2
    tDiff = t-lastCompact[key]
    if(key in lastCompact && tDiff < interval2){
#	print "compacting", host, interval, interval2 ": not enough time elapsed:", tDiff
	return(1)
    }
#    print "compacting", host, interval, interval2
    lastCompact[key] = t
    f="./" host "_" intervalMap[interval] ".tsdb"
    fTmp=f".tmp"
    nextF = "./" host "_" intervalMap[interval2] ".tsdb"
    r=getline < nextF
    if(r == 1)
	nextFirstTS = $1
    else
	nextFirstTS = 0
    close(nextF)
    close(f)
    line=0
    processed=0
    lastTS=firstTS
    while(1==(r=getline < f)){
	line++
	if(NF == 3){
	    processed++
	    if(line==1){
		lastTS=$1
		if(!nextFirstTS){
		    nextFirstTS=lastTS
		    print nextFirstTS,0,0 > nextF
		}
		lastLine=line
		s_in=s_out=0
	    }
	    s_in  += $2
	    s_out += $3
	    if($1 - lastTS >= interval2 - interval){
		addEntry($1, s_in, s_out, nextF)
		print $1":", lastTS, s_in, s_out, nextF
		lastTS=$1
		s_in=s_out=0
		lastLine = line
	    }
	}
    }
    close(f)
    if(processed > 0){
	close(nextF)
	print lastTS,0,0 > fTmp
	close(fTmp)
	# retain entries not compacted
	if(lastLine != line){
#	    print line-lastLine " leftover of " line " entries"
	    cmd = "tail -n +" lastLine+1" "f " | uniq >> " fTmp " 2>/dev/null"
	    system(cmd)
	}
	system("mv " fTmp " " f)
	return(0)
    } else {
	# no lines processed, so next compaction doesn't need to run,
	# but we need to add an initial timestamp to the file
	print lastTS,0,0 > f
	return(1)
    }
}

function compact(host,
		 i, r)
{
    if(lastCompact[host]){
	print "compacting " host " at time " t ": " t-lastCompact[host] "s"
    } else {
	print "first compaction for " host
    }
    r=0
    for(i=1; i < numLabels; i++)
	if(!r)
	    r=_compact(host, s_intervals[i], s_intervals[i+1])
    lastCompact[host] = t
}

function dump(){
    for(host in hosts)
	if(!(host in zeros) && !(host in db_in)){
	    addEntry(t, 0, 0, "./" host "_" intervalMap[0] ".tsdb")
	    zeros[host] = ""
	}
    
    for(host in db_in){
	delete zeros[host]
	if(t-lastCompact[host] >= 10)
	    compact(host)
	if(!(host in hosts)){
	    numHosts++
	    hosts[host] = ""
	}
	if(!(host in db_out))
	    db_out[host] = 0
	# entries should be tagged with the end time of the interval
	addEntry(t, db_in[host], db_out[host],
		 "./" host "_" intervalMap[0] ".tsdb")
    }
    delete db_in
    delete db_out
    samples++
}

#time
NF==1 && $1 ~ /[0-9]+[.][0-9]+/{
    if(t==0)
	firstTS=$1
    t=$1
    printf "%s\r", t
    dump()
    next
}

NF==1 && $1 == "collect"{
    # we really just need to pause here and provide a consistent copy
    # of the on-disk data. This would also be faster if we kept a copy
    # in awk.
    print t, "collect!\n"
    getline pid < pipe
    split(pid, a, " ")
    pid=a[1]
    reqTime=a[2]
    pidPipe = "/tmp/"pid".pipe"
    pidDump = "/tmp/"pid".dump"
    cmd="awk -v ts="reqTime" -f ./dump.awk *.tsdb > "pidDump
    system(cmd)
    print pidDump > pidPipe
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
    next
}

END{
    dump()
    # record timestamp of last realtime entry
    print "tsdb ending"
    if(t)
	print t > fLastUpdate
}
