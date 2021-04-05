##echo "$sshPrivateKey" > /root/.ssh/id_rsa
##echo "$sshPublicKey" > /root/.ssh/id_rsa.pub

while [ ! -f /home/opc/.ssh/id_rsa ]
do
  sleep 60s
  echo "Waiting for file to be copied by TF ..."
done

\cp /home/opc/.ssh/id_rsa* /root/.ssh/
if [ $? -ne 0 ]; then
  exit 1;
fi


chmod 600 /home/opc/.ssh/id_rsa*
chmod 640 /home/opc/.ssh/authorized_keys

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config

mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys
##cd /root/.ssh/; cat id_rsa.pub >> authorized_keys ; cd -
cat /root/.ssh/id_rsa.pub >> authorized_keys ;

sudo chmod 600 /root/.ssh/id_rsa*
sudo chmod 640 /root/.ssh/authorized_keys


find_cluster_nodes () {
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
domainName=${privateBSubnetsFQDN}
nodeType="nsd"
nodeHostnamePrefix=$nsdNodeHostnamePrefix
nodeCount=$nsdNodeCount
find_cluster_nodes

nodeType="client"
nodeHostnamePrefix=$clientNodeHostnamePrefix
nodeCount=$clientNodeCount
find_cluster_nodes

nodeType="ces"
nodeHostnamePrefix=$cesNodeHostnamePrefix
nodeCount=$cesNodeCount
find_cluster_nodes

nodeType="mgmtgui"
nodeHostnamePrefix=$mgmtGuiNodeHostnamePrefix
nodeCount=$mgmtGuiNodeCount
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

# passwordless ssh 
for host_fqdn in `cat /tmp/allnodehosts` ; do
  host=$host_fqdn
  do_ssh_keyscan
  host=${host_fqdn%%.*}
  do_ssh_keyscan
  host_ip=`nslookup $host_fqdn | grep "Address: " | gawk '{print $2}'`
  host=$host_ip
  do_ssh_keyscan
  echo "$host_ip ${host_fqdn} ${host_fqdn%%.*}" >> /etc/hosts
done ;
