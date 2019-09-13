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
" > /tmp/gpfs_env_variables.sh

echo "installerNode = $installerNode"
echo "$sshPrivateKey" > /root/.ssh/id_rsa
echo "$sshPublicKey" > /root/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
chmod 640 ~/.ssh/authorized_keys

# we might need this for BM shapes
sleep 60s


#######################################################"
#################   Update resolv.conf  ###############"
#######################################################"
## Modify resolv.conf to ensure DNS lookups work from one private subnet to another subnet
mv /etc/resolv.conf /etc/resolv.conf.backup
echo `hostname` | grep -q $clientNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  echo "search ${privateBSubnetsFQDN}" > /etc/resolv.conf
  echo "nameserver 169.254.169.254" >> /etc/resolv.conf
else 
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


#######################################################"
#################   configure 2nd NIC   ###############"
#######################################################"
echo `hostname` | grep -q $clientNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  echo "client nodes - get hostname..."
  thisFQDN=`hostname --fqdn`
  thisHost=${thisFQDN%%.*}
else
  ifconfig | grep "^eno3d1:\|^enp70s0f1d1:"
  if [ $? -eq 0 ] ; then
    echo "2 NIC setup"
    ifconfig | grep "^enp70s0f1d1:"
      if [ $? -eq 0 ] ; then
        interface="enp70s0f1d1"
      else
        interface="eno3d1"
      fi

      ip route
      ifconfig
      route
      ip addr

      cd /etc/sysconfig/network-scripts/

      # Wait till 2nd NIC is configured, since the GPFS cluster will use the 2nd NIC for cluster comm.
      privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp' | sed 's/"//g' ` ; echo $privateIp
      while [ -z "$privateIp" -o $privateIp = "null" ];
      do
        sleep 10s
        echo "Waiting for 2nd Physical NIC to get configured with hostname"
        privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp' | sed 's/"//g' ` ; echo $privateIp
      done
      echo "Server nodes with 2 NICs - get hostname for 2nd NIC..."

      privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp' | sed 's/"//g' ` ; echo $privateIp
      macAddr=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].macAddr' | sed 's/"//g' ` ; echo $macAddr
      subnetCidrBlock=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].subnetCidrBlock' | sed 's/"//g' ` ; echo $subnetCidrBlock
      vnicId=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId' | sed 's/"//g' ` ; echo $vnicId

      echo "$subnetCidrBlock via $privateIp dev $interface" >  /etc/sysconfig/network-scripts/route-$interface

      echo "DEVICE=$interface
HWADDR=$macAddr
ONBOOT=yes
TYPE=Ethernet
USERCTL=no
IPADDR=$privateIp
NETMASK=255.255.255.0
MTU=9000
NM_CONTROLLED=no
ETHTOOL_OPTS=\"-G ${interface} rx 2047 tx 2047 rx-jumbo 8191; -L ${interface} combined 74\"
" > /etc/sysconfig/network-scripts/ifcfg-$interface


      systemctl status network.service
      # You might see some DHCP error, ignore it.  Its not impacting any functionality I know of.
      systemctl restart network.service

      ip route ; ifconfig ; route ; ip addr ;
# Add logic to ensure the below is not empty
      secondNicFQDNHostname=`nslookup $privateIp | grep "name = " | gawk -F"=" '{ print $2 }' | sed  "s|^ ||g" | sed  "s|\.$||g"`
      thisFQDN=$secondNicFQDNHostname
      thisHost=${thisFQDN%%.*}
      secondNICDomainName=${thisFQDN#*.*}
      echo $secondNICDomainName
      primaryNICHostname="`hostname`"

    else
      # Servers with only 1 physical NIC
      echo "Server nodes with 1 physical NIC - get hostname for 1st NIC..."
      thisFQDN="`hostname --fqdn`"
      thisHost="${thisFQDN%%.*}"
    fi
fi


#######################################################"
########  configure 1st NIC for performance   #########"
#######################################################"
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

echo "MTU=9000" >> /etc/sysconfig/network-scripts/ifcfg-$primaryNICInterface
echo "NM_CONTROLLED=no" >> /etc/sysconfig/network-scripts/ifcfg-$primaryNICInterface
echo "ETHTOOL_OPTS=\"-G ${primaryNICInterface} rx 2047 tx 2047 rx-jumbo 8191; -L ${primaryNICInterface} combined 74\" " >> /etc/sysconfig/network-scripts/ifcfg-$primaryNICInterface

#######################################################"


# Add host info to gpfs_env_variables.sh for other scripts to re-use
echo "thisFQDN=\"$thisFQDN\"" >> /tmp/gpfs_env_variables.sh
echo "thisHost=\"$thisHost\"" >> /tmp/gpfs_env_variables.sh

#######################################################"

mv /etc/yum.repos.d/epel.repo  /etc/yum.repos.d/epel.repo.disabled
mv /etc/yum.repos.d/epel-testing.repo  /etc/yum.repos.d/epel-testing.repo.disabled
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
setenforce 0 



###########################
### OS Performance tuning
###########################

echo "$thisHost" | grep -q  $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then

  # The below applies for both compute and server nodes (storage)
  cd /usr/lib/tuned/
  cp -r throughput-performance/ gpfs-oci-performance


echo "
#
# tuned configuration
#

[main]
summary=Broadly applicable tuning that provides excellent performance across a variety of common server workloads

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


tuned-adm profile gpfs-oci-performance

# Display active profile
tuned-adm active
cd - 
fi


echo "$thisHost" | grep -q  $clientNodeHostnamePrefix
if [ $? -eq 0 ] ; then

  # This might be applicable only for compute-n nodes.  Its unclear from recommendations doc.  
  # require restart for the change to be effective
  echo "* soft nofile 500000" >> /etc/security/limits.conf
  echo "* soft nproc 131072" >> /etc/security/limits.conf
  echo "* hard nofile 500000" >> /etc/security/limits.conf
  echo "* hard nproc 131072" >> /etc/security/limits.conf


  # To set values for current session
  ulimit -n 500000
  ulimit -u 131072

  # check if the ulimits were updated for the current session
  ulimit -n 
  ulimit -u  

  echo "ulimit -n 500000 >>  ~/.bash_profile
  echo "ulimit -u 131072 >>  ~/.bash_profile


else
  # Assume its server node

  echo "*   soft    memlock      -1 " >> /etc/security/limits.conf
  echo "*   hard    memlock      -1 " >> /etc/security/limits.conf
  echo "*   soft    rss          -1 " >> /etc/security/limits.conf
  echo "*   hard    rss          -1 " >> /etc/security/limits.conf
  echo "*   soft    core          -1 " >> /etc/security/limits.conf
  echo "*   hard    core          -1 " >> /etc/security/limits.conf
  echo "*   soft    maxlogins     8192 " >> /etc/security/limits.conf
  echo "*   hard    maxlogins     8192 " >> /etc/security/limits.conf
  echo "*   soft    stack         -1 " >> /etc/security/limits.conf
  echo "*   hard    stack         -1 " >> /etc/security/limits.conf
  echo "*   soft    nproc         2067554 " >> /etc/security/limits.conf
  echo "*   hard    nproc         2067554 " >> /etc/security/limits.conf
  echo "* soft nofile 500000 " >> /etc/security/limits.conf
  echo "* hard nofile 500000 " >> /etc/security/limits.conf


  echo "ulimit -l unlimited" >>  ~/.bash_profile
  echo "ulimit -m unlimited" >>  ~/.bash_profile
  echo "ulimit -c unlimited" >>  ~/.bash_profile
  echo "ulimit -s unlimited" >>  ~/.bash_profile
  echo "ulimit -u 2067554" >>  ~/.bash_profile
  echo "ulimit -n 500000" >>  ~/.bash_profile


echo '#
# Identify eligible SCSI disks by the absence of a SWAP partition.
# The only attribute that should possibly be changed is max_sectors_kb,
# up to a value of 8192, depending on what the SCSI driver and disks support.
#
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd*[^0-9]", PROGRAM="/usr/bin/lsblk -rno FSTYPE,MOUNTPOINT,NAME /dev/%k", RESULT!="*SWAP*", ATTR{queue/scheduler}="deadline", ATTR{queue/nr_requests}="256", ATTR{device/queue_depth}="31", ATTR{queue/max_sectors_kb}="8192", ATTR{queue/read_ahead_kb}="0", ATTR{queue/rq_affinity}="2"
' > /etc/udev/rules.d/99-ibm-spectrum-scale.rules
# Run this to load the rules
udevadm control --reload-rules && udevadm trigger


fi

cd -


###########################
### OS Performance tuning - END
###########################





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



if [ ! -f ~/.ssh/known_hosts ]; then
        touch ~/.ssh/known_hosts
fi




echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then

  # Wait for multi-attach of the Block volumes to complete.  Only way to do that is via OCI CLI preview tool version which is called from Terraform scripts.  It then creates the below file on all nodes of the cluster.
  while [ ! -f /tmp/multi-attach.complete ]
  do
    sleep 60s
    echo "Waiting for multi-attach via oci-cli to  complete ..."
  done
fi 

## Start SSHD to prevent remote execution during this process
systemctl status sshd
systemctl stop sshd
systemctl status sshd


# Run the iscsi commands
# iscsiadm discovery/login
# loop over various ip's but needs to only attempt disks that actually
# do/will exist.
echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then

    if [ $blockVolumesPerPool -gt 0 ] ;
    then
      echo "Number of disks : $blockVolumesPerPool"
      for n in `seq 2 $((blockVolumesPerPool+1))`; do
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
      echo "Zero block volumes, not calling iscsiadm, Total Disk Count: $blockVolumesPerPool"
    fi
    # Create this file for TF script to proceed with next steps
    touch /tmp/multi-attach-iscsi.complete
fi



echo "$thisHost" | grep -q $nsdNodeHostnamePrefix
if [ $? -eq 0 ] ; then
  # Run on all server nodes
  # To enable custom disk consistent devicepath discovery for nsds.
  mkdir -p /var/mmfs/etc/
  if [ -f /tmp/nsddevices ]; then
    cp /tmp/nsddevices /var/mmfs/etc/
    chmod +x /var/mmfs/etc/nsddevices
  else 
    exit 1
  fi
fi



################################
### download spectrum scale ###
###############################
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
yum -y update
yum -y install kernel-devel cpp gcc gcc-c++ binutils kernel-headers
sed -i '/distroverpkg/a exclude=kernel*' /etc/yum.conf


echo "cloud-init complete"
touch /tmp/cloud_init.complete

reboot


