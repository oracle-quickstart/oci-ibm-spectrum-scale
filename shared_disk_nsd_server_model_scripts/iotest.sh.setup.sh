#!/bin/bash

echo "Run this on GPFS client nodes as opc user, not root" 

cd ~/
wget http://ftp.sas.com/techsup/download/ts-tools/external/SASTSST_UNIX_installation.sh
chmod 744 SASTSST_UNIX_installation.sh

mkdir -p ~/sas
./SASTSST_UNIX_installation.sh

# yes ~/sas 14

cd ~/sas
chmod 0555 iotest.sh
sudo chown -R opc:opc /gpfs/*


echo "./iotest.sh -i 1 -t /gpfs/fs1 -s 256 -b 1000000"
echo "256K block size,  data transfered is 256K * 1000000  = 25GB"

