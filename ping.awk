BEGIN{
    sC=0
    fC=0
    lastSuccess=""
    lastFail=""
    last=1
}
/^(P|#|$)/{
    next
}
/.*bytes.*/{
    sC++
    gsub("[][]","",$1)
    if(!last){
	print "down from", lastSuccess, "to", $1 ":", $1 - lastSuccess "s"
    }
    last=1
    lastSuccess=$1
    next
}
/.*Unre.*/{
    gsub("[][]","",$1)
    last=0
    lastFail=$1
    next
}
{print}
END{
#print sC
}

