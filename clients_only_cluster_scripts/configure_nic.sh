#   configure 2nd NIC
echo `hostname` | grep -q "$clientNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
  echo "thisFQDN=$thisFQDN  and thisHost=$thisHost"
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

# Intel or AMD
lscpu | grep "Vendor ID:"  | grep "AuthenticAMD"
if [ $? -eq 0 ];  then
  echo "do nothing"
else
  echo Intel
  # For Intel shapes, it degrades n/w performance on AMD
  ethtool -G $primaryNICInterface rx 2047 tx 2047 rx-jumbo 8191
  echo "ethtool -G $primaryNICInterface rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
  # For BM shapes only and fails on VM shapes, but harmless to still run it
  echo "ethtool -L $primaryNICInterface combined 74" >> /etc/rc.local
  chmod +x /etc/rc.local
  # node needs to be rebooted for rc.local change to be effective.  This is only required for tuning NIC for better performance
fi

# Add host info
echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh


