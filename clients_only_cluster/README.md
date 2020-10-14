# Spectrum Scale - Clients Only Cluster on OCI
This Terrrafom template deploys a Spectrum Scale clients only cluster which is typically used in production to seperate the client/compute nodes who access a Spectrum Scale File System cluster (Storage Cluster).  Keeping the Client nodes Spectrum Scale cluster seperate from Spectrum Scale Storage cluster allows customers to manage their compute/client node clusters seperately from their Spectrum Scale Storage cluster.  Also there could be multiple client clusters accessing a single Storage cluster.  

Since its very common in HPC world to spin up/spin down a compute cluster, the above approach allows customer to install Spectrum Scale clients on their HPC client nodes and then remote mount the Spectrum Scale Storage cluster to access file system. 

Note:  This template assumes the Storage Spectrum Scale cluster was already created and this "clients_only_cluster" will not provision any server nodes or storage devices.  For more information on how to create "Storage Spectrum Scale cluster", refer to this link:  [Storage Spectrum Scale cluster](https://github.com/oracle-quickstart/oci-ibm-spectrum-scale/tree/master/network_shared_disk_server_model).


## Client Only Nodes Cluster architecture
Given below are architecture diagram which show both the Client Only Spectrum Scale cluster and Storage cluster, but this template will only provision/deploy the IaaS resources for "clients_only_cluster" and install/configure Spectrum Scale binaries.   


### Multi Cluster Spectrum Scale  
![](../images/multi_cluster_spectrum_scale/01_multi_cluster_spectrum_scale_architecture.png)

### Multi Cluster Spectrum Scale with VCN Peering
![](../images/multi_cluster_spectrum_scale/02_multi_cluster_spectrum_scale_vcn_peering_architecture.png)


## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).


## Clone the Terraform template
Now, you'll want a local copy of this repo.  You can make that with the commands:

    git clone https://github.com/oracle/oci-quickstart-ibm-spectrum-scale.git
    cd oci-quickstart-ibm-spectrum-scale/clients_only_cluster
    ls



## Update variables.tf file (optional)
This is optional, but you can update the variables.tf to change compute shapes to use, # of client nodes  and various other values. 
Note:  A minimum of 3 client nodes are required to maintain quorum in a cluster.  There are ways to overcome this requirement for production, but that's not covered in this deployment template. 



## Deployment & Post Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan
        terraform apply 


## Post Deploy Steps 
Once the "clients_only_cluster" is deployed,  there are some post deploy steps to establish authentication between the two clusters and to get the filesystem mounted on client/compute nodes.  

TODO - Steps
