

# download spectrum scale
cd /tmp/
curl -O $downloadUrl -s

# logic to ensure if download fails due to intermittent error
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
rpm -Uvh ${rpmDownloadURLPrefix}/kernel-devel-${kernelVersion}.rpm
rpm -Uvh ${rpmDownloadURLPrefix}/kernel-headers-${kernelVersion}.rpm


yum -y install psmisc numad numactl iperf3 dstat iproute automake autoconf git

# for the protocol/ces nodes.
echo "$thisHost" | grep -q $cesNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  # (for Active Directory integration)
  yum install -y nfs-utils bind-utils
  # (for LDAP integration)
  yum install -y nfs-utils openldap-client sssd-common sssd-ldap
fi

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
