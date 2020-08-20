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
  sleep 10s
  vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ;
  RC=1
  interface=""
  while ( [ $vnic_cnt -le 1 ] || [ $RC -ne 0 ] )
  do
    systemctl restart secondnic.service
    echo "sleep 10s"
    sleep 10s
    privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
    interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
    if [ -z $interface ]; then
      # repeat loop
      RC=1
    else
      RC=0
    fi
    vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ;
  done

}

function configure_2nd_VNIC {

      configure_vnics
      # check if 1 or 2 VNIC.
      vnic_count=`curl -s $MDATA_VNIC_URL | jq '. | length'`

      if [ $vnic_count -gt 1 ] ; then
        echo "2 VNIC setup"

        privateIp=`curl -s $MDATA_VNIC_URL | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
        interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface

        if [ "$intel_node" = "true" ];  then
          if [ "$hpc_node" = "true" ];  then
            echo "don't tune on hpc shape"
          else
            tune_interface
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
        set_env_variables
      fi
}

function tune_interface {
  ethtool -G $interface rx 2047 tx 2047 rx-jumbo 8191
  ethtool -L $interface combined 74
  echo "ethtool -G $interface rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
  echo "ethtool -L $interface combined 74" >> /etc/rc.local
  chmod +x /etc/rc.local
}

function set_env_variables {
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
}

coreIdCount=`grep "^core id" /proc/cpuinfo | sort -u | wc -l` ;
socketCount=`echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1))` ;


#  configure 1st NIC
privateIp=`curl -s $MDATA_VNIC_URL | jq '.[0].privateIp ' | sed 's/"//g' ` ; echo $privateIp
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
    tune_interface
  fi
fi

#   configure 2nd NIC
echo `hostname` | grep -q "$clientNodeHostnamePrefix\|$mgmtGuiNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
  set_env_variables
else
  echo `hostname` | grep -q "$cesNodeHostnamePrefix"
  if [ $? -eq 0 ] ; then
    configure_2nd_VNIC
  else
      if [ "$privateSubnetsFQDN" = "$privateBSubnetsFQDN" ]; then
        set_env_variables
      else
        configure_2nd_VNIC
      fi
  fi
fi

# required to include in this file
echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh

echo $thisHost | grep -q "$cesNodeHostnamePrefix"
if [ $? -eq 0 ] ; then

  # TODO: fix it This assume 3rd in the list is VIP IP and 2nd will be for privateb subnet
  privateVipIp=`curl -s $MDATA_VNIC_URL | jq '.[2].privateIp ' | sed 's/"//g' ` ;
  echo $privateVipIp | grep "\." ;
  while [ $? -ne 0 ];
  do
    sleep 10s
    echo "Waiting for IP of VNIC to get configured..."
    privateVipIp=`curl -s $MDATA_VNIC_URL | jq '.[2].privateIp ' | sed 's/"//g' ` ;
    echo $privateVipIp | grep "\." ;
  done
  echo "$privateVipIp" >> /tmp/ces_vip_ips
fi

