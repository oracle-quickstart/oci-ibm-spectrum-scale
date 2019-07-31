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

GPFSMGMTGUINODECOUNT="${GPFSMgmtGUINodeCount}"
GPFSMGMTGUINODEHOSTNAMEPREFIX="${GPFSMgmtGUINodeHostnamePrefix}"

BLOCKSIZE="${BlockSize}"
DATAREPLICA="${DataReplica}"
GPFSMOUNTPOINT="${GpfsMountPoint}"
SharedDataDiskCount="${SharedDataDiskCount}"
DISKPERNODE=$SharedDataDiskCount
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
#echo "search ${PrivateSubnetsFQDN}" > /etc/resolv.conf
#echo "nameserver 169.254.169.254" >> /etc/resolv.conf

echo `hostname` | grep -q $MGMTGUINODEHOSTNAMEPREFIX
if [ $? -eq 0 ] ; then
  echo "search ${PrivateBSubnetsFQDN}" > /etc/resolv.conf
  echo "nameserver 169.254.169.254" >> /etc/resolv.conf
else 
  echo "search ${PrivateBSubnetsFQDN} ${PrivateSubnetsFQDN} " > /etc/resolv.conf
  echo "nameserver 169.254.169.254" >> /etc/resolv.conf
fi


#######################################################"
#######################################################"

#######################################################"

KERNALVERSION=`uname -a  | gawk -F" " '{ print $3 }' | sed "s|.x86_64||g"`
sudo yum install kernel-devel-$KERNALVERSION  -y
yum install kernel-headers-$KERNALVERSION -y 
yum install gcc gcc-c++ -y 


cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
service sshd restart


mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys


echo "export PATH=$PATH:/usr/lpp/mmfs/bin" >> ~/.bash_profile

cd /root/.ssh/; cat id_rsa.pub >> authorized_keys ; cd - 

SecondNICDomainName=$${THIS_FQDN#*.*} ; echo $SecondNICDomainName;
echo "Doing nslookup for nodes"
ct=1
if [ $SERVERNODECOUNT -gt 0 ]; then
        while [ $ct -le $SERVERNODECOUNT ]; do
                nslk=`nslookup $SERVERNODEHOSTNAMEPREFIX$${ct}.$SecondNICDomainName`
                ns_ck=`echo -e $?`
                if [ $ns_ck = 0 ]; then
                        hname=`nslookup $SERVERNODEHOSTNAMEPREFIX$${ct}.$SecondNICDomainName | grep Name | gawk '{print $2}'`
                        echo "$hname" >> /tmp/servernodehosts;
                        echo "$hname" >> /tmp/allnodehosts;
                        if [ $ct -le 2 ]; then
				echo "$hname" >> /tmp/adminnodehosts;
    				echo "$hname" >> /tmp/guinodehosts;
			fi
                        ct=$((ct+1));
                else
                        # sleep 10 seconds and check again - infinite loop
                        echo "Sleeping for 10 secs and will check again for nslookup $SERVERNODEHOSTNAMEPREFIX$${ct}.$SecondNICDomainName"
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



touch /tmp/complete
echo "cloud-init setup complete"
set +x

exit 0 
