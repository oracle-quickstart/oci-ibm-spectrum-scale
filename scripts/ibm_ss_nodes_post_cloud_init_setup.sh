#/bin/bash

set -x

uname -a

sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo service sshd restart
sudo mv /root/.ssh/authorized_keys /root/.ssh/authorized_keys.backup
sudo cp /home/opc/.ssh/authorized_keys /root/.ssh/authorized_keys

echo "Content of /root/.ssh/authorized_keys.backup"
cat /root/.ssh/authorized_keys.backup 


echo "Content of /root/.ssh/authorized_keys"
cat /root/.ssh/authorized_keys

echo "setup complete"
set +x


