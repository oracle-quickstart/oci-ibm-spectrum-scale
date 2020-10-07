#!/bin/bash

set -x

source /tmp/gpfs_env_variables.sh


# Only on installerNode
echo "$thisHost" | grep -q -w $installerNode
if [ $? -eq 0 ] ; then
  rm  /root/node.stanza
  count=0
  for hname in `cat /tmp/allnodehosts` ; do
    if [ $count -lt 3 ] ; then
      echo "${hname}:quorum" >> /root/node.stanza
    else
      echo "${hname}" >> /root/node.stanza
    fi
    count=$((count+1))
  done
  cat /root/node.stanza

  mmcrcluster -N node.stanza -r /usr/bin/ssh -R /usr/bin/scp -C ss-compute-only -A
  sleep 30s

  count=0
  for hname in `cat /tmp/allnodehosts` ; do
    if [ $count -lt 3 ] ; then
      mmchlicense server --accept -N ${hname}
    else
      mmchlicense client --accept -N ${hname}
    fi
    count=$((count+1))
  done

  sleep 30s
  mmstartup -a
  while [ `mmgetstate -a | grep "active" | wc -l` -lt $((clientNodeCount)) ] ; do echo "waiting for client nodes of cluster to start ..." ; sleep 10s; done;

  mmlscluster
  mmlsnodeclass --all

  # https://www.ibm.com/support/knowledgecenter/STXKQY_5.0.5/com.ibm.spectrum.scale.v5r05.doc/bl1adv_admrmsec.htm
  mmauth genkey new
  mmauth update . -l AUTHONLY
  cp /var/mmfs/ssl/id_rsa.pub /home/opc/accessingCluster_id_rsa.pub
  chown opc:opc /home/opc/accessingCluster_id_rsa.pub

  # run the below on ss-compute-1 node, after the ss-compute-only cluster is provisioned and you have the value of accessingClusterName and accessingCluster_id_rsa.pub file copied to ss-server-1 server. example:
  # owningClusterName=ss-storage-cluster.storage.gpfs.oraclevcn.com
  # owningClusterAuthPublicKeyFilePath=/home/opc/owningCluster_id_rsa.pub
  # contactNodes are all NSD nodes.  node1,node2,node3
  # owningClusterContactNodes=ss-server-1.storage.gpfs.oraclevcn.com,ss-server-2.storage.gpfs.oraclevcn.com
  # filesystemName - name of the filesystem, eg: fs1 is the default in server only cluster.
  # filesystemName=fs1

##mmremotecluster add $owningClusterName -n $owningClusterContactNodes -k $owningClusterAuthPublicKeyFilePath

  # Only run these after this cluster (accessingCluster) information is configured on the owningCluster.
  # mmremotefs add remote${filesystemName} -f ${filesystemName} -C $owningClusterName -T /remote${filesystemName}
  # It needs to be manually mounted on each node
  # filesystemName=fs1 ; mmmount remote${filesystemName}


fi

exit 0;





