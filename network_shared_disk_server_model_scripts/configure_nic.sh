MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"

#   configure 2nd NIC
echo `hostname` | grep -q "$clientNodeHostnamePrefix\|$mgmtGuiNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
  echo "thisFQDN=$thisFQDN  and thisHost=$thisHost"
else
ifconfig | grep "^eno3d1:\|^enp70s0f1d1:\|^eno2d1:"
  if [ $? -eq 0 ] ; then
    echo "2 NIC setup"
    ifconfig | grep "^enp70s0f1d1:"
    if [ $? -eq 0 ] ; then
      interface="enp70s0f1d1"
    fi
    ifconfig | grep "^eno3d1:"
    if [ $? -eq 0 ] ; then
      interface="eno3d1"
    fi
    # AMD BM.Standard.E2.64
    ifconfig | grep "^eno2d1:"
    if [ $? -eq 0 ] ; then
      interface="eno2d1"
    fi

    ip route ; ifconfig ; route ; ip addr
    cd /etc/sysconfig/network-scripts/

    # Wait till 2nd NIC is configured
    privateIp=`curl -s $MDATA_VNIC_URL | jq '.[]  | select (.nicIndex == 1) | select (.vlanTag == 0) | .privateIp ' | sed 's/"//g' ` ;
    echo $privateIp | grep "\." ;
    while [ $? -ne 0 ];
    do
      sleep 10s
      echo "Waiting for 2nd Physical NIC to get configured with hostname"
      privateIp=`curl -s $MDATA_VNIC_URL | jq '.[]  | select (.nicIndex == 1) | select (.vlanTag == 0) | .privateIp ' | sed 's/"//g' ` ;
      echo $privateIp | grep "\." ;
    done

    macAddr=`curl -s $MDATA_VNIC_URL | jq '.[]  | select (.nicIndex == 1) | select (.vlanTag == 0) | .macAddr ' | sed 's/"//g' ` ;
    subnetCidrBlock=`curl -s $MDATA_VNIC_URL | jq '.[]  | select (.nicIndex == 1) | select (.vlanTag == 0) | .subnetCidrBlock ' | sed 's/"//g' ` ;

    echo "$subnetCidrBlock via $privateIp dev $interface" >  /etc/sysconfig/network-scripts/route-$interface
    echo "Permanently configure 2nd NIC...$interface"
    echo "DEVICE=$interface
HWADDR=$macAddr
ONBOOT=yes
TYPE=Ethernet
USERCTL=no
IPADDR=$privateIp
NETMASK=255.255.255.0
MTU=9000
NM_CONTROLLED=no
" > /etc/sysconfig/network-scripts/ifcfg-$interface

    lscpu | grep "Vendor ID:"  | grep "AuthenticAMD"
    if [ $? -eq 0 ];  then
      echo "do nothing - AMD"
    else
      # For Intel, it degrades n/w performance on AMD
      echo "ETHTOOL_OPTS=\"-G ${interface} rx 2047 tx 2047 rx-jumbo 8191; -L ${interface} combined 74\"" >> /etc/sysconfig/network-scripts/ifcfg-$interface
    fi

    systemctl status network.service
    ifdown $interface
    ifup $interface

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

#  configure 1st NIC
ifconfig | grep "^eno2:"
if [ $? -eq 0 ] ; then
  primaryNICInterface="eno2"
fi
ifconfig | grep "^ens3:"
if [ $? -eq 0 ] ; then
  primaryNICInterface="ens3"
fi

ifconfig | grep "^enp70s0f0:"
if [ $? -eq 0 ] ; then
  primaryNICInterface="enp70s0f0"
fi
ifconfig | grep "^eno1:"
if [ $? -eq 0 ] ; then
  primaryNICInterface="eno1"
fi

lscpu | grep "Vendor ID:"  | grep "AuthenticAMD"
if [ $? -eq 0 ];  then
  echo "do nothing - AMD"
else
  # For Intel, it degrades n/w performance on AMD
  echo "ethtool -G $primaryNICInterface rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
  echo "ethtool -L $primaryNICInterface combined 74" >> /etc/rc.local
  chmod +x /etc/rc.local
  # node needs to be rebooted for rc.local change to be effective.
fi

echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh

echo $thisHost | grep -q "$cesNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
  privateVipIp=`curl -s $MDATA_VNIC_URL | jq '.[]  | select (.nicIndex == 0) | select (.vlanTag == 1) | .privateIp ' | sed 's/"//g' ` ;
  echo $privateVipIp | grep "\." ;
  while [ $? -ne 0 ];
  do
    sleep 10s
    echo "Waiting for IP of VNIC to get configured..."
    privateVipIp=`curl -s $MDATA_VNIC_URL | jq '.[]  | select (.nicIndex == 0) | select (.vlanTag == 1) | .privateIp ' | sed 's/"//g' ` ;
    echo $privateVipIp | grep "\." ;
  done
  echo "$privateVipIp" >> /tmp/ces_vip_ips
fi
