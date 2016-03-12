DESTDIR?=/
install-files=wrtbwmon.sh readDB.awk $(wildcard usage.htm*) wrtbwmon
ipk-files=control
version:=$(shell egrep '^Version:' ./control | awk '{print $$2}')
target=wrtbwmon_$(version)_all.ipk

all: $(target)

$(target): $(install-files) $(ipk-files)
	./mkipk.sh $^

install: $(install-files)
	./install.sh $^

.SUFFIXES:
