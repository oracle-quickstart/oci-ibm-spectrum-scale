mv /etc/resolv.conf /etc/resolv.conf.backup
echo "search ${vcnFQDN} ${privateBSubnetsFQDN} ${privateSubnetsFQDN} ${privateProtocolSubnetFQDN}" > /etc/resolv.conf
echo "nameserver 169.254.169.254" >> /etc/resolv.conf

if [ -z /etc/oci-hostname.conf ]; then
  echo "PRESERVE_HOSTINFO=2" > /etc/oci-hostname.conf
else
  # https://docs.cloud.oracle.com/iaas/Content/Network/Tasks/managingDHCP.htm#notes
  sed -i "s/^PRESERVE_HOSTINFO/#PRESERVE_HOSTINFO/g" /etc/oci-hostname.conf
  echo "PRESERVE_HOSTINFO=2" >> /etc/oci-hostname.conf
fi
# not be overwritten by dhclient
chattr +i /etc/resolv.conf
