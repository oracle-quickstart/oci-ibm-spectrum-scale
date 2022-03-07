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
      if [ $count -eq 2 ] ; then
        echo "${hname}" | grep -q $quorumNodeHostnamePrefix
        if [ $? -eq 0 ] ; then
          echo "${hname}:quorum" >> /root/node.stanza
        else
          echo "${hname}:quorum-manager" >> /root/node.stanza
        fi
      else
        echo "${hname}:quorum-manager" >> /root/node.stanza
      fi
    else
      echo "${hname}" >> /root/node.stanza
    fi
    count=$((count+1))
  done
  cat /root/node.stanza

  mmcrcluster -N node.stanza -r /usr/bin/ssh -R /usr/bin/scp -C ss-direct-attached -A
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

mmlscluster
sleep 30s

/usr/lpp/mmfs/bin/mmstartup -a
while [ `mmgetstate -a | grep "active" | wc -l` -lt $((clientNodeCount + quorumNodeCount)) ] ; do echo "waiting for client nodes of cluster to start ..." ; sleep 10s; done;



diskArray=(b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af ag)

stanzaForNSDFileName="/tmp/nsd.stanza"
rm -rf $stanzaForNSDFileName

for i in `seq 1 $sharedDataDiskCount`;
do

if ([ $metadataReplica -gt 1 ] || [ $dataReplica -gt 1 ]); then
echo $i
if [ $((i % 2)) -eq 0 ]; then
failureGroup=102
else
failureGroup=101
fi
else
failureGroup=100
fi
echo $failureGroup

echo " " >> $stanzaForNSDFileName
echo "%nsd: nsd=nsd${i}" >> $stanzaForNSDFileName
echo "device=/dev/oracleoci/oraclevd${diskArray[(($i-1))]}" >> $stanzaForNSDFileName
echo "usage=dataAndMetadata" >> $stanzaForNSDFileName
echo "failureGroup=$failureGroup" >> $stanzaForNSDFileName
echo "pool=system" >> $stanzaForNSDFileName

done

if [ $quorumNodeCount -eq 1 ]; then
  echo " " >> $stanzaForNSDFileName
  echo "%nsd: nsd=nsdquorum" >> $stanzaForNSDFileName
  echo "device=/dev/oracleoci/oraclevd${diskArray[(($sharedDataDiskCount))]}" >> $stanzaForNSDFileName
  echo "servers=${quorumNodeHostnamePrefix}1" >> $stanzaForNSDFileName
  echo "usage=descOnly" >> $stanzaForNSDFileName
  echo "failureGroup=500" >> $stanzaForNSDFileName
  echo "pool=system" >> $stanzaForNSDFileName
fi


mmlsnodeclass --all

mmcrnsd -F $stanzaForNSDFileName
sleep 15s
/usr/lpp/mmfs/bin/mmlsnsd -X
/usr/lpp/mmfs/bin/mmlsnsd

mmcrfs fs1  -F $stanzaForNSDFileName -B $blockSize -m $metadataReplica -M 2 -r $dataReplica -R 2
sleep 60s

mmlsfs fs1
mmlsnsd
mmlsdisk fs1 -L

mmmount fs1 -a
sleep 15s
df -h

# Try - 2 FG and roundrobin the NSD in 2 FG , then try metadataReplica=2

fi

exit 0;


