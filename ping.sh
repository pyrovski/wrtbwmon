#chmod ugo+rw /mnt/cifs2/ping.log
echo -n '#' >> /mnt/cifs2/ping.log
date +%Y_%m_%d.%H:%M:%S >> /mnt/cifs2/ping.log
/usr/bin/ping -Dni 10 -W 5 google.com 2>&1 | tee -a /mnt/cifs2/ping.log

