BEGIN{
    OFS=","
    fc=0
}
FNR==1{
    fc++
    if(fc>1)
	print "0],"
    else
	print "{"
    n=split(FILENAME, a, "_")
    split(a[n], b, ".")
    print "\""a[1]":"b[1]"\":["
}
NF==3 && $1 > ts{
    print "["$1,$2,$3"],"
}
END{
    print "0]}"
}
