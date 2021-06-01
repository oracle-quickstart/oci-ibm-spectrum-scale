

cd /tmp/
curl -O $downloadUrl -s

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
[spectrum_scale-zimon]
name = Spectrum Scale - Zimon
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/zimon_rpms/rhel7
gpgcheck=0
enabled=1
[spectrum_scale-gpfs-optional]
name = Spectrum Scale - GPFS optional
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel
gpgcheck=0
enabled=1
' > /etc/yum.repos.d/spectrum-scale.repo

echo $version | egrep "5.0.5|5.0.4"
if ( [ $? -eq 0 ] ); then
echo '[spectrum_scale-object]
name = Spectrum Scale - Object
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/object_rpms/rhel7
gpgcheck=0
enabled=1
[spectrum_scale-gpfs-optional-5050]
name = Spectrum Scale - GPFS-5050
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel/rhel7
gpgcheck=0
enabled=1' >> /etc/yum.repos.d/spectrum-scale.repo
fi


yum clean all
yum makecache
rerun=false
yum -y install  cpp gcc gcc-c++ binutils
if [ $? -ne 0 ]; then
  rerun=true
fi

function downloadKernelRPMs {
  packagePrefix=$1
  kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
  sudo yum install -y -q  redhat-lsb-core
  lsb_release -a
  osVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }' | gawk -F"." '{ print $1"."$2 }' ` ; echo $osVersion
  fullOSReleaseVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }'` ; echo $fullOSReleaseVersion

  declare -a rpmServers=("http://linuxsoft.cern.ch/centos-vault/${fullOSReleaseVersion}/updates/x86_64/Packages"
                "http://repo1.xorcom.com/repos/centos/7/x86_64/Updates_OS_X86_64/Packages/k"
                "http://ftp.scientificlinux.org/linux/scientific/${osVersion}/x86_64/updates/security"
                "http://archive.kernel.org/centos-vault/${fullOSReleaseVersion}/updates/x86_64/Packages"
                )

  for rpmDownloadURLPrefix in "${rpmServers[@]}"
  do
    echo "$rpmDownloadURLPrefix"
    curl --head --fail --silent ${rpmDownloadURLPrefix}/${packagePrefix}-${kernelVersion}.rpm
    if [ $? -eq 0 ]; then
      curl -O ${rpmDownloadURLPrefix}/${packagePrefix}-${kernelVersion}.rpm
      if [ $? -eq 0 ]; then
        break;
      fi
    fi
  done
}
kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
downloadKernelRPMs "kernel-devel"
downloadKernelRPMs "kernel-headers"
# --oldpackage
rpm -Uvh kernel-devel-${kernelVersion}.rpm
rpm -Uvh kernel-headers-${kernelVersion}.rpm

if [ "$rerun" = "true" ]; then
  yum -y install  cpp gcc gcc-c++ binutils
fi

yum -y install psmisc numad numactl iperf3 dstat iproute automake autoconf git

echo "$thisHost" | grep -q $cesNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  # AD
  yum install -y nfs-utils bind-utils
  # LDAP
  yum install -y nfs-utils openldap-client sssd-common sssd-ldap
fi

echo "$thisHost" | grep -q $mgmtGuiNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  #GUI node:
  yum -y install gpfs.base gpfs.gpl gpfs.msg.en_US gpfs.gskit gpfs.license* gpfs.ext gpfs.crypto gpfs.compression gpfs.adv gpfs.gss.pmsensors gpfs.docs gpfs.java gpfs.kafka gpfs.librdkafka gpfs.gui gpfs.gss.pmcollector
else
  yum -y install gpfs.base gpfs.gpl gpfs.msg.en_US gpfs.gskit gpfs.license* gpfs.ext gpfs.crypto gpfs.compression gpfs.adv gpfs.gss.pmsensors gpfs.docs gpfs.java gpfs.kafka gpfs.librdkafka
fi

sed -i '/distroverpkg/a exclude=kernel*' /etc/yum.conf


echo "cloud-init complete"
touch /tmp/cloud_init.complete
