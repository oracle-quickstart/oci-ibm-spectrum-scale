#!/bin/bash

set -x

source /tmp/gpfs_env_variables.sh

# Only on installerNode
echo "$thisHost" | grep -q -w $installerNode
if [ $? -eq 0 ] ; then
  rm  /root/node.stanza
  qcount=1
  for hname in `cat /tmp/allnodehosts` ; do
    echo "$hname" | grep -q $nsdNodeHostnamePrefix
    if [ $? -eq 0 ] ; then
      if [ $qcount -le 5 ]; then
        echo "${hname}:quorum-manager" >> /root/node.stanza
        qcount=$((qcount+1))
      else
        echo "${hname}" >> /root/node.stanza
      fi
    fi
    echo "$hname" | grep -q $clientNodeHostnamePrefix
    if [ $? -eq 0 ] ; then
      echo "${hname}" >> /root/node.stanza
    fi
  done
  cat /root/node.stanza

  mmcrcluster -N node.stanza -r /usr/bin/ssh -R /usr/bin/scp -C ss-storage-cluster -A
  sleep 30s

  diskArray=(b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af ag)

  command="mmchlicense server --accept -N "
  for node in `seq 1 $nsdNodeCount`;
  do
    echo $node
    if [ $node -eq $nsdNodeCount ]; then
      # no comma at the end
      command="${command}${node}"
    else
      command="${command}${node},"
    fi
  done
  echo $command
  $command

  sleep 30s
  
  if [ $clientNodeCount -gt 0 ]; then
    startIndex=$((nsdNodeCount+1))
    endIndex=$((nsdNodeCount+clientNodeCount))
    command="mmchlicense client --accept -N  "
    for node in `seq $startIndex $endIndex`;
    do
      echo $node
      if [ $node -eq $endIndex ]; then
        # no comma
        command="${command}${node}"
      else
        command="${command}${node},"
      fi
    done
    echo $command
    $command
  else
    echo "No client nodes to configure"
  fi

  sleep 30s

  rm /tmp/nsd.stanza.sv*
  for poolIndex in `seq 1 $totalNsdNodePools`;
  do
    if [ $highAvailability = true ]; then
      if [ $((poolIndex % 2)) -eq 0  ]; then
        failureGroup=102
      else
        failureGroup=101
      fi
    fi

    setFileName="/tmp/nsd.stanza.sv${nsdNodesPerPool}.set${poolIndex}"
    rm $setFileName
    for i in `seq 1 $blockVolumesPerPool`;
    do
      if [ $((i % 2)) -eq 0 ]; then
        primaryServer="${nsdNodeHostnamePrefix}$((((poolIndex-1)*nsdNodesPerPool)+2))"
        secondaryServer="${nsdNodeHostnamePrefix}$((((poolIndex-1)*nsdNodesPerPool)+1))"
      else
        primaryServer="${nsdNodeHostnamePrefix}$((((poolIndex-1)*nsdNodesPerPool)+1))"
        secondaryServer="${nsdNodeHostnamePrefix}$((((poolIndex-1)*nsdNodesPerPool)+2))"
      fi

      if [ $highAvailability = false ] && ([ $metadataReplica -gt 1 ] || [ $dataReplica -gt 1 ]); then
        echo $i
        if [ $((i % 2)) -eq 0 ]; then
          failureGroup=102
        else
          failureGroup=101
        fi
      else
        failureGroup=100
      fi

      setFileName="/tmp/nsd.stanza.sv${nsdNodesPerPool}.set${poolIndex}"
      echo " " >> $setFileName
      echo "%nsd: nsd=nsd$((((poolIndex-1)*blockVolumesPerPool)+i))" >> $setFileName
      echo "device=/dev/oracleoci/oraclevd${diskArray[(($i-1))]}" >> $setFileName
      echo "servers=$primaryServer,$secondaryServer" >> $setFileName
      echo "usage=dataAndMetadata" >> $setFileName
      echo "pool=system" >> $setFileName
      echo "failureGroup=$failureGroup" >> $setFileName
    done

  done

  #Create the NSDs from all NSD stanza files.
  for poolIndex in `seq 1 $totalNsdNodePools`;
  do
    echo "mmcrnsd -F /tmp/nsd.stanza.sv${nsdNodesPerPool}.set${poolIndex}  "
    mmcrnsd -F /tmp/nsd.stanza.sv${nsdNodesPerPool}.set${poolIndex}
    sleep 15s
  done

  mmchconfig maxblocksize=16M,maxMBpS=6250,numaMemoryInterleave=yes,tscCmdPortRange=60000-61000,workerThreads=1024
  # Change these values based on VM/BM shape. The below are for BM shape.
  #  mmchconfig pagepool=128G,maxFilesToCache=5M -N nsdNodes
  #  mmchconfig pagepool=64G,maxFilesToCache=1M -N clientNodes



  mmstartup -N nsdNodes
  while [ `mmgetstate -a | grep "active" | wc -l` -ne $((nsdNodeCount)) ] ; do echo "waiting for server nodes of cluster to start ..." ; sleep 10s; done;

  mmumount fs1 -a
  sleep 15s
  mmmount fs1 -a
  sleep 15s

  if [ $clientNodeCount -gt 0 ]; then
    mmstartup -N clientNodes
    while [ `mmgetstate -a | grep "active" | wc -l` -ne $((nsdNodeCount + clientNodeCount)) ] ; do echo "waiting for client nodes of cluster to start ..." ; sleep 10s; done;
  fi

  # Consolidate, since both failure groups needs to be in the same file, for the command the work.
  rm /tmp/nsd.stanza.sv${nsdNodesPerPool}.consolidated
  for poolIndex in `seq 1 $totalNsdNodePools`;
  do
    echo "consolidating the files... /tmp/nsd.stanza.sv${nsdNodesPerPool}.set${poolIndex} into /tmp/nsd.stanza.sv${nsdNodesPerPool}.consolidated "
    cat /tmp/nsd.stanza.sv${nsdNodesPerPool}.set${poolIndex} >> /tmp/nsd.stanza.sv${nsdNodesPerPool}.consolidated
    sleep 15s
  done

  # Create file system
  mmcrfs fs1  -F /tmp/nsd.stanza.sv${nsdNodesPerPool}.consolidated -B $blockSize -m $metadataReplica -M 2 -r $dataReplica -R 2
  sleep 60s

  mmrestripefs fs1 -b

  mmlsnsd
  mmlsfs fs1
  mmlsdisk fs1 -L

  mmmount fs1 -a
  sleep 15s
  df -h

  ### CES Nodes
  ## mmaddnode needs to be ran on a node which is already part of the cluster
  # Step.  Assign the quorum role to one of protocol node and the manager role to both nodes.
  for node in `cat /tmp/cesnodehosts` ; do
    mmaddnode -N $node
    mmchlicense server --accept -N $node
    mmchnode --manager -N $node
    mmstartup -N $node
  done
  while [ `mmgetstate -a  | grep "$cesNodeHostnamePrefix" | grep "active" | wc -l` -lt $((cesNodeCount)) ] ; do echo "waiting for ces nodes of cluster to start ..." ; sleep 10s; done;


  # To ensure pmsensors is installed on all nodes.
  #   mmdsh -N all "rpm -qa | grep gpfs.gss.pmsensors"
  # To ensure pmcollector is installed on only GUI mgmt nodes.
  #   mmdsh -N all "rpm -qa | grep gpfs.gss.pmcollector"

  for node in `cat /tmp/mgmtguinodehosts` ; do
    mmaddnode -N $node
    mmchlicense client --accept -N $node
    # recommended - 32G,  if node has memory
    #mmchconfig pagepool=32G -N $node
    mmchconfig pagepool=10G -N $node
  done

  if [ $clientNodeCount -eq 0 ]; then
    mmauth genkey new
    mmauth update . -l AUTHONLY
    cp /var/mmfs/ssl/id_rsa.pub /home/opc/owningCluster_id_rsa.pub
    chown opc:opc /home/opc/owningCluster_id_rsa.pub

    # run the below on ss-server-1 node, after the ss-compute-only cluster is provisioned and you have the value of accessingClusterName and accessingCluster_id_rsa.pub file copied to ss-server-1 server. example:
    # filesystemName=fs1
    # accessingClusterName=ss-compute-only.fs.gpfs.oraclevcn.com
    # accessingClusterAuthPublicKeyFilePath=/home/opc/accessingCluster_id_rsa.pub
    # mmauth add $accessingClusterName -k $accessingClusterAuthPublicKeyFilePath
    # mmauth grant $accessingClusterName -f ${filesystemName}
  fi


fi

exit 0;


