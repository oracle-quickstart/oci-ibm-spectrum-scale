#!/bin/bash
## cloud-init bootstrap script

set -x 

THIS_FQDN=`hostname --fqdn`
THIS_HOST=$${THIS_FQDN%%.*}

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
#cp /etc/resolv.conf /etc/resolv.conf.backup
#rm -f /etc/resolv.conf
#echo "search ${PrivateSubnetsFQDN}" > /etc/resolv.conf
#echo "nameserver 169.254.169.254" >> /etc/resolv.conf

#######################################################"

mv /etc/yum.repos.d/epel.repo  /etc/yum.repos.d/epel.repo.disabled
mv /etc/yum.repos.d/epel-testing.repo  /etc/yum.repos.d/epel-testing.repo.disabled
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config


wget ftp://ftp.icm.edu.pl/vol/rzm3/linux-scientificlinux/7.5/x86_64/updates/security/kernel-headers-3.10.0-862.11.6.el7.x86_64.rpm
wget ftp://ftp.icm.edu.pl/vol/rzm3/linux-slc/centos/7.1.1503/updates/x86_64/Packages/kernel-devel-3.10.0-862.11.6.el7.x86_64.rpm
yum install cpp gcc gcc-c++ -y
yum erase kernel-headers-3.10.0 -y 
yum install kernel-headers-3.10.0-862.11.6.el7.x86_64.rpm -y 
yum install kernel-devel-3.10.0-862.11.6.el7.x86_64.rpm -y
yum install gcc gcc-c++ -y 



mv /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
service sshd restart


mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys


touch /tmp/complete


## To be ran on 1 of the nodes of the cluster.  We will assume node1.  

cd /tmp
wget  https://objectstorage.us-phoenix-1.oraclecloud.com/n/intmahesht/b/pinkesh/o/Scale_dme_install-5.0.2.0_x86_64.tar.gz
## For some unknown reason, the below curl does not work. 
# curl -f -s https://objectstorage.us-phoenix-1.oraclecloud.com/n/intmahesht/b/pinkesh/o/Scale_dme_install-5.0.2.0_x86_64.tar.gz  -o /tmp/Scale_dme_install-5.0.2.0_x86_64.tar.gz --retry 0 --retry-max-time 60

tar -xzvf /tmp/Scale_dme_install-5.0.2.0_x86_64.tar.gz
cd /usr/lpp/mmfs/5.0.2.0/installer/
sudo ./spectrumscale setup -s `hostname -i` -i /home/opc/.ssh/id_rsa

## Node1 as Admin Node
sudo ./spectrumscale -v  node add ibm-ss-server-1 -a

## Add Client Nodes
sudo ./spectrumscale -v  node add ibm-ss-client-1

## Add NSD Nodes
sudo ./spectrumscale -v  node add ibm-ss-server-1 -n
sudo ./spectrumscale -v  node add ibm-ss-server-2 -n
sudo ./spectrumscale -v  node add ibm-ss-server-3 -n

## Add Node3 as GUI node.  It requires the Node3 to be also Admin Node
sudo ./spectrumscale -v  node add ibm-ss-server-3 -g
sudo ./spectrumscale -v  node add ibm-ss-server-3 -a

## To see the list of Nodes and their configuration
# sudo ./spectrumscale node list

## Add Block storage devices as NSDs
## Standalone mode.  No Secondary. 
sudo ./spectrumscale -v nsd add /dev/sdb -p ibm-ss-server-1
sudo ./spectrumscale -v nsd add /dev/sdb -p ibm-ss-server-2
sudo ./spectrumscale -v nsd add /dev/sdb -p ibm-ss-server-3

## To see the list of NSDs
# sudo ./spectrumscale nsd list

## To see the filesystem list 
# sudo ./spectrumscale filesystem list

## Change name of filesystem for the NSD's
sudo ./spectrumscale nsd modify nsd1 -fs filesystem_1
sudo ./spectrumscale nsd modify nsd2 -fs filesystem_1
sudo ./spectrumscale nsd modify nsd3 -fs filesystem_1

## Update the Block Size to 256K and change mount point to /gpfs/gpfs1
sudo ./spectrumscale filesystem modify filesystem_1 -B 256K -m /gpfs/gpfs1

















echo "boot.sh.tpl setup complete"
set +x 
