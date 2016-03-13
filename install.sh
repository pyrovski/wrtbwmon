do_copy() {
    local dest perm file
    for file in $*; do
	dest=`egrep ".+ $file( |$)" ./fileMap | cut -d':' -f1`
	mkdir -p $DESTDIR/$dest
	if [ -n `echo $dest | egrep '/s*bin$'` ]; then
    	    perm=0744
	else
    	    perm=0644
	fi
	install -m $perm -t $DESTDIR/$dest/ $file
    done
}

base=`basename $0`
if [ "$base" = "mkipk.sh" ]; then
    DESTDIR=$(mktemp -d)
    do_copy $*
    fakeroot -- ipkg-build $DESTDIR
    rm -rf $DESTDIR
else
    DESTDIR=${DESTDIR:-"/"}
    do_copy $*
fi
