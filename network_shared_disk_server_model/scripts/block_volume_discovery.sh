
echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then

  while [ ! -f /tmp/multi-attach.complete ]
  do
    sleep 60s
    echo "Waiting for multi-attach via oci-cli to  complete ..."
  done
fi

echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then
    # for TF script to proceed with next steps
    touch /tmp/multi-attach-iscsi.complete
fi


echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  mkdir -p /var/mmfs/etc/
  if [ -f /tmp/nsddevices ]; then
    cp /tmp/nsddevices /var/mmfs/etc/
    chmod +x /var/mmfs/etc/nsddevices
  else
    exit 1
  fi
fi


