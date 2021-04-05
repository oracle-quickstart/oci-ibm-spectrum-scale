#!/bin/bash
set -x
echo "Configure ces nodes ..."

source /tmp/gpfs_env_variables.sh


firstNode=`head -n 1 /tmp/cesnodehosts`
echo $firstNode
mmchnode --quorum -N $firstNode

mmlscluster
mmlslicense

# Step 4. Create the fileset for cesSharedRoot.
mmcrfileset fs1 cesSharedRoot
sleep 10s
mmlinkfileset fs1 cesSharedRoot -J /gpfs/fs1/cesSharedRoot
sleep 10s

# Step 5. Configure the cesSharedRoot.
mmchconfig cesSharedRoot=/gpfs/fs1/cesSharedRoot
sleep 10s
chmod 0755 /gpfs/fs1/cesSharedRoot

# Step 5. Change the file system ACL semantic.
sleep 10s
mmchfs fs1 -k nfs4

# Step 6. Restart the GPFS service.
sleep 10s
mmshutdown -a
sleep 20s
mmstartup -a

totalNodeCount=`cat /tmp/allnodehosts | wc -l `
echo $totalNodeCount
while [ `mmgetstate -a | grep "active" | wc -l` -lt $((totalNodeCount - mgmtGuiNodeCount)) ] ; do echo "waiting for all nodes of cluster to start ..." ; sleep 10s; done;


# Step 7. Assign the CES role to the nodes.
allCesNodes=`cat /tmp/cesnodehosts | paste -s -d, - `
echo $allCesNodes
mmchnode --ces-enable -N $allCesNodes
sleep 10s

mmlscluster --ces

index=0
cesVipList=""
for node in `cat /tmp/cesnodehosts` ; do
  vip=`mmdsh -N $node "cat /tmp/ces_vip_ips"  | grep "$node"  | gawk -F":" '{ print $2 }' `
  vip=`echo $vip | sed -e 's/^[[:space:]]*//'`
  if [ $index -eq 0 ]; then
    cesVipList="${vip}"
  else
    cesVipList="${cesVipList},${vip}"
  fi
  index=$((index+1))
done
echo $cesVipList

# Step 8. Add the VIPs to the CES IP address pool.
# mmces address add --ces-ip 10.0.9.4,10.0.9.5
mmces address add --ces-ip $cesVipList

mmlscluster --ces

# Step 9.  Configure the parameters for protocol (CES) nodes.
mmchconfig pagepool=4G -N cesNodes
# For BM shape
#mmchconfig pagepool=128G -N cesNodes
mmchconfig workerThreads=2048 -N cesNodes
mmchconfig maxFilesToCache=5M -N cesNodes

# Step 10. Install necessary RPMs for the protocol nodes.
mmdsh -N cesNodes "yum -y install gpfs.nfs-ganesha gpfs.nfs-ganesha-gpfs gpfs.nfs-ganesha-utils gpfs.smb gpfs.pm-ganesha"

# Step 11. Enabling the NFS/SMB service on the protocol nodes.
mmces service enable NFS
mmces service enable SMB

mmces service list --all
# Enabled services: NFS SMB
# ss-ces-nic1-1.privateb0.gpfs.oraclevcn.com:  NFS is running, SMB is running
# ss-ces-nic1-2.privateb0.gpfs.oraclevcn.com:  NFS is running, SMB is running


# Step 12. Configure the local user authentication.
mmuserauth service create --data-access-method file --type userdefined
mmuserauth service list

# Step 13. Configure the NFS domain (for NFSv4).
mmnfs config change DOMAINNAME=gpfs.oraclevcn.com
mmnfs config change IDMAPD_DOMAIN=GPFS.ORACLEVCN.COM


# Step 14. Create a NFS export.
mmcrfileset fs1 gpfsHome
sleep 5s
mmlinkfileset fs1 gpfsHome -J /gpfs/fs1/home

# CES NODE ONLY - root@ss-ces-1
mkdir -p /gpfs/fs1/home
chmod 755 /gpfs/fs1/home
mmnfs export add /gpfs/fs1/home --client "*(Access_Type=RW,Squash=no_root_squash,SecType=sys)"
mmnfs export list

mmnfs export list --nfsdefs /gpfs/fs1/home

# Step 15. Create a SMB export.
mmsmb export add gpfsHome /gpfs/fs1/home/%U
mmsmb export list

# Step 16. Create a local user account on all protocol nodes (for local user authentication) – uid/gid has tp be matched on all protocol nodes as well as the NFS clients.
# [root@ss-ces-1 ~]#
for node in `cat /tmp/cesnodehosts` ; do
  mmdsh -N $node "groupadd -g 1001 demo"
  mmdsh -N $node "useradd -u 1001 -g demo demo0143"
  mmdsh -N $node "echo -e \"demo0143\ndemo0143\" | passwd demo0143"
done

# Step 17. Create local computer object and user account (for SMB).
# [root@ss-ces-1 ~]#
/usr/lpp/mmfs/bin/net conf setparm global "netbios name" "SSCES"
echo -e "demo0143\ndemo0143" | /usr/lpp/mmfs/bin/smbpasswd -a demo0143
# New SMB password:
# Retype new SMB password:
# Added user demo01.

# On [root@ss-ces-1 ~]#
/usr/lpp/mmfs/bin/pdbedit -L -v

# Step 18. Create the export directory and assign appropriate ownership and permission.
# as [root@ss-ces-1 ~]#
mkdir -p /gpfs/fs1/home/demo0143
chown demo0143:demo /gpfs/fs1/home/demo0143
chmod 700 /gpfs/fs1/home/demo0143


# Step 19. Create the local user account on the NFS client – uid/gid has to be matched with the one from the protocol nodes.
# on [root@bastion-1 ~]#
# groupadd -g 1001 demo
# useradd -u 1001 -g demo demo01
# echo -e "demo01\ndemo01" | passwd demo01

# So…VIP is not working. Without using the VIP, I can mount the NFS share using VNIC ip of primary NIC and 1st VNIC on it:
# [root@bastion-1 ~]#
## mount -t nfs 10.0.9.3:/gpfs/fs1/home /mnt
# But without VIP, there is no fault tolerant.

## SMB validation
# on Windows client - use windows explorer.  Use ces node primary NIC ip (not VIP)
#      \\10.0.9.2\gpfsHome
# At login prompt enter below info.  (not: \\SSCES\demo01,  only demo01)
#      Login: demo01
#      Password: demo01  (or password set in the configure_ces.sh file)


