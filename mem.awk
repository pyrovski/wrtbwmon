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
	    if(!(host in hosts))
		newHost(host)
	    hostPeriod = host",r"
	    if(t != lastReadTS[host]){
		++samples[hostPeriod]
		hostIndex = hostPeriod","samples[hostPeriod]
		times[hostIndex] = lastReadTS[host] = t
		inBytes[hostIndex] = outBytes[hostIndex] = 0
		print minSample[hostPeriod],samples[hostPeriod], $0
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
	    if(t) print totalSamples/(t-firstTS) "/s"
	    for(host in hosts)
		compact(host)
	    dump()
	} else if($1 ~ /[0-9]+[.][0-9]+/){
	    if(t==0) firstTS=$1
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
		  nextSamples, compacted)
{
    # start at the end of the realtime array, compact.

    # This differs from the original file-based compact() in that it
    # doesn't maintain an interval start entry at the head of each
    # period. The only change that should be necessary is to make sure
    # that new hosts get a zero entry before their first measurement.
    period = s_labels[intervalIndex]
    nextPeriod = s_labels[intervalIndex+1]
    hostPeriod = host","period
    hostNextPeriod = host","nextPeriod
    nextSamples = samples[hostNextPeriod]
    lastIndex = minSample[hostPeriod]-1
    lastTS = times[hostNextPeriod","nextSamples]
    compacted = 0
    for(sample=lastIndex+1; sample <= samples[hostPeriod]; sample++){
	hostIndex = hostPeriod","sample
	ts = times[hostIndex]
	inTotal += inBytes[hostIndex]
	outTotal += outBytes[hostIndex]
	if(ts - lastTS >= s_intervals[intervalIndex+1]){
	    compacted = 1
	    nextSamples = ++samples[hostNextPeriod]
	    hostNextIndex = hostNextPeriod","nextSamples
	    times[hostNextIndex] = lastTS = ts
	    inBytes[hostNextIndex] = inTotal
	    outBytes[hostNextIndex] = outTotal
	    inTotal = outTotal = 0
	    for(dSample=lastIndex+1; dSample <= sample; dSample++){
		hostIndex = hostPeriod","dSample
		delete times[hostIndex]
		delete inBytes[hostIndex]
		delete outBytes[hostIndex]
		minSample[hostPeriod]++
	    }
	    lastIndex = sample
	}
    }
    return(!compacted)
}

function compact(host,
		 i){
    for(i=1; i < numLabels; i++)
	if(_compact(host, i))
	    break
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
	    period = s_labels[i]
	    f = host "_" period ".tsdb"
	    hostPeriod = host","period
	    
	    for(sample=minSample[hostPeriod]; sample <= samples[hostPeriod]; sample++){
		hostIndex = hostPeriod","sample
		print times[hostIndex], inBytes[hostIndex], outBytes[hostIndex] > f
	    }
	    close(f)
	}
    }
    if(t) print t > fLastUpdate
}

BEGIN{
    quiet=1
    fLastUpdate = "/tmp/wrtbwmon.lastUpdate"
#    r=getline t < fLastUpdate
#    close(fLastUpdate)
#    if(r != 1)
	t=0
#    else
#	firstTS = t

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
    if(ARGC == 1)
	exit
}

FNR==1{
    if(FILENAME ~ /.*_.+[.]tsdb/){
	split(FILENAME, f, "_")
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
    hostIndex = hostPeriod "," (++samples[hostPeriod])
    times[hostIndex] = $1
    inBytes[hostIndex] = $2
    outBytes[hostIndex] = $3
    next
}

END{
    print "commands"
    while(1){
	getline < pipe
	close(pipe)
	command()
    }
    print "exit?"
}
