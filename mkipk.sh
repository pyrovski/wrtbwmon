tmpdir=$(mktemp -d)
#cp -a $* $tmpdir/
for file in $*; do
    dest=`grep $file ./fileMap | cut -d':' -f1`
    mkdir -p $tmpdir/$dest
    cp -a $file $tmpdir/$dest/
done
fakeroot -- ipkg-build $tmpdir
rm -rf $tmpdir
