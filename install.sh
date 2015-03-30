#!/bin/sh
[ -f ./wrtbwmon ] && cp ./wrtbmon* /usr/sbin/ && exit
wget -O /usr/sbin/wrtbwmon http://raw.githubusercontent.com/pyrovski/wrtbwmon/master/wrtbwmon.sh
