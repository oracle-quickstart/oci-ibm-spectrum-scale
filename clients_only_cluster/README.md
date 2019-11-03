# Spectrum Scale - Clients Only Cluster on OCI
This Terrrafom template deploys a Spectrum Scale clients onlynodes cluster which is typically used in production to seperate the HPC client nodes who access a Spectrum Scale File System cluster (Storage Cluster).  Logically seperating the Client nodes cluster from Storage cluster allows customer to manage their HPC compute/client node clusters seperately from their Spectrum Scale Storage cluster.  

Since its very common in HPC world to only spin up/spin down a cluster, the above approach allows customer to install Spectrum Scale clients on their HPC client nodes and then remote mount the Spectrum Scale Storage cluster to access file system. 


## Client Only Nodes Cluster architecture

### Single AD 
![](../images/network_shared_disk_server_model/X01a-single-AD-architecture.png)


## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).


## Clone the Terraform template
Now, you'll want a local copy of this repo.  You can make that with the commands:

    git clone https://github.com/oracle/oci-quickstart-ibm-spectrum-scale.git
    cd oci-quickstart-ibm-spectrum-scale/clients_only_cluster
    ls



## Update variables.tf file (optional)
This is optional, but you can update the variables.tf to change compute shapes to use, # of client nodes  and various other values. 




## Deployment & Post Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan
        terraform apply 


## Terraform apply - output 

![](../images/network_shared_disk_server_model/X02-tf-apply.png)

## Output for various GPFS commands

![](../images/network_shared_disk_server_model/X03-mm-commands.png)


