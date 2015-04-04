BEGIN{
    sC=0
    fC=0
    lastSuccess=""
    lastFail=""
    last=1
    min=100000.0
    t=max=sum=0
}
/^(P|#|$)/{
    next
}
/.*bytes.*/{
    sC++
    gsub("[][]","",$1)
    if(!last)
	print "down from", lastSuccess, "to", $1 ":", $1 - lastSuccess "s"
    last=1
    lastSuccess=$1
    sub("time=","",$8)
    t=$8+0
    sum+=t
    min=(t < min)?t:min
    max=(t > max)?t:max
    next
}
/.*Unre.*/{
    gsub("[][]","",$1)
    last=0
    lastFail=$1
    next
}
{}
END{
    print "average:", sum/sC "ms"
    print "min:", min "ms"
    print "max:", max "ms"
#print sC
}

