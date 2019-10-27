#!/bin/bash

set -x

source /tmp/gpfs_env_variables.sh

###############################
### passwordless ssh setup ###
##############################
#for x_fqdn in `cat /tmp/allnodehosts` ; do
#
#    if [ -z `ssh-keygen -F $x_fqdn` ]; then
#        ssh-keyscan -H $x_fqdn > /tmp/keyscan
#        cat /tmp/keyscan | grep "ssh-rsa"
#        while [ $? -ne 0 ]; do
#                  sleep 10s;
#                  ssh-keyscan -H $x_fqdn > /tmp/keyscan
#                  cat /tmp/keyscan | grep "ssh-rsa"
#        done;
#        ssh-keyscan -H $x_fqdn >> ~/.ssh/known_hosts
#    fi
#
#    x=${x_fqdn%%.*}
#    if [ -z `ssh-keygen -F $x` ]; then
#        ssh-keyscan -H $x > /tmp/keyscan
#        cat /tmp/keyscan | grep "ssh-rsa"
#        while [ $? -ne 0 ]; do
#                  sleep 10s;
#                  ssh-keyscan -H $x > /tmp/keyscan
#                  cat /tmp/keyscan | grep "ssh-rsa"
#        done;
#        ssh-keyscan -H $x  >> ~/.ssh/known_hosts
#    fi
#
#    ip=`nslookup $x_fqdn | grep "Address: " | gawk '{print $2}'`
#    if [ -z `ssh-keygen -F $ip` ]; then
#        ssh-keyscan -H $ip > /tmp/keyscan
#        cat /tmp/keyscan | grep "ssh-rsa"
#        while [ $? -ne 0 ]; do
#                  sleep 10s;
#                  ssh-keyscan -H $ip > /tmp/keyscan
#                  cat /tmp/keyscan | grep "ssh-rsa"
#        done;
#        ssh-keyscan -H $ip  >> ~/.ssh/known_hosts
#    fi

#    # update /etc/hosts file on all nodes with ip, fqdn and hostname of all nodes
#    echo "$ip ${x_fqdn} $x" >> /etc/hosts
#done ;


###############################


# Build the GPFS potability layer.
/usr/lpp/mmfs/bin/mmbuildgpl
# have seen the above fail sometimes, hence the below loop
while [ $? -ne 0 ]; do
  sleep 10s;
  /usr/lpp/mmfs/bin/mmbuildgpl
done;


# Up date the PATH environmental variable.
echo -e '\nexport PATH=/usr/lpp/mmfs/bin:$PATH' >> ~/.bash_profile
source ~/.bash_profile

exit 0;

