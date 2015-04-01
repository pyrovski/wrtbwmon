# date line
fid==3 && NF==2 {
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
    print d-ld
    ld=d
    next
}
