BEGIN{
    OFS=","
    fc=0
}
FNR==1{
    fc++
    if(fc>1){
	print "0],"
    }else{
	print "{"
    }
    split(FILENAME, a, "_")
    print "\""a[1]"\":["
}
NF==3 && $1 > ts{
    print "["$1,$2,$3"],"
}
END{
    print "0]}"
}
