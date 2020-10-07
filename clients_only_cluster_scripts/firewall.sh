echo "Turning off the Firewall..."
service firewalld stop
chkconfig firewalld off

echo `hostname` | grep -q "$clientNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
 echo "continue, no sleep required"
else
  coreIdCount=`grep "^core id" /proc/cpuinfo | sort -u | wc -l`
  socketCount=`echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1))`
  if [ $((socketCount*coreIdCount)) -eq 36  ]; then
    sleep 900s
  fi
fi
