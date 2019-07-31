#!/bin/bash

set -x 

IBMSSVERSION="5.0.2.0"
cd /usr/lpp/mmfs/${IBMSSVERSION}/installer/

CMD="./spectrumscale install"
eval "$CMD"
while [ $? -ne 0 ] ; do
        eval "$CMD"
done;

# ntp
# ./spectrumscale config ntp -e on -s 10.0.2.8,10.0.2.6 

CMD="./spectrumscale deploy --precheck"
eval "$CMD"
while [ $? -ne 0 ] ; do
        eval "$CMD"
done;

CMD="./spectrumscale deploy"
eval "$CMD"
while [ $? -ne 0 ] ; do
        eval "$CMD"
done;

# Update Max inodes and preallocated to be approx 70% of max.
/usr/lpp/mmfs/bin/mmchfs fs1 --inode-limit 1500K:1100K


echo "Print cluster information..."
/usr/lpp/mmfs/bin/mmlscluster ; /usr/lpp/mmfs/bin/mmlsnsd -L ; /usr/lpp/mmfs/bin/mmlsdisk fs1 -L ; /usr/lpp/mmfs/bin/mmgetstate -a

echo "NSD and Failure Group Details..."
less /var/log/messages | grep "\-fg "
