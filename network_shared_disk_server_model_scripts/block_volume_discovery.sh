
echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then

  # Wait for multi-attach of the Block volumes to complete.  Only way to do that is via OCI CLI preview tool version which is called from Terraform scripts.  It then creates the below file on all nodes of the cluster.
  while [ ! -f /tmp/multi-attach.complete ]
  do
    sleep 60s
    echo "Waiting for multi-attach via oci-cli to  complete ..."
  done
fi

# Run the iscsi commands
echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then

    if [ $blockVolumesPerPool -gt 0 ] ;
    then
      echo "Number of disks : $blockVolumesPerPool"
      for n in `seq 2 $((blockVolumesPerPool+1))`; do
        echo "Disk $((n-2)), attempting iscsi discovery/login of 169.254.2.$n ..."
        success=1
        while [[ $success -eq 1 ]]; do
          iqn=$(iscsiadm -m discovery -t sendtargets -p 169.254.2.$n:3260 | awk '{print $2}')
          if  [[ $iqn != iqn.* ]] ;
          then
            echo "Error: unexpected iqn value: $iqn"
            sleep 10s
            continue
          else
            echo "Success for iqn: $iqn"
            success=0
          fi
        done
        iscsiadm -m node -o update -T $iqn -n node.startup -v automatic
        iscsiadm -m node -T $iqn -p 169.254.2.$n:3260 -l
      done
    else
      echo "Zero block volumes, not calling iscsiadm, Total Disk Count: $blockVolumesPerPool"
    fi
    # Create this file for TF script to proceed with next steps
    touch /tmp/multi-attach-iscsi.complete
fi


echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  # Run on all server nodes
  # To enable custom disk consistent devicepath discovery for nsds.
  mkdir -p /var/mmfs/etc/
  if [ -f /tmp/nsddevices ]; then
    cp /tmp/nsddevices /var/mmfs/etc/
    chmod +x /var/mmfs/etc/nsddevices
  else
    exit 1
  fi
fi


