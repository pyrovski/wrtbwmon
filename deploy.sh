# Check syntax first
sh -n wrtbwmon
if [ "$?" != 0 ]; then
  echo "Deployment aborted due to errors"
  exit 1
fi

HOST=router
DST=/mnt/usb1/wrtbwmon

scp wrtbwmon.conf.dist root@$HOST:$DST/wrtbwmon.conf
scp wrtbwmon chart.html root@$HOST:$DST/
