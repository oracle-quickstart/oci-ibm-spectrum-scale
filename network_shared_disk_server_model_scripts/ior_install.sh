#!/bin/bash

set -x

# Installs all required packages.
install_pkgs()
{
    echo "no new package required for Beegfs"
    # yum -y install epel-release
    #yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs nfs-utils rpcbind mdadm wget python-pip openmpi openmpi-devel automake autoconf cpp gcc gcc-c++ binutils gcc-gfortran
}

install_ior()
{

cd /root

# Download  the latest source tar ball from https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.1.tar.bz2
#Configure and compile as normal user on one of compute node:
curl -O https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.1.tar.bz2
tar -jxvf openmpi-4.0.1.tar.bz2
cd openmpi-4.0.1
mkdir -p build
cd build
../configure --prefix=${filesystem_root}/openmpi-4.0.1
make all -j 8
make check
sudo make install

#To use RDMA mellanox card - use this:
##../configure --prefix=${filesystem_root}/openmpi-4.0.1 --with-mxm=/opt/mellanox/mxm --with-knem=/opt/knem-1.1.3.90mlnx1 --with-hcoll=/opt/mellanox/hcoll


# Setup the environment variables. Append following lines to ~/.bash_profile

echo "export MPI_HOME=${filesystem_root}/openmpi-4.0.1" >> /root/.bash_profile
echo 'export PATH=${MPI_HOME}/bin:$PATH' >> /root/.bash_profile
echo 'export MANPATH=${MPI_HOME}/share/man' >> /root/.bash_profile
echo 'export LD_LIBRARY_PATH=${MPI_HOME}/lib:${MPI_HOME}/lib/openmpi:$LD_LIBRARY_PATH' >> /root/.bash_profile

source /root/.bash_profile



    cd /root
    # curl command downloads, but tar to extract fails, hence using wget
    wget https://github.com/hpc/ior/releases/download/3.2.1/ior-3.2.1.tar.gz
    #Extract and compile the source:
    tar -zxvf ior-3.2.1.tar.gz
    cd ior-3.2.1
    ./configure --prefix=${filesystem_root}/ior-3.2.1
    make
    make install
    cd /root

    sudo chmod +777 ${filesystem_root}
}

filesystem_root=$1

# Check to see if the file system cluster was created and mounted on the clients.
while [ ! -f /tmp/mount.complete ]
do
  sleep 60s
  echo "Waiting for filesystem cluster creation to be completed..."
done

install_pkgs
install_ior

client_hostname_prefix="$3"
client_node_count="$2"
fs_mount_loc=$filesystem_root
vcn_name="$4"


for x in $(seq 1 1 $client_node_count); do
  echo "client-${x}.privateb0.${vcn_name}.oraclevcn.com  slots=24" >> ${fs_mount_loc}/hostsfile.cn.$client_node_count
  echo "client-${x}.privateb0.${vcn_name}.oraclevcn.com  slots=24" >> ${fs_mount_loc}/hostsfile.cn
done


echo "IOR START
fsync=1
intraTestBarriers=1
api=POSIX
reorderTasksRandom=1
verbose=0
filePerProc=1
interTestDelay=30
blockSize=10g
testFile = $filesystem_root/test
transferSize=2m
repetitions=1
RUN
IOR STOP" > ${filesystem_root}/ior.conf.cn.10g


echo "IOR START
fsync=1
intraTestBarriers=1
api=POSIX
reorderTasksRandom=1
verbose=0
filePerProc=1
interTestDelay=30
blockSize=10g
testFile = $filesystem_root/test
transferSize=2m
repetitions=1
RUN
IOR STOP" > ${filesystem_root}/ior.conf.cn

