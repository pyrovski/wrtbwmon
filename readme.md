# Wrtbwmon

An enhanced version of the original [wrtbwmon](http://code.google.com/p/wrtbwmon/).
This version allows to define a netmask which is counted as internal traffic.
Also a nice web frontend was added using google chart tools to display the traffic data.

## Homepage
[https://gitorious.org/wrtbwmon](https://gitorious.org/wrtbwmon)


## Prerequisites
A router running DD-WRT or the like with Optware (might work without) installed.


## Setup

Download the script to /opt/bin and make it executable:

```
$ wget http://gitorious.org/wrtbwmon/wrtbwmon/blobs/raw/master/wrtbwmon -O /opt/bin/wrtbwmon
$ chmod +x /opt/bin/wrtbwmon
```


Optionally create a /opt/etc/wrtbwmon.rc to override default settings, i.e.

```
INTERNAL_NETMASK=192.168.0.0/24
```


Call script with 'setup' and 'download_scripts' parameters:

```
$ /opt/bin/wrtbwmon setup
$ /opt/bin/wrtbwmon download_scripts
```


Add the following cron jobs:

```
* * * * * root /opt/bin/wrtbwmon setup traffic
* * * * * root /opt/bin/wrtbwmon update traffic
1 * * * * root /opt/bin/wrtbwmon backup traffic
1 * * * * root /opt/bin/wrtbwmon publish_users traffic
```
