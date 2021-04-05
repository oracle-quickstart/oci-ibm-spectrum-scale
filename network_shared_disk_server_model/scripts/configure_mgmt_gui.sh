#!/bin/bash
set -x
echo "Configure mgmt gui nodes ..."

source /tmp/gpfs_env_variables.sh


# Step 4.  Configure the pm collectors.
allMgmtGuiNodes=`cat /tmp/mgmtguinodehosts | paste -s -d, - `
mmperfmon config generate --collectors $allMgmtGuiNodes

# Step 5.  Enabling the performance monitoring feature.
mmchnode --perfmon -N all


mmperfmon config show
# Step 6. Add the zimon sensors for protocol (NFS/SMB).  Create following pm sensors configuration file:
OUT=/tmp/ces_sensors.cfg
cat <<EOF >$OUT
sensors = {
        # NFS Ganesha statistics
        name = "NFSIO"
        period = 1
        restrict = "cesNodes"
        type = "Generic"
}, {
        name = "SMBStats"
        period = 1
        restrict = "cesNodes"
        type = "Generic"
}, {
        name = "SMBGlobalStats"
        period = 1
        restrict = "cesNodes"
        type = "Generic"
}, {
        name = "CTDBStats"
        period = 1
        restrict = "cesNodes"
        type = "Generic"
}, {
        name = "CTDBDBStats"
        period = 1
        restrict = "cesNodes"
        type = "Generic"
}
EOF

# Add the sensors to existing sensors.
mmperfmon config add --sensors $OUT


# Happens automatically
# Step 7.  Federate the pm collectors.  Modify following lines in /opt/IBM/zimon/ZIMonCollector.cfg file on both pm collector nodes.
#[root@ss-mgmt-gui-1 ~]
# cat /opt/IBM/zimon/ZIMonCollector.cfg
#...
#...
#peers = {
#        host = "ss-mgmt-gui-1.privateb0.gpfs.oraclevcn.com"
#        port = "9085"
#}, {
#        host = "ss-mgmt-gui-2.privateb0.gpfs.oraclevcn.com"
#        port = "9085"
#}
#...


# Step 8.  Restart the pm collector and pm sensors services.
mmdsh -N $allMgmtGuiNodes "systemctl restart pmcollector"
mmdsh -N all "systemctl restart pmsensors"

# Step 9.  Enable and start the gpfsgui services.
# Starting version 5.0.5.0 or may be 5.0.4.0, this change is required.
mmdsh -N $allMgmtGuiNodes 'sed -i "s|java -XX|java -Xmx2048m -XX|g" /usr/lib/systemd/system/gpfsgui.service'
mmdsh -N $allMgmtGuiNodes "systemctl stop gpfsgui.service"
mmdsh -N $allMgmtGuiNodes "systemctl start gpfsgui.service"
mmdsh -N $allMgmtGuiNodes "systemctl enable gpfsgui.service"


# Step 10.  Create the GUI admin account.
mmdsh -N $allMgmtGuiNodes "/usr/lpp/mmfs/gui/cli/initgui"

# Run on [root@ss-mgmt-gui-1 ~]
echo -e "passw0rd\npassw0rd" | /usr/lpp/mmfs/gui/cli/mkuser admin -g SecurityAdmin
# EFSSG1007A Enter password for User :
# EFSSG0225I Repeat the password:
# EFSSG0019I The user admin has been successfully created.
# EFSSG1000I The command completed successfully.

# Step 11.  Start GPFS deamon.
mmstartup -N $allMgmtGuiNodes

while [ `mmgetstate -a  | grep "$mgmtGuiNodeHostnamePrefix" | grep "active" | wc -l` -lt $((mgmtGuiNodeCount)) ] ; do echo "waiting for mgmt gui nodes of cluster to start ..." ; sleep 10s; done;


# To see master GUI node.  You can run this on all MGMT GUI nodes, if you have more than 1
# One of them will show "Master GUI Node" , other will show just "GUI Node"
/usr/lpp/mmfs/gui/cli/lsnode

# From your local machine, create an ssh tunnel using bastion host as the intermediatory to reach the GUI on the GUI Mgmt node which is in private subnet.

#   ssh -i ~/.ssh/oci -N -L localhost:11443:10.0.3.5:443 opc@129.146.189.209

#   bastion = 129.146.189.209
#   Remote node (private) =  10.0.6.5
#   Assuming a GUI running on default 443 port on 10.0.6.5

#   Using above command,  I am connecting my MacBook (localhost) on port 11443 to create a tunnel to 10.0.6.5:443 and its via the bastion host.  Hence we do ssh to the bastion host above.

#   Open browser locally and use https (not http):  https://localhost:11443

# Generate file using any client node and see the throughput using GUI.
#   dd if=/dev/zero of=/gpfs/fs1/test.file bs=1024k count=100000
#   dd if=/dev/zero of=/gpfs/fs1/test.file bs=1024k count=1000000


#Other commands - not required for deployment
## mmperfmon query compareNodes cpu
## systemctl status gpfsgui
## cd /opt/IBM/zimon
## more ZIMonCollector.cfg
## echo "get metrics mem_active, cpu_idle, gpfs_ns_read_ops, last 10 bucket_size 1" | ./zc 127.0.0.1
## more /etc/gss/mech.d/gssproxy.conf
## more /etc/gssproxy/gssproxy.conf
## /usr/lpp/mmfs/gui/cli/lsnode

