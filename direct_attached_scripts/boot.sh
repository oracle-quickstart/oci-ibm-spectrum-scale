
set -x 

function set_env_variables {
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
}


echo "
version=\"$version\"
downloadUrl=\"$downloadUrl\"
sshPrivateKey=\"$sshPrivateKey\"
sshPublicKey=\"$sshPublicKey\"
clientNodeCount=\"$clientNodeCount\"
clientNodeHostnamePrefix=\"$clientNodeHostnamePrefix\"
blockSize=\"$blockSize\"
dataReplica=\"$dataReplica\"
metadataReplica=\"$metadataReplica\"
gpfsMountPoint=\"$gpfsMountPoint\"
sharedDataDiskCount=\"$sharedDataDiskCount\"
installerNode=\"$installerNode\"
privateSubnetsFQDN=\"$privateSubnetsFQDN\"
quorumNodeCount=\"$quorumNodeCount\"
quorumNodeHostnamePrefix=\"$quorumNodeHostnamePrefix\"
" > /tmp/gpfs_env_variables.sh


set_env_variables
# required to include in this file
echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh


#######################################################"
################# Turn Off the Firewall ###############"
#######################################################"
echo "Turning off the Firewall..."
which apt-get &> /dev/null
if [ $? -eq 0 ] ; then
    echo "" > /etc/iptables/rules.v4
    echo "" > /etc/iptables/rules.v6

    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
else
    service firewalld stop
    chkconfig firewalld off
fi

#######################################################"
#################   Update resolv.conf  ###############"
#######################################################"
## Modify resolv.conf to ensure DNS lookups work from one private subnet to another subnet
cp /etc/resolv.conf /etc/resolv.conf.backup
rm -f /etc/resolv.conf
echo "search ${privateSubnetsFQDN}" > /etc/resolv.conf
echo "nameserver 169.254.169.254" >> /etc/resolv.conf

# The below is to ensure any custom change to hosts and resolv.conf will not be overwritten with data from metaservice, but dhclient will still overwrite resolv.conf.
if [ -z /etc/oci-hostname.conf ]; then
  echo "PRESERVE_HOSTINFO=2" > /etc/oci-hostname.conf
else
  # https://docs.cloud.oracle.com/iaas/Content/Network/Tasks/managingDHCP.htm#notes
  sed -i "s/^PRESERVE_HOSTINFO/#PRESERVE_HOSTINFO/g" /etc/oci-hostname.conf
  echo "PRESERVE_HOSTINFO=2" >> /etc/oci-hostname.conf
fi
# The below is to ensure above changes will not be overwritten by dhclient
chattr +i /etc/resolv.conf

#######################################################"

#####
echo "$sshPrivateKey" > /root/.ssh/id_rsa
echo "$sshPublicKey" > /root/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa*
chmod 640 ~/.ssh/authorized_keys


cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
#service sshd restart

mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys
cd /root/.ssh/; cat id_rsa.pub >> authorized_keys ; cd -

find_cluster_nodes () {
  # Make a list of nodes in the cluster
  echo "Doing nslookup for $nodeType nodes"
  ct=1
  if [ $nodeCount -gt 0 ]; then
    while [ $ct -le $nodeCount ]; do
      nslk=`nslookup $nodeHostnamePrefix${ct}.$domainName`
      ns_ck=`echo -e $?`
      if [ $ns_ck = 0 ]; then
        hname=`nslookup $nodeHostnamePrefix${ct}.$domainName | grep Name | gawk '{print $2}'`
        echo "$hname" >> /tmp/${nodeType}nodehosts;
        echo "$hname" >> /tmp/allnodehosts;
        ct=$((ct+1));
      else
        # sleep 10 seconds and check again - infinite loop
        echo "Sleeping for 10 secs and will check again for nslookup $nodeHostnamePrefix${ct}.$domainName"
        sleep 10
      fi
    done;
    echo "Found `cat /tmp/${nodeType}nodehosts | wc -l` $nodeType nodes";
    echo `cat /tmp/${nodeType}nodehosts`;
  else
    echo "no $nodeType nodes configured"
  fi
}

# Subnet used for GPFS network
domainName=${privateSubnetsFQDN}

nodeType="client"
nodeHostnamePrefix=$clientNodeHostnamePrefix
nodeCount=$clientNodeCount
find_cluster_nodes

nodeType="quorum"
nodeHostnamePrefix=$quorumNodeHostnamePrefix
nodeCount=$quorumNodeCount
find_cluster_nodes



if [ ! -f ~/.ssh/known_hosts ]; then
        touch ~/.ssh/known_hosts
fi

do_ssh_keyscan () {
  if [ -z `ssh-keygen -F $host` ]; then
    ssh-keyscan -H $host > /tmp/keyscan
    cat /tmp/keyscan | grep "ssh-rsa"
    while [ $? -ne 0 ]; do
      sleep 10s;
      ssh-keyscan -H $host > /tmp/keyscan
      cat /tmp/keyscan | grep "ssh-rsa"
    done;
      ssh-keyscan -H $host >> ~/.ssh/known_hosts
  fi
}

### passwordless ssh setup
for host_fqdn in `cat /tmp/allnodehosts` ; do
  host=$host_fqdn
  do_ssh_keyscan
  host=${host_fqdn%%.*}
  do_ssh_keyscan
  host_ip=`nslookup $host_fqdn | grep "Address: " | gawk '{print $2}'`
  host=$host_ip
  do_ssh_keyscan
  # update /etc/hosts file on all nodes with ip, fqdn and hostname of all nodes
  echo "$host_ip ${host_fqdn} ${host_fqdn%%.*}" >> /etc/hosts
done ;

#####



# added logic to quorum node to create this file also.  
# Wait for multi-attach of the Block volumes to complete.
while [ ! -f /tmp/multi-attach.complete ]
do
  sleep 60s
  echo "Waiting for multi-attach via oci-cli to  complete ..."
done


# Run the iscsi commands
# iscsiadm discovery/login
# loop over various ip's but needs to only attempt disks that actually
# do/will exist.

# Compute nodes will only have Shared Data disk attached and Server nodes requires both metadata and data nodes attached (IBM requirement)
echo "$thisHost" | grep -q $clientNodeHostnamePrefix
if [ $? -eq 100 ] ; then
  total_disk_count=$sharedDataDiskCount

if [ $total_disk_count -gt 0 ] ;
then
  echo "Number of disks : $total_disk_count"
  for n in `seq 2 $((total_disk_count+1))`; do
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
  echo "Zero block volumes, not calling iscsiadm, Total Disk Count: $((total_disk_count))"
fi

touch /tmp/multi-attach-iscsi.complete
fi

touch /tmp/multi-attach-iscsi.complete


#############
# Needed on all nodes for direct attached model
##echo "$thisHost" | grep -q $clientNodeHostnamePrefix
##if [ $? -eq 0 ] ; then
  # To enable custom disk consistent devicepath discovery for nsds.
  mkdir -p /var/mmfs/etc/
  if [ -f /tmp/nsddevices ]; then
    cp /tmp/nsddevices /var/mmfs/etc/
    chmod +x /var/mmfs/etc/nsddevices
  else
    exit 1
  fi
##fi


############



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

echo '[spectrum_scale-object-rhel8]
name = Spectrum Scale - Object
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/object_rpms/rhel8
gpgcheck=0
enabled=1
[spectrum_scale-gpfs-rhel]
name = Spectrum Scale - rhel
baseurl = file:///usr/lpp/mmfs/$spec_scale_ver/gpfs_rpms/rhel
gpgcheck=0
enabled=1
' >> /etc/yum.repos.d/spectrum-scale.repo



yum clean all
yum makecache
rerun=false
yum -y install  cpp gcc gcc-c++ binutils
if [ $? -ne 0 ]; then
  rerun=true
fi

function downloadKernelRPMs {
  # eg: "kernel-devel"
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

  ## now loop through the above array
  ## You can access them using echo "${rpmServers[0]}", "${rpmServers[1]}" also
  # while ${#rpmServers[@]} gives the length of the array
  # Note that the double quotes around "${arr[@]}" are really important. Without them, the for loop will break up the array by substrings separated by any spaces within the strings instead of by whole string elements within the array. ie: if you had declare -a arr=("element 1" "element 2" "element 3"), then for i in ${arr[@]} would mistakenly iterate 6 times since each string becomes 2 substrings separated by the space in the string, whereas for i in "${arr[@]}" would iterate 3 times, correctly
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
# function call
downloadKernelRPMs "kernel-devel"
downloadKernelRPMs "kernel-headers"


# pass this parameter --oldpackage in rpm -Uvh command,  if the package is older than current kernel version.
rpm -Uvh kernel-devel-${kernelVersion}.rpm  --oldpackage
rpm -Uvh kernel-headers-${kernelVersion}.rpm --oldpackage

if [ "$rerun" = "true" ]; then
  yum -y install  cpp gcc gcc-c++ binutils
fi

yum -y install psmisc numad numactl iperf3 dstat iproute automake autoconf git

  #non-GUI node:
  yum -y install gpfs.base gpfs.gpl gpfs.msg.en_US gpfs.gskit gpfs.license* gpfs.ext gpfs.crypto gpfs.compression gpfs.adv gpfs.gss.pmsensors gpfs.docs gpfs.java gpfs.kafka gpfs.librdkafka

sed -i '/distroverpkg/a exclude=kernel*' /etc/yum.conf


#################


function tune_interface {
  ethtool -G $interface rx 2047 tx 2047 rx-jumbo 8191
  echo "ethtool -G $interface rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
  chmod +x /etc/rc.local
}

MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"

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


echo '#
# Identify eligible SCSI disks by the absence of a SWAP partition.
# The only attribute that should possibly be changed is max_sectors_kb,
# up to a value of 8192, depending on what the SCSI driver and disks support.
#
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd*[^0-9]", PROGRAM="/usr/bin/lsblk -rno FSTYPE,MOUNTPOINT,NAME /dev/%k", RESULT!="*SWAP*", ATTR{queue/scheduler}="deadline", ATTR{queue/nr_requests}="256", ATTR{device/queue_depth}="31", ATTR{queue/max_sectors_kb}="8192", ATTR{queue/read_ahead_kb}="0", ATTR{queue/rq_affinity}="2"
' > /etc/udev/rules.d/99-ibm-spectrum-scale.rules
# Run this to load the rules
udevadm control --reload-rules && udevadm trigger


mv /etc/yum.repos.d/epel.repo  /etc/yum.repos.d/epel.repo.disabled
mv /etc/yum.repos.d/epel-testing.repo  /etc/yum.repos.d/epel-testing.repo.disabled
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
setenforce 0

### OS Performance tuning
cd /usr/lib/tuned/
cp -r throughput-performance/ gpfs-oci-performance

echo "
#
# tuned configuration
#

[main]
summary=gpfs perf tuning for common gpfs workloads

[cpu]
force_latency=1
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[vm]
transparent_huge_pages=never

[sysctl]
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_adv_win_scale=2
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_syn_retries=8
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=16777216
net.core.somaxconn = 8192
net.core.netdev_max_backlog=250000
sunrpc.udp_slot_table_entries=128
sunrpc.tcp_slot_table_entries=128
kernel.sysrq = 1
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000
vm.min_free_kbytes = 16777216
vm.dirty_ratio = 30
vm.dirty_background_ratio = 10
vm.swappiness=30
" > gpfs-oci-performance/tuned.conf

cd -



# make sure client nodes they have enough memory.
echo "$thisHost" | grep -q  $clientNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  coreIdCount=`grep "^core id" /proc/cpuinfo | sort -u | wc -l` ; echo $coreIdCount
  socketCount=`echo $(($(grep "^physical id" /proc/cpuinfo | awk '{print $4}' | sort -un | tail -1)+1))` ; echo $socketCount
  if [ $((socketCount*coreIdCount)) -gt 4  ]; then
    tuned-adm profile gpfs-oci-performance
  else
    # Client with less than 4 physical cores and less 30GB memory, above tuned profile requires atleast 16GB of vm.min_free_kbytes, hence let user do manual tuning.
    echo "skip profile tuning..."
  fi ;
fi;

tuned-adm active

echo "$thisHost" | grep -q  $clientNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  echo off > /sys/devices/system/cpu/smt/control
fi

########


echo "cloud-init complete"
touch /tmp/cloud_init.complete

exit 0;




