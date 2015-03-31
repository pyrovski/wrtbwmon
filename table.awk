BEGIN {od=""}
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
#    print d-ld
    ld=d
    next
}
$2 > 0{
    if($6 != "*")
	n=$6 "/in"
    else if($7 != "*")
	n=$7 "/out"
    else if($8 != "0.0.0.0/0")
	n=$8 "/in"
    else
	n=$9 "/out"
    _[n]+=$2
}
