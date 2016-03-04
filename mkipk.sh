tmpdir=$(mktemp -d)
for file in $*; do
    dest=`egrep " $file( |$)" ./fileMap | cut -d':' -f1`
    mkdir -p $tmpdir/$dest
    if [ -n `echo $dest | egrep '/bin$'` ]; then
    	perm=0744
    else
    	perm=0644
    fi
    if [ -d "$file" ]; then
    	install -d -m $perm $file $tmpdir/$dest
    else
    	install -m $perm $file $tmpdir/$dest/
    fi
done
fakeroot -- ipkg-build $tmpdir
rm -rf "$tmpdir"
