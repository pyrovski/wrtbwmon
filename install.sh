if [ -n "$DESTDIR" ]; then
    mkdir -p $DESTDIR
else
    DESTDIR="/"
fi

for file in $*; do
    dest=`egrep " $file( |$)" ./fileMap | cut -d':' -f1`
    mkdir -p $DESTDIR/$dest
    if [ -n `echo $dest | egrep '/bin$'` ]; then
    	perm=0744
    else
    	perm=0644
    fi
    if [ -d "$file" ]; then
    	install -d -m $perm $file $DESTDIR/$dest
    else
    	install -m $perm $file $DESTDIR/$dest/
    fi
done
