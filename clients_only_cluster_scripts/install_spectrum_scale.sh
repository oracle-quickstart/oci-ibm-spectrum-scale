

# download SS
cd /tmp/
curl -O $downloadUrl -s

# if download fails due to intermittent error
while [ $? -ne 0 ]; do
  rm -rf /tmp/Spectrum_Scale_Data_Management-*
  rm -rf "/tmp/Spectrum Scale*"
  curl -O $downloadUrl -s
done

echo $downloadUrl | grep "Developer" | grep "zip$"
if [ $? -eq 0 ]; then
  SS_DE=true
  zip_filepath=`ls /tmp/*  | grep "Developer" | grep "${version}" | grep "zip$" `
  unzip "$zip_filepath"
  install_dir=`ls -d  /tmp/*/ | grep "Developer" | grep "Edition" `
  cd """$install_dir"""
  cp Spectrum_Scale_Developer-${version}-x86_64-Linux-install /tmp/
  install_filepath="/tmp/Spectrum_Scale_Developer-${version}-x86_64-Linux-install"
else
  SS_DE=false
  install_filepath="/tmp/Spectrum_Scale_Data_Management-${version}-x86_64-Linux-install"
fi

while [ ! -f $install_filepath ];
do
  sleep 5s
  echo "Waiting for download"
done

chmod +x $install_filepath
$install_filepath --silent


echo "$version" > /etc/yum/vars/spec_scale_ver

echo '[spectrum_scale-gpfs]
name = Spectrum Scale - GPFS
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms
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

echo $version | egrep "5.0.5|5.0.4"
if ( [ $? -eq 0 ] ); then
echo '[spectrum_scale-gpfs-optional-5050]
name = Spectrum Scale - GPFS-5050
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel
gpgcheck=0
enabled=1
[spectrum_scale-gpfs-optional-5050]
name = Spectrum Scale - GPFS-5050
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel/rhel7
gpgcheck=0
enabled=1' >> /etc/yum.repos.d/spectrum-scale.repo
elif  ( [ "$version" = "5.0.3.2" ] || [ "$version" = "5.0.3.3" ] ); then
echo '[spectrum_scale-gpfs-optional-503X]
name = Spectrum Scale - GPFS-503X
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel7
gpgcheck=0
enabled=1' >> /etc/yum.repos.d/spectrum-scale.repo
else
  exit 1;
fi

yum clean all
yum makecache
rerun=false
yum -y install  cpp gcc gcc-c++ binutils
if [ $? -ne 0 ]; then
  rerun=true
fi

kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
yum install -y redhat-lsb-core
lsb_release -a
osVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }' | gawk -F"." '{ print $1"."$2 }' ` ; echo $osVersion
rpmDownloadURLPrefix="http://ftp.scientificlinux.org/linux/scientific/${osVersion}/x86_64/updates/security"
curl -O ${rpmDownloadURLPrefix}/kernel-devel-${kernelVersion}.rpm
curl -O ${rpmDownloadURLPrefix}/kernel-headers-${kernelVersion}.rpm
# --oldpackage
rpm -Uvh kernel-devel-${kernelVersion}.rpm
rpm -Uvh kernel-headers-${kernelVersion}.rpm

if [ "$rerun" = "true" ]; then
  yum -y install  cpp gcc gcc-c++ binutils
fi

yum -y install psmisc numad numactl iperf3 dstat iproute automake autoconf git

#non-GUI node:
yum -y install gpfs.base gpfs.gpl gpfs.msg.en_US gpfs.gskit gpfs.license* gpfs.ext gpfs.crypto gpfs.compression gpfs.adv gpfs.gss.pmsensors gpfs.docs gpfs.java gpfs.kafka gpfs.librdkafka

sed -i '/distroverpkg/a exclude=kernel*' /etc/yum.conf


echo "cloud-init complete"
touch /tmp/cloud_init.complete

