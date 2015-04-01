#!/bin/sh
[ -f ./wrtbwmon ] && cp ./wrtbwmon* /usr/sbin/ && exit
wget -O /usr/sbin/wrtbwmon http://raw.githubusercontent.com/pyrovski/wrtbwmon/master/wrtbwmon.sh && chmod +x /usr/sbin/wrtbwmon
ln -s /tmp/usage.htm /www/
