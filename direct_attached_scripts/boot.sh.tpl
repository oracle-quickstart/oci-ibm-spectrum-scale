#!/bin/bash
## cloud-init bootstrap script

set -x 

THIS_FQDN=`hostname --fqdn`
THIS_HOST=$${THIS_FQDN%%.*}

INSTALLERNODE=${InstallerNode}
echo "INSTALLERNODE = $INSTALLERNODE"

SSHPRIVATEKEY="${SSHPrivateKey}"
SSHPUBLICKEY="${SSHPublicKey}"
echo "$SSHPRIVATEKEY" > /root/.ssh/id_rsa
echo "$SSHPUBLICKEY" > /root/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa.pub
chmod 640 ~/.ssh/authorized_keys

IBMSSVERSION="${IBMSSVersion}"
SOFTWAREDOWNLOADURL="${SoftwareDownloadURL}"
SERVERNODECOUNT="${ServerNodeCount}"
SERVERNODEHOSTNAMEPREFIX="${ServerNodeHostnamePrefix}"
COMPUTENODECOUNT="${ComputeNodeCount}"
COMPUTENODEHOSTNAMEPREFIX="${ComputeNodeHostnamePrefix}"


BLOCKSIZE="${BlockSize}"
DATAREPLICA="${DataReplica}"
GPFSMOUNTPOINT="${GpfsMountPoint}"
SharedMetaDataDiskCount="${SharedMetaDataDiskCount}"
SharedDataDiskCount="${SharedDataDiskCount}"
## Preconfigured. 
METADATAREPLICA=2 

COMPANYNAME="${CompanyName}"
COMPANYID="${CompanyID}"
COUNTRYCODE="${CountryCode}"
EMAILADDRESS="${EmailAddress}"

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
echo "search ${PrivateSubnetsFQDN}" > /etc/resolv.conf
echo "nameserver 169.254.169.254" >> /etc/resolv.conf

#######################################################"

mv /etc/yum.repos.d/epel.repo  /etc/yum.repos.d/epel.repo.disabled
mv /etc/yum.repos.d/epel-testing.repo  /etc/yum.repos.d/epel-testing.repo.disabled
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0 

KERNALVERSION=`uname -a  | gawk -F" " '{ print $3 }' | sed "s|.x86_64||g"`


#wget ftp://ftp.icm.edu.pl/vol/rzm3/linux-scientificlinux/7.5/x86_64/updates/security/kernel-headers-3.10.0-862.11.6.el7.x86_64.rpm
#wget ftp://ftp.icm.edu.pl/vol/rzm3/linux-slc/centos/7.1.1503/updates/x86_64/Packages/kernel-devel-3.10.0-862.11.6.el7.x86_64.rpm
#yum install cpp gcc gcc-c++ -y
#yum erase kernel-headers-3.10.0 -y 
sudo yum install kernel-devel-$KERNALVERSION  -y
yum install kernel-headers-$KERNALVERSION -y 
#yum install kernel-headers-3.10.0-862.11.6.el7.x86_64.rpm -y 
#yum install kernel-devel-3.10.0-862.11.6.el7.x86_64.rpm -y
yum install gcc gcc-c++ -y 



cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
service sshd restart


mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys


#cat /dev/zero | ssh-keygen -b 2048 -t rsa -q -N "" > /dev/null


echo "export PATH=$PATH:/usr/lpp/mmfs/bin" >> ~/.bash_profile
# turn debug for mm* commands
echo "export DEBUG=1" >> ~/.bash_profile
# source ~/.bash_profile
. ~/.bash_profile


cd /root/.ssh/; cat id_rsa.pub >> authorized_keys ; cd - 


echo "Doing nslookup for nodes"
ct=1;
if [ $SERVERNODECOUNT -gt 0 ]; then
        while [ $ct -le $SERVERNODECOUNT ]; do
                nslk=`nslookup $SERVERNODEHOSTNAMEPREFIX$ct`
                ns_ck=`echo -e $?`
                if [ $ns_ck = 0 ]; then
                        hname=`nslookup $SERVERNODEHOSTNAMEPREFIX$ct | grep Name | gawk '{print $2}'`
                        echo "$hname" >> /tmp/servernodehosts;
                        echo "$hname" >> /tmp/allnodehosts;
                        if [ $ct -le 2 ]; then
				echo "$hname" >> /tmp/adminnodehosts;
    				echo "$hname" >> /tmp/nsdnodehosts;
			fi
                        ct=$((ct+1));
                else
                        # sleep 10 seconds and check again - infinite loop
                        echo "Sleeping for 10 secs and will check again for nslookup $SERVERNODEHOSTNAMEPREFIX$ct"
                        sleep 10
                fi
        done;
        echo "Found `cat /tmp/servernodehosts | wc -l` nodes";
        echo `cat /tmp/servernodehosts`;
else
        echo "no server nodes configured"
fi


echo "Doing nslookup for nodes"
ct=1;
if [ $COMPUTENODECOUNT -gt 0 ]; then
        while [ $ct -le $COMPUTENODECOUNT ]; do
                nslk=`nslookup $COMPUTENODEHOSTNAMEPREFIX$ct`
                ns_ck=`echo -e $?`
                if [ $ns_ck = 0 ]; then
                        hname=`nslookup $COMPUTENODEHOSTNAMEPREFIX$ct | grep Name | gawk '{print $2}'`
                        echo "$hname" >> /tmp/computenodehosts;
                        echo "$hname" >> /tmp/allnodehosts;
                        ct=$((ct+1));
                else
                        # sleep 10 seconds and check again - infinite loop
                        echo "Sleeping for 10 secs and will check again for nslookup $COMPUTENODEHOSTNAMEPREFIX$ct"
                        sleep 10
                fi
        done;
        echo "Found `cat /tmp/computenodehosts | wc -l` nodes";
        echo `cat /tmp/computenodehosts`;
else
        echo "no compute nodes configured"
fi



if [ ! -f ~/.ssh/known_hosts ]; then
        touch ~/.ssh/known_hosts
fi

for x_fqdn in `cat /tmp/allnodehosts` ; do

        if [ -z `ssh-keygen -F $x_fqdn` ]; then
                ssh-keyscan -H $x_fqdn > /tmp/keyscan
                cat /tmp/keyscan | grep "ssh-rsa"
                while [ $? -ne 0 ]; do
                          sleep 10s;
                          ssh-keyscan -H $x_fqdn > /tmp/keyscan
                          cat /tmp/keyscan | grep "ssh-rsa"
                done;
                ssh-keyscan -H $x_fqdn >> ~/.ssh/known_hosts
        fi


        x=$${x_fqdn%%.*}
        if [ -z `ssh-keygen -F $x` ]; then
                ssh-keyscan -H $x > /tmp/keyscan
                cat /tmp/keyscan | grep "ssh-rsa"
                while [ $? -ne 0 ]; do
                          sleep 10s;
                          ssh-keyscan -H $x > /tmp/keyscan
                          cat /tmp/keyscan | grep "ssh-rsa"
                done;
                ssh-keyscan -H $x  >> ~/.ssh/known_hosts
        fi

        ip=`nslookup $x_fqdn | grep "Address: " | gawk '{print $2}'`
        if [ -z `ssh-keygen -F $ip` ]; then
                ssh-keyscan -H $ip > /tmp/keyscan
                cat /tmp/keyscan | grep "ssh-rsa"
                while [ $? -ne 0 ]; do
                          sleep 10s;
                          ssh-keyscan -H $ip > /tmp/keyscan
                          cat /tmp/keyscan | grep "ssh-rsa"
                done;
                ssh-keyscan -H $ip  >> ~/.ssh/known_hosts
        fi

done ;

# Wait for multi-attach of the Block volumes to complete.  Only way to do that is via OCI CLI preview tool version which is called from Terraform scripts.  
# It then creates the below file on all nodes of the cluster. 
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
echo "$THIS_HOST" | grep -q $COMPUTENODEHOSTNAMEPREFIX
if [ $? -eq 0 ] ; then
  total_disk_count=$SharedDataDiskCount
else
  total_disk_count=$((SharedDataDiskCount+SharedMetaDataDiskCount))
fi

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
  echo "Zero block volumes, not calling iscsiadm, Total Disk Count: $((SharedDataDiskCount+SharedMetaDataDiskCount))"
fi

touch /tmp/multi-attach-iscsi.complete

#############
echo $IBMSSVERSION
cd /tmp
wget  "$SOFTWAREDOWNLOADURL"

while [ $? -ne 0 ]; do
  rm -rf /tmp/Scale_dme_install-$${IBMSSVERSION}_x86_64.tar
  wget  "$SOFTWAREDOWNLOADURL"
done

while [ ! -f /tmp/Scale_dme_install-$${IBMSSVERSION}_x86_64.tar ];
do
        sleep 5s
        echo "Waiting for file to download"
done

tar -xvf /tmp/Scale_dme_install-$${IBMSSVERSION}_x86_64.tar
./Spectrum_Scale_Data_Management-$${IBMSSVERSION}-x86_64-Linux-install --silent
cd /usr/lpp/mmfs/$${IBMSSVERSION}/gpfs_rpms
yum install  gpfs.base*.rpm gpfs.gpl*rpm gpfs.license*rpm gpfs.gskit*rpm gpfs.msg*rpm  gpfs.compression*rpm gpfs.adv*rpm gpfs.crypto*rpm -y
/usr/lpp/mmfs/bin/mmbuildgpl

# Run on all nodes
# To enable custom disk consistent devicepath discovery for nsds.
if [ -f /tmp/nsddevices ]; then
  cp /tmp/nsddevices /var/mmfs/etc/
  chmod +x /var/mmfs/etc/nsddevices
else 
  exit 1
fi


############

## To be ran on 1 of the nodes of the cluster.  We will assume node1.
echo "$THIS_HOST" | grep -q -w $INSTALLERNODE
if [ $? -eq 0 ] ; then




# Create NodeDesc file
NodeDesc="/usr/lpp/mmfs/NodesDesc"
ct=1
for x in `cat /tmp/servernodehosts` ; do
  echo "$${x}:quorum-manager" >> $NodeDesc
  ct=$((ct+1));
done ;

ct=1
for x in `cat /tmp/computenodehosts` ; do
  if [ $ct -eq 1 ]; then
    echo "$${x}:quorum" >> $NodeDesc
  else
    echo "$${x}:" >> $NodeDesc
  fi
  ct=$((ct+1));
done ;

cat $NodeDesc



# Added sleep after few of the commands below,  since they require sync work to happen before next command.  
# Create cluster
/usr/lpp/mmfs/bin/mmcrcluster -N /usr/lpp/mmfs/NodesDesc -r /usr/bin/ssh -R /usr/bin/scp
sleep 90s;
# Accept licenses
/usr/lpp/mmfs/bin/mmchlicense server --accept -N `paste -sd, /tmp/servernodehosts`
/usr/lpp/mmfs/bin/mmchlicense client --accept -N `paste -sd, /tmp/computenodehosts`
# /usr/lpp/mmfs/bin/mmchlicense server --accept -N managernodes  

/usr/lpp/mmfs/bin/mmchconfig tscCmdPortRange=60000-61000   

/usr/lpp/mmfs/bin/mmlscluster

/usr/lpp/mmfs/bin/mmstartup -a 
sleep 30s;
/usr/lpp/mmfs/bin/mmgetstate -a | tail -n +4 


# check for file on each node of the cluster
for x_fqdn in `cat /tmp/allnodehosts` ; do
        while [ ! `ssh $x_fqdn "if [ -f /tmp/multi-attach-iscsi.complete ]; then echo \"true\"; else echo \"false\" ; fi"` = "true" ]; do
        echo "Waiting for multi-attach iscsi commands complete on node: $x_fqdn ..."
        sleep 20s;
        done;
done;




StanzaFileDataOnly="/usr/lpp/mmfs/StanzaFileDataOnly"
StanzaFileMetaDataOnly="/usr/lpp/mmfs/StanzaFileMetaDataOnly"
filesystemName="fs1"
StanzaFileForFilesystem="/usr/lpp/mmfs/StanzaFile-$filesystemName"
cursor=0
total_disk_count=`ls /dev/oracleoci/oraclevd* | grep -iv "oraclevda$" |  grep -iv '[1-9]$'  | wc -l`
if [ $total_disk_count -ne $((SharedDataDiskCount+SharedMetaDataDiskCount)) ]; then
  echo "Total disk attached: $total_disk_count is less than expected count of $((SharedDataDiskCount+SharedMetaDataDiskCount))"
  exit 1
fi

for disk in `ls /dev/oracleoci/oraclevd* | grep -iv "oraclevda$" |  grep -iv '[1-9]$' `; do
  echo -e "\nProcessing $disk"
#  if [ $cursor -lt $SharedDataDiskCount ]; then
  echo $disk | grep -q "oraclevda[a-g]"
  if [ $? -ne 0 ]; then
    echo -e "%nsd: device=$disk\nnsd=nsd$cursor\nusage=dataOnly\nfailureGroup=0\n" >> "$StanzaFileDataOnly"
    echo -e "%nsd: device=$disk\nnsd=nsd$cursor\nusage=dataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
  else
    echo "wait"
    # With no Server assiged, so directly attached to all server & compute nodes. 
    #echo -e "%nsd: device=/dev/$disk\nnsd=nsd$cursor\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"
    #echo -e "%nsd: device=/dev/$disk\nnsd=nsd$cursor\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
    # With NSD Server nodes assigned
    serverlist=`paste -sd, /tmp/servernodehosts`
    echo -e "%nsd: device=$disk\nnsd=nsd$cursor\nservers=$serverlist\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFileMetaDataOnly"
    echo -e "%nsd: device=$disk\nnsd=nsd$cursor\nservers=$serverlist\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
  fi
  cursor=$((cursor+1))
done;

#echo -e "%nsd: device=/dev/sdb\nnsd=nsd10\nservers=ss-server-1\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"
#echo -e "%nsd: device=/dev/sdc\nnsd=nsd11\nservers=ss-server-1\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"
#echo -e "%nsd: device=/dev/sdb\nnsd=nsd12\nservers=ss-server-2\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"
#echo -e "%nsd: device=/dev/sdc\nnsd=nsd13\nservers=ss-server-2\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"
#echo -e "%nsd: device=/dev/sdb\nnsd=nsd14\nservers=ss-server-3\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"
#echo -e "%nsd: device=/dev/sdc\nnsd=nsd15\nservers=ss-server-3\nusage=metadataOnly\nfailureGroup=0\n" >> "$StanzaFile"

#echo -e "%nsd: device=/dev/sdb\nnsd=nsd10\nservers=ss-server-1\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
#echo -e "%nsd: device=/dev/sdc\nnsd=nsd11\nservers=ss-server-1\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
#echo -e "%nsd: device=/dev/sdb\nnsd=nsd12\nservers=ss-server-2\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
#echo -e "%nsd: device=/dev/sdc\nnsd=nsd13\nservers=ss-server-2\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
#echo -e "%nsd: device=/dev/sdb\nnsd=nsd14\nservers=ss-server-3\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"
#echo -e "%nsd: device=/dev/sdc\nnsd=nsd15\nservers=ss-server-3\nusage=metadataOnly\nfailureGroup=0\npool=system\n" >> "$StanzaFileForFilesystem"

/usr/lpp/mmfs/bin/mmcrnsd -F $StanzaFileDataOnly
sleep 30s;
/usr/lpp/mmfs/bin/mmcrnsd -F $StanzaFileMetaDataOnly
sleep 30s;
/usr/lpp/mmfs/bin/mmlsnsd -X 
####   #/usr/lpp/mmfs/bin/mmchnsd -F $StanzaFile
sleep 30s;

# Block size:  4M recommended by IBM team for SAS
/usr/lpp/mmfs/bin/mmcrfs $filesystemName -F $StanzaFileForFilesystem  -A yes -B 4M -m 1 -M 2 -n 100  -Q no -j scatter -k nfs4 -r 1 -R 2 -T $GPFSMOUNTPOINT
sleep 30s;
/usr/lpp/mmfs/bin/mmmount $filesystemName -a
sleep 30s;
df -h


# Update Max inodes and preallocated to be approx 70% of max.
##_##/usr/lpp/mmfs/bin/mmchfs $filesystemName --inode-limit 1500K:1100K
##_##sleep 30s;
echo "Printing cluster information..."
/usr/lpp/mmfs/bin/mmlscluster ; /usr/lpp/mmfs/bin/mmlsnsd -L ; /usr/lpp/mmfs/bin/mmlsdisk $filesystemName -L ; /usr/lpp/mmfs/bin/mmgetstate -a

# For troubleshooting and to get list of all mm commands which were ran
grep "+ /usr/lpp/mmfs/bin/mm" /var/log/messages




# Do this first or else the below loop will wait infinitely.
touch /tmp/complete

for x_fqdn in `cat /tmp/allnodehosts` ; do
	while [ ! `ssh $x_fqdn "if [ -f /tmp/complete ]; then echo \"true\"; else echo \"false\" ; fi"` = "true" ]; do
	sleep 20s;
	done;
done;



exit 0



else	
	# To indicate on rest of the nodes,  that boot cloud init is complete. 
	touch /tmp/complete
# end if loop
fi

echo "boot.sh.tpl setup complete"
set +x 
