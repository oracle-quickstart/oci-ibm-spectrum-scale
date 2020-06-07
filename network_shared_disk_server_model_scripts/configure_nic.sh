MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"

function configure_vnics {
  # Configure second vNIC
  scriptsource="https://raw.githubusercontent.com/oracle/terraform-examples/master/examples/oci/connect_vcns_using_multiple_vnics/scripts/secondary_vnic_all_configure.sh"
  vnicscript=/root/secondary_vnic_all_configure.sh
  curl -s $scriptsource > $vnicscript
  chmod +x $vnicscript
  cat > /etc/systemd/system/secondnic.service << EOF
[Unit]
Description=Script to configure a secondary vNIC

[Service]
Type=oneshot
ExecStart=$vnicscript -c
ExecStop=$vnicscript -d
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

EOF

  systemctl enable secondnic.service
  systemctl start secondnic.service
  vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ;
  RC=1
  while ( [ $vnic_cnt -le 1 ] || [ $RC -ne 0 ] )
  do
    echo "sleep 10s"
    sleep 10
    systemctl restart secondnic.service
    RC=$?
    # sometimes takes awhile after restart
    sleep 5s
    vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ;
  done

}

coreIdCount=`grep "^core id" /proc/cpuinfo | sort -u | wc -l` ;
socketCount=`echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1))` ;


#  configure 1st NIC
privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[0].privateIp ' | sed 's/"//g' ` ; echo $privateIp
interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface

hpc_node=false
intel_node=true
lscpu | grep "Vendor ID:"  | grep "AuthenticAMD"
if [ $? -eq 0 ];  then
  echo "do nothing - AMD"
  intel_node=false
else
  if [ $((socketCount*coreIdCount)) -eq 36  ]; then
    echo "skip for hpc"
    hpc_node=true
  else
    echo "ethtool -G $interface rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
    echo "ethtool -L $interface combined 74" >> /etc/rc.local
    chmod +x /etc/rc.local
  fi
fi

#   configure 2nd NIC
echo `hostname` | grep -q "$clientNodeHostnamePrefix\|$mgmtGuiNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
  echo "thisFQDN=$thisFQDN  and thisHost=$thisHost"
else

  configure_vnics
  # check if 1 or 2 VNIC.
  vnic_count=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '. | length'`

  if [ $vnic_count -gt 1 ] ; then
    echo "2 VNIC setup"

    privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
    interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface

    if [ "$intel_node" = "true" ];  then
      if [ "$hpc_node" = "true" ];  then
        echo "don't tune on hpc shape"
      else
        echo "ETHTOOL_OPTS=\"-G ${interface} rx 2047 tx 2047 rx-jumbo 8191; -L ${interface} combined 74\"" >> /etc/sysconfig/network-scripts/ifcfg-$interface
      fi
    fi

    # ensure the below is not empty
    test=`nslookup $privateIp | grep -q "name = "`
    while [ $? -ne 0 ];
    do
      echo "Waiting for nslookup..."
      sleep 10s
      test=`nslookup $privateIp | grep -q "name = "`
    done

    secondNicFQDNHostname=`nslookup $privateIp | grep "name = " | gawk -F"=" '{ print $2 }' | sed  "s|^ ||g" | sed  "s|\.$||g"`
    thisFQDN=$secondNicFQDNHostname
    thisHost=${thisFQDN%%.*}
    secondNICDomainName=${thisFQDN#*.*}
    echo $secondNICDomainName
    primaryNICHostname="`hostname`"

  else
    echo "Server nodes with 1 physical NIC - get hostname for 1st NIC..."
    thisFQDN="`hostname --fqdn`"
    thisHost="${thisFQDN%%.*}"
  fi
fi

# required to include in this file
echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh

echo $thisHost | grep -q "$cesNodeHostnamePrefix"
if [ $? -eq 0 ] ; then

  # NOTE:  This assume 2nd in the list is VIP IP and 3rd will be for privateb subnet
  privateVipIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ;
  echo $privateVipIp | grep "\." ;
  while [ $? -ne 0 ];
  do
    sleep 10s
    echo "Waiting for IP of VNIC to get configured..."
    privateVipIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ;
    echo $privateVipIp | grep "\." ;
  done
  echo "$privateVipIp" >> /tmp/ces_vip_ips
fi

