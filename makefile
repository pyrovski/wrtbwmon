DESTDIR?=/
install-files=wrtbwmon.sh readDB.awk usage.htm*
ipk-files=control

all: wrtbwmon.ipk

wrtbwmon.ipk: $(install-files) $(ipk-files)
	./mkipk.sh $^

install: $(install-files)
	./install.sh $^
