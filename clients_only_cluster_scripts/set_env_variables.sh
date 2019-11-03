
echo "
version=\"$version\"
downloadUrl=\"$downloadUrl\"
sshPrivateKey=\"$sshPrivateKey\"
sshPublicKey=\"$sshPublicKey\"
clientNodeCount=\"$clientNodeCount\"
clientNodeHostnamePrefix=\"$clientNodeHostnamePrefix\"
gpfsMountPoint=\"$gpfsMountPoint\"
highAvailability=\"$highAvailability\"
installerNode=\"$installerNode\"
vcnFQDN=\"$vcnFQDN\"
privateBSubnetsFQDN=\"$privateBSubnetsFQDN\"
companyName=\"$companyName\"
companyID=\"$companyID\"
countryCode=\"$countryCode\"
emailaddress=\"$emailaddress\"
" > /tmp/gpfs_env_variables.sh

# we might need this for BM shapes for core OS services to be ready
sleep 60s

