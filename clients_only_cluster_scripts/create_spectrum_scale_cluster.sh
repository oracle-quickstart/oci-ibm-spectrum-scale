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
      echo "${hname}:quorum-manager" >> /root/node.stanza
    else
      echo "${hname}" >> /root/node.stanza
    fi
    count=$((count+1))
  done
  cat /root/node.stanza

  mmcrcluster -N node.stanza -r /usr/bin/ssh -R /usr/bin/scp -C ss-client-only.privateb2.ibmssvcnv3.oraclevcn.com -A
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



  mmchconfig maxblocksize=16M,maxMBpS=6250,numaMemoryInterleave=yes,tscCmdPortRange=60000-61000,workerThreads=1024
# mmchconfig pagepool=128G,maxFilesToCache=5M -N nsdNodes
# mmchconfig pagepool=64G,maxFilesToCache=1M -N clientNodes
  mmchconfig pagepool=64G,maxFilesToCache=1M -N all




mmstartup -a
while [ `mmgetstate -a | grep "active" | wc -l` -lt $((clientNodeCount)) ] ; do echo "waiting for client nodes of cluster to start ..." ; sleep 10s; done;


  mmlscluster
  mmlsnodeclass --all

fi

exit 0;


