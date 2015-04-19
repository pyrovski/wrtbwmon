function newEntry(i, time, inB, outB){
    times[i] = time
    inBytes[i] = inB
    outBytes[i] = outB
}

function date(){
    cmd="date +%s.%N"
    cmd | getline d
    close(cmd)
    return(d)
}

function newHost(host, i){
    hosts[host] = ""
    for(i = 1; i < numLabels; i++)
	minSample[host","s_labels[i]] = 1
}

function command(a, host, dir, f){
    if(NF == 2){
	if($1 ~ /\//){
	    split($1, a, "/")
	    host = a[1]
	    hostPeriod = host",r"
	    if(!(host in hosts))
		newHost(host)
	    if(t != lastReadTS[host]){
		++samples[hostPeriod]
		hostIndex = hostPeriod","samples[hostPeriod]
		lastReadTS[host] = t
		newEntry(hostIndex, t, 0, 0)
#		print minSample[hostPeriod],samples[hostPeriod], $0
	    } else
		hostIndex = hostPeriod","samples[hostPeriod]
	    dir  = a[2]
	    if(dir == "in")
		inBytes[hostIndex] += $2
	    else
		outBytes[hostIndex] += $2
	} else if($2 ~ /[0-9]+([.][0-9]+)?/){
	    ## pid timestamp
	    print $0
	    f = "/tmp/"$1".pipe"
	    dumpJSON($2, f)
	    close(f)
	}
    } else if(NF == 1){
	if($1 == "dump"){
	    if(t && t != firstTS) print totalSamples/(t-firstTS) "/s"
	    for(host in hosts)
		compact(host, 0)
	    dump()
	    exit
	} else if($1 ~ /[0-9]+[.][0-9]+/){
	    t=$1
	    totalSamples++
	} else if($1 == "exit"){
	    dump()
	    exit
	}
    }
}

function _compact(host, intervalIndex,
		  hostIndex, hostNextIndex, hostPeriod, hostNextPeriod, period,
		  inTotal, outTotal, lastTS, ts, sample, dSample,
		  compacted)
{
    # start at the end of the realtime array, compact.

    # This differs from the original file-based compact() in that it
    # doesn't maintain an interval start entry at the head of each
    # period. The only change that should be necessary is to make sure
    # that new hosts get a zero entry before their first measurement.

#    if(host == "192.168.1.133")
#	print "compacting " host " " s_labels[intervalIndex] "(" s_intervals[intervalIndex] ") to " s_labels[intervalIndex+1] "(" s_intervals[intervalIndex+1] ")"
    period = s_labels[intervalIndex]
    nextPeriod = s_labels[intervalIndex+1]
    hostPeriod = host","period
    hostNextPeriod = host","nextPeriod
    if(!samples[hostNextPeriod]){
#	if(host == "192.168.1.133")
#	    print "adding new entry to " nextPeriod ": " lastUpdate
	newEntry(hostNextPeriod","(++samples[hostNextPeriod]),
		 lastUpdate, 0, 0)
	lastTS = lastUpdate
    } else
	lastTS = times[hostNextPeriod","samples[hostNextPeriod]]
    compacted = 0
    if(samples[hostPeriod]){
	lastIndex = minSample[hostPeriod]-1
	for(sample=minSample[hostPeriod]; sample <= samples[hostPeriod]; sample++){
	    hostIndex = hostPeriod","sample
	    ts = times[hostIndex]
#	    if(host == "192.168.1.133")
#		print "sample " sample " of " samples[hostPeriod] ": " ts " " inBytes[hostIndex] " " outBytes[hostIndex] " " ts - lastTS
	    inTotal += inBytes[hostIndex]
	    outTotal += outBytes[hostIndex]
	    if(ts - lastTS >= s_intervals[intervalIndex+1]){
		compacted = 1
		hostNextIndex = hostNextPeriod","(++samples[hostNextPeriod])
#		if(host == "192.168.1.133")
#		    print "adding new entry to " nextPeriod ": " ts " " inTotal " " outTotal
		newEntry(hostNextIndex, lastTS=ts, inTotal, outTotal)
		inTotal = outTotal = 0
		for(dSample=lastIndex+1; dSample <= sample; dSample++){
		    hostIndex = hostPeriod","dSample
		    #!@todo this doesn't seem to free up any memory.
		    delete times[hostIndex]
		    delete inBytes[hostIndex]
		    delete outBytes[hostIndex]
		    minSample[hostPeriod]++
		}
		lastIndex = sample
	    }
	}
    }
#    if(host == "192.168.1.133")
#	print compacted
    return(!compacted)
}

function compact(host, force,
		 i){
    for(i=1; i < numLabels; i++)
	if(_compact(host, i) && !force) break
}

function dumpJSON(ts, toPipe,
		  host, printCount, i, period, hostPeriod, sample, hostIndex)
{    
    OFS=","
    print "{" > toPipe
    printCount = 0
    for(host in hosts){
	for(i=numLabels; i >= 1; i--){
	    period = s_labels[i]
	    if(printCount++)
		printf "," > toPipe
	    print "\"" host ":" period "\":[" > toPipe
	    hostPeriod = host","period
	    if(times[hostPeriod","samples[hostPeriod]] <= ts){
		print "0]" > toPipe
		continue
	    }
	    for(sample=minSample[hostPeriod]; sample <= samples[hostPeriod]; sample++){
		hostIndex = hostPeriod","sample
		if(times[hostIndex] <= ts){
		    #!@todo could do a binary search for the start time
		    continue
		}
		print "["times[hostIndex], inBytes[hostIndex], outBytes[hostIndex]"]," > toPipe
	    }
	    print "0]" > toPipe
	}
    }
    print "}" > toPipe
    OFS=" "
}

function dump(  f, host, i, period, hostPeriod, sample, hostIndex)
{
    print "dump"
    for(host in hosts){
	for(i=numLabels; i >= 1; i--){
	    close(f = host "_" (period = s_labels[i]) ".tsdb")
	    if(!samples[hostPeriod = host","period]){
		continue
	    }
	    for(sample=minSample[hostPeriod]; sample <= samples[hostPeriod]; sample++){
		hostIndex = hostPeriod","sample
		if(!times[hostIndex])
		    print "Warning: zero time: " hostIndex
		print times[hostIndex], inBytes[hostIndex], outBytes[hostIndex] > f
	    }
	    close(f)
	}
    }
    if(t) print t > fLastUpdate
}

BEGIN{
    if(!getline < "/tmp/continuous.pid"){
	reallyExit=1
	exit
    }
    t = firstTS = date()
    fLastUpdate = "/tmp/wrtbwmon.lastUpdate"
    if(1 != getline lastUpdate < fLastUpdate)
	lastUpdate = firstTS
    close(fLastUpdate)
    
    intervals="0 10  60 3600 86400 2628000 31536000"
    labels   ="r 10s m  h    d     M       y"
    split(intervals, s_intervals)
    numLabels=split(labels, s_labels)
    for(i=1; i <= numLabels; i++)
	intervalMap[s_intervals[i]] = s_labels[i]
    pipe="/tmp/continuous.pipe"
    #!@todo support zeros as in tsdb.awk
    #zeros=""
    totalSamples = 0
    if(ARGC == 1) exit
}

FNR==1{
    if(FILENAME ~ /.*_.+[.]tsdb/){
	n = split(FILENAME, f, "/")
	f = f[n]
	split(f, f, "_")
	host = f[1]
	if(!(host in hosts))
	    newHost(host)

	split(f[2], period, ".")
	period = period[1]
	hostPeriod = host","period
	if(!(hostPeriod in samples)){
	    samples[hostPeriod] = 0
	}
    }
}

NF == 3 && $1 > 0{
    newEntry(hostPeriod "," (++samples[hostPeriod]),
	     $1, $2, $3)
    next
}

END{
    if(reallyExit) exit
    for(host in hosts)
	compact(host, 1)
    print "commands"
    while(1){
	getline < pipe
	close(pipe)
	command()
    }
    print "exit?"
}
