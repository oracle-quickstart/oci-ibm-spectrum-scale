#!/bin/bash

set -x

source /tmp/gpfs_env_variables.sh


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

