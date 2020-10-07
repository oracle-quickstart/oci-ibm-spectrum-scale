
echo "
version=\"$version\"
downloadUrl=\"$downloadUrl\"
sshPrivateKey=\"$sshPrivateKey\"
sshPublicKey=\"$sshPublicKey\"
clientNodeCount=\"$clientNodeCount\"
clientNodeHostnamePrefix=\"$clientNodeHostnamePrefix\"
installerNode=\"$installerNode\"
vcnFQDN=\"$vcnFQDN\"
privateBSubnetsFQDN=\"$privateBSubnetsFQDN\"
" > /tmp/gpfs_env_variables.sh

# we might need this for BM shapes for core OS services to be ready
sleep 60s



