## cloud-init bootstrap script


echo "
version=\"$version\"
downloadUrl=\"$downloadUrl\"
sshPrivateKey=\"$sshPrivateKey\"
sshPublicKey=\"$sshPublicKey\"
totalNsdNodePools=\"$totalNsdNodePools\"
nsdNodesPerPool=\"$nsdNodesPerPool\"
nsdNodeCount=\"$nsdNodeCount\"
nsdNodeHostnamePrefix=\"$nsdNodeHostnamePrefix\"
clientNodeCount=\"$clientNodeCount\"
clientNodeHostnamePrefix=\"$clientNodeHostnamePrefix\"
blockSize=\"$blockSize\"
dataReplica=\"$dataReplica\"
metadataReplica=\"$metadataReplica\"
gpfsMountPoint=\"$gpfsMountPoint\"
highAvailability=\"$highAvailability\"
sharedDataDiskCount=\"$sharedDataDiskCount\"
blockVolumesPerPool=\"$blockVolumesPerPool\"
installerNode=\"$installerNode\"
privateSubnetsFQDN=\"$privateSubnetsFQDN\"
privateBSubnetsFQDN=\"$privateBSubnetsFQDN\"
companyName=\"$companyName\"
companyID=\"$companyID\"
countryCode=\"$countryCode\"
emailaddress=\"$emailaddress\"
cesNodeCount=\"$cesNodeCount\"
cesNodeHostnamePrefix=\"$cesNodeHostnamePrefix\"
mgmtGuiNodeCount=\"$mgmtGuiNodeCount\"
mgmtGuiNodeHostnamePrefix=\"$mgmtGuiNodeHostnamePrefix\"
privateProtocolSubnetFQDN=\"$privateProtocolSubnetFQDN\"
" > /tmp/gpfs_env_variables.sh

echo "installerNode = $installerNode"
echo "$sshPrivateKey" > /root/.ssh/id_rsa
echo "$sshPublicKey" > /root/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
chmod 640 ~/.ssh/authorized_keys

# we might need this for BM shapes
sleep 60s


#   Update resolv.conf  #
## Modify resolv.conf to ensure DNS lookups work from one private subnet to another subnet
mv /etc/resolv.conf /etc/resolv.conf.backup
echo `hostname` | grep -q "$clientNodeHostnamePrefix\|$mgmtGuiNodeHostnamePrefix"
if [ $? -eq 0 ] ; then
  echo "search ${privateBSubnetsFQDN}" > /etc/resolv.conf
  echo "nameserver 169.254.169.254" >> /etc/resolv.conf
fi
echo `hostname` | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  echo "search ${privateBSubnetsFQDN} ${privateSubnetsFQDN} " > /etc/resolv.conf
  echo "nameserver 169.254.169.254" >> /etc/resolv.conf
fi

# The below is to ensure any custom change to /etc/hosts and /etc/resolv.conf will not be overwritten with data from metaservice, but dhclient will still overwrite /etc/resolv.conf.  Hence do the additional step using chattr command.
if [ -z /etc/oci-hostname.conf ]; then
  echo "PRESERVE_HOSTINFO=2" > /etc/oci-hostname.conf
else
  # https://docs.cloud.oracle.com/iaas/Content/Network/Tasks/managingDHCP.htm#notes
  sed -i "s/^PRESERVE_HOSTINFO/#PRESERVE_HOSTINFO/g" /etc/oci-hostname.conf
  echo "PRESERVE_HOSTINFO=2" >> /etc/oci-hostname.conf
fi
cat /etc/oci-hostname.conf
# The below is to ensure above changes will not be overwritten by dhclient
chattr +i /etc/resolv.conf


#   configure 2nd NIC   #
echo `hostname` | grep -q $mgmtGuiNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  echo "gui nodes - get hostname..."
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
else

fi


#  configure 1st NIC for performance   #
# First NIC names
# eno2  & ens3
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

# Check if processor is Intel or AMD
lscpu | grep "Vendor ID:"  | grep "AuthenticAMD"
if [ $? -eq 0 ];  then
  echo AMD
  # Do nothing. Use default
else
  echo Intel
  # The below are only applicable to Intel shapes, not for AMD shapes, it degrades n/w performance on AMD
  echo "ethtool -G $primaryNICInterface rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
  # the below change applies to BM shapes and fails on VM shapes, but harmless to still run it
  echo "ethtool -L $primaryNICInterface combined 74" >> /etc/rc.local
  chmod +x /etc/rc.local

fi


#
# Add host info to gpfs_env_variables.sh for other scripts to re-use
echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh
#

mv /etc/yum.repos.d/epel.repo  /etc/yum.repos.d/epel.repo.disabled
mv /etc/yum.repos.d/epel-testing.repo  /etc/yum.repos.d/epel-testing.repo.disabled
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
setenforce 0



# Display active profile
tuned-adm active


cd -

### OS Performance tuning - END

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
#service sshd restart


mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys

cd /root/.ssh/; cat id_rsa.pub >> authorized_keys ; cd -

secondNICDomainName=${thisFQDN#*.*}
echo "Doing nslookup for nodes"
ct=1
if [ $nsdNodeCount -gt 0 ]; then
        while [ $ct -le $nsdNodeCount ]; do
                nslk=`nslookup $nsdNodeHostnamePrefix${ct}.$secondNICDomainName`
                ns_ck=`echo -e $?`
                if [ $ns_ck = 0 ]; then
                        hname=`nslookup $nsdNodeHostnamePrefix${ct}.$secondNICDomainName | grep Name | gawk '{print $2}'`
                        echo "$hname" >> /tmp/nsdnodehosts;
                        echo "$hname" >> /tmp/allnodehosts;
                        ct=$((ct+1));
                else
                        # sleep 10 seconds and check again - infinite loop
                        echo "Sleeping for 10 secs and will check again for nslookup $nsdNodeHostnamePrefix${ct}.$secondNICDomainName"
                        sleep 10
                fi
        done;
        echo "Found `cat /tmp/nsdnodehosts | wc -l` nodes";
        echo `cat /tmp/nsdnodehosts`;
else
        echo "no server nodes configured"
fi


echo "Doing nslookup for nodes"
ct=1;
if [ $clientNodeCount -gt 0 ]; then
        while [ $ct -le $clientNodeCount ]; do
                nslk=`nslookup $clientNodeHostnamePrefix$ct`
                ns_ck=`echo -e $?`
                if [ $ns_ck = 0 ]; then
                        hname=`nslookup $clientNodeHostnamePrefix$ct | grep Name | gawk '{print $2}'`
                        echo "$hname" >> /tmp/clientnodehosts;
                        echo "$hname" >> /tmp/allnodehosts;
                        ct=$((ct+1));
                else
                        # sleep 10 seconds and check again - infinite loop
                        echo "Sleeping for 10 secs and will check again for nslookup $clientNodeHostnamePrefix$ct"
                        sleep 10
                fi
        done;
        echo "Found `cat /tmp/clientnodehosts | wc -l` nodes";
        echo `cat /tmp/clientnodehosts`;
else
        echo "no compute nodes configured"
fi

echo "Doing nslookup for nodes"
ct=1
if [ $mgmtGuiNodeCount -gt 0 ]; then
        while [ $ct -le $mgmtGuiNodeCount ]; do
                nslk=`nslookup $mgmtGuiNodeHostnamePrefix${ct}`
                ns_ck=`echo -e $?`
                if [ $ns_ck = 0 ]; then
                        hname=`nslookup $mgmtGuiNodeHostnamePrefix${ct} | grep Name | gawk '{print $2}'`
                        echo "$hname" >> /tmp/mgmtguinodehosts;
                        echo "$hname" >> /tmp/allnodehosts;
                        ct=$((ct+1));
                else
                        # sleep 10 seconds and check again - infinite loop
                        echo "Sleeping for 10 secs and will check again for nslookup $mgmtGuiNodeHostnamePrefix${ct}"
                        sleep 10
                fi
        done;
        echo "Found `cat /tmp/mgmtguinodehosts | wc -l` nodes";
        echo `cat /tmp/mgmtguinodehosts`;
else
        echo "no mgmt gui nodes configured"
fi


if [ ! -f ~/.ssh/known_hosts ]; then
        touch ~/.ssh/known_hosts
fi





### download spectrum scale ###
cd /tmp/
curl -O $downloadUrl -s

# logic to ensure if download fails due to intermittent error, it re-downloads.
while [ $? -ne 0 ]; do
  rm -rf /tmp/Spectrum_Scale_Data_Management-*
  curl -O $downloadUrl -s
done

while [ ! -f /tmp/Spectrum_Scale_Data_Management-${version}-x86_64-Linux-install ];
do
  sleep 5s
  echo "Waiting for file to download"
done


chmod +x Spectrum_Scale_Data_Management-${version}-x86_64-Linux-install
./Spectrum_Scale_Data_Management-${version}-x86_64-Linux-install --silent

echo "$version" > /etc/yum/vars/spec_scale_ver

echo '[spectrum_scale-gpfs]
name = Spectrum Scale - GPFS
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms
gpgcheck=0
enabled=1
[spectrum_scale-gpfs-optional]
name = Spectrum Scale - GPFS
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel7
gpgcheck=0
enabled=1
[spectrum_scale-ganesha]
name = Spectrum Scale - NFS-Ganesha
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/ganesha_rpms/rhel7
gpgcheck=0
enabled=1
[spectrum_scale-smb]
name = Spectrum Scale - SMB
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/smb_rpms/rhel7
gpgcheck=0
enabled=1
[spectrum_scale-object]
name = Spectrum Scale - Object
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/object_rpms/rhel7
gpgcheck=0
enabled=1
[spectrum_scale-zimon]
name = Spectrum Scale - Zimon
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/zimon_rpms/rhel7
gpgcheck=0
enabled=1' > /etc/yum.repos.d/spectrum-scale.repo


yum clean all
yum makecache

yum -y install  cpp gcc gcc-c++ binutils
kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
yum install -y redhat-lsb-core
lsb_release -a
osVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }' | gawk -F"." '{ print $1"."$2 }' ` ; echo $osVersion
rpmDownloadURLPrefix="http://ftp.scientificlinux.org/linux/scientific/${osVersion}/x86_64/updates/security"
curl -O ${rpmDownloadURLPrefix}/kernel-devel-${kernelVersion}.rpm
curl -O ${rpmDownloadURLPrefix}/kernel-headers-${kernelVersion}.rpm
# --oldpackage
rpm -Uvh kernel-devel-${kernelVersion}.rpm --oldpackage
rpm -Uvh kernel-headers-${kernelVersion}.rpm --oldpackage


yum -y install psmisc numad numactl iperf3 dstat iproute automake autoconf git
#yum -y update

echo "$thisHost" | grep -q $mgmtGuiNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  # For GUI node:
  yum -y install gpfs.base gpfs.gpl gpfs.msg.en_US gpfs.gskit gpfs.license* gpfs.ext gpfs.crypto gpfs.compression gpfs.adv gpfs.gss.pmsensors gpfs.docs gpfs.java gpfs.kafka gpfs.librdkafka gpfs.gui gpfs.gss.pmcollector
else
  # For non-GUI node:
  yum -y install gpfs.base gpfs.gpl gpfs.msg.en_US gpfs.gskit gpfs.license* gpfs.ext gpfs.crypto gpfs.compression gpfs.adv gpfs.gss.pmsensors gpfs.docs gpfs.java gpfs.kafka gpfs.librdkafka
fi

sed -i '/distroverpkg/a exclude=kernel*' /etc/yum.conf


echo "cloud-init complete"
touch /tmp/cloud_init.complete

#reboot



