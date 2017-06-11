DESTDIR?=/
install-files=$(shell grep -v CONTROL fileMap  | cut -d: -f2- | tr -d '\n')
ipk-files=$(shell grep CONTROL fileMap | cut -d: -f2-)
version:=$(shell egrep '^Version:' ./control | awk '{print $$2}')
target=wrtbwmon_$(version)_all.ipk

all: $(target)

$(target): $(install-files) $(ipk-files)
	./mkipk.sh $^

install: $(install-files)
	./install.sh $^

deb:
	gbp buildpackage -Pdebian --git-ignore-new

clean:
	rm -f *.ipk

.PHONY: deb install clean

.SUFFIXES:
