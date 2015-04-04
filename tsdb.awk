#!/usr/bin/awk

BEGIN{
    t=0
    intervals="0 10  60 3600 86400 2628000 31536000"
    labels   ="r 10s m  h    d     M       y"
    split(intervals, s_intervals)
    numLabels=split(labels, s_labels)

    for(i=1; i <= numLabels; i++)
	intervalMap[s_intervals[i]] = s_labels[i]
}

function addEntry(t, _in, _out, entryFile){
    printf "%f/%d/%d ", t, _in, _out >> entryFile
}

function _compact(host, interval, interval2,  i,n,l,a,f){
    key=host "." interval2
    tDiff = t-lastCompact[key]
    if(key in lastCompact && tDiff < interval2){
	print "compacting", host, interval, interval2 ": not enough time elapsed:", tDiff
	return(1)
    }
    print "compacting", host, interval, interval2
    lastCompact[key] = t
    f="./" host "." intervalMap[interval] ".tsdb"
    print f
    close(f)
    n=0
    while(1==(r=getline line < f)){
	n=split(line, l, " ")
	if(n > 0){
	    split(l[1], a, "/")
	    firstTS=a[1]
	    lastTS=firstTS
	    last_i=s_in=s_out=0
	    for(i in l){
		split(l[i], a, "/")
		s_in  += a[2]
		s_out += a[3]
		if(a[1] - lastTS > interval2 - interval){
		    nextF = "./" host "." intervalMap[interval2] ".tsdb"
		    addEntry(a[1], s_in, s_out, nextF)
		    print a[1], s_in, s_out, nextF
		    lastTS=a[1]
		    s_in=s_out=0
		    last_i = i
		}
	    }
	}
    }
    close(f)
    if(n > 0){
	system("rm -f " f)
	# retain entries not compacted
	if(last_i != n){
	    print n-last_i " leftover of " n " entries"
	    for(i=last_i + 1; i <= n; i++)
		printf "%s ", l[i] > f
	}
	return(0)
    } else
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
	if(!r)
	    r=_compact(host, s_intervals[i], s_intervals[i+1])
    lastCompact[host] = t
}

function dump(){
    for(host in db_in){
	if(t-lastCompact[host] >= 10)
	    compact(host)
	addEntry(t, db_in[host], db_out[host], "./" host "." intervalMap[0] ".tsdb")
	delete db_in[host]
	delete db_out[host]
    }
}

NF==1{
    t=$1
    printf "%s\r", t
    dump()
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
