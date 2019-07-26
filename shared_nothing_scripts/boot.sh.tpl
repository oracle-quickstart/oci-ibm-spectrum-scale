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
DISKPERNODE="${DiskPerNode}"
DISKSIZE="${DiskSize}"
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


wget ftp://ftp.icm.edu.pl/vol/rzm3/linux-scientificlinux/7.5/x86_64/updates/security/kernel-headers-3.10.0-862.11.6.el7.x86_64.rpm
wget ftp://ftp.icm.edu.pl/vol/rzm3/linux-slc/centos/7.1.1503/updates/x86_64/Packages/kernel-devel-3.10.0-862.11.6.el7.x86_64.rpm
yum install cpp gcc gcc-c++ -y
yum erase kernel-headers-3.10.0 -y 
yum install kernel-headers-3.10.0-862.11.6.el7.x86_64.rpm -y 
yum install kernel-devel-3.10.0-862.11.6.el7.x86_64.rpm -y
yum install gcc gcc-c++ -y 



cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
service sshd restart


mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys


#cat /dev/zero | ssh-keygen -b 2048 -t rsa -q -N "" > /dev/null


echo "export PATH=$PATH:/usr/lpp/mmfs/bin" >> ~/.bash_profile

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
    				echo "$hname" >> /tmp/guinodehosts;
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


#if [ $SERVERNODECOUNT -gt 1 ] ; then 
#        ADMINNODELIST="$${SERVERNODEHOSTNAMEPREFIX}1 $${SERVERNODEHOSTNAMEPREFIX}2"
#else 
#	ADMINNODELIST="$${SERVERNODEHOSTNAMEPREFIX}1"
#fi 

# touch /tmp/complete

## To be ran on 1 of the nodes of the cluster.  We will assume node1.

echo "$THIS_HOST" | grep -q -w $INSTALLERNODE
if [ $? -eq 0 ] ; then

echo $IBMSSVERSION

cd /tmp
wget  "$SOFTWAREDOWNLOADURL"  

while [ ! -f /tmp/Scale_dme_install-$${IBMSSVERSION}_x86_64.tar ]; 
do 
        sleep 5s
        echo "Waiting for file to download" 
done

tar -xvf /tmp/Scale_dme_install-$${IBMSSVERSION}_x86_64.tar

./Spectrum_Scale_Data_Management-$${IBMSSVERSION}-x86_64-Linux-install --silent

cd /usr/lpp/mmfs/$${IBMSSVERSION}/installer/


./spectrumscale setup -s `hostname -i` -i /root/.ssh/id_rsa

for x in `cat /tmp/adminnodehosts` ; do
	# Add Admin Nodes
	./spectrumscale -v  node add $x -a
done ;

ct=1
for x in `cat /tmp/computenodehosts` ; do
                if [ $ct -eq 1 ]; then
			# Make the first compute node to be a quorum node and nsd, so we can have descOnly disk on it. 
			./spectrumscale -v  node add $x -n -q
                        # Add desc only 50GB block volume. 
                        ./spectrumscale -v nsd add /dev/sdb -p $x -fs fs1 -fg 5 -u descOnly
		else
			# Add Client/Compute Nodes
        		./spectrumscale -v  node add $x
                fi
	ct=$((ct+1));
done ;


for x in `cat /tmp/servernodehosts` ; do
        # Add NSD Nodes 
        ./spectrumscale -v  node add $x -n -q -m
done ;

for x in `cat /tmp/guinodehosts` ; do
        # Add GUI Nodes
        ./spectrumscale -v  node add $x -g
done ;

# callhome setup
#./spectrumscale node add -c `head -n 1 /tmp/adminnodehosts` 
#echo "accept" | ./spectrumscale callhome config -n "$COMPANYNAME" -i "$COMPANYID" -e "$EMAILADDRESS" -cn "$COUNTRYCODE"
./spectrumscale callhome disable

./spectrumscale config gpfs -c ibmss

## To see the list of Nodes and their configuration
./spectrumscale node list


add_nvme_disk_as_nsd () {
        ct=0 ; nvme_disks=0; 
        nvme_disks=`ls /dev/ | grep nvme | grep n1 | sort | wc -l`
	nvme_meta_disks=0
        nvme_data_disks=0
        if [ $nvme_disks -gt 0 ]; then
                if [ $nvme_disks -gt 4 ]; then nvme_meta_disks=2;  else nvme_meta_disks=1; fi
                	nvme_data_disks=$((nvme_disks-nvme_meta_disks))
                	echo "nvme_disks = $nvme_disks"
                	echo "nvme_meta_disks = $nvme_meta_disks"
                	echo "nvme_data_disks = $nvme_data_disks"
                	for y in `seq 0 $((nvme_disks-1))` ; do
                        	if [ $y -ge $nvme_meta_disks ]; then u="dataOnly"; else u="metaDataOnly";  fi
                        	# Add block starage devices as NSDs.  Standalone mode.  No Secondary.
                        	./spectrumscale -v nsd add /dev/nvme$${y}n1 -p $x -fs fs1 -fg $fg -u $u
                	done ;
        fi
}

setFailureGroup () {
	if [ $DATAREPLICA -eq 1 ]; then	
		if [ $((nodect % 2)) -eq 0 ]; then fg=0; else fg=1; fi
	else
        	if [ $nodect -eq 0 ]; then
                	# We are using Subnet dns label to indirectly  determine the AZ and if the hostnames are not
                	# in the same subnet/AD, then set the failuregroup to different values.
                	FIRSTAD=`echo $x | gawk -F'.' '{ print $2 }'`;
              		fg=0;
                else
                	TEMP=`echo $x | gawk -F'.' '{ print $2 }'`;
                        if [ $TEMP = $FIRSTAD ]; then
                        	fg=0;
                        else
                                fg=1;
                        fi
		fi
	fi
}

add_blockvolume_disk_as_nsd () {
	if [ $DISKPERNODE -eq 0 -a  $nvme_disks -gt 0 -a $nvme_data_disks -eq 0 ]; then
                echo "# Not enough disks available to be data NSDs"
        else

		if [ $DISKPERNODE -gt 0 -a  $nvme_disks -gt 0 ]; then
                	# all BVs are data only NSDs
                	u="dataOnly";
		fi
        	if [ $DISKPERNODE -gt 0 -a  $nvme_disks -eq 0 ]; then
               		# BVs are meta & data NSDs combined
                	u="dataAndMetadata";
        	fi
		ct=0;
        	for y in {b..z} ; do
        		if [ $ct -lt $DISKPERNODE ]; then
	                        ./spectrumscale -v nsd add /dev/sd$${y} -p $x -fs fs1 -fg $fg -u $u
	                        ct=$((ct+1));
	                else
        	                break;
                	fi
        	done;
        fi
}

echo "DISKPERNODE=$DISKPERNODE"
echo "DATAREPLICA=$DATAREPLICA"
echo "SERVERNODECOUNT=$SERVERNODECOUNT"
fg=-1
nodect=0
for x in `cat /tmp/servernodehosts` ; do

	setFailureGroup
        add_nvme_disk_as_nsd
        add_blockvolume_disk_as_nsd
	nodect=$((nodect+1));
done ;






## Update the Block Size to 256K and change mount point to /gpfs/gpfs1
./spectrumscale filesystem modify fs1 -B $BLOCKSIZE -m $GPFSMOUNTPOINT -MR 2 -R 2 -r $DATAREPLICA -mr $METADATAREPLICA

./spectrumscale config gpfs --ephemeral_port_range 60000-61000

## To see the list of NSDs
./spectrumscale nsd list

## To see the filesystem list 
./spectrumscale filesystem list


# Do this first or else the below loop will wait infinitely.
touch /tmp/complete

for x_fqdn in `cat /tmp/allnodehosts` ; do
	while [ ! `ssh $x_fqdn "if [ -f /tmp/complete ]; then echo \"true\"; else echo \"false\" ; fi"` = "true" ]; do
	sleep 20s;
	done;
done;



exit 0


# ntp
# ./spectrumscale config ntp -e on -s 10.0.2.8,10.0.2.6 


else	
	# To indicate on rest of the nodes,  that boot cloud init is complete. 
	touch /tmp/complete
# end if loop
fi


echo "boot.sh.tpl setup complete"
set +x 
