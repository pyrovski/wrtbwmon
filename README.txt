Description
===========
OpenWRT Bandwidth Monitor (wrtbwmon) is a lightweight, efficient, yet
feature rich bandwidth monitor for routers running OpenWRT.

Have you ever asked yourself the following questions:
- "What is eating up bandwidth in my home/office?",
- "Who uses the most bandwidth?",
- "Who is downloading stuff all the time",
- "Are malware infected computers on my network eating up bandwidth?"

If you asked yourself these questions, but never had the data to formulate
an answer, then this script is for you.

The OpenWRT Bandwidth Monitor provides the following:
- Logs the number of kilobytes that each device uses per hour, day and month
  for upload and download
- Stores the above data for at least a year.
- Displays a graph of comparative device usage per hour, day, and month.
- Uses very little system resources (CPU and storage).

Requirements
============
OpenWRT Version:
----------------
Your router must be running a recent version of OpenWRT. This version of 
wrtbwmon was successfully tested with bleeding edge r39729 built in February
2014, and with Barrier Breaker 14.07 stable release. It was not tested with
12.09.

External Storage:
-----------------
This version assumes that you have a permanent storage device to store the
data on your router. The best case is that your router has a USB port, 
and you install the packages necessary for USB storage, and configure 
the router to automatically mount the USB disk on boot.

To configure USB storage for OpenWRT follow the instruction here:
http://goo.gl/j4DU3B

If your router does not have a USB port, and you have an external server,
you may be able to store the script and the data on a remote file system
using NFS, SAMBA or SSHFS. There is more overhead for this approach vs. 
using a USB storage device, specially with NFS.

You can read about how to configure network file system clients on OpenWRT
here: http://wiki.openwrt.org/doc/howto/client.overview

Installation
============
To install and configure wrtbwmon, you need to follow the steps below:

1. Create a directory on the USB disk, e.g. "/mnt/usb/wrtbwmon".

2. Copy the following files to the above directory:
   wrtbwmon
   wrtbwmon.conf.dist 
   chart.html

3. In the same directory, copy or rename the "wrtbwmon.conf.dist" to
   "wrtbwmon.conf"

4. Change the values in the wrtbwmon.conf, e.g. 

   USERSFILE="/tmp/etc/dnsmasq.conf"
   BASE_DIR="/mnt/usb/wrtbwmon"
   LAN_IFACE="br-lan"
   INTERNAL_NETMASK="192.168.0.0/24"

5. Run the script with the "install" option. This will create the necessary
   directories and symbolic links, as well as setup the required iptables
   configuration. You have to use the full path name of the script!
   
   # /mnt/usb/wrtbwmon/wrtbwmon install

6. Add wrtbwmon with the install option to your startup. To do this go to 
   LuCI, and under "System -> Startup -> Local Startup" add the following
   line, before the "exit 0" line:

   /mnt/usb/wrtbwmon/wrtbwmon install

7. Setup cron, either via LuCI, or via the command line using "crontab -e"

   # OpenWRT Bandwidth monitor
   # Scan for new devices every minute
   */1    * * * * /mnt/usb/wrtbwmon/wrtbwmon scan
   # Collect usage data every 3 minutes
   */3  * * * * /mnt/usb/wrtbwmon/wrtbwmon collect
   # Create a list of devices every 10 minutes 
   */10 * * * * /mnt/usb/wrtbwmon/wrtbwmon devices

8. Start cron, and make it start automatically on boot too:
   # /etc/init.d/cron start
   # /etc/init.d/cron enable
 
Reports
=======
You all done now, to see traffic usage, point your browser to "/wrtbwmon/chart.html"
on your router. For example, if your router is at the default IP address 192.168.1.1,
then you should use this URL: http://192.168.1.1/wrtbwmon/chart.html

You can select Day to view usage by hour, Month, to view usage by day, and Year to view
usage by months. You can also zoom in on a specific day.

To Do
=====
1. How to really get internal and external traffic?

2. Remove the unused columns from the data files and report

Credits
=======
This version of wrtbwmon is based on https://gitorious.org/wrtbwmon,
which borrows from other variants.
